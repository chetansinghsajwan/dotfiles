{ firefox-extensions, ... }:
{
  programs.firefox = {
    enable = true;

    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;
      settings = {
        "browser.tabs.closeWindowWithLastTab" = false;
        "browser.tabs.tabmanager.enabled" = true;
        "browser.tabs.warnOnClose" = true;
        "browser.tabs.inTitlebar" = true;
        "browser.startup.homepage" = "about:home";
        "browser.startup.firstrunSkipsHomepage" = false;
        "browser.toolbars.bookmarks.visibility" = "never";
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.showRecentSaves" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        "browser.aboutConfig.showWarning" = false;

        # disable password management
        "signon.rememberSignons" = false;
        "signon.management.page.breach-alerts.enabled" = false;

        # so that only the active tab has close button
        "browser.tabs.tabClipWidth" = 999;

        "app.update.service.enabled" = false;
        "findbar.highlightAll" = true;
        "findbar.modalHighlight" = true;
        "media.autoplay.enabled" = false;

        # zoom settings
        "mousewheel.default.delta_multiplier_x" = 20;
        "mousewheel.default.delta_multiplier_y" = 20;
        "mousewheel.default.delta_multiplier_z" = 20;

        # removes full screen transition
        "full-screen-api.transition-duration.enter" = 0;
        "full-screen-api.transition-duration.leave" = 0;
        "full-screen-api.transition.timeout" = 0;
        "full-screen-api.warning.delay" = 0;
        "full-screen-api.warning.timeout" = 0;

        # disables pocket
        "extensions.pocket.enabled" = false;
      };

      extensions = with firefox-extensions; [
        bitwarden
        ublock-origin
        darkreader
        # wikiwand-wikipedia-modernized
      ];
    };
  };
}
