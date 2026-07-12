{
  clangPkgs,
  user,
  ...
}:
{
  home-manager.users."${user}".programs.keepassxc = {
    enable = true;
    package = clangPkgs.keepassxc;
  };
}
