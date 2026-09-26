{
  description = ''
    Aggregate of every pkgs/<name>/ flake - the single input callers need
    instead of threading each package through flake.nix and every host.
  '';

  # Each pkgs/<name>/ subdirectory stays its own independent flake (so
  # `nix build ./pkgs/<name>#default` still works standalone), just listed
  # here once. Adding a new package means: write pkgs/<name>/flake.nix,
  # add its input + output lines below - nothing in the root flake.nix or
  # any hosts/*/default.nix needs to change.
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # nix-wrapper-modules-based packages - each follows this flake's own
    # nixpkgs (which itself follows the root flake's, once threaded there).
    btop = {
      url = "path:./btop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    eza = {
      url = "path:./eza";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fzf = {
      url = "path:./fzf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git = {
      url = "path:./git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helix = {
      url = "path:./helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazygit = {
      url = "path:./lazygit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tealdeer = {
      url = "path:./tealdeer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode = {
      url = "path:./vscode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    yazi = {
      url = "path:./yazi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zed = {
      url = "path:./zed";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zellij = {
      url = "path:./zellij";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zsh = {
      url = "path:./zsh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plain home-manager-only packages - no inputs of their own, so nothing
    # to follow.
    batman.url = "path:./batman";
    clipboard.url = "path:./clipboard";
    dconf-editor.url = "path:./dconf-editor";
    direnv.url = "path:./direnv";
    docker.url = "path:./docker";
    epiphany.url = "path:./epiphany";
    firefox.url = "path:./firefox";
    ghostty.url = "path:./ghostty";
    gnome-terminal.url = "path:./gnome-terminal";
    gnome-text-editor.url = "path:./gnome-text-editor";
    kanata-layer-indicator.url = "path:./kanata-layer-indicator";
    libreoffice.url = "path:./libreoffice";
    nbfc-linux.url = "path:./nbfc-linux";
    op.url = "path:./op";
    pv.url = "path:./pv";
    starship.url = "path:./starship";
    vlc.url = "path:./vlc";
    # Named distinctly from this flake's own `nixpkgs` (nixos-unstable)
    # input - this is the repo's fzf-driven nixpkgs-search picker, not
    # actual nixpkgs.
    nixpkgs-picker.url = "path:./nixpkgs";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # Packages exposing a buildable `packages.<system>.default` (the
      # nix-wrapper-modules-based ones).
      withPackage = [
        "btop"
        "eza"
        "fzf"
        "git"
        "helix"
        "lazygit"
        "tealdeer"
        "vscode"
        "yazi"
        "zed"
        "zellij"
        "zsh"
      ];

      # Packages exposing a `lib` output of their own helper functions.
      withLib = [
        "btop"
        "eza"
        "fzf"
        "git"
        "helix"
        "lazygit"
        "op"
        "pv"
        "tealdeer"
        "vscode"
        "yazi"
        "zed"
        "zellij"
      ];
    in
    {
      homeModules = {
        batman = inputs.batman.homeModules.default;
        btop = inputs.btop.homeModules.default;
        clipboard = inputs.clipboard.homeModules.default;
        dconf-editor = inputs.dconf-editor.homeModules.default;
        direnv = inputs.direnv.homeModules.default;
        docker = inputs.docker.homeModules.default;
        epiphany = inputs.epiphany.homeModules.default;
        eza = inputs.eza.homeModules.default;
        firefox = inputs.firefox.homeModules.default;
        fzf = inputs.fzf.homeModules.default;
        ghostty = inputs.ghostty.homeModules.default;
        git = inputs.git.homeModules.default;
        gnome-terminal = inputs.gnome-terminal.homeModules.default;
        gnome-text-editor = inputs.gnome-text-editor.homeModules.default;
        helix = inputs.helix.homeModules.default;
        kanata-layer-indicator = inputs.kanata-layer-indicator.homeModules.default;
        lazygit = inputs.lazygit.homeModules.default;
        libreoffice = inputs.libreoffice.homeModules.default;
        nbfc-linux = inputs.nbfc-linux.homeModules.default;
        nixpkgs = inputs.nixpkgs-picker.homeModules.default;
        op = inputs.op.homeModules.default;
        pv = inputs.pv.homeModules.default;
        starship = inputs.starship.homeModules.default;
        tealdeer = inputs.tealdeer.homeModules.default;
        vlc = inputs.vlc.homeModules.default;
        vscode = inputs.vscode.homeModules.default;
        yazi = inputs.yazi.homeModules.default;
        zed = inputs.zed.homeModules.default;
        zellij = inputs.zellij.homeModules.default;
        zsh = inputs.zsh.homeModules.default;
      };

      packages = forEachSystem (
        system: nixpkgs.lib.genAttrs withPackage (name: inputs.${name}.packages.${system}.default)
      );

      lib = nixpkgs.lib.genAttrs withLib (name: inputs.${name}.lib);
    };
}
