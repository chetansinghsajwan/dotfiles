{ config, pkgs, ... }:
{
  home.packages = [ pkgs.git ];

  programs.git = {
    enable = true;

    includes = [{ path = "~/.gitconfig.local"; }];

    lfs = {
      enable = true;
      skipSmudge = false;
    };

    extraConfig = {
      core.editor = "nvim";
      credential.helper = "store";
      init.defaultBranch = "main";
      push.default = "current";
      pull.ff = "only";
      pull.rebase = true;
      protocol.version = 2;

      # user settings
      user.name = "chetansinghsajwan";
      user.email = "76040441+chetansinghsajwan@users.noreply.github.com";

      # url aliases
      url."git@github.com:".insteadOf = "gh:";

      # aliases
      alias.cm = "commit";
      alias.co = "checkout";
      alias.br = "branch";
      alias.st = "status";
      alias.sreset = "reset --soft";
      alias.hreset = "reset --hard";
      alias.ammend = "commit --amend --all --no-edit";
      alias.df = "diff --color --color-words --abbrev";
      alias.lg = "log --color --oneline --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cd) %C(bold blue)<%an>%Creset' --abbrev-commit";

      # advice settings
      advice.pushUpdateRejected = false;
      advice.pushNonFFCurrent = false;
      advice.pushNonFFMatching = false;
      advice.pushAlreadyExists = false;
      advice.pushFetchFirst = false;
      advice.pushNeedsForce = false;
      advice.statusHints = false;
      advice.statusUoption = false;
      advice.commitBeforeMerge = false;
      advice.resolveConflict = false;
      advice.implicitIdentity = false;
      advice.detachedHead = false;
      advice.amWorkDir = false;
      advice.rmHints = false;
    };
  };
}
