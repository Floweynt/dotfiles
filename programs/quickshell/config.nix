{
    clangPkgs,
    user,
    ...
}:
{
    # configure users
    users.users."${user}".packages = with clangPkgs; [
        quickshell
        kdePackages.qtdeclarative
    ];

    # home-manager.users."${user}".xdg.configFile."quickshell".source = ./src;
}

