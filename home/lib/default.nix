{ pkgs, lib, ... }:
{
  # Create a program module with boilerplate
  mkProgram = name: cfg: 
    {
      programs.${name} = { enable = true; } // cfg;
    };

  # Create a simple package list
  mkPackages = packages:
    {
      home.packages = packages;
    };

  # Conditional import based on feature flag
  mkFeature = name: enable: path:
    if enable then [ (import path) ] else [];

  # Merge multiple configurations
  mergeConfigs = configs:
    lib.foldl (acc: cfg: lib.recursiveUpdate acc cfg) {} configs;
}
