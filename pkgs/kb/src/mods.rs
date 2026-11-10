//! Held keys, read from the OS (the modifiers are derived from them in `keys`). Linux reads
//! kanata's virtual output device (the same events the compositor acts on); Windows and
//! macOS poll the OS key state, so a tap shorter than the poll interval can be missed.

/// Tracks which keys are down from a stream of Linux key events.
#[cfg_attr(not(all(target_os = "linux", target_pointer_width = "64")), allow(dead_code))]
#[derive(Default)]
pub struct Tracker {
    held: Vec<&'static str>,
}

#[cfg_attr(not(all(target_os = "linux", target_pointer_width = "64")), allow(dead_code))]
impl Tracker {
    /// Feeds one key event (`value`: 0 release, 1 press, 2 repeat); returns the new
    /// held keys, in press order, if this event changed them.
    pub fn key(&mut self, code: u16, value: i32) -> Option<Vec<String>> {
        let name = crate::keys::linux(code)?;
        match value {
            1 if !self.held.contains(&name) => self.held.push(name),
            0 if self.held.contains(&name) => self.held.retain(|k| *k != name),
            _ => return None,
        }
        Some(self.held())
    }

    pub fn held(&self) -> Vec<String> {
        self.held.iter().map(|k| k.to_string()).collect()
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

    /// Calls `on_change` with the held keys every time they change, forever; waits for
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
        assert_eq!(t.key(29, 1), Some(vec!["lctl".into()]));
        assert_eq!(t.key(30, 1), Some(vec!["lctl".into(), "a".into()]));
        assert_eq!(t.key(29, 0), Some(vec!["a".into()]));
    }

    #[test]
    fn poller_reports_only_changes() {
        let mut p = super::Poller::default();
        assert_eq!(p.sample(vec![]), None);
        assert_eq!(p.sample(vec!["lctl".into()]), Some(vec!["lctl".into()]));
        assert_eq!(p.sample(vec!["lctl".into()]), None);
        assert_eq!(p.sample(vec![]), Some(vec![]));
    }

    #[test]
    fn repeats_and_unknown_keys_are_ignored() {
        let mut t = Tracker::default();
        assert_eq!(t.key(999, 1), None);
        t.key(56, 1);
        assert_eq!(t.key(56, 2), None);
        assert_eq!(t.key(56, 1), None);
    }
}

/// Turns periodic samples of "which keys are down" into change events. Used where the OS
/// can be asked, not told: Windows and macOS.
#[derive(Default)]
#[cfg_attr(not(any(windows, target_os = "macos")), allow(dead_code))]
pub struct Poller {
    last: Vec<String>,
}

#[cfg_attr(not(any(windows, target_os = "macos")), allow(dead_code))]
impl Poller {
    /// The new held keys if they differ from the previous sample.
    pub fn sample(&mut self, down: Vec<String>) -> Option<Vec<String>> {
        if down == self.last {
            return None;
        }
        self.last = down.clone();
        Some(down)
    }
}

#[cfg(any(windows, target_os = "macos"))]
fn poll_forever(sample: impl Fn() -> Vec<String>, mut on_change: impl FnMut(Vec<String>)) -> ! {
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

    fn sample() -> Vec<String> {
        crate::keys::WINDOWS
            .iter()
            // SAFETY: plain user32 call with no pointers; the high bit means "currently down".
            .filter(|(vk, _)| unsafe { GetAsyncKeyState(*vk) } < 0)
            .map(|(_, name)| name.to_string())
            .collect()
    }

    pub fn watch(on_change: impl FnMut(Vec<String>)) -> ! {
        super::poll_forever(sample, on_change)
    }
}

/// macOS: the combined session state includes events posted by kanata's virtual keyboard.
#[cfg(target_os = "macos")]
pub mod macos {
    #[link(name = "CoreGraphics", kind = "framework")]
    unsafe extern "C" {
        fn CGEventSourceKeyState(state_id: i32, key: u16) -> bool;
    }

    /// `kCGEventSourceStateCombinedSessionState`
    const COMBINED_SESSION: i32 = 0;

    fn sample() -> Vec<String> {
        crate::keys::MACOS
            .iter()
            // SAFETY: plain CoreGraphics call with no pointers.
            .filter(|(code, _)| unsafe { CGEventSourceKeyState(COMBINED_SESSION, *code) })
            .map(|(_, name)| name.to_string())
            .collect()
    }

    pub fn watch(on_change: impl FnMut(Vec<String>)) -> ! {
        super::poll_forever(sample, on_change)
    }
}
