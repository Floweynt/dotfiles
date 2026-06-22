{
    pkgs,
    ...
}:
{
    powerManagement = {
        enable = true;
        powertop.enable = true;
    };
    services = {
        upower.enable = true;
        power-profiles-daemon.enable = true;
    };
    services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set low-power"
        SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
        SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.brightnessctl}/bin/brightnessctl set 70%%"
        SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.brightnessctl}/bin/brightnessctl set 100%%"
    '';
}
