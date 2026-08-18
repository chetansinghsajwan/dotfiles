{
  # Feature flags for different machine profiles
  features = {
    dev = true;          # development tools (vscode, git, neovim)
    gui = true;          # desktop GUI apps (firefox, vlc, nautilus)
    gaming = false;      # gaming tools (proton, bottles)
  };

  # Application preferences
  programs = {
    firefox.enable = true;
    vscode.enable = true;
    gnomeDesktop.enable = true;
    terminal = "ghostty";  # ghostty or gnome-terminal
  };

  # Shell configuration
  shell = {
    program = "zsh";
    theme = "powerlevel10k";
  };
}
