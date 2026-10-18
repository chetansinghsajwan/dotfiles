{ osConfig ? null, lib, ... }:
let
    mkDefaultLeaves =
        v:
        if lib.isAttrs v && !lib.isDerivation v then
            lib.mapAttrs (_: mkDefaultLeaves) v
        else
            lib.mkDefault v;
in
{
    config = lib.mkIf (osConfig != null) {
        dotfiles = mkDefaultLeaves (osConfig.dotfiles or { });
    };
}
