mod client;
mod daemon;
mod keys;
mod mods;
mod state;

use std::process::ExitCode;

use client::Format;

const DEFAULT_KANATA: &str = "127.0.0.1:6666";
const DEFAULT_ADDR: &str = "127.0.0.1:6667";
const DEFAULT_MODS_DEVICE: &str = "/run/kanata-main/main";

const USAGE: &str = "\
kb - keyboard status stream

usage:
  kb daemon [--kanata ADDR] [--listen ADDR] [--mods-device PATH]
                                              follow kanata, serve state to clients
  kb watch  [--addr ADDR] [--format json|layer|line]   print every change
  kb get    [--addr ADDR] [--format json|layer|line]   print the current state once

formats: json (raw), layer (LAYER), line (LAYER +mods, e.g. NAV +CS)
defaults: kanata 127.0.0.1:6666, daemon/clients 127.0.0.1:6667,
          mods device /run/kanata-main/main (Linux only; Windows and macOS poll the OS)";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match run(&args) {
        Ok(()) => ExitCode::SUCCESS,
        Err(msg) => {
            eprintln!("kb: {msg}\n\n{USAGE}");
            ExitCode::FAILURE
        }
    }
}

fn run(args: &[String]) -> Result<(), String> {
    let (cmd, rest) = args.split_first().ok_or("missing command")?;
    let opts = Opts::parse(rest)?;
    match cmd.as_str() {
        "daemon" => {
            daemon::run(opts.kanata, opts.addr, opts.mods_device).map_err(|e| e.to_string())
        }
        "watch" => client::watch(&opts.addr, opts.format).map_err(|e| e.to_string()),
        "get" => client::get(&opts.addr, opts.format).map_err(|e| e.to_string()),
        other => Err(format!("unknown command `{other}`")),
    }
}

struct Opts {
    kanata: String,
    addr: String,
    mods_device: String,
    format: Format,
}

impl Opts {
    fn parse(args: &[String]) -> Result<Self, String> {
        let mut opts = Opts {
            kanata: DEFAULT_KANATA.into(),
            addr: DEFAULT_ADDR.into(),
            mods_device: DEFAULT_MODS_DEVICE.into(),
            format: Format::Json,
        };
        let mut it = args.iter();
        while let Some(flag) = it.next() {
            let mut value = || it.next().cloned().ok_or(format!("{flag} needs a value"));
            match flag.as_str() {
                "--kanata" => opts.kanata = value()?,
                "--listen" | "--addr" => opts.addr = value()?,
                "--mods-device" => opts.mods_device = value()?,
                "--format" => {
                    opts.format = match value()?.as_str() {
                        "json" => Format::Json,
                        "layer" => Format::Layer,
                        "line" => Format::Line,
                        other => return Err(format!("unknown format `{other}`")),
                    }
                }
                other => return Err(format!("unknown option `{other}`")),
            }
        }
        Ok(opts)
    }
}
