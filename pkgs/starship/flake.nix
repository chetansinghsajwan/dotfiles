{
  description = "starship: shell prompt";

  # No settings are configured in this repo, so there's no config to bake
  # into a wrapper - nix-wrapper-modules would add indirection for zero
  # benefit here. This just installs the package and wires the shell hook
  # by hand, same as direnv.
  outputs = _: {
    homeModules.default =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        active = config.dotfiles.shell.theme == "starship";
      in
      {
        config.home.packages = lib.mkIf active [ pkgs.starship ];

        config.programs.bash.initExtra = lib.mkIf (active && config.dotfiles.shell.program == "bash") ''
          if [[ $TERM != "dumb" ]]; then
            eval "$(${lib.getExe pkgs.starship} init bash --print-full-init)"
          fi
        '';

        config.wrappers.zsh.extraInitContent =
          lib.mkIf (active && config.dotfiles.shell.program == "zsh")
            ''
              if [[ $TERM != "dumb" ]]; then
                eval "$(${lib.getExe pkgs.starship} init zsh)"
              fi
            '';

        config.programs.fish.interactiveShellInit =
          lib.mkIf (active && config.dotfiles.shell.program == "fish")
            ''
              if test "$TERM" != "dumb"
                ${lib.getExe pkgs.starship} init fish | source
              end
            '';

        # Ported from home-manager's own programs.starship module: nushell
        # can't conditionally source, so (unlike the other shells here)
        # there's no $TERM check.
        config.programs.nushell.extraConfig =
          lib.mkIf (active && config.dotfiles.shell.program == "nushell")
            ''
              use ${
                pkgs.runCommand "starship-nushell-config.nu" { } ''
                  ${lib.getExe pkgs.starship} init nu >> "$out"
                ''
              }
            '';
      };
  };
}
