{ pkgs, ... }:
let
    kickstart = pkgs.fetchFromGitHub {
        owner = "nvim-lua";
	repo = "kickstart.nvim";
	rev = "23773900d9a2e1079a1a04d31adce5c5e901db6f";
	hash = "sha256-IwR/HT38WnEpDiJFWZc+Z2ACN6tggP6vOa/i43YLue4=";
    };
in
{
    programs.neovim = {
        enable = true;
        defaultEditor = true;
        extraLuaConfig = builtins.readFile "${kickstart}/init.lua";
    };

    home.packages = with pkgs; [ clang_17 ];
}
