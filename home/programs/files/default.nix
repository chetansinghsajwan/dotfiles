{
    config,
    lib,
    pkgs,
    crane,
    ...
}:
let
    shell = config.dotfiles.shell.program;
    # `y`: run the explorer and `cd` to where it ended up.
    posix = ''
        y() {
            local tmp="$(mktemp -t files-cwd.XXXXXX)" cwd
            files --cwd-file "$tmp" "$@"
            cwd="$(command cat -- "$tmp")"
            [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
            command rm -f -- "$tmp"
        }
    '';
in
{
    # `files`: the file explorer (Rust, home/crates/files), the same panel the
    # helix fork embeds. Replaces yazi. `y` changes directory on exit.
    home.packages = [ (pkgs.callPackage ../../crates { craneLib = crane.mkLib pkgs; } "files") ];

    programs.zsh.initContent = lib.mkIf (shell == "zsh") posix;
    programs.fish.functions.y = lib.mkIf (shell == "fish") ''
        set tmp (mktemp -t files-cwd.XXXXXX)
        files --cwd-file $tmp $argv
        set cwd (command cat -- $tmp)
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- $cwd
        end
        command rm -f -- $tmp
    '';
    programs.nushell.extraConfig = lib.mkIf (shell == "nushell") ''
        def --env y [...args] {
            let tmp = (mktemp -t files-cwd.XXXXXX)
            files --cwd-file $tmp ...$args
            let cwd = (open $tmp)
            if $cwd != "" and $cwd != $env.PWD { cd $cwd }
            rm -fp $tmp
        }
    '';
}
