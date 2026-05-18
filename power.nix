{
    pkgs,
    lib,
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
}
