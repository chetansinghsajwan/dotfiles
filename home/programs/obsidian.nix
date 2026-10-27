let
    vaultDir = "obsidian";
in
{
    programs.obsidian = {
        defaultSettings.app = {
            settingsPopoutWindow = false;
            spellcheck = false;
            useTab = false;
        };

        vaults.notes.target = "${vaultDir}/notes";
    };
}
