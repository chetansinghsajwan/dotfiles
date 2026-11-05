{
    config,
    lib,
    pkgs,
    tools,
    ...
}:
let
    fonts = config.dotfiles.theme.fonts;
    system = pkgs.stdenv.hostPlatform.system;
    pkgOf = tool: tool.packages.${system}.default;
in
{
    # Our Rust tools (pkgs/*, each its own flake on pkgs/term-toolkit): `pv` (preview), `pick`
    # (picker), `files` (explorer), `gu` (the multi-pane git screen), `tb` (table editor), `nu`
    # (connections), `mdexport` (Markdown to PDF). The helix fork is wired in home/programs/helix.nix.
    home.packages = map pkgOf (lib.attrValues (removeAttrs tools [ "helix-fork" ]));

    # The PDFs `mdexport` writes use the fonts stylix sets (the defaults; the helix export popup and the
    # command line override them).
    xdg.configFile."mdexport/config.toml".text = ''
        font = "${fonts.serif.name}"
        mono = "${fonts.mono.name}"
        size_pt = ${toString fonts.sizes.applications}.0
    '';
}
