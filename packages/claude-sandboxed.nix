{ pkgs, ... }:
let
  claudeMd = pkgs.writeText "CLAUDE.md" ''
    # Sandbox environment

    You are running inside a systemd-isolated sandbox.  The sandbox uses
    an explicit allowlist: anything not listed here is INVISIBLE.

    ## Filesystem you can see
    - The current project directory (read-write).
    - /nix (read-only) - full Nix store, daemon socket.
    - /run/current-system, /run/booted-system (read-only) - NixOS profile.
    - A fresh empty $HOME (writable tmpfs, discarded on exit).
    - A handful of /etc files needed for DNS, certs, user lookup.
    - /tmp is a private tmpfs.

    ## Filesystem you CANNOT see
    - The real $HOME (your dotfiles, SSH keys, browser data, etc.).
    - /var, /root, /boot, /mnt, /media, /srv, other /home/* users.
    - Any /etc files not explicitly bound (no /etc/shadow, etc.).

    ## Running commands
    You have full access to the Nix daemon (NIX_REMOTE=daemon is set).
    Every Nix workflow works normally:

    ```bash
    nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#ripgrep nixpkgs#jq --command rg "foo" src/
    nix --extra-experimental-features 'nix-command flakes' run nixpkgs#hyperfine -- --warmup 3 './my-bench'
    nix --extra-experimental-features 'nix-command flakes' build .#myPackage
    ```

    This is a flakes-based setup with no nixpkgs channels registered.
    Always pass `--extra-experimental-features 'nix-command flakes'` to nix commands.
    Prefer `nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#<pkg> --command <cmd>`
    for one-off tool use rather than assuming a tool is on PATH.
    Do NOT use `nix-shell -p <pkg>` as that requires channels.

    ## What you cannot do
    - Write outside the project directory and the ephemeral $HOME.
    - Load kernel modules, change hostnames, acquire new privileges.
  '';
in
pkgs.writeShellApplication {
  name = "claude-sandboxed";

  runtimeInputs = [
    pkgs.systemd
    pkgs.coreutils
    pkgs.nix
  ];

  text = ''
    ALLOW_UNFREE=0
    FILTERED_ARGS=()
    for arg in "$@"; do
      if [[ "$arg" == "--acknowledge-unfree" || "$arg" == "--allow-unfree" ]]; then
        ALLOW_UNFREE=1
      else
        FILTERED_ARGS+=("$arg")
      fi
    done
    set -- "''${FILTERED_ARGS[@]}"

    if [[ "$ALLOW_UNFREE" == "0" ]]; then
      echo "error: claude-sandboxed wraps the unfree package 'claude-code'." >&2
      echo "Pass --acknowledge-unfree to allow the unfree nixpkgs import." >&2
      exit 1
    fi

    # NIXPKGS_ALLOW_UNFREE=1 directly controls nixpkgs' config.allowUnfree;
    # --impure is required for nix to read the env var during evaluation.
    CLAUDE_BIN=$(NIXPKGS_ALLOW_UNFREE=1 nix build nixpkgs#claude-code --no-link --print-out-paths --impure)/bin/claude
    BASH_BIN="${pkgs.bash}/bin/bash"

    PROJECT_DIR="$(realpath "''${1:-.}")"
    shift 2>/dev/null || true

    LAUNCH_SHELL=0
    CLAUDE_ARGS=()
    for arg in "$@"; do
      if [[ "$arg" == "--shell" ]]; then
        LAUNCH_SHELL=1
      else
        CLAUDE_ARGS+=("$arg")
      fi
    done

    USER_RUNTIME="/run/user/$(id -u)"

    # Ensure ~/.claude/CLAUDE.md exists with the sandbox context description.
    # ~/.claude is not persisted across reboots (darling erasure), so initialize it on first use.
    mkdir -p "$HOME/.claude"
    if [[ ! -f "$HOME/.claude/CLAUDE.md" ]]; then
      cp ${claudeMd} "$HOME/.claude/CLAUDE.md"
    fi

    PROPS=(
      --user
      --collect
      --description="Claude Code sandbox: $PROJECT_DIR"
      --working-directory="$PROJECT_DIR"

      --property=TemporaryFileSystem=/
      --property=PrivateTmp=yes

      --property=BindReadOnlyPaths=/nix
      --property=BindReadOnlyPaths=-/run/current-system
      --property=BindReadOnlyPaths=-/run/booted-system
      --property=BindReadOnlyPaths=-/bin
      --property=BindReadOnlyPaths=-/usr
      --property=BindReadOnlyPaths=-/lib
      --property=BindReadOnlyPaths=-/lib64
      --property=BindReadOnlyPaths=-/sbin
      --property=BindReadOnlyPaths=-/etc/resolv.conf
      --property=BindReadOnlyPaths=-/etc/ssl
      --property=BindReadOnlyPaths=-/etc/static
      --property=BindReadOnlyPaths=-/etc/nsswitch.conf
      --property=BindReadOnlyPaths=-/etc/hosts
      --property=BindReadOnlyPaths=-/etc/protocols
      --property=BindReadOnlyPaths=-/etc/services
      --property=BindReadOnlyPaths=-/etc/passwd
      --property=BindReadOnlyPaths=-/etc/group
      --property=BindReadOnlyPaths=-/etc/profile
      --property=BindReadOnlyPaths=-/etc/login.defs
      --property=BindReadOnlyPaths=-/etc/bashrc

      --property=TemporaryFileSystem="$USER_RUNTIME"
      --property=TemporaryFileSystem="$HOME"
      --property=BindPaths="$HOME/.claude"  # global Claude state (memory, settings, API key)
      --property=BindPaths="$PROJECT_DIR"

      --property=ProtectKernelTunables=yes
      --property=ProtectKernelModules=yes
      --property=ProtectKernelLogs=yes
      --property=ProtectControlGroups=yes
      --property=ProtectHostname=yes
      --property=ProtectClock=yes
      --property=RestrictNamespaces=yes
      --property=LockPersonality=yes
      --property=RestrictRealtime=yes
      --property=RestrictSUIDSGID=yes
      --property=NoNewPrivileges=yes
      --property=RemoveIPC=yes
      --property=MemoryDenyWriteExecute=no  # Bun needs JIT pages

      --property=Environment=NIX_REMOTE=daemon
      --property=Environment=HOME="$HOME"
      --property=Environment=PATH="$PATH"
      --property="Environment=TERM=''${TERM:-xterm-256color}"
      --property="Environment=LANG=''${LANG:-en_US.UTF-8}"
    )

    RUN_FLAGS=(--pty --quiet --send-sighup)

    if [[ "$LAUNCH_SHELL" == "1" ]]; then
      exec systemd-run "''${PROPS[@]}" "''${RUN_FLAGS[@]}" "$BASH_BIN" --login
    elif [[ "''${CLAUDE_ARGS[0]:-}" == "--debug" ]]; then
      CLAUDE_ARGS=("''${CLAUDE_ARGS[@]:1}")
      exec systemd-run "''${PROPS[@]}" --pipe --wait "$CLAUDE_BIN" "''${CLAUDE_ARGS[@]}"
    else
      exec systemd-run "''${PROPS[@]}" "''${RUN_FLAGS[@]}" "$CLAUDE_BIN" "''${CLAUDE_ARGS[@]}"
    fi
  '';
}
