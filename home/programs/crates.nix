{
    config,
    pkgs,
    crane,
    ...
}:
let
    fonts = config.dotfiles.theme.fonts;
in
{
    # Our Rust tools, built together from home/crates: `pv` (preview), `pick`
    # (picker), `files` (explorer), `git-panel`, `git-ui` (the multi-pane git
    # screen), `mdexport` (Markdown to PDF), `ui-demo`.
    home.packages = [ (pkgs.callPackage ../crates { craneLib = crane.mkLib pkgs; }) ];

    # `gu`: the multi-pane git screen.
    home.shellAliases.gu = "git-ui";

    # The PDFs `mdexport` writes use the fonts stylix sets (the defaults; the helix export popup and the
    # command line override them).
    xdg.configFile."mdexport/config.toml".text = ''
        font = "${fonts.serif.name}"
        mono = "${fonts.mono.name}"
        size_pt = ${toString fonts.sizes.applications}.0
    '';
}
