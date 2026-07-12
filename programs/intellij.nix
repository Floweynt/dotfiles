{
  clangPkgs,
  user,
  lib,
  nix-jetbrains-plugins,
  ...
}:
let
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
          (lib.attrValues plugins)
          ++ [
            # (userPackages.nix-jdk-sync-plugin jdks)
          ]
        ))
      ];
  };
}
