//! Held modifiers, read from the OS. Linux reads kanata's virtual output device (the same
//! events the compositor acts on); Windows and macOS poll the OS key state.

pub const MODS: [&str; 4] = ["ctrl", "shift", "alt", "meta"];

/// Counts presses per modifier, not booleans, so releasing the left shift while the
/// right one is still down keeps shift held.
#[cfg_attr(not(all(target_os = "linux", target_pointer_width = "64")), allow(dead_code))]
#[derive(Default)]
pub struct Tracker {
    held: [u32; 4],
}

#[cfg_attr(not(all(target_os = "linux", target_pointer_width = "64")), allow(dead_code))]
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
#[cfg_attr(not(all(target_os = "linux", target_pointer_width = "64")), allow(dead_code))]
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
    fn poller_reports_only_changes() {
        let mut p = super::Poller::default();
        assert_eq!(p.sample([false; 4]), None);
        assert_eq!(
            p.sample([true, false, false, true]),
            Some(vec!["ctrl".into(), "meta".into()])
        );
        assert_eq!(p.sample([true, false, false, true]), None);
        assert_eq!(p.sample([false; 4]), Some(vec![]));
    }

    #[test]
    fn repeats_and_other_keys_are_ignored() {
        let mut t = Tracker::default();
        assert_eq!(t.key(30, 1), None);
        t.key(56, 1);
        assert_eq!(t.key(56, 2), None);
    }
}

/// Turns periodic samples of "which of ctrl, shift, alt, meta are down" (in `MODS`
/// order) into change events. Used where the OS can be asked, not told: Windows and macOS.
#[derive(Default)]
#[cfg_attr(not(any(windows, target_os = "macos")), allow(dead_code))]
pub struct Poller {
    last: [bool; 4],
}

#[cfg_attr(not(any(windows, target_os = "macos")), allow(dead_code))]
impl Poller {
    /// The new held set if it differs from the previous sample.
    pub fn sample(&mut self, down: [bool; 4]) -> Option<Vec<String>> {
        if down == self.last {
            return None;
        }
        self.last = down;
        Some(
            MODS.iter()
                .zip(down)
                .filter(|(_, d)| *d)
                .map(|(m, _)| m.to_string())
                .collect(),
        )
    }
}

#[cfg(any(windows, target_os = "macos"))]
fn poll_forever(sample: impl Fn() -> [bool; 4], mut on_change: impl FnMut(Vec<String>)) -> ! {
    let mut poller = Poller::default();
    loop {
        if let Some(held) = poller.sample(sample()) {
            on_change(held);
        }
        std::thread::sleep(std::time::Duration::from_millis(30));
    }
}

/// Windows: `GetAsyncKeyState` reports the physical-plus-injected state, so it sees the
/// keys kanata emits.
#[cfg(windows)]
pub mod windows {
    #[link(name = "user32")]
    unsafe extern "system" {
        fn GetAsyncKeyState(vkey: i32) -> i16;
    }

    const VK_SHIFT: i32 = 0x10;
    const VK_CONTROL: i32 = 0x11;
    const VK_MENU: i32 = 0x12; // alt
    const VK_LWIN: i32 = 0x5B;
    const VK_RWIN: i32 = 0x5C;

    fn down(vkey: i32) -> bool {
        // SAFETY: plain user32 call with no pointers; the high bit means "currently down".
        unsafe { GetAsyncKeyState(vkey) < 0 }
    }

    fn sample() -> [bool; 4] {
        [
            down(VK_CONTROL),
            down(VK_SHIFT),
            down(VK_MENU),
            down(VK_LWIN) || down(VK_RWIN),
        ]
    }

    pub fn watch(on_change: impl FnMut(Vec<String>)) -> ! {
        super::poll_forever(sample, on_change)
    }
}

/// macOS: the combined session flags include events posted by kanata's virtual keyboard.
#[cfg(target_os = "macos")]
pub mod macos {
    #[link(name = "CoreGraphics", kind = "framework")]
    unsafe extern "C" {
        fn CGEventSourceFlagsState(state_id: i32) -> u64;
    }

    /// `kCGEventSourceStateCombinedSessionState`
    const COMBINED_SESSION: i32 = 0;
    const SHIFT: u64 = 0x0002_0000;
    const CONTROL: u64 = 0x0004_0000;
    const OPTION: u64 = 0x0008_0000; // alt
    const COMMAND: u64 = 0x0010_0000;

    fn sample() -> [bool; 4] {
        // SAFETY: plain CoreGraphics call with no pointers.
        let flags = unsafe { CGEventSourceFlagsState(COMBINED_SESSION) };
        [
            flags & CONTROL != 0,
            flags & SHIFT != 0,
            flags & OPTION != 0,
            flags & COMMAND != 0,
        ]
    }

    pub fn watch(on_change: impl FnMut(Vec<String>)) -> ! {
        super::poll_forever(sample, on_change)
    }
}
