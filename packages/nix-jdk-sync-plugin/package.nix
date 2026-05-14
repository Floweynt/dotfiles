{ pkgs, lib, ... }:
jdks:
let
  gradle2nix = import (fetchTarball "https://github.com/tadfisher/gradle2nix/archive/v2.tar.gz") {};

  gradleDist = pkgs.fetchurl {
    url = "https://services.gradle.org/distributions/gradle-9.0.0-bin.zip";
    hash = "sha256-j609eClspRgRPz0pAWYXx/k2fcAF+TK9nZO/RbpGBys=";
  };

  generatedManifest = pkgs.writeText "GeneratedSdkManifest.kt" ''
    package dev.nixsdk

    object GeneratedSdkManifest {
        val jdks = listOf<JdkEntry>(
          ${lib.concatStringsSep ",\n" (
            map (jdk: ''
              JdkEntry(
                  name = "${jdk.name} (${jdk.package.name})",
                  path = "${jdk.package}/lib/openjdk"
              )
            '') jdks
          )}
        )
    }
  '';
in
gradle2nix.buildGradlePackage {
  pname = "nix-jdk-sync-plugin";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    pkgs.jdk21
    pkgs.unzip
  ];

  lockFile = ./gradle.lock;

  buildPhase = ''
    runHook preBuild

    # Pre-populate the Gradle wrapper cache so ./gradlew doesn't try to download anything.
    # The wrapper picks up the distribution from GRADLE_USER_HOME/wrapper/dists/<name>/<url-md5-base36>/.
    WRAPPER_DISTS="$GRADLE_USER_HOME/wrapper/dists/gradle-9.0.0-bin/d6wjpkvcgsg3oed0qlfss3wgl"
    mkdir -p "$WRAPPER_DISTS"
    cp ${gradleDist} "$WRAPPER_DISTS/gradle-9.0.0-bin.zip"
    unzip -q "$WRAPPER_DISTS/gradle-9.0.0-bin.zip" -d "$WRAPPER_DISTS"
    touch "$WRAPPER_DISTS/gradle-9.0.0-bin.zip.ok"

    cp ${generatedManifest} src/main/kotlin/dev/nixsdk/GeneratedSdkManifest.kt
    ./gradlew :buildPlugin
    runHook postBuild
  '';

  installPhase = ''
    mkdir -p $out
    unzip build/distributions/*.zip 
    cp nix-jdk-sync/* $out/ -r
  '';
}
