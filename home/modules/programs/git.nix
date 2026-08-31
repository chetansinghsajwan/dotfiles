{ config, pkgs, lib, ... }: {
  config = lib.mkIf config.programs.git.enable {
    programs.git = {
      delta = {
        enable = true;
        options.navigate = true;
      };

      includes = [
        { path = "~/.gitconfig.local"; }
      ];

      lfs = {
        enable = true;
        skipSmudge = false;
      };

      settings = {
        init.defaultBranch = "main";
        protocol.version = 2;

        credential = {
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
          credentialStore =
            if pkgs.stdenv.hostPlatform.isDarwin then "keychain"
            else if config.dotfiles.desktop.gnome.enable then "secretservice"
            else "cache";
        };

        user = {
          name = config.dotfiles.user.displayName;
          email = config.dotfiles.user.git.email;
        };

        core = {
          editor = "nvim";
        };

        pull = {
          ff = "only";
          rebase = true;
        };

        push = {
          autoSetupRemote = true;
        };

        # url aliases
        url = {
          "git@github.com:".insteadOf = "gh:";
        };

        lfs = {
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
          process = "git-lfs filter-process";
          required = true;
        };

        # aliases
        alias = {
          lg = "log --graph --abbrev-commit --decorate --pretty=format:'%C(bold blue)%h%C(reset) %C(bold green)(%cr)%C(reset) %C(cyan)%cn%C(reset)%C(bold red)%d%C(reset)%n%C(normal)%s%C(reset)'";
          lg1 = "lg -1";
          lg2 = "lg -2";
          lg3 = "lg -3";
          lg4 = "lg -4";
          lg5 = "lg -5";
          lga = "lg --all";
          lgf = "log --graph --abbrev-commit --decorate --pretty=format:'%C(bold blue)%h%C(reset) %C(bold green)(%cr)%C(reset) %C(cyan)%cn%C(reset)%C(bold red)%d%C(reset)%n%C(normal)%s%n%n%b%C(reset)'";
          lgfa = "lgf --all";
          br = "branch";
          sw = "switch";
          co = "checkout";
          rt = "restore";
          rs = "reset";
          rss = "reset --soft";
          rsm = "reset --mixed";
          rsh = "reset --hard";
          cm = "commit";
          ca = "commit --amend --no-edit";
          caa = "ca --all";
          st = "status";
          wt = "worktree";
          fc = "fetch --prune";
          rb = "rebase";
          rbp = "rebase --pull";
          ps = "push";
          psf = "push -f";
          wip = "commit -m 'WIP'";
          wipa = "commit -m 'WIP' --amend";
          tags = "tag -n1 -l";
          who = "shortlog -sn --no-merges";
          whoami = "!git config --get user.name && git config --get user.email";
          alias = "!f() { git config --get-regexp alias | cut -c 7- | sed \"s/ /$(echo 2B | xxd -r -p)/\" | column -t -s $(echo 2B | xxd -r -p); }; f";
          gcm = "credential-manager";
        };

        # advice settings
        advice = {
          pushUpdateRejected = false;
          pushNonFFCurrent = false;
          pushNonFFMatching = false;
          pushAlreadyExists = false;
          pushFetchFirst = false;
          pushNeedsForce = false;
          statusHints = false;
          statusUoption = false;
          commitBeforeMerge = false;
          resolveConflict = false;
          implicitIdentity = false;
          detachedHead = false;
          amWorkDir = false;
          rmHints = false;
        };
      };
    };

    programs.delta.enableGitIntegration = true;

    home = {
      packages = with pkgs; [
        git-credential-manager
      ];

      shellAliases.gcm = "git-credential-manager";
    };
  };
}
