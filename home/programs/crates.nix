{
    config,
    lib,
    pkgs,
    lpkgs,
    ...
}: let
    fonts = config.dotfiles.theme.fonts;
    system = pkgs.stdenv.hostPlatform.system;
in {
    # Our Rust tools (the pkgs/tuikit submodule, re-exported by pkgs/flake.nix): `pv` (preview), `pick`
    # (picker), `files` (explorer), `gu` (the multi-pane git screen), `tb` (table editor), `nu`
    # (connections), `mdexport` (Markdown to PDF). The helix fork is wired in home/programs/helix.nix.
    # The `<tool>-static` musl builds are for the GitHub Release; CI does not push them to the binary cache,
    # so installing them here would compile every tool from source.
    home.packages = lib.attrValues (
        lib.filterAttrs (name: _: name != "helix" && !(lib.hasSuffix "-static" name)) lpkgs.packages.${system}
    );

    # The PDFs `mdexport` writes use the fonts stylix sets (the defaults; the helix export popup and the
    # command line override them).
    xdg.configFile."mdexport/config.toml".text = ''
        font = "${fonts.serif.name}"
        mono = "${fonts.mono.name}"
        size_pt = ${toString fonts.sizes.applications}.0
    '';
}
