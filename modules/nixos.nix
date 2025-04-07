self:
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
  config = {
    programs.mnw.finalPackage = self.lib.uncheckedWrap pkgs cfg;
    environment.systemPackages = lib.mkIf cfg.enable [ config.programs.mnw.finalPackage ];
  };
  _file = ./nixos.nix;
}
