{ pkgs, ... }:
let
    firefox-addons = pkgs.nur.repos.rycee.firefox-addons;
in
{
    programs.firefox = {
        enable = true;

        profiles.default = {
            id = 0;
            name = "default";
            isDefault = true;

            settings = {
                "browser.tabs.closeWindowWithLastTab" = false;
                "browser.tabs.warnOnClose" = true;
                "browser.tabs.inTitlebar" = false;
                "browser.tabs.tabmanager.enabled" = false;
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

            search = {
                force = true;
                default = "Google";
                privateDefault = "Google";

                engines = {
                    "Bing".metaData.hidden = true;
                    "Google".metaData.alias = "@g";
                    "Wikipedia (en)".metaData.alias = "@wiki";
                    "youtube" = {
                        urls = [{
                            template = "https://www.youtube.com/results";
                            params = [
                                { name = "search_query"; value = "{searchTerms}"; }
                            ];
                        }];
                        definedAliases = [ "@yt" ];
                    };
                    "youtube-music" = {
                        urls = [{
                            template = "https://music.youtube.com/search";
                            params = [
                                { name = "q"; value = "{searchTerms}"; }
                            ];
                        }];
                        definedAliases = [ "@ytm" ];
                    };
                    "nixpkgs" = {
                        urls = [{
                            template = "https://search.nixos.org/packages";
                            params = [
                                { name = "query"; value = "{searchTerms}"; }
                            ];
                        }];
                        definedAliases = [ "@np" ];
                    };
                    "nixopts" = {
                        urls = [{
                            template = "https://search.nixos.org/options";
                            params = [
                                { name = "query"; value = "{searchTerms}"; }
                            ];
                        }];
                        definedAliases = [ "@no" ];
                    };
                    "nixwiki" = {
                        urls = [{
                            template = "https://nixos.wiki/index.php";
                            params = [
                                { name = "search"; value = "{searchTerms}"; }
                            ];
                        }];
                        definedAliases = [ "@nw" ];
                    };
                    "home-manager" = {
                        urls = [{
                            template = "https://home-manager-options.extranix.com";
                            params = [
                                { name = "query"; value = "{searchTerms}"; }
                            ];
                        }];
                        definedAliases = [ "@hm" ];
                    };
                };
            };

            extensions = with firefox-addons; [
                bitwarden
                ublock-origin
                darkreader
                wikiwand-wikipedia-modernized
            ];
        };
    };
}
