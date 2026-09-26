{
  description = "clipboard: fzf-driven clipboard history picker (cliphist + wl-clipboard)";

  # No nix-wrapper-modules here: this is shell glue (a fzf picker sourced
  # into bash/zsh) plus a cliphist/wl-clipboard watcher, not a program with
  # its own CLI worth wrapping.
  outputs = _: {
    homeModules.default =
      {
        config,
        pkgs,
        lib,
        localLib,
        ...
      }:
      localLib.mkToggleModule config "clipboard" {
        home.file = {
          ".config/clipboard-fzf/clipboard.sh".source = ./clipboard.sh;
          ".config/clipboard-fzf/clipboard.zsh".source = ./clipboard.zsh;
        };

        # wl-clipboard and cliphist declared here (not just relying on the
        # hyprland module's own wl-clipboard) so this picker works standalone
        # regardless of which hyprland shell variant, if any, is active.
        home.packages = with pkgs; [
          cliphist
          wl-clipboard
          file
        ];

        programs.bash.initExtra = ''
          source ~/.config/clipboard-fzf/clipboard.sh
        '';
        # clipboard.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
        wrappers.zsh.extraInitContent = ''
          source ~/.config/clipboard-fzf/clipboard.sh
          source ~/.config/clipboard-fzf/clipboard.zsh
        '';

        # cliphist only has history to browse once something is actually watching
        # the clipboard and storing it; that requires a running Wayland session,
        # so this is wired into Hyprland's startup rather than run unconditionally.
        wayland.windowManager.hyprland.extraConfig = lib.mkIf config.dotfiles.desktop.hyprland.enable (
          lib.mkAfter ''
            hl.on("hyprland.start", function()
              hl.exec_cmd("wl-paste --type text --watch cliphist store")
              hl.exec_cmd("wl-paste --type image --watch cliphist store")
            end)
          ''
        );
      };
  };
}
