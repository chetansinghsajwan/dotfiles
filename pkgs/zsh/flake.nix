{
  description = "zsh, wrapped via nix-wrapper-modules, delegating its actual rc content to home-manager's own zsh dotfiles";

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
    in
    {
      # Drop-in home-manager module: `imports = [ zsh-wrapped.homeModules.default ];`
      # is the whole integration.
      #
      # This wrapper does NOT reimplement zsh's rc generation (plugins,
      # initContent, shellAliases, ...) - that's still entirely
      # home-manager's own `programs.zsh` module, unconditionally kept
      # enabled by home.nix's `dotfiles.shell.program == "zsh"` check, same
      # as before. Instead, this points nix-wrapper-modules' own generated
      # ZDOTDIR at home-manager's dotDir (`${xdg.configHome}/zsh`), so the
      # wrapper's own .zshenv sources home-manager's real .zshenv - the
      # same file home-manager's own root ~/.zshenv would have sourced
      # anyway - which then reassigns ZDOTDIR to the real dotDir before
      # zsh reads .zshrc/.zprofile/.zlogin. Every other module's
      # `programs.zsh.initContent`/`shellAliases`/etc. keeps working
      # completely unchanged.
      #
      # `home.sessionVariables` (GIT_CONFIG_GLOBAL, EDITOR, ...) still
      # reaches the shell too: home-manager's own zsh module sources
      # hm-session-vars.sh directly in its generated rc content,
      # independent of any system-level shell integration - confirmed in
      # modules/programs/zsh/default.nix - so hmSessionVariables is left
      # null here to avoid sourcing it a second time.
      homeModules.default =
        { config, lib, ... }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "zsh";
              value = wrappers.wrapperModules.zsh;
            })
          ];

          config.wrappers.zsh = {
            zdotdir = "${config.xdg.configHome}/zsh";
            hmSessionVariables = null;
          };

          # Avoids a `bin/zsh` collision between home-manager's own
          # (unwrapped) zsh install and this wrapped one - dotfile
          # generation (everything but the package install) is untouched.
          config.programs.zsh.package = lib.mkForce null;
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.zsh
          ];
        }
      );
    };
}
