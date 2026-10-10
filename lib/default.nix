{ lib }:
rec {
    # Shared home-manager wiring for a host's default.nix — keeps
    # useUserPackages/backupFileExtension/etc. from drifting between hosts.
    mkHomeManagerModule =
        {
            username,
            imports,
            extraSpecialArgs ? { },
        }:
        {
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            home-manager.overwriteBackup = true;
            home-manager.extraSpecialArgs = extraSpecialArgs;
            home-manager.users.${username}.imports = imports;
        };

    mkToggleModule = config: name: body: {
        options.dotfiles.programs.${name}.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
        };
        config = lib.mkIf config.dotfiles.programs.${name}.enable body;
    };

    importDir =
        dir:
        let
            entries = builtins.readDir dir;
        in
        builtins.map (name: dir + "/${name}") (
            builtins.filter (
                name:
                entries.${name} == "regular" && builtins.match ".*\\.nix" name != null && name != "default.nix"
            ) (builtins.attrNames entries)
        );

    maxStringLen = list:
        assert lib.assertMsg (lib.isList list) "maxStringLen: expected a list";
        assert lib.assertMsg (lib.all lib.isString list) "maxStringLen: all items must be strings";
        lib.foldl' lib.max 0 (map builtins.stringLength list);

    defaultPadChar = " ";

    # v: string to pad, padChar: single-character padding string, width: target length
    padLeftWith = v: padChar: width:
        let
            padLen = width - builtins.stringLength v;
        in
        if padLen <= 0 then v else lib.concatStrings (lib.replicate padLen padChar) + v;

    padLeft = v: padLeftWith v defaultPadChar;

    padRightWith = v: padChar: width:
        let
            padLen = width - builtins.stringLength v;
        in
        if padLen <= 0 then v else v + lib.concatStrings (lib.replicate padLen padChar);

    padRight = v: padRightWith v defaultPadChar;

    padCenterWith = v: padChar: width:
        let
            padLen = width - builtins.stringLength v;
            leftLen = padLen / 2;
            rightLen = padLen - leftLen;
        in
        if padLen <= 0 then
            v
        else
            lib.concatStrings (lib.replicate leftLen padChar) + v + lib.concatStrings (lib.replicate rightLen padChar);

    padCenter = v: padCenterWith v defaultPadChar;

    # list: list of strings, padChar: single-character padding string
    # Pads every string on the right up to the length of the longest string.
    alignLeftPadWith = list: padChar:
        let
            width = maxStringLen list;
        in
        map (v: padRightWith v padChar width) list;

    alignLeftPad = list: alignLeftPadWith list defaultPadChar;

    # list: list of strings, padChar: single-character padding string
    # Pads every string on the left up to the length of the longest string.
    alignRightPadWith = list: padChar:
        let
            width = maxStringLen list;
        in
        map (v: padLeftWith v padChar width) list;

    alignRightPad = list: alignRightPadWith list defaultPadChar;

    # list: list of strings, padChar: single-character padding string
    # Pads every string on both sides up to the length of the longest string.
    alignCenterPadWith = list: padChar:
        let
            width = maxStringLen list;
        in
        map (v: padCenterWith v padChar width) list;

    alignCenterPad = list: alignCenterPadWith list defaultPadChar;

    # s: string to split, e.g. "camelCase", "PascalCase", "snake_case", "kebab-case"
    # Splits on "_", "-", " " and on lower/digit -> upper transitions.
    # Returns the words with their original casing intact (does not split acronym runs, e.g. "HTTPServer").
    splitWords = s:
        let
            len = builtins.stringLength s;
            chars = map (i: builtins.substring i 1 s) (lib.range 0 (len - 1));
            isUpper = c: c != "" && c == lib.toUpper c && c != lib.toLower c;
            isSep = c: c == "_" || c == "-" || c == " ";

            step = acc: c:
                if isSep c then
                    acc // { words = if acc.cur == "" then acc.words else acc.words ++ [ acc.cur ]; cur = ""; prevChar = ""; }
                else if acc.cur != "" && isUpper c && !(isUpper acc.prevChar) then
                    acc // { words = acc.words ++ [ acc.cur ]; cur = c; prevChar = c; }
                else
                    acc // { cur = acc.cur + c; prevChar = c; };

            result = lib.foldl' step { words = [ ]; cur = ""; prevChar = ""; } chars;
        in
        result.words ++ (if result.cur == "" then [ ] else [ result.cur ]);

    toUpperSep = v: sep: lib.concatStringsSep sep (map (w: lib.toUpper w) (splitWords v));
    toUpperSpc = v: toUpperSep v " ";
    toUpper = v: toUpperSep v "_";

    toLowerSep = v: sep: lib.concatStringsSep sep (map (w: lib.toLower w) (splitWords v));
    toLowerSpc = v: toLowerSep v " ";
    toLower = v: toLowerSep v "_";
}
