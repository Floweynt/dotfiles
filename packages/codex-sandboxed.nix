{ pkgs, ... }:

let
  codexMd = pkgs.writeText "AGENTS.md" ''
    # Sandbox environment

    You are running inside a systemd-isolated sandbox. The sandbox uses
    an explicit allowlist: anything not listed here is INVISIBLE.

    ## Filesystem you can see
    - The current project directory (read-write).
    - /nix (read-only) - full Nix store, daemon socket.
    - /run/current-system, /run/booted-system (read-only) - NixOS profile.
    - A fresh empty $HOME (writable tmpfs, discarded on exit) - except
      `~/.codex`, which is bind-mounted from the real one and persists
      (memory, settings, API key).
    - A handful of /etc files needed for DNS, certs, user lookup.
    - /tmp is a private tmpfs.

    ## Filesystem you CANNOT see
    - The real $HOME (your dotfiles, SSH keys, browser data, etc.).
    - /var, /root, /boot, /mnt, /media, /srv, other /home/* users.
    - Any /etc files not explicitly bound (no /etc/shadow, etc.).

    ## Running commands
    You have full access to the Nix daemon (NIX_REMOTE=daemon is set).
    Every Nix workflow works normally.

    Prefer Nix commands through the pinned nixpkgs input when a package
    is needed for one-off tool use.

    Do NOT use `nix-shell -p <pkg>` as that requires channels.

    # Code standards

    IT IS VERY IMPORTANT THAT YOU ADHERE TO THESE STANDARDS, ALWAYS, UNLESS EXPLICITLY
    PROMPTED BY THE USER OTHERWISE.

    You are encouraged to write reusable, modular, and clean code. This means that:

    1) functions should do one thing (usually)
    2) functions should be pure if possible
    3) functions should not be verbose
    4) do NOT reinvent the wheel if possible

    ## Abstraction

    Abstraction hides details, which is bad when it hides things you need to see and good when it
    hides things you'd rather not think about - consider which case applies. Do NOT copy blocks of
    code just to change one thing - abstract instead. Do NOT abstract over one or two cases - that's
    premature.

    ## Commenting

    You are heavily discouraged from writing comments. A comment is justified only when:

    1) something is done in a genuinely counterintuitive way, and that way isn't already a
       well-known pattern or standard (counterintuitive-but-standard needs no comment)
    2) there's important context that cannot be inferred from the codebase alone
    3) the comment is for documentation purposes

    Otherwise, write NO comments.

    # Modernization

    You are encouraged to use the most modern constructs in the language as permitted by the buildsystem's specification of the language version.
  '';

  codex = pkgs.codex;

in
pkgs.writeShellApplication {
  name = "codex-sandboxed";

  runtimeInputs = [
    pkgs.systemd
    pkgs.coreutils
  ];

  text = ''
    CODEX_BIN="${codex}/bin/codex"
    BASH_BIN="${pkgs.bash}/bin/bash"

    PROJECT_DIR="$(realpath "''${1:-.}")"
    shift 2>/dev/null || true

    LAUNCH_SHELL=0
    CODEX_ARGS=()

    for arg in "$@"; do
      if [[ "$arg" == "--shell" ]]; then
        LAUNCH_SHELL=1
      else
        CODEX_ARGS+=("$arg")
      fi
    done

    USER_RUNTIME="/run/user/$(id -u)"

    mkdir -p "$HOME/.codex"
    if [[ ! -f "$HOME/.codex/AGENTS.md" ]]; then
      cp ${codexMd} "$HOME/.codex/AGENTS.md"
    fi

    PROPS=(
      --user
      --collect
      --description="Codex sandbox: $PROJECT_DIR"
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
      --property=BindPaths="$HOME/.codex"
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
      --property=MemoryDenyWriteExecute=no

      --property=Environment=NIX_REMOTE=daemon
      --property=Environment=HOME="$HOME"
      --property=Environment=PATH="$PATH:${codex}/bin"
      --property="Environment=TERM=''${TERM:-xterm-256color}"
      --property="Environment=LANG=''${LANG:-en_US.UTF-8}"
    )

    RUN_FLAGS=(--pty --quiet --send-sighup)

    if [[ "$LAUNCH_SHELL" == "1" ]]; then
      exec systemd-run "''${PROPS[@]}" "''${RUN_FLAGS[@]}" "$BASH_BIN" --login
    elif [[ "''${CODEX_ARGS[0]:-}" == "--debug" ]]; then
      CODEX_ARGS=("''${CODEX_ARGS[@]:1}")
      exec systemd-run "''${PROPS[@]}" --pipe --wait "$CODEX_BIN" "''${CODEX_ARGS[@]}"
    else
      exec systemd-run "''${PROPS[@]}" "''${RUN_FLAGS[@]}" "$CODEX_BIN" "''${CODEX_ARGS[@]}"
    fi
  '';
}
