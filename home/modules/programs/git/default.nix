{
  config,
  pkgs,
  lib,
  git-wrapped,
  delta-wrapped,
  ...
}:
let
  isWSL = config.dotfiles.system.isWsl;

  deltaPkg = delta-wrapped.lib.mkDelta {
    inherit pkgs lib;
    settings = {
      navigate = true;
      line-numbers = true;
      width = "variable";

      # Stylix has no delta target, but delta's default styles (file-style,
      # plus/minus-style, etc.) reference named ANSI colors ("blue", "red",
      # "syntax auto", ...) which already resolve through the stylix-themed
      # terminal palette - so they're left unset here rather than
      # hardcoded, to keep following the terminal theme. syntax-theme is
      # the one thing stylix can't reach (it's a bundled syntect theme,
      # not a terminal color), so it's pointed at the same base16-stylix
      # theme home-manager generates for bat.
      syntax-theme = "base16-stylix";

      # Default hunk-header-decoration-style ("blue box") draws a full
      # bordered box around the function-context line above every hunk;
      # dropping to a plain underline, sized to the text instead of the
      # full terminal width (width = variable), keeps that context visible
      # without it dominating the diff.
      hunk-header-decoration-style = "ul";
    };
  };

  gitPkg = git-wrapped.lib.mkGit {
    inherit pkgs lib;
    extraPackages = [
      pkgs.git-lfs
      pkgs.git-credential-manager
    ];

    settings = {
      "credential \"https://dev.azure.com\"" = {
        useHttpPath = true;
      };

      # Was programs.gh's gitCredentialHelper (default-on whenever
      # programs.gh.enable is set) - replicated directly here since git no
      # longer reads the config location that module writes to.
      "credential \"https://github.com\"" = {
        helper = [
          ""
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
      };
      "credential \"https://gist.github.com\"" = {
        helper = [
          ""
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
      };

      credential.azreposCredentialType = "pat";

      init.defaultBranch = "main";
      protocol.version = 2;

      credential = {
        helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
        credentialStore =
          if config.dotfiles.system.isDarwin then
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
        editor = "hx";
      };

      # Was programs.delta.enable's generated pager/interactive wiring -
      # points at the wrapped delta binary directly (it reads its own
      # baked --config instead of this file's now-absent [delta] section).
      interactive.diffFilter = "${deltaPkg}/bin/delta --color-only";
      pager = {
        diff = "${deltaPkg}/bin/delta";
        log = "${deltaPkg}/bin/delta";
        show = "${deltaPkg}/bin/delta";
        blame = "${deltaPkg}/bin/delta";
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

      # Was programs.git.lfs.enable's generated filter driver (absolute
      # paths, always correct regardless of PATH).
      "filter \"lfs\"" = {
        clean = "${pkgs.git-lfs}/bin/git-lfs clean -- %f";
        smudge = "${pkgs.git-lfs}/bin/git-lfs smudge -- %f";
        process = "${pkgs.git-lfs}/bin/git-lfs filter-process";
        required = true;
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

      include.path = "~/.config/git/local-config";
    };
  };
in
{
  home.packages = [
    gitPkg
    deltaPkg
    pkgs.git-credential-manager
  ];

  home.shellAliases.gcm = "git-credential-manager";

  programs.bash.initExtra = "source ${gitPkg}/share/git-shell/git.sh";
  # git.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
  programs.zsh.initContent = ''
    source ${gitPkg}/share/git-shell/git.sh
    source ${gitPkg}/share/git-shell/git.zsh
  '';

  programs.gpg.enable = isWSL;

  programs.password-store = {
    enable = isWSL;
    settings = { };
  };

  services.gpg-agent = lib.mkIf isWSL {
    enable = true;
    enableSshSupport = false;
    # pinentry-curses draws on the controlling tty, which collides with
    # lazygit's own terminal UI (broken input, corrupted redraws). WSLg
    # provides a display, so use a GUI pinentry that pops its own window.
    pinentry.package = pkgs.pinentry-qt;
  };
}
