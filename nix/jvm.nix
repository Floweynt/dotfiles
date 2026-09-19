let
  shenBase = [
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:+UseShenandoahGC"
    "-XX:ShenandoahGuaranteedGCInterval=1000000"
    "-XX:AllocatePrefetchStyle=1"
  ];

  shenGenerational = shenBase ++ [ "-XX:ShenandoahGCMode=generational" ];
  shenIncrementalUpdate = shenBase ++ [ "-XX:ShenandoahGCMode=iu" ];

  g1 = [
    "-XX:+UseG1GC"
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:MaxGCPauseMillis=37"
    "-XX:+PerfDisableSharedMem"
    "-XX:G1HeapRegionSize=16M"
    "-XX:G1NewSizePercent=23"
    "-XX:G1ReservePercent=20"
    "-XX:SurvivorRatio=32"
    "-XX:G1MixedGCCountTarget=3"
    "-XX:G1HeapWastePercent=20"
    "-XX:InitiatingHeapOccupancyPercent=10"
    "-XX:G1RSetUpdatingPauseTimePercent=0"
    "-XX:MaxTenuringThreshold=1"
    "-XX:G1SATBBufferEnqueueingThresholdPercent=30"
    "-XX:G1ConcMarkStepDurationMillis=5.0"
    "-XX:G1ConcRSHotCardLimit=16"
    "-XX:G1ConcRefinementServiceIntervalMillis=150"
    "-XX:GCTimeRatio=99"
  ];

  aggressivePack = [
    "-XX:+UnlockExperimentalVMOptions"
    "-XX:+UnlockDiagnosticVMOptions"
    "-XX:+AlwaysActAsServerClassMachine"
    "-XX:+UseNUMA"
    "-XX:NmethodSweepActivity=1"
    "-XX:ReservedCodeCacheSize=400M"
    "-XX:NonNMethodCodeHeapSize=12M"
    "-XX:ProfiledCodeHeapSize=194M"
    "-XX:NonProfiledCodeHeapSize=194M"
    "-XX:-DontCompileHugeMethods"
    "-XX:MaxNodeLimit=240000"
    "-XX:NodeLimitFudgeFactor=8000"
    "-XX:+UseVectorCmov"
    "-XX:+UseFastUnorderedTimeStamps"
    "-XX:+UseCriticalJavaThreadPriority"
    "-XX:ThreadPriorityPolicy=1"
    "-XX:+UseTransparentHugePages"
  ];

  autoGc = jdkMajor: if jdkMajor >= 21 then "shenandoah" else "g1";

  gcFlagsFor =
    gc: jdkMajor:
    let
      sets = {
        inherit g1;
        shenandoah = if jdkMajor >= 24 then shenGenerational else shenIncrementalUpdate;
        zgc = [
          "-XX:+UseZGC"
        ]
        # ZGenerational is the default on 24+ where the flag is obsolete; set it only on 21-23
        ++ (if jdkMajor >= 21 && jdkMajor <= 23 then [ "-XX:+ZGenerational" ] else [ ])
        ++ [
          "-XX:AllocatePrefetchStyle=1"
          "-XX:-ZProactive"
        ];
        parallel = [ "-XX:+UseParallelGC" ];
        serial = [ "-XX:+UseSerialGC" ];
      };
    in
    sets.${gc} or (throw "gcFlagsFor: unknown gc ${gc}");
in
{
  jdkMajor,
  memory,
  gc ? "auto",
  aggressive ? false,
  extraJvmArgs ? [ ],
}:
let
  resolved = if gc == "auto" then autoGc jdkMajor else gc;
  heap = [
    "-Xms${memory}"
    "-Xmx${memory}"
  ];
in
if resolved == "none" then
  heap ++ extraJvmArgs
else
  heap
  ++ [
    "-XX:+AlwaysPreTouch"
    "-XX:+DisableExplicitGC"
  ]
  ++ gcFlagsFor resolved jdkMajor
  ++ (if aggressive then aggressivePack else [ ])
  ++ extraJvmArgs
