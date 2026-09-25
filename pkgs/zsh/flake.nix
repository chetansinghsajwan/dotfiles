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

      # This repo's own zsh customization: plugins + the extraInitContent
      # hook other pkgs/<name> modules use instead of
      # programs.zsh.initContent (see module.nix).
      wrapperModule = ./module.nix;
    in
    {
      # Drop-in home-manager module: `imports = [ zsh-wrapped.homeModules.default ];`
      # is the whole integration.
      #
      # home-manager's own `programs.zsh` module (unconditionally kept
      # enabled by home.nix's `dotfiles.shell.program == "zsh"` check) is
      # still responsible for the *base* rc content - completion init,
      # history, shellAliases, hm-session-vars sourcing, etc. Plugins and
      # every other module's extra rc content (previously
      # `programs.zsh.initContent`) have moved into this wrapper's own
      # generated content instead (module.nix). This wrapper points
      # nix-wrapper-modules' own generated ZDOTDIR at home-manager's
      # dotDir (`${xdg.configHome}/zsh`), so the wrapper's own .zshenv
      # sources home-manager's real .zshenv first - the same file
      # home-manager's own root ~/.zshenv would have sourced anyway -
      # which reassigns ZDOTDIR to the real dotDir before zsh reads the
      # rest of home-manager's base rc files, and only then does the
      # wrapper's own generated .zshrc (plugins + extraInitContent) run.
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
              value = [
                wrappers.wrapperModules.zsh
                wrapperModule
              ];
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
            wrapperModule
          ];
        }
      );
    };
}
