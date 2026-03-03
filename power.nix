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
        auto-cpufreq = {
            enable = true;
            settings = {
                battery = {
                    governor = "powersave";
                    turbo = "never";
                };
                charger = {
                    governor = "performance";
                    turbo = "auto";
                };
            };
        };
    };
}
