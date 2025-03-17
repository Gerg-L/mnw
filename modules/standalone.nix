{ lib, ... }:
{
  options.warnings = lib.mkOption {
    internal = true;
    default = [ ];
    type = lib.types.listOf lib.types.str;
  };
}
