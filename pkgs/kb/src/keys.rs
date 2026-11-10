//! Key names shared by every platform: kanata's own (the ones written in a `.kbd` file), so
//! clients can match what is held against what the config maps.
#![allow(dead_code)]

pub const MODS: [&str; 4] = ["ctrl", "shift", "alt", "meta"];

/// The modifier a key belongs to, if it is one.
pub fn mod_of(key: &str) -> Option<&'static str> {
    match key {
        "lctl" | "rctl" => Some("ctrl"),
        "lsft" | "rsft" => Some("shift"),
        "lalt" | "ralt" => Some("alt"),
        "lmet" | "rmet" => Some("meta"),
        _ => None,
    }
}

/// The held modifiers (in `MODS` order) among the held keys.
pub fn mods_of(keys: &[String]) -> Vec<String> {
    MODS.iter()
        .filter(|m| keys.iter().any(|k| mod_of(k) == Some(**m)))
        .map(|m| m.to_string())
        .collect()
}

/// Linux key codes (`linux/input-event-codes.h`).
pub const LINUX: &[(u16, &str)] = &[
    (1, "esc"), (2, "1"), (3, "2"), (4, "3"), (5, "4"), (6, "5"), (7, "6"), (8, "7"), (9, "8"),
    (10, "9"), (11, "0"), (12, "-"), (13, "="), (14, "bspc"), (15, "tab"), (16, "q"), (17, "w"),
    (18, "e"), (19, "r"), (20, "t"), (21, "y"), (22, "u"), (23, "i"), (24, "o"), (25, "p"),
    (26, "["), (27, "]"), (28, "ret"), (29, "lctl"), (30, "a"), (31, "s"), (32, "d"), (33, "f"),
    (34, "g"), (35, "h"), (36, "j"), (37, "k"), (38, "l"), (39, ";"), (40, "'"), (41, "grv"),
    (42, "lsft"), (43, "\\"), (44, "z"), (45, "x"), (46, "c"), (47, "v"), (48, "b"), (49, "n"),
    (50, "m"), (51, ","), (52, "."), (53, "/"), (54, "rsft"), (56, "lalt"), (57, "spc"),
    (58, "caps"), (59, "f1"), (60, "f2"), (61, "f3"), (62, "f4"), (63, "f5"), (64, "f6"),
    (65, "f7"), (66, "f8"), (67, "f9"), (68, "f10"), (87, "f11"), (88, "f12"), (97, "rctl"),
    (100, "ralt"), (102, "home"), (103, "up"), (104, "pgup"), (105, "left"), (106, "right"),
    (107, "end"), (108, "down"), (109, "pgdn"), (110, "ins"), (111, "del"), (113, "mute"),
    (114, "vold"), (115, "volu"), (125, "lmet"), (126, "rmet"), (127, "menu"),
];

pub fn linux(code: u16) -> Option<&'static str> {
    LINUX.iter().find(|(c, _)| *c == code).map(|(_, n)| *n)
}

/// Windows virtual-key codes.
pub const WINDOWS: &[(i32, &str)] = &[
    (0x08, "bspc"), (0x09, "tab"), (0x0D, "ret"), (0x14, "caps"), (0x1B, "esc"), (0x20, "spc"),
    (0x21, "pgup"), (0x22, "pgdn"), (0x23, "end"), (0x24, "home"), (0x25, "left"), (0x26, "up"),
    (0x27, "right"), (0x28, "down"), (0x2D, "ins"), (0x2E, "del"),
    (0x30, "0"), (0x31, "1"), (0x32, "2"), (0x33, "3"), (0x34, "4"), (0x35, "5"), (0x36, "6"),
    (0x37, "7"), (0x38, "8"), (0x39, "9"),
    (0x41, "a"), (0x42, "b"), (0x43, "c"), (0x44, "d"), (0x45, "e"), (0x46, "f"), (0x47, "g"),
    (0x48, "h"), (0x49, "i"), (0x4A, "j"), (0x4B, "k"), (0x4C, "l"), (0x4D, "m"), (0x4E, "n"),
    (0x4F, "o"), (0x50, "p"), (0x51, "q"), (0x52, "r"), (0x53, "s"), (0x54, "t"), (0x55, "u"),
    (0x56, "v"), (0x57, "w"), (0x58, "x"), (0x59, "y"), (0x5A, "z"),
    (0x5B, "lmet"), (0x5C, "rmet"), (0x5D, "menu"),
    (0x70, "f1"), (0x71, "f2"), (0x72, "f3"), (0x73, "f4"), (0x74, "f5"), (0x75, "f6"),
    (0x76, "f7"), (0x77, "f8"), (0x78, "f9"), (0x79, "f10"), (0x7A, "f11"), (0x7B, "f12"),
    (0xA0, "lsft"), (0xA1, "rsft"), (0xA2, "lctl"), (0xA3, "rctl"), (0xA4, "lalt"), (0xA5, "ralt"),
    (0xAD, "mute"), (0xAE, "vold"), (0xAF, "volu"),
    (0xBA, ";"), (0xBB, "="), (0xBC, ","), (0xBD, "-"), (0xBE, "."), (0xBF, "/"), (0xC0, "grv"),
    (0xDB, "["), (0xDC, "\\"), (0xDD, "]"), (0xDE, "'"),
];

/// macOS virtual key codes (`kVK_*`, ANSI layout).
pub const MACOS: &[(u16, &str)] = &[
    (0, "a"), (1, "s"), (2, "d"), (3, "f"), (4, "h"), (5, "g"), (6, "z"), (7, "x"), (8, "c"),
    (9, "v"), (11, "b"), (12, "q"), (13, "w"), (14, "e"), (15, "r"), (16, "y"), (17, "t"),
    (18, "1"), (19, "2"), (20, "3"), (21, "4"), (22, "6"), (23, "5"), (24, "="), (25, "9"),
    (26, "7"), (27, "-"), (28, "8"), (29, "0"), (30, "]"), (31, "o"), (32, "u"), (33, "["),
    (34, "i"), (35, "p"), (36, "ret"), (37, "l"), (38, "j"), (39, "'"), (40, "k"), (41, ";"),
    (42, "\\"), (43, ","), (44, "/"), (45, "n"), (46, "m"), (47, "."), (48, "tab"), (49, "spc"),
    (50, "grv"), (51, "bspc"), (53, "esc"), (54, "rmet"), (55, "lmet"), (56, "lsft"),
    (57, "caps"), (58, "lalt"), (59, "lctl"), (60, "rsft"), (61, "ralt"), (62, "rctl"),
    (96, "f5"), (97, "f6"), (98, "f7"), (99, "f3"), (100, "f8"), (101, "f9"), (103, "f11"),
    (109, "f10"), (111, "f12"), (115, "home"), (116, "pgup"), (117, "del"), (118, "f4"),
    (119, "end"), (120, "f2"), (121, "pgdn"), (122, "f1"), (123, "left"), (124, "right"),
    (125, "down"), (126, "up"),
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mods_follow_either_side() {
        let keys = ["a".to_string(), "rsft".into(), "lctl".into()];
        assert_eq!(mods_of(&keys), vec!["ctrl", "shift"]);
    }

    #[test]
    fn tables_have_no_duplicate_codes() {
        for t in [LINUX.iter().map(|(c, _)| *c as i32).collect::<Vec<_>>(),
                  WINDOWS.iter().map(|(c, _)| *c).collect(),
                  MACOS.iter().map(|(c, _)| *c as i32).collect()] {
            let mut sorted = t.clone();
            sorted.sort();
            sorted.dedup();
            assert_eq!(sorted.len(), t.len());
        }
    }
}
