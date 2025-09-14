{ user, lib, ... }:
{
    boot.initrd.postDeviceCommands = lib.mkBefore (builtins.readFile ./darling_erasure.sh);

    environment.etc = {
        "NetworkManager/system-connections".source = "/persist/@config/network-manager/connections";
        passwd.source = "/persist/@config/passwd";
        shadow.source = "/persist/@config/shadow";
    };
    
    systemd.tmpfiles.rules = [
        "L /var/lib/NetworkManager/secret_key - - - - /persist/@config/network-manager/secret_key"
        "L /var/lib/NetworkManager/seen-bssids - - - - /persist/@config/network-manager/seen-bssids"
        "L /var/lib/NetworkManager/timestamps - - - - /persist/@config/network-manager/timestamps"
        "C /var/lib/fprint/ - - - - /persist/@state/fprint/"
    ];
    
    home-manager.users."${user}" = { config, ...}: {
        home.file = {
            ".config/vesktop/sessionData/Cache/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/vesktop/cache/";
            ".config/vesktop/sessionData/Code Cache/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/vesktop/code_cache/";
            ".config/zsh/.zsh_history" = {
                source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/zsh/history";
                force = true;
            };
            ".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "/persist/@config/user/${user}/git/config";
            ".cache/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/cache/";
            ".gradle/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/gradle/";
            ".librewolf/c3p0ytbp.default/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/librewolf/c3p0ytbp.default/";
            ".librewolf/Profile Groups/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/librewolf/Profile Groups/";
            ".librewolf/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/librewolf/profiles.ini";
            "dev/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/dev/";
            "dotfiles/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/dotfiles/";
            ".ssh/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/ssh/";
            ".local/state/nvim/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/nvim_state/";
            ".local/share/PrismLauncher/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/prism_launcher/";
            "Passwords.kdbx".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/Passwords.kdbx";
            ".config/JetBrains/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@config/user/${user}/jetbrains/";
            "${config.xdg.cacheHome}/.keep".enable = false;
            "${config.xdg.cacheHome}/oh-my-zsh/.keep".enable = false;
        };
    };
}
