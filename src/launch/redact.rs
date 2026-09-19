use std::io::{self, Write};
use std::sync::{Arc, LazyLock, RwLock};

use regex::Regex;
use tracing_subscriber::fmt::MakeWriter;

fn replace_nix_store_paths(input: &str) -> String {
    static RE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"/nix/store/[a-z0-9]{32}").unwrap());
    RE.replace_all(input, "(nix)").into_owned()
}

#[derive(Clone, Default)]
pub struct Redactor {
    secrets: Arc<RwLock<Vec<String>>>,
}

impl Redactor {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn hide(&self, secret: String) {
        if !secret.is_empty() && secret != "0" {
            self.secrets.write().unwrap().push(secret);
        }
    }

    fn apply(&self, line: &str) -> String {
        let mut out = replace_nix_store_paths(line);
        for secret in self.secrets.read().unwrap().iter() {
            out = out.replace(secret, "<redacted>");
        }
        out
    }
}

pub struct RedactWriter(Redactor);

impl Write for RedactWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        let text = String::from_utf8_lossy(buf);
        io::stderr().write_all(self.0.apply(&text).as_bytes())?;
        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        io::stderr().flush()
    }
}

impl<'a> MakeWriter<'a> for Redactor {
    type Writer = RedactWriter;
    fn make_writer(&'a self) -> Self::Writer {
        RedactWriter(self.clone())
    }
}

#[cfg(test)]
mod tests {
    use super::Redactor;

    #[test]
    fn scrubs_secrets_and_store_hashes() {
        let r = Redactor::new();
        r.hide("s3cr3t-token".to_string());
        r.hide(String::new());
        r.hide("0".to_string());
        let line = "token=s3cr3t-token cp=/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-jre/bin";
        assert_eq!(r.apply(line), "token=<redacted> cp=(nix)-jre/bin");
    }
}
