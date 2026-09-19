use std::io::{self, Write};
use std::time::Duration;

use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use tracing_subscriber::fmt::MakeWriter;

pub fn bar(multi: &MultiProgress, len: u64, msg: &'static str) -> ProgressBar {
    let pb = multi.add(ProgressBar::new(len));
    pb.set_style(
        ProgressStyle::with_template("{spinner:.green} {msg} [{bar:40}] {pos}/{len} ({eta})")
            .unwrap()
            .progress_chars("=>-"),
    );
    pb.set_message(msg);
    pb
}

pub fn spinner(multi: &MultiProgress, msg: String) -> ProgressBar {
    let pb = multi.add(ProgressBar::new_spinner());
    pb.set_style(ProgressStyle::with_template("{spinner:.green} {msg}").unwrap());
    pb.enable_steady_tick(Duration::from_millis(100));
    pb.set_message(msg);
    pb
}

#[derive(Clone)]
pub struct BarWriter(pub MultiProgress);

impl Write for BarWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        self.0.suspend(|| io::stderr().write(buf))
    }

    fn flush(&mut self) -> io::Result<()> {
        io::stderr().flush()
    }
}

impl<'a> MakeWriter<'a> for BarWriter {
    type Writer = BarWriter;

    fn make_writer(&'a self) -> Self::Writer {
        self.clone()
    }
}
