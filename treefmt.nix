_: {
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  programs.statix.enable = true;
  programs.deadnix.enable = true;

  programs.shfmt.enable = true;
  programs.shfmt.indent_size = 4;
  programs.shellcheck.enable = true;
  settings.formatter.shfmt.includes = [ "*.zsh" ];

  programs.stylua.enable = true;

  programs.mdformat.enable = true;
  programs.mdformat.plugins = ps: [ ps.mdformat-gfm ];
}
