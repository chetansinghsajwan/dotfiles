{
  description = "git, wrapped with its config baked in";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # This repo's own git customization, baked in as the default so a
      # bare `mkGit { inherit pkgs lib; settings = { user = { name = ...;
      # email = ...; }; credential.credentialStore = ...; }; }` already
      # produces the fully configured tool with just the genuinely
      # per-host bits supplied. Everything here either has no host-
      # specific dependency, or only needs `pkgs` (already in scope) -
      # unlike user.name/email, credential.credentialStore, and the
      # delta pager/interactive wiring, which depend on config.dotfiles.*
      # or a sibling wrapped package this flake can't see, and so stay
      # real caller inputs.
      defaultSettings = pkgs: {
        "credential \"https://dev.azure.com\"" = {
          useHttpPath = true;
        };

        # Was programs.gh's gitCredentialHelper (default-on whenever
        # programs.gh.enable is set) - replicated directly here since
        # git no longer reads the config location that module writes to.
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

        credential = {
          azreposCredentialType = "pat";
          helper = "${pkgs.git-credential-manager}/bin/git-credential-manager";
        };

        init.defaultBranch = "main";
        protocol.version = 2;

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

      defaultExtraPackages =
        pkgs: with pkgs; [
          git-lfs
          git-credential-manager
        ];

      mkGit =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
        }:
        let
          finalSettings = lib.recursiveUpdate (defaultSettings pkgs) settings;
          configFile = pkgs.writeText "gitconfig" (lib.generators.toGitINI finalSettings);
        in
        pkgs.symlinkJoin {
          name = "git-wrapped";
          paths = [ pkgs.git ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/git \
              --set GIT_CONFIG_GLOBAL "${configFile}" \
              --suffix PATH : ${lib.makeBinPath (defaultExtraPackages pkgs ++ extraPackages)}

            mkdir -p $out/share/git-shell
            cp ${./git.sh} $out/share/git-shell/git.sh
            cp ${./git.zsh} $out/share/git-shell/git.zsh
          '';
        };
    in
    {
      lib = { inherit mkGit; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkGit { inherit pkgs; };
        }
      );
    };
}
