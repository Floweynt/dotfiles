# mkSystemdRun: build a wrapper that runs a program in a locked-down transient
# `systemd-run --user` service - empty tmpfs root + explicit path allowlist,
# no bwrap/setuid, reusing the running per-user systemd manager.
#
# Only service units get an exec sandbox, so there is deliberately no --scope
# mode: a scope runs in the caller's context and would drop every mount and
# Protect* directive below.
#
# Args are grouped; unknown keys in any group throw. Every field shown with its
# default.
#
#   name                 wrapper/unit name (required)
#
#   exe = {              executable to run; set exactly one
#     package = null;      derivation; exe resolved via lib.getExe
#     path    = null;      explicit path string, e.g. "${pkg}/bin/foo"
#     resolve = null;      shell snippet that sets $EXE at runtime
#   }
#
#   fs = {               filesystem view; working dir bound RW separately
#     readOnly      = <NixOS DNS/TLS/user set>;  RO binds; "-" prefix = optional
#     extraReadOnly = [ ];   appended to readOnly
#     readWrite     = [ ];   RW binds from host; may contain "$HOME"
#     tmpfs         = [ ];   fresh empty tmpfs mounts, e.g. "$HOME"
#     bindWorkdir   = true;  bind $PWD (or $SANDBOX_DIR) RW as cwd
#   }
#
#   policy = {
#     network          = true;      false -> PrivateNetwork=yes
#     nixAware         = true;      expose nix daemon + NIX_REMOTE=daemon
#     privateDevices   = true;      minimal /dev instead of host /dev
#     allowWriteExecute = true;     keep W+X (JIT: node/v8, jvm)
#     onMissingSystemd = "refuse";  "refuse" (exit 1) | "run" (unsandboxed)
#   }
#
#   limits = {           resource control; null = property omitted
#     memoryMax = memoryHigh = memorySwapMax = null;  byte strings, e.g. "2G"
#     cpuQuota  = null;    percent string, e.g. "150%"
#     cpuWeight = tasksMax = ioWeight = null;          integers
#     deviceAllow = [ ];   e.g. [ "/dev/dri rw" ]
#   }
#
#   run = {              systemd-run invocation
#     mode            = "interactive";  "interactive" (pty) | "pipe" | "wait"
#     slice = unit = nice = serviceType = null;  native flags
#     sliceInherit = remainAfterExit = false;
#     expandEnvironment = true;   false -> --expand-environment=no (systemd 254+)
#     extraFlags = [ ];           extra native systemd-run flags
#   }
#
#   environment     = { };   attr -> value; values shell-expanded, "$FOO" works
#   extraProperties = [ ];   extra --property= values, verbatim
#   runtimeInputs   = [ ];   extra PATH deps for the wrapper
#   preLaunch       = "";    host-side snippet, runs before the sandbox
#
# Runtime: $SANDBOX_DIR overrides cwd; trailing argv is forwarded to the program.
{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs)
    writeShellApplication
    bash
    systemd
    coreutils
    ;

  nixosBaseReadOnly = [
    "/nix"
    "-/run/current-system"
    "-/run/booted-system"
    "-/bin"
    "-/usr"
    "-/lib"
    "-/lib64"
    "-/sbin"
    "-/etc/resolv.conf"
    "-/etc/ssl"
    "-/etc/static"
    "-/etc/nsswitch.conf"
    "-/etc/hosts"
    "-/etc/protocols"
    "-/etc/services"
    "-/etc/passwd"
    "-/etc/group"
    "-/etc/profile"
    "-/etc/login.defs"
    "-/etc/bashrc"
  ];

  hardening = [
    "ProtectKernelTunables=yes"
    "ProtectKernelModules=yes"
    "ProtectKernelLogs=yes"
    "ProtectControlGroups=yes"
    "ProtectHostname=yes"
    "ProtectClock=yes"
    "RestrictNamespaces=yes"
    "LockPersonality=yes"
    "RestrictRealtime=yes"
    "RestrictSUIDSGID=yes"
    "NoNewPrivileges=yes"
    "RemoveIPC=yes"
  ];

  # Fill defaults and reject unknown keys, so typos fail loudly.
  group =
    label: defaults: given:
    let
      unknown = builtins.attrNames (removeAttrs given (builtins.attrNames defaults));
    in
    lib.throwIf (unknown != [ ])
      "mkSystemdRun: unknown ${label} option(s): ${lib.concatStringsSep ", " unknown}"
      (defaults // given);
in

{
  name,
  exe ? { },
  fs ? { },
  policy ? { },
  limits ? { },
  run ? { },
  environment ? { },
  extraProperties ? [ ],
  runtimeInputs ? [ ],
  preLaunch ? "",
}:

let
  exeCfg = group "exe" {
    package = null;
    path = null;
    resolve = null;
  } exe;

  fsCfg = group "fs" {
    readOnly = nixosBaseReadOnly;
    extraReadOnly = [ ];
    readWrite = [ ];
    tmpfs = [ ];
    bindWorkdir = true;
  } fs;

  policyCfg = group "policy" {
    network = true;
    nixAware = true;
    privateDevices = true;
    allowWriteExecute = true;
    onMissingSystemd = "refuse";
  } policy;

  limitsCfg = group "limits" {
    memoryMax = null;
    memoryHigh = null;
    memorySwapMax = null;
    cpuQuota = null;
    cpuWeight = null;
    tasksMax = null;
    ioWeight = null;
    deviceAllow = [ ];
  } limits;

  runCfg = group "run" {
    mode = "interactive";
    slice = null;
    unit = null;
    nice = null;
    serviceType = null;
    sliceInherit = false;
    remainAfterExit = false;
    expandEnvironment = true;
    extraFlags = [ ];
  } run;

  exeSources = lib.filter (x: x != null) [
    exeCfg.package
    exeCfg.path
    exeCfg.resolve
  ];
  runModes = [
    "interactive"
    "pipe"
    "wait"
  ];

  prop = p: ''--property="${p}"'';
  optProp = n: v: lib.optional (v != null) (prop "${n}=${toString v}");

  roProps = map (p: prop "BindReadOnlyPaths=${p}") (fsCfg.readOnly ++ fsCfg.extraReadOnly);
  rwProps = map (p: prop "BindPaths=${p}") fsCfg.readWrite;
  tmpfsProps = map (p: prop "TemporaryFileSystem=${p}") fsCfg.tmpfs;
  hardeningProps = map prop hardening;
  envProps = lib.mapAttrsToList (n: v: prop "Environment=${n}=${v}") environment;

  toggleProps =
    lib.optional (!policyCfg.network) (prop "PrivateNetwork=yes")
    ++ lib.optional policyCfg.privateDevices (prop "PrivateDevices=yes")
    ++ [ (prop "MemoryDenyWriteExecute=${if policyCfg.allowWriteExecute then "no" else "yes"}") ]
    ++ map prop extraProperties;

  resourceProps =
    optProp "MemoryMax" limitsCfg.memoryMax
    ++ optProp "MemoryHigh" limitsCfg.memoryHigh
    ++ optProp "MemorySwapMax" limitsCfg.memorySwapMax
    ++ optProp "CPUQuota" limitsCfg.cpuQuota
    ++ optProp "CPUWeight" limitsCfg.cpuWeight
    ++ optProp "TasksMax" limitsCfg.tasksMax
    ++ optProp "IOWeight" limitsCfg.ioWeight
    ++ map (d: prop "DeviceAllow=${d}") limitsCfg.deviceAllow;

  modeFlags =
    {
      interactive = [
        "--pty"
        "--send-sighup"
      ];
      pipe = [ "--pipe" ];
      wait = [ "--wait" ];
    }
    .${runCfg.mode};

  nativeFlags = [
    "--user"
    "--collect"
    "--quiet"
  ]
  ++ modeFlags
  ++ lib.optional (!runCfg.expandEnvironment) "--expand-environment=no"
  ++ lib.optional runCfg.remainAfterExit "--remain-after-exit"
  ++ lib.optional runCfg.sliceInherit "--slice-inherit"
  ++ lib.optionals (runCfg.slice != null) [ "--slice=${runCfg.slice}" ]
  ++ lib.optionals (runCfg.unit != null) [ "--unit=${runCfg.unit}" ]
  ++ lib.optionals (runCfg.nice != null) [ "--nice=${toString runCfg.nice}" ]
  ++ lib.optionals (runCfg.serviceType != null) [ "--service-type=${runCfg.serviceType}" ]
  ++ runCfg.extraFlags;

  resolveExe =
    if exeCfg.resolve != null then
      exeCfg.resolve
    else
      "EXE=${if exeCfg.path != null then exeCfg.path else lib.getExe exeCfg.package}";

  nixEnvLine = lib.optionalString policyCfg.nixAware "\n  --property=Environment=NIX_REMOTE=daemon";
  join = lib.concatStringsSep "\n";

  onMissing =
    if policyCfg.onMissingSystemd == "run" then
      ''exec "$EXE" "$@"''
    else
      ''{ echo "error: systemd-run unavailable; refusing to run '${name}' unsandboxed" >&2; exit 1; }'';
in

assert lib.all builtins.isAttrs [
  exeCfg
  fsCfg
  policyCfg
  limitsCfg
  runCfg
];
assert lib.assertMsg (
  builtins.length exeSources == 1
) "mkSystemdRun (${name}): set exactly one of exe.{package,path,resolve}";
assert lib.assertMsg (lib.elem runCfg.mode runModes)
  "mkSystemdRun (${name}): run.mode must be one of ${lib.concatStringsSep ", " runModes}";
assert lib.assertMsg (lib.elem policyCfg.onMissingSystemd [
  "refuse"
  "run"
]) "mkSystemdRun (${name}): policy.onMissingSystemd must be \"refuse\" or \"run\"";

writeShellApplication {
  inherit name;
  runtimeInputs = [
    systemd
    coreutils
    bash
  ]
  ++ runtimeInputs;

  text = ''
    ${preLaunch}

    ${resolveExe}

    command -v systemd-run >/dev/null 2>&1 || ${onMissing}

    WORKDIR="$(realpath "''${SANDBOX_DIR:-$PWD}")"
    UID_NUM="$(id -u)"

    PROPS=(
      --property=TemporaryFileSystem=/
      --property=PrivateTmp=yes
      --property=TemporaryFileSystem=/run/user/"$UID_NUM"
    ${join roProps}
    ${join tmpfsProps}${lib.optionalString fsCfg.bindWorkdir "\n  --property=\"BindPaths=$WORKDIR\""}
    ${join rwProps}
    ${join hardeningProps}
    ${join toggleProps}
    ${join resourceProps}${nixEnvLine}
      --property="Environment=HOME=$HOME"
      --property="Environment=PATH=$PATH"
      --property="Environment=TERM=''${TERM:-xterm-256color}"
      --property="Environment=LANG=''${LANG:-en_US.UTF-8}"
    ${join envProps}
    )

    exec systemd-run ${lib.concatStringsSep " " nativeFlags} \
      --description="${name} sandbox: $WORKDIR" \
      --working-directory="$WORKDIR" \
      "''${PROPS[@]}" \
      "$EXE" "$@"
  '';
}
