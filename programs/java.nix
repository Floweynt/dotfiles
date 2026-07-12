{
  clangPkgs,
  user,
  ...
}:
let
  jdks = with clangPkgs; [
    jdk8
    jdk11
    jdk17
    jdk # 21
    jetbrains.jdk-21
    jetbrains.jdk
  ];
in
{
  users.users."${user}".packages = with clangPkgs; [
    jdk
  ];

  home-manager.users."${user}" = {
    home = {
      sessionPath = [ "$HOME/.jdks" ];
      file = builtins.listToAttrs (
        builtins.map (jdk: {
          name = ".jdks/${jdk.name}";
          value.source = "${jdk}/lib/openjdk";
        }) jdks
      );
    };

    /*
      programs.gradle = {
          enable = true;
          package = clangPkgs.gradle;
          settings = {
              "org.gradle.caching" = true;
              "org.gradle.parallel" = true;
              "org.gradle.jvmargs" = "-Xmx4G -Xms4G -XX:MaxMetaspaceSize=1G";
              "org.gradle.java.home" = clangPkgs.jdk;
          };
      };
    */
  };
}
