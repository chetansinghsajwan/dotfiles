{
  description = "direnv: per-directory environment loader";

  # No nix-wrapper-modules here: direnv takes no CLI flags/config file
  # worth baking into a wrapper - its behaviour is entirely file-based
  # (.envrc per project, plus direnvrc/lib files under $XDG_CONFIG_HOME),
  # so this just installs the package and writes those files directly.
  outputs =
    _:
    {
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          config.home.packages = [ pkgs.direnv ];

          # direnv auto-sources every *.sh file under
          # $XDG_CONFIG_HOME/direnv/lib/ - these were home-manager's own
          # `programs.direnv.mise.enable` / `.nix-direnv.enable`.
          config.xdg.configFile = {
            "direnv/lib/hm-mise.sh".text = ''
              eval "$(${lib.getExe pkgs.mise} direnv activate)"
            '';
            "direnv/lib/hm-nix-direnv.sh".source = "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";
          };

          config.programs.bash.initExtra = lib.mkIf (config.dotfiles.shell.program == "bash") ''
            eval "$(${lib.getExe pkgs.direnv} hook bash)"
          '';

          config.programs.zsh.initContent = lib.mkIf (config.dotfiles.shell.program == "zsh") ''
            eval "$(${lib.getExe pkgs.direnv} hook zsh)"
          '';

          config.programs.fish.interactiveShellInit = lib.mkIf (config.dotfiles.shell.program == "fish") ''
            if not functions -q __direnv_export_eval
              ${lib.getExe pkgs.direnv} hook fish | source
            end
          '';

          # Ported verbatim from home-manager's own programs.direnv module
          # (modules/programs/direnv.nix) - handles PATH-like env var
          # conversions, not just a plain eval.
          config.programs.nushell.extraConfig = lib.mkIf (config.dotfiles.shell.program == "nushell") ''
            $env.config = ($env.config? | default {})
            $env.config.hooks = ($env.config.hooks? | default {})
            $env.config.hooks.pre_prompt = (
                $env.config.hooks.pre_prompt?
                | default []
                | append {||
                    let direnv = (
                        ${lib.getExe pkgs.direnv} export json
                        | from json --strict
                        | default {}
                    )

                    for key in ($direnv | columns) {
                        if ($direnv | get $key) == null {
                            hide-env --ignore-errors $key
                        }
                    }

                    $direnv
                    | items {|key, value|
                        let value = do (
                            {
                              "PATH": {
                                from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                                to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
                              }
                            }
                            | merge ($env.ENV_CONVERSIONS? | default {})
                            | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
                            | if ($in | is-empty) { {|x| $x} } else { $in }
                        ) $value
                        return [ $key $value ]
                    }
                    | where {|pair| $pair.1 != null }
                    | into record
                    | load-env
                }
            )
          '';
        };
    };
}
