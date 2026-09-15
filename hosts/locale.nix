{
  # i18n.defaultLocale isn't a declared option under nix-darwin, so this
  # file is only ever imported by Linux hosts directly — see hosts/shared.nix
  # for why it can't live there (even gated), unlike time.timeZone.
  i18n.defaultLocale = "en_IN";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };
}
