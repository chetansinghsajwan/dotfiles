{
    config,
    lib,
    ...
}: let
    shell = config.dotfiles.shell.program;
    # `f`: run the explorer and `cd` to where it ended up.
    posix = ''
        f() {
            local tmp="$(mktemp -t files-cwd.XXXXXX)" cwd
            files --cwd-file "$tmp" "$@"
            cwd="$(command cat -- "$tmp")"
            [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
            command rm -f -- "$tmp"
        }
    '';
in {
    # `files`: the file explorer (Rust, pkgs/tuikit/tools/files), the same panel the
    # helix fork embeds. Replaces yazi. `f` changes directory on exit.

    # `ll`: the folder's entries as a list (permissions, size, age, git state).
    home.shellAliases.ll = "files list";

    programs.zsh.initContent = lib.mkIf (shell == "zsh") posix;
    programs.fish.functions.f = lib.mkIf (shell == "fish") ''
        set tmp (mktemp -t files-cwd.XXXXXX)
        files --cwd-file $tmp $argv
        set cwd (command cat -- $tmp)
        if test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- $cwd
        end
        command rm -f -- $tmp
    '';
    programs.nushell.extraConfig = lib.mkIf (shell == "nushell") ''
        def --env f [...args] {
            let tmp = (mktemp -t files-cwd.XXXXXX)
            files --cwd-file $tmp ...$args
            let cwd = (open $tmp)
            if $cwd != "" and $cwd != $env.PWD { cd $cwd }
            rm -fp $tmp
        }
    '';
}
