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
    - A fresh empty $HOME (writable tmpfs, discarded on exit) - except
      `~/.claude`, which is bind-mounted from the real one and persists
      (memory, settings, API key).
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

    If semantics can be inferred from the type, the variable/function name, and surrounding context,
    drop the comment. Never leave a comment asserting that code works, was tested, or was verified
    ("verified this works", "tested and confirmed") - correctness is the default assumption, not
    something to announce. Don't empirically justify a claim in prose ("75ms vs 35ms, verified by
    benchmark") - state the conclusion ("this impl is faster") and drop the receipts.

    Comments must be "WHY" comments, not "HOW" or "WHAT." Keep them terse, direct, and technical -
    no fluff words ("genuinely", "honestly"), no negatives (say what is, not what isn't), no fancy
    box characters (plain ASCII only). Sentence fragments are fine if intent is obvious. Avoid
    em-dashes, since those can almost always be replaced with more trivial constructs (even '-' is
    better, no one cares about comment grammar).

    Good places for a comment:
    - a dense optimized routine (e.g. hand-rolled SIMD) - briefly explain the algorithm and loosely
      justify correctness and a few edge cases
    - a workaround that looks broken but works for some obscure reason - explain the reason

    Further discipline, learned from practice:
    - Even a justified comment states the bare fact, not the reasoning chain that produced it.
      State the conclusion, drop the walkthrough - the benchmark rule above applies to any comment,
      not just performance claims.
    - Never justify a design decision in a comment ("we did X instead of Y because Z"), even when Y
      would cause a real bug (crash, infinite recursion). That's process history - a commit
      message's job, not the code's. If an operative constraint matters, state it as a fact on its
      own, never as a decision narrative.
    - Don't explain a gotcha the code already signals as deliberate by its own shape (an unusual
      option path, a call that's clearly not the default). Do comment a setting that looks removable
      or accidental on its face (e.g. a lone boolean flag on an otherwise-plain block) - someone
      could plausibly "simplify" it away without the comment.
    - Keep a runnable example command verbatim even when trimming everything around it.
    - A detailed workaround comment (named tool + concrete broken behavior + concrete fix) earns its
      length. The terseness push is for reasoning chains that collapse to one fact, not for comments
      where the detail is the payload.
    - If two comments say the same thing, drop one - identical comments on adjacent near-duplicate
      lines, or a doc-comment and an inline comment covering the same ground, don't need saying
      twice.
    - Prefer fixing the code over documenting a workaround, when the workaround itself is cheap to
      remove (e.g. add a missing trailing newline instead of commenting why it's missing).
    - Doc comments (a function's `/** ... */` API block) stay API-only: types, inputs, behavior
      contract. Implementation rationale doesn't belong there either - inline it near the code
      under the rules above, or drop it.
    - Don't write a comment purely to distinguish two similarly-named variables - trust the reader
      to read the code.
    - Write like a person talks: short, blunt, plain sentences. No formal subordinate clauses
      ("since it depends on...", "which doesn't page on its own without...").

    Bad:
    ```
    Tried -Oz (clang's more-aggressive-than-Os size level) here and measured
    it *larger* in practice (1801 vs 1424 bytes) -- its stricter anti-inlining
    heuristic stops inlining small few-call-site helpers (e.g. deflate.c's
    br_get_byte out of bootstrap_postcar), and for a codebase this small the
    call/ret+prologue overhead that costs is bigger than what it saves.
    Sticking with -Os.
    ```

    Good:
    ```
    -Oz produces larger binary because clang doesn't like inlining functions
    ```

    ## Modernization

    You are encouraged to use the most modern constructs in the language as permitted by the buildsystem's specification of the
    language version.
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
      --property=BindPaths="$HOME/.claude"
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
