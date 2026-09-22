_: {
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  programs.statix.enable = true;
  programs.deadnix.enable = true;

  programs.shfmt.enable = true;
  programs.shfmt.indent_size = 4;
  programs.shellcheck.enable = true;
  settings.formatter.shfmt.includes = [ "*.zsh" ];
  # fzf.sh mixes bash and zsh (guarded by $ZSH_VERSION at runtime) and contains
  # a zsh-only associative-array-key expansion shfmt's bash/posix parser can't
  # parse at all, unlike shellcheck's per-line disable comments.
  settings.formatter.shfmt.excludes = [ "home/modules/programs/fzf/fzf.sh" ];

  programs.stylua.enable = true;

  programs.mdformat.enable = true;
  programs.mdformat.plugins = ps: [ ps.mdformat-gfm ];
}
