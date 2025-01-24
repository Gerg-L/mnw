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
      programs.mnw.finalPackage = self.lib.uncheckedWrap pkgs (
        builtins.removeAttrs cfg [
          "finalPackage"
          "enable"
        ]
      );
    })
    (lib.optionalAttrs install { environment.systemPackages = [ config.programs.mnw.finalPackage ]; })
  ];
  _file = ./nixDarwin.nix;
}
