# The colors of syntax highlighting, one set for every tool: `pv` reads them from `ui/theme.json`, and
# helix's theme (helix.nix) uses the same ones, so a file looks the same in the editor and in a preview.
# `c` is the stylix palette with the leading "#".
c: {
    comment = c.base03;
    keyword = c.base0E;
    function = c.base0D;
    string = c.base0B;
    number = c.base09;
    type_ = c.base0A;
    constant = c.base09;
    variable = c.base08;
    operator = c.base0C;
}
