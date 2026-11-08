//! Held modifiers, read from the OS. Linux reads kanata's virtual output device
//! (the same events the compositor acts on); other platforms are not implemented yet.

pub const MODS: [&str; 4] = ["ctrl", "shift", "alt", "meta"];

/// Counts presses per modifier, not booleans, so releasing the left shift while the
/// right one is still down keeps shift held.
#[derive(Default)]
pub struct Tracker {
    held: [u32; 4],
}

impl Tracker {
    /// Feeds one key event (`value`: 0 release, 1 press, 2 repeat); returns the new
    /// held set if this event changed it.
    pub fn key(&mut self, code: u16, value: i32) -> Option<Vec<String>> {
        let slot = slot_of(code)?;
        let before = self.held[slot] > 0;
        match value {
            1 => self.held[slot] += 1,
            0 => self.held[slot] = self.held[slot].saturating_sub(1),
            _ => return None,
        }
        (before != (self.held[slot] > 0)).then(|| self.held())
    }

    pub fn held(&self) -> Vec<String> {
        MODS.iter()
            .zip(self.held)
            .filter(|(_, n)| *n > 0)
            .map(|(m, _)| m.to_string())
            .collect()
    }
}

/// Index into `MODS` for a Linux key code (`linux/input-event-codes.h`).
fn slot_of(code: u16) -> Option<usize> {
    match code {
        29 | 97 => Some(0),   // KEY_LEFTCTRL, KEY_RIGHTCTRL
        42 | 54 => Some(1),   // KEY_LEFTSHIFT, KEY_RIGHTSHIFT
        56 | 100 => Some(2),  // KEY_LEFTALT, KEY_RIGHTALT
        125 | 126 => Some(3), // KEY_LEFTMETA, KEY_RIGHTMETA
        _ => None,
    }
}

#[cfg(all(target_os = "linux", target_pointer_width = "64"))]
pub mod linux {
    use std::fs::File;
    use std::io::Read;
    use std::thread;
    use std::time::Duration;

    use super::Tracker;

    const EV_KEY: u16 = 1;
    /// `struct input_event` on 64-bit Linux: timeval (16) + type (2) + code (2) + value (4).
    const EVENT_SIZE: usize = 24;

    /// (type, code, value) of a raw `input_event`.
    fn parse(buf: &[u8; EVENT_SIZE]) -> (u16, u16, i32) {
        (
            u16::from_ne_bytes([buf[16], buf[17]]),
            u16::from_ne_bytes([buf[18], buf[19]]),
            i32::from_ne_bytes([buf[20], buf[21], buf[22], buf[23]]),
        )
    }

    /// Calls `on_change` with the held mods every time they change, forever; waits for
    /// the device to appear and reopens it if it goes away.
    pub fn watch(device: &str, mut on_change: impl FnMut(Vec<String>)) {
        loop {
            if let Ok(mut file) = File::open(device) {
                let mut tracker = Tracker::default();
                let mut buf = [0u8; EVENT_SIZE];
                while file.read_exact(&mut buf).is_ok() {
                    let (kind, code, value) = parse(&buf);
                    if kind == EV_KEY
                        && let Some(held) = tracker.key(code, value)
                    {
                        on_change(held);
                    }
                }
                on_change(Vec::new());
            }
            thread::sleep(Duration::from_secs(1));
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn parses_a_raw_event() {
            let mut buf = [0u8; EVENT_SIZE];
            buf[16..18].copy_from_slice(&1u16.to_ne_bytes());
            buf[18..20].copy_from_slice(&29u16.to_ne_bytes());
            buf[20..24].copy_from_slice(&1i32.to_ne_bytes());
            assert_eq!(parse(&buf), (1, 29, 1));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Tracker;

    #[test]
    fn press_and_release() {
        let mut t = Tracker::default();
        assert_eq!(t.key(29, 1), Some(vec!["ctrl".into()]));
        assert_eq!(t.key(42, 1), Some(vec!["ctrl".into(), "shift".into()]));
        assert_eq!(t.key(29, 0), Some(vec!["shift".into()]));
    }

    #[test]
    fn two_sides_of_one_mod_do_not_cancel() {
        let mut t = Tracker::default();
        t.key(42, 1);
        assert_eq!(t.key(54, 1), None);
        assert_eq!(t.key(42, 0), None);
        assert_eq!(t.key(54, 0), Some(vec![]));
    }

    #[test]
    fn repeats_and_other_keys_are_ignored() {
        let mut t = Tracker::default();
        assert_eq!(t.key(30, 1), None);
        t.key(56, 1);
        assert_eq!(t.key(56, 2), None);
    }
}
