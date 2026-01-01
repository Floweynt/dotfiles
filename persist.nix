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
            # caches
            ".config/vesktop/sessionData/Cache/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/vesktop/cache/";
            ".config/vesktop/sessionData/Code Cache/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/vesktop/code_cache/";
            ".cache/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/cache/";
            ".gradle/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/gradle/";
            ".rustup/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/rustup/";
            ".cargo/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@caches/user/${user}/cargo/";


            # config
            ".gitconfig".source = config.lib.file.mkOutOfStoreSymlink "/persist/@config/user/${user}/git/config";
            ".config/JetBrains/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@config/user/${user}/jetbrains/";

            # state
            ".config/zsh/.zsh_history" = {
                source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/zsh/history";
                force = true;
            };
            ".librewolf/c3p0ytbp.default/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/librewolf/c3p0ytbp.default/";
            ".librewolf/Profile Groups/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/librewolf/Profile Groups/";
            ".librewolf/profiles.ini".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/librewolf/profiles.ini";
            ".local/state/nvim/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/nvim_state/";
            ".local/share/PrismLauncher/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@state/user/${user}/prism_launcher/";

            # home
            "dev/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/dev/";
            "dotfiles/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/dotfiles/";
            "files/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/files/";
            ".ssh/".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/ssh/";
            "Passwords.kdbx".source = config.lib.file.mkOutOfStoreSymlink "/persist/@home/Passwords.kdbx";

            "${config.xdg.cacheHome}/.keep".enable = false;
            "${config.xdg.cacheHome}/oh-my-zsh/.keep".enable = false;
        };
    };
}
