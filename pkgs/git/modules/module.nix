# nix-wrapper-modules wrapper module: pulls in nix-wrapper-modules' own
# native git module plus this repo's customization (settings, delta
# integration, identity, credential store) on top - so this one file is
# the complete git wrapper, and callers only ever need to reference it,
# not also list `wrappers.wrapperModules.git` separately. Identity and
# credential store are this module's own responsibility end to end:
# `userName`/`userEmail`/`credentialStore` default to this repo's own
# config.dotfiles.user.*/config.dotfiles.system.*, so a standalone build
# is fully configured out of the box with no outer config needed at all.
# Whatever imports this (see flake.nix's `homeModules.default`) may
# still override any of the three explicitly.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  deltaCmd = lib.getExe pkgs.delta;
  lfsCmd = lib.getExe pkgs.git-lfs;
in
{
  imports = [
    wlib.wrapperModules.git

    # Purely so userName/userEmail/credentialStore below can default to
    # config.dotfiles.* - the same config/default.nix options this
    # repo's home-manager hosts already get, just merged into this
    # wrapper module's own isolated evalModules instead of
    # home-manager's. pkgs/lib/config are already shared module args, so
    # this needs no separate evalModules call or specialArgs threading.
    ../../../config
  ];

  options.userName = lib.mkOption {
    type = lib.types.str;
    default = config.dotfiles.user.displayName;
    description = "git user.name.";
  };

  options.userEmail = lib.mkOption {
    type = lib.types.str;
    default = config.dotfiles.user.git.email;
    description = "git user.email.";
  };

  options.credentialStore = lib.mkOption {
    type = lib.types.str;
    default =
      if config.dotfiles.system.isDarwin then
        "keychain"
      else if config.dotfiles.desktop.gnome.enable then
        "secretservice"
      else if config.dotfiles.system.isWsl then
        "gpg"
      else
        "cache";
    defaultText = lib.literalExpression ''
      "keychain" on Darwin, "secretservice" under GNOME, "gpg" under
      WSL, "cache" otherwise - see config.dotfiles.system.*/desktop.gnome.
    '';
    description = "git credential.credentialStore.";
  };

  config = {
    # So `git lfs <subcommand>` resolves without needing git-lfs on the
    # general PATH. ripgrep backs git.sh's fglf (fuzzy log for a chosen
    # file) - baked in here too so it still works on a standalone
    # install that never installed ripgrep on its own (e.g. via fzf's
    # own module).
    runtimePkgs = [
      pkgs.git-lfs
      pkgs.ripgrep
    ];

    # git.sh/git.zsh (the fgl/fgb/fgt/fgs/fgst/fglf/fgr fuzzy pickers +
    # git.zsh's direct alt-g keybindings) baked directly into this
    # package's own output, so a plain `nix profile
    # install`/`home.packages`/`environment.systemPackages` install
    # already carries them - not just a home-manager one. Whatever
    # imports this module (see flake.nix's `homeModules.default`) still
    # decides which shell to actually wire the sourcing into.
    constructFiles.gitSh = {
      relPath = "share/git/git.sh";
      content = builtins.readFile ../resources/git.sh;
    };
    constructFiles.gitZsh = {
      relPath = "share/git/git.zsh";
      content = builtins.readFile ../resources/git.zsh;
    };

    settings = {
      user = {
        name = config.userName;
        email = config.userEmail;
      };

      credential.credentialStore = config.credentialStore;

      "credential \"https://dev.azure.com\"" = {
        useHttpPath = true;
      };

      credential.azreposCredentialType = "pat";

      init.defaultBranch = "main";
      protocol.version = 2;

      credential.helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";

      core.editor = "hx";

      pull = {
        ff = "only";
        rebase = true;
      };

      push.autoSetupRemote = true;

      # url aliases
      url."git@github.com:".insteadOf = "gh:";

      lfs = {
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
      };

      # The actual filter git consults (core git reads [filter "lfs"], not
      # [lfs]) - matches what home-manager's own programs.git.lfs.enable
      # generates, using git-lfs's full store path.
      filter.lfs = {
        clean = "${lfsCmd} clean -- %f";
        smudge = "${lfsCmd} smudge -- %f";
        process = "${lfsCmd} filter-process";
        required = true;
      };

      include.path = "~/.config/git/local-config";

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

      # delta (was programs.delta.enableGitIntegration = true, which
      # injects this same content into programs.git.iniContent)
      pager = {
        diff = deltaCmd;
        log = deltaCmd;
        show = deltaCmd;
        blame = deltaCmd;
      };

      interactive.diffFilter = "${deltaCmd} --color-only";

      delta = {
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
  };
}
