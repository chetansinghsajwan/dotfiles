{ pkgs, ... }:
let
    # eza theme that reuses yazi's own icon table (glyph + colour per file name /
    # extension / dir name), so eza listings (including `pv` folder previews) look
    # like yazi's file list instead of eza's single-colour icons. Generated from
    # yazi's preset so it follows yazi upgrades.
    yaziIconTheme =
        pkgs.runCommand "eza-yazi-icons"
            {
                nativeBuildInputs = [
                    pkgs.remarshal
                    pkgs.jq
                ];
            }
            ''
                mkdir -p $out
                toml2json ${pkgs.yazi-unwrapped.srcs.code_src}/yazi-config/preset/theme-dark.toml \
                    | jq '
                        .icon
                        | def entry: { key: .name, value: { icon: { glyph: .text, style: { foreground: .fg } } } };
                        {
                          filenames: ((.dirs + .files) | map(entry) | from_entries),
                          extensions: (.exts | map(entry) | from_entries)
                        }' > $out/theme.yml
            '';
in
{
    programs.eza = {
        enableZshIntegration = true;
        extraOptions = [
            "--git"
            "--icons"
            "always"
        ];
    };

    # Not `programs.eza.theme`: that option takes an attrset, and reading the
    # generated file back into one would need import-from-derivation.
    xdg.configFile."eza/theme.yml".source = "${yaziIconTheme}/theme.yml";
}
