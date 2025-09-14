{
    clangPkgs,
    user,
    ...
}:
{
    home-manager.users."${user}".programs = {
        eza = {
            enable = true;
            package = clangPkgs.eza;
            enableZshIntegration = true;
            icons = "auto";
        };
        zsh.shellAliases = {
            ls = "eza";
        };
    };
}

