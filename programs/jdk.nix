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
        jetbrains.jdk
    ];
in
{
    users.users."${user}".packages = with clangPkgs; [
        jdk
    ];

    home-manager.users."${user}".home = {
        sessionPath = [ "$HOME/.jdks" ];
        file = builtins.listToAttrs (builtins.map (jdk: {
            name = ".jdks/${jdk.name}";
            value.source = jdk;
        }) jdks);
    };
}

