use std::path::PathBuf;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use minecraft::launch::redact::Redactor;
use minecraft::launch::{self, auth};
use tracing::{error, info};

#[derive(Parser)]
#[command(
    name = "mc",
    about = "Launch and authenticate declarative Minecraft instances"
)]
struct Cli {
    #[arg(short, long, global = true)]
    verbose: bool,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    Launch {
        #[arg(hide = true)]
        spec: Option<PathBuf>,
        #[arg(long)]
        profile: Option<String>,
    },
    Login {
        #[arg(long, default_value = "default")]
        account: String,
    },
    Logout {
        #[arg(long, default_value = "default")]
        account: String,
    },
}

fn init_tracing(verbose: bool) -> launch::redact::Redactor {
    let ours = if verbose { "debug" } else { "info" };
    let filter = tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
        tracing_subscriber::EnvFilter::new(format!("warn,minecraft={ours},mc={ours}"))
    });
    let redactor = launch::redact::Redactor::new();
    tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .without_time()
        .with_writer(redactor.clone())
        .init();
    redactor
}

async fn dispatch(command: Command, redactor: Redactor) -> Result<()> {
    match command {
        Command::Launch { spec, profile } => {
            let spec = spec.context("no launch spec provided")?;
            let contents = std::fs::read_to_string(&spec)
                .with_context(|| format!("failed to read spec file {}", spec.display()))?;
            let spec_data: launch::Spec =
                serde_json::from_str(&contents).context("failed to parse launch spec")?;
            launch::run(spec, spec_data, profile, redactor).await
        }
        Command::Login { account } => {
            let session = auth::authenticate(&account).await?;
            info!("logged in as {}", session.name);
            Ok(())
        }
        Command::Logout { account } => {
            auth::logout(&account)?;
            info!("logged out account '{account}'");
            Ok(())
        }
    }
}

// Errors are logged through the redactor rather than returned, so the runtime's
// Debug printer never emits an unredacted line.
#[tokio::main]
async fn main() -> std::process::ExitCode {
    let cli = Cli::parse();
    let redactor = init_tracing(cli.verbose);

    match dispatch(cli.command, redactor).await {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(err) => {
            error!("{err:#}");
            std::process::ExitCode::FAILURE
        }
    }
}
