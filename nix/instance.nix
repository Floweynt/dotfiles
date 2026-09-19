let
  rules = import ./rules.nix;
  jvmFlags = import ./jvm.nix;
in
{
  pkgs,
  tools,
  lib,
}:
{
  version,
  name ? version,
  loader ? null,
  jdk ? null,
  memory ? "4G",
  gc ? "auto",
  aggressive ? false,
  jvmArgs ? [ ],
  env ? { },
  gameDir ? null,
  username ? null,
  account ? "default",
  demo ? false,
  resolution ? null,
  quickPlay ? null,
  glfw ? pkgs.glfw,
  openal ? pkgs.openal,
  useSystemGlfw ? true,
  useSystemOpenal ? true,
  runtimeLibs ? null,
  extraRuntimeLibs ? [ ],
  mods ? [ ],
}:
let
  mkLibraries = import ./libraries.nix { inherit pkgs lib rules; };

  pname = lib.replaceStrings [ " " ] [ "-" ] name;

  lock = builtins.fromJSON (builtins.readFile (../lock/versions + "/${version}.json"));
  assetObjects = builtins.fromJSON (
    builtins.readFile (../lock/assets + "/${lock.assetIndex.id}.json")
  );

  modloaders = {
    fabric =
      loaderVersion:
      import ./modloaders/fabric.nix {
        inherit
          pkgs
          lib
          version
          loaderVersion
          mods
          ;
        loaderName = "fabric";
        vanillaMainClass = lock.mainClass;
      };
  };

  modloader =
    assert lib.assertMsg (mods == [ ] || loader != null) "minecraft-nix: `mods` requires a `loader`";
    if loader == null then
      null
    else
      let
        names = builtins.attrNames loader;
        name = builtins.head names;
      in
      assert lib.assertMsg (
        builtins.length names == 1
      ) "minecraft-nix: `loader` must name exactly one modloader";
      assert lib.assertMsg (modloaders ? ${name}) "minecraft-nix: unknown modloader `${name}`";
      modloaders.${name} loader.${name};

  useLoader = modloader != null;
  loaderLibs = if useLoader then modloader.libraries else [ ];
  loaderJvm = if useLoader then modloader.jvmArgs else [ ];
  mainClass = if useLoader then modloader.mainClass else lock.mainClass;

  libKey = l: lib.concatStringsSep ":" (lib.take 2 (lib.splitString ":" l.name));
  loaderKeys = map libKey loaderLibs;
  mergedLibraries =
    builtins.filter (l: !(builtins.elem (libKey l) loaderKeys)) lock.libraries ++ loaderLibs;

  substitute =
    str:
    let
      keys = builtins.attrNames values;
    in
    builtins.replaceStrings (map (k: "\${${k}}") keys) (map (k: values.${k}) keys) str;

  resolveArgs = builtins.concatMap (
    arg:
    if builtins.isString arg then
      [ (substitute arg) ]
    else if
      rules.evalRules {
        inherit (arg) rules;
        inherit os arch features;
      }
    then
      map substitute arg.value
    else
      [ ]
  );

  resolveLegacyArgs =
    argString: map substitute (builtins.filter (s: s != "") (lib.splitString " " argString));

  assetDescriptor = pkgs.writeText "asset-index-${lock.assetIndex.id}.json" (
    builtins.toJSON { objects = assetObjects; }
  );

  target = rules.target pkgs.stdenv.hostPlatform.system;
  inherit (target) os arch;

  recommendedMajor = lock.javaMajor or 8;
  jdk' = if jdk != null then jdk else (pkgs."jdk${toString recommendedMajor}" or pkgs.jdk);
  jdkMajor = lib.toInt (lib.versions.major jdk'.version);

  legacy = lock ? minecraftArguments;
  offline = username != null;

  offlineUuid =
    n:
    let
      h = builtins.hashString "md5" "OfflinePlayer:${n}";
      sub = i: len: builtins.substring i len h;
      variant =
        {
          "0" = "8";
          "1" = "9";
          "2" = "a";
          "3" = "b";
          "4" = "8";
          "5" = "9";
          "6" = "a";
          "7" = "b";
          "8" = "8";
          "9" = "9";
          "a" = "a";
          "b" = "b";
          "c" = "8";
          "d" = "9";
          "e" = "a";
          "f" = "b";
        }
        .${sub 16 1};
    in
    "${sub 0 8}-${sub 8 4}-3${sub 13 3}-${variant}${sub 17 3}-${sub 20 12}";

  features = {
    is_demo_user = demo;
    has_custom_resolution = resolution != null;
    has_quick_plays_support = quickPlay != null;
    is_quick_play_singleplayer = quickPlay != null && quickPlay ? singleplayer;
    is_quick_play_multiplayer = quickPlay != null && quickPlay ? multiplayer;
    is_quick_play_realms = quickPlay != null && quickPlay ? realms;
  };

  libs = mkLibraries {
    libraries = mergedLibraries;
    inherit (lock) client;
    inherit os arch features;
  };

  nativesSubpath = "natives/${baseNameOf libs.nativesDir}";

  stripClasspath = builtins.filter (a: a != "-cp" && a != "\${classpath}");

  values = {
    auth_player_name = "@MCN_AUTH_NAME@";
    auth_uuid = "@MCN_AUTH_UUID@";
    auth_access_token = "@MCN_AUTH_TOKEN@";
    auth_xuid = "@MCN_AUTH_XUID@";
    clientid = "@MCN_AUTH_CLIENTID@";
    user_type = "@MCN_AUTH_USER_TYPE@";
    auth_session = "@MCN_AUTH_SESSION@";

    game_directory = "@MCN_GAME_DIR@";
    assets_root = "@MCN_ASSETS_DIR@";
    game_assets =
      if lock.assetIndex.kind == "standard" then
        "@MCN_ASSETS_DIR@"
      else
        "@MCN_ASSETS_DIR@/virtual/${lock.assetIndex.id}";
    natives_directory = "@MCN_CACHE_DIR@/${nativesSubpath}";

    version_name = version;
    version_type = lock.type;
    assets_index_name = lock.assetIndex.id;
    launcher_name = "minecraft-nix";
    launcher_version = "0.1.0";
    resolution_width = if resolution != null then toString resolution.width else "";
    resolution_height = if resolution != null then toString resolution.height else "";
    quickPlayPath = "";
    quickPlaySingleplayer = if features.is_quick_play_singleplayer then quickPlay.singleplayer else "";
    quickPlayMultiplayer = if features.is_quick_play_multiplayer then quickPlay.multiplayer else "";
    quickPlayRealms = if features.is_quick_play_realms then quickPlay.realms else "";
    user_properties = "{}";
  };

  lwjglFlags =
    (lib.optional useSystemGlfw "-Dorg.lwjgl.glfw.libname=${glfw}/lib/libglfw.so")
    ++ (lib.optional useSystemOpenal "-Dorg.lwjgl.openal.libname=${openal}/lib/libopenal.so");

  tuningFlags = jvmFlags {
    inherit
      jdkMajor
      memory
      gc
      aggressive
      ;
    extraJvmArgs = jvmArgs;
  };

  lockJvm =
    if legacy then
      [ "-Djava.library.path=@MCN_CACHE_DIR@/${nativesSubpath}" ]
    else
      stripClasspath (resolveArgs lock.args.jvm);

  lockGame = if legacy then resolveLegacyArgs lock.minecraftArguments else resolveArgs lock.args.game;

  defaultRuntimeLibs = with pkgs; [
    libGL
    libpulseaudio
    stdenv.cc.cc.lib
    udev
    flite
    libx11
    libxext
    libxcursor
    libxrandr
    libxxf86vm
    libxi
    libxtst
    libdecor
    wayland
    libxkbcommon
  ];

  ldLibraryPath = lib.makeLibraryPath (
    (if runtimeLibs != null then runtimeLibs else defaultRuntimeLibs)
    ++ extraRuntimeLibs
    ++ [
      glfw
      openal
    ]
  );

  defaultGameDir =
    if gameDir != null then gameDir else "$HOME/.local/share/minecraft-nix/instances/${pname}";

  envMap = {
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    LD_LIBRARY_PATH = {
      join_paths = lib.splitString ":" ldLibraryPath;
      inherit_existing = true;
    };
    LIBDECOR_PLUGIN_DIR = "${pkgs.libdecor}/lib/libdecor/plugins-1";
  }
  // env;

  spec = {
    steps = [
      {
        type = "symlink";
        source = "${libs.nativesDir}";
        folder = "cache";
        path = nativesSubpath;
        recursive = true;
      }
      {
        type = "download_assets";
        descriptor = "${assetDescriptor}";
        index_id = lock.assetIndex.id;
        index_hash = lock.assetIndex.hash;
        kind = lock.assetIndex.kind;
      }
    ];
    launch = {
      java = "${jdk'}/bin/java";
      main_class = mainClass;
      classpath = libs.classpathList;
      jvm_args = tuningFlags ++ lwjglFlags ++ lockJvm ++ loaderJvm;
      game_args = lockGame;
      env = envMap;
      game_dir_default = defaultGameDir;
      auth =
        if offline then
          {
            mode = "offline";
            inherit username;
            uuid = offlineUuid username;
            xuid = "0";
          }
        else
          {
            mode = "online";
            inherit account;
          };
    };
  };

  specFile = pkgs.writeText "minecraft-${pname}-spec.json" (builtins.toJSON spec);

  mismatchWarn =
    lib.warnIf (jdkMajor != recommendedMajor)
      "minecraft-nix: ${version} recommends JDK ${toString recommendedMajor}, using JDK ${toString jdkMajor}";
in
mismatchWarn (
  pkgs.runCommand "minecraft-${pname}"
    {
      nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
      meta.mainProgram = "minecraft-${pname}";
      passthru = { inherit spec specFile; };
    }
    ''
      makeBinaryWrapper ${tools}/bin/mc "$out/bin/minecraft-${pname}" \
        --add-flags "launch ${specFile}"
    ''
)
