{
  config,
  pkgs,
  lib,
  ...
}:
let
  isWSL = config.dotfiles.system.isWsl;
in
{
  config = lib.mkIf config.programs.git.enable {
    programs.git = {
      includes = [
        { path = "~/.gitconfig.local"; }
      ];

      lfs = {
        enable = true;
        skipSmudge = false;
      };

      settings = {

        "credential \"https://dev.azure.com\"" = {
          useHttpPath = true;
        };

        credential.azreposCredentialType = "pat";

        init.defaultBranch = "main";
        protocol.version = 2;

        credential = {
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
          credentialStore =
            if pkgs.stdenv.hostPlatform.isDarwin then
              "keychain"
            else if config.dotfiles.desktop.gnome.enable then
              "secretservice"
            else if isWSL then
              "gpg"
            else
              "cache";
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
        alias =
          let
            logBase = "log --graph --abbrev-commit --decorate --pretty=format:'%C(bold blue)%h%C(reset) %C(bold green)(%cr)%C(reset) %C(cyan)%cn%C(reset)%C(bold red)%d%C(reset)%n%C(normal)";
          in
          {
            l = "${logBase}%s%C(reset)'";
            l1 = "l -1";
            l2 = "l -2";
            l3 = "l -3";
            l4 = "l -4";
            l5 = "l -5";
            l6 = "l -6";
            l7 = "l -7";
            l8 = "l -8";
            l9 = "l -9";
            la = "l --all";
            lf = "${logBase}%s%n%n%b%C(reset)'";
            lfa = "lf --all";
            b = "branch";
            bd = "branch -d";
            bD = "branch -D";

            # branch delete remote only
            bdr = "push origin --delete";

            # branch delete local and remote
            bda = "!f() { git branch -d $1 && git push origin --delete $1; }; f";

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
            s = "status";
            ss = "status --short";
            d = "diff";
            df = "diff --cached";
            ds = "diff --staged";
            wt = "worktree";
            fc = "fetch --prune";
            rb = "rebase";
            rbp = "rebase --pull";
            ps = "push";
            psf = "push --force-with-lease";
            pl = "pull";
            plf = "pull --ff-only";
            plr = "pull --rebase";
            plrf = "pull --rebase --ff-only";
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

    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
      };
    };

    home = {
      packages = with pkgs; [
        git-credential-manager
      ];

      shellAliases.gcm = "git-credential-manager";
    };

    programs.gpg.enable = isWSL;
    programs.password-store = {
      enable = isWSL;
      settings = { };
    };

    services.gpg-agent = lib.mkIf isWSL {
      enable = true;
      enableSshSupport = false;
      pinentry.package = pkgs.pinentry-curses;
    };
  };
}
