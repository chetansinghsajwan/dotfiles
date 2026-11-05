{
    config,
    lib,
    pkgs,
    ...
}:
let
    # "Rounded Powerline": the ends of a bar segment with slightly rounded corners (U+E0F0 to U+E0F3), drawn by
    # rounded_powerline.py. It is a separate tiny font on codepoints no Nerd Font uses, so nothing else changes.
    rounded = pkgs.runCommand "rounded-powerline-font" { nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.fonttools ])) ]; } ''
        mkdir -p $out/share/fonts/truetype
        python3 ${./rounded_powerline.py} $out/share/fonts/truetype/RoundedPowerline.ttf
    '';
    isDarwin = config.dotfiles.system.isDarwin;
in
{
    home.packages = [ rounded ];

    fonts.fontconfig.enable = lib.mkIf (!isDarwin) true;

    # macOS reads ~/Library/Fonts.
    home.file."Library/Fonts/RoundedPowerline.ttf" = lib.mkIf isDarwin {
        source = "${rounded}/share/fonts/truetype/RoundedPowerline.ttf";
    };

    # The terminals draw these codepoints with it, whatever the main font is.
    programs.ghostty.settings.font-codepoint-map = lib.mkIf config.programs.ghostty.enable "U+E0F0-U+E0F3=Rounded Powerline";
    programs.kitty.settings.symbol_map = lib.mkIf config.programs.kitty.enable "U+E0F0-U+E0F3 Rounded Powerline";
}
