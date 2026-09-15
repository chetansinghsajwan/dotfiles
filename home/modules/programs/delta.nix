_: {
  programs.delta = {
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      width = "variable";

      # Stylix has no delta target, but delta's default styles (file-style,
      # plus/minus-style, etc.) reference named ANSI colors ("blue", "red",
      # "syntax auto", ...) which already resolve through the stylix-themed
      # terminal palette (see stylix.targets.ghostty) - so they're left
      # unset here rather than hardcoded, to keep following the terminal
      # theme. syntax-theme is the one thing stylix can't reach (it's a
      # bundled syntect theme, not a terminal color), so it's pointed at
      # the same base16-stylix theme home-manager generates for bat.
      syntax-theme = "base16-stylix";

      # Default hunk-header-decoration-style ("blue box") draws a full
      # bordered box around the function-context line above every hunk;
      # dropping to a plain underline, sized to the text instead of the
      # full terminal width (width = variable), keeps that context visible
      # without it dominating the diff.
      hunk-header-decoration-style = "ul";
    };
  };
}
