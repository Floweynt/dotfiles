let
  targets = {
    "x86_64-linux" = {
      os = "linux";
      arch = "x86_64";
    };
    "aarch64-linux" = {
      os = "linux";
      arch = "arm64";
    };
    "i686-linux" = {
      os = "linux";
      arch = "x86";
    };
    "x86_64-darwin" = {
      os = "osx";
      arch = "x86_64";
    };
    "aarch64-darwin" = {
      os = "osx";
      arch = "arm64";
    };
  };

  osMatches =
    osRule: os: arch:
    ((osRule.name or null) == null || osRule.name == os)
    && ((osRule.arch or null) == null || osRule.arch == arch);

  featuresMatch =
    required: features:
    builtins.all (k: (features.${k} or false) == required.${k}) (builtins.attrNames required);

  ruleMatches =
    rule: os: arch: features:
    ((rule.os or null) == null || osMatches rule.os os arch)
    && ((rule.features or null) == null || featuresMatch rule.features features);

  evalRules =
    {
      rules ? null,
      os,
      arch,
      features ? { },
    }:
    if rules == null || rules == [ ] then
      true
    else
      builtins.foldl' (
        allowed: rule: if ruleMatches rule os arch features then rule.action == "allow" else allowed
      ) false rules;

  nativeMatches =
    lib: os: arch:
    lib.os == os && (if (lib.arch or null) == null then arch == "x86_64" else lib.arch == arch);
in
{
  inherit
    targets
    evalRules
    nativeMatches
    ;
  target = system: targets.${system} or (throw "unsupported system: ${system}");
}
