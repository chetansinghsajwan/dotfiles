{
    config,
    pkgs,
    llib,
    ...
}:
llib.mkToggleModule config "nixpkgs" {
    home.file = {
        ".config/nixpkgs-pick/nixpkgs.sh".source = ./nixpkgs.sh;
        ".config/nixpkgs-pick/nixpkgs.zsh".source = ./nixpkgs.zsh;
    };

    home.packages = [ pkgs.jq ];

    programs.bash.initExtra = ''
        source ~/.config/nixpkgs-pick/nixpkgs.sh
    '';
    # nixpkgs.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
    programs.zsh.initContent = ''
        source ~/.config/nixpkgs-pick/nixpkgs.sh
        source ~/.config/nixpkgs-pick/nixpkgs.zsh
    '';

}
