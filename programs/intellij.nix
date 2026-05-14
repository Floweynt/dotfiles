{
  clangPkgs,
  user,
  lib,
  ...
}:
let
  nix-jetbrains-plugins = import (
    builtins.fetchGit {
      url = "https://github.com/nix-community/nix-jetbrains-plugins";
      ref = "refs/heads/main";
    }
  );

  idea-plugins = [
    "com.demonwav.minecraft-dev"
    "nix-idea"
  ];
in
{
  users.users."${user}" = {
    packages =
      with clangPkgs;
      let
        idea = jetbrains.idea-oss;
        plugins = nix-jetbrains-plugins.lib.pluginsForIde clangPkgs idea idea-plugins;
      in
      [
        (jetbrains.plugins.addPlugins idea (
          (lib.attrValues plugins) ++ [/* (userPackages.nix-jdk-sync-plugin jdks) */]
        ))
      ];
  };
}
