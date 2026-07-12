{
  lib,
  pkgs,
  config,
  ...
}:
let
  realpath = "${pkgs.coreutils}/bin/realpath";

  cfg = config.hardware.framework.wakeOnInput;

  # Write $1 into the power/wakeup attribute of all nodes that the udev rules
  # matched
  helper = pkgs.writeShellScript "framework-wakeup-helper.sh" ''
    attrs="$(udevadm info --query property --property=DISABLE_WAKEUP_NODE --value /sys/class/input/input*)"

    declare -A nodes=()

    echo "Setting wakeup attrs to $1:"
    for a in $attrs; do
        if [[ "''${nodes[$a]}" ]]; then continue; fi
        echo "  $a"
        echo "$1" > "$a"/power/wakeup
        nodes[$a]=true
    done
  '';
in
{
  options.hardware.framework.wakeOnInput = lib.mkOption {
    description = ''
      When to allow the built-in keyboard and touchpad to wake the system

      Takes one of three values: "always", "lid-open", or "never". If set to
      "always", the laptop's keyboard and touchpad will wake the laptop. If set
      to "lid-open" the laptop's keyboard and touchpad will only wake the
      laptop if the lid was open when it entered suspend. If set to "never",
      the laptop's keyboard and touchpad will never wake the laptop.

      Note that the "lid-open" setting is best-effort. If the lid is closed
      after the laptop is suspended, the touchpad and keyboard will still wake
      it up!
    '';

    default = "always";
    type = lib.types.enum [
      "always"
      "lid-open"
      "never"
    ];
  };

  config = lib.mkIf (cfg != "always") {
    # For each input device that might be responsible for waking the system,
    # store the path of a device node that can have wakeups disabled.
    # Consistently using input device nodes makes them easier for the helper
    # script to find, and it seems reasonable to assume that any physical input
    # capable of waking the system will have a corresponding input device.
    services.udev.extraRules = ''
      # Wakeup attr for the FW13 and FW16 touchpad's i2c device. The touchpad
      # doesn't identify itself as a Framework product, so this rule matches
      # any PixArt touchpad.
      SUBSYSTEM=="input", DRIVERS=="i2c_hid_acpi", ATTR{phys}=="i2c-PIXA3854:00", PROGRAM=="${realpath} /sys%p/../../..", ENV{DISABLE_WAKEUP_NODE}="%c"

      # Wakeup attr for any Framework USB HID devices, e.g. the FW16 keyboard
      # modules. Only the ANSI keyboard has been tested.
      SUBSYSTEM=="input", DRIVERS=="usbhid", ENV{ID_VENDOR_ID}=="32ac", PROGRAM=="${realpath} /sys%p/../../../..", ENV{DISABLE_WAKEUP_NODE}="%c"

      # Wakeup attr for FW13 keyboard. Untested.
      SUBSYSTEM=="input", DRIVERS=="atkbd", PROGRAM=="${realpath} /sys%p/../..", ENV{DISABLE_WAKEUP_NODE}="%c"
    '';

    systemd.services."framework-wakeup" = {
      description = "Configure Framework keyboard/touchpad wakeup";

      # If "always", run once during boot. If "lid-open", run before every
      # suspend to check the lid state. NixOS doesn't have a good equivalent
      # for /usr/lib/systemd/system-sleep, so we have to fake it.
      wantedBy = if cfg == "lid-open" then [ "sleep.target" ] else [ "multi-user.target" ];
      before = lib.mkIf (cfg == "lid-open") [ "sleep.target" ];

      unitConfig.StopWhenUnneeded = true;

      # Disable wakeups on all nodes that udev has discovered when the service
      # starts (optionally checking lid state first); enable them when it
      # exits.
      serviceConfig = {
        ExecStart =
          if cfg == "lid-open" then
            "/bin/sh -c 'if grep -q closed /proc/acpi/button/lid/LID*/state; then ${helper} disabled; fi'"
          else
            "${helper} disabled";
        ExecStop = "${helper} enabled";

        SyslogIdentifier = "framework-wakeup";
        RemainAfterExit = true;
      };
    };
  };
}
