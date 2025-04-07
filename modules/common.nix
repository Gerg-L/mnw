{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.programs.mnw = lib.mkOption {
    type = lib.types.submoduleWith {
      specialArgs = { inherit pkgs; };
      modules = [
        ./options.nix
      ];
    };
  };
  config = lib.mkIf config.programs.mnw.enable {

    warnings = map (warning: "programs.mnw: ${warning}") config.programs.mnw.warnings;
    assertions = map (assertion: {
      inherit (assertion) assertion;
      message = "programs.mnw: ${assertion.message}";
    }) config.programs.mnw.assertions;
  };
}
