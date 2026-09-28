{
  description = "git, wrapped with its config and delta integration baked in";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    wrappers = {
      url = "github:nix-community/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, wrappers, ... }:
    let
      inherit (nixpkgs) lib;

      forEachSystem =
        f:
        lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # The complete git wrapper (nix-wrapper-modules' own native git
      # module plus this repo's customization, including its own default
      # identity/credential store - see modules/module.nix), shared
      # between the home-manager module below and a bare package build.
      # Fully configured out of the box even with no caller-supplied
      # overrides at all - see modules/module.nix's
      # userName/userEmail/credentialStore defaults.
      wrapperModule = ./modules/module.nix;

      # Builds the same wrapped git both `lib.mkGit` (for external
      # callers) and `packages.default` (this flake's own standalone
      # build) use, so there's exactly one module list to keep in sync
      # instead of two.
      mkGit =
        {
          pkgs,
          # Override module.nix's own userName/userEmail/credentialStore
          # defaults (config.dotfiles.user.*/config.dotfiles.system.*)
          # when given; left alone (module.nix's defaults apply) when null.
          userName ? null,
          userEmail ? null,
          credentialStore ? null,
        }:
        wrappers.lib.evalPackage (
          [
            { inherit pkgs; }
            wrapperModule
          ]
          ++ lib.optional (userName != null) { config.userName = userName; }
          ++ lib.optional (userEmail != null) { config.userEmail = userEmail; }
          ++ lib.optional (credentialStore != null) { config.credentialStore = credentialStore; }
        );
    in
    {
      lib = {
        inherit mkGit;
      };

      # Drop-in home-manager module: `imports = [ git-wrapped.homeModules.default ];`
      # is the whole integration - exports GIT_CONFIG_GLOBAL so delta
      # (invoked directly, e.g. by lazygit) still sees the same config,
      # and wires up the fuzzy git pickers.
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          isWSL = config.dotfiles.system.isWsl;
          wrapper = config.wrappers.git;
          files = wrapper.wrapper.configuration.constructFiles;
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "git";
              value = wrapperModule;
            })
          ];

          # module.nix's own userName/userEmail/credentialStore defaults
          # are computed from a standalone, isolated evaluation of
          # config/default.nix alone (see their own defaultText) - they
          # never see this host's real dotfiles.user.*/dotfiles.system.*
          # overrides (set in hosts/*/default.nix), so they have to be
          # explicitly recomputed here from the live values and pushed
          # in, the same way `colors` is overridden in the other
          # pkgs/<name> packages.
          config.wrappers.git.userName = config.dotfiles.user.displayName;
          config.wrappers.git.userEmail = config.dotfiles.user.git.email;

          config.wrappers.git.credentialStore =
            if config.dotfiles.system.isDarwin then
              "keychain"
            else if config.dotfiles.desktop.gnome.enable then
              "secretservice"
            else if isWSL then
              "gpg"
            else
              "cache";

          # GIT_CONFIG_GLOBAL is normally set by the wrapper's own env, but
          # only takes effect when git is actually invoked through it.
          # delta reads the same [delta]/[pager] sections directly when
          # invoked on its own (e.g. lazygit's diffRenderers), so this
          # needs to be exported for every process, not just git's own.
          config.home.sessionVariables.GIT_CONFIG_GLOBAL =
            wrapper.wrapper.configuration.constructFiles.gitconfig.outPath;

          # delta/git-credential-manager both need to be on the *general*
          # interactive PATH, not just git's own wrapper's - lazygit's
          # diffRenderers calls a plain `delta` (not an absolute path,
          # unlike git's own [pager] config below), and `gcm` is meant to
          # be run directly. Neither can move into module.nix's own
          # runtimePkgs, which only extends the PATH git's own wrapped
          # binary sees.
          config.home = {
            packages = [
              pkgs.git-credential-manager
              pkgs.delta
            ];

            shellAliases.gcm = "git-credential-manager";

            file = {
              ".config/git/git.sh".source = files.gitSh.outPath;
              ".config/git/git.zsh".source = files.gitZsh.outPath;
            };
          };

          config.programs.bash.initExtra = ''
            source ~/.config/git/git.sh
          '';

          # git.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
          config.wrappers.zsh.extraInitContent = ''
            source ~/.config/git/git.sh
            source ~/.config/git/git.zsh
          '';

          config.programs = {
            gpg.enable = isWSL;

            password-store = {
              enable = isWSL;
              settings = { };
            };
          };

          config.services.gpg-agent = lib.mkIf isWSL {
            enable = true;
            enableSshSupport = false;
            # pinentry-curses draws on the controlling tty, which collides with
            # lazygit's own terminal UI (broken input, corrupted redraws). WSLg
            # provides a display, so use a GUI pinentry that pops its own window.
            pinentry.package = pkgs.pinentry-qt;
          };
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkGit { inherit pkgs; };
        }
      );
    };
}
