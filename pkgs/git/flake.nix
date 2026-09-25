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

      # This repo's own git customization, shared between the
      # home-manager module below and a bare package build. Doesn't
      # include user.{name,email} or credential.credentialStore: a plain
      # wrapper module only ever sees its own submodule config, not the
      # config of whatever imports it, so those have to come from the
      # caller.
      wrapperModule = ./module.nix;
    in
    {
      lib = {
        mkGit =
          {
            pkgs,
            userName ? null,
            userEmail ? null,
            credentialStore ? "cache",
          }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.git
            wrapperModule
            {
              config.settings = {
                credential.credentialStore = credentialStore;
                user =
                  lib.optionalAttrs (userName != null) { name = userName; }
                  // lib.optionalAttrs (userEmail != null) { email = userEmail; };
              };
            }
          ];
      };

      # Drop-in home-manager module: `imports = [ git-wrapped.homeModules.default ];`
      # is the whole integration - sets user/credentialStore from
      # config.dotfiles.*, exports GIT_CONFIG_GLOBAL so delta (invoked
      # directly, e.g. by lazygit) still sees the same config, and wires
      # up the fuzzy git pickers.
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          isWSL = config.dotfiles.system.isWsl;

          credentialStore =
            if config.dotfiles.system.isDarwin then
              "keychain"
            else if config.dotfiles.desktop.gnome.enable then
              "secretservice"
            else if isWSL then
              "gpg"
            else
              "cache";
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "git";
              value = [
                wrappers.wrapperModules.git
                wrapperModule
              ];
            })
          ];

          config.wrappers.git = {
            enable = true;
            settings = {
              credential.credentialStore = credentialStore;
              user = {
                name = config.dotfiles.user.displayName;
                email = config.dotfiles.user.git.email;
              };
            };
          };

          # GIT_CONFIG_GLOBAL is normally set by the wrapper's own env, but
          # only takes effect when git is actually invoked through it.
          # delta reads the same [delta]/[pager] sections directly when
          # invoked on its own (e.g. lazygit's diffRenderers), so this
          # needs to be exported for every process, not just git's own.
          config.home.sessionVariables.GIT_CONFIG_GLOBAL =
            config.wrappers.git.wrapper.configuration.constructFiles.gitconfig.outPath;

          config.home = {
            packages = [
              pkgs.git-credential-manager
              pkgs.delta
            ];

            shellAliases.gcm = "git-credential-manager";

            file = {
              ".config/git/git.sh".source = ./git.sh;
              ".config/git/git.zsh".source = ./git.zsh;
            };
          };

          config.programs.bash.initExtra = ''
            source ~/.config/git/git.sh
          '';

          # git.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
          config.programs.zsh.initContent = ''
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
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.git
            wrapperModule
          ];
        }
      );
    };
}
