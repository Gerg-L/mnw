{ self, install }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.mnw;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.mnw.finalPackage = self.lib.wrap pkgs (
        builtins.removeAttrs cfg [
          "finalPackage"
          "enable"
        ]
      );
    })
    (lib.optionalAttrs install { home.packages = [ config.programs.mnw.finalPackage ]; })
  ];
  _file = ./homeManager.nix;
}
