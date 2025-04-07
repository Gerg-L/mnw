{
  outputs =
    { self, ... }:
    {
      lib = {
        uncheckedWrap = pkgs: pkgs.callPackage ./wrapper.nix { };
        wrap =
          pkgs: module:
          let
            inherit (pkgs) lib;
            evaled = lib.evalModules {
              specialArgs = {
                inherit pkgs;
                modulesPath = toString ./modules;
              };
              modules = [
                ./modules/options.nix
                module
              ];
            };

            failedAssertions = map (x: x.message) (builtins.filter (x: !x.assertion) evaled.config.assertions);
            baseSystemAssertWarn =
              if failedAssertions != [ ] then
                throw "\nFailed assertions:\n${lib.concatMapStrings (x: "- ${x}") failedAssertions}"
              else
                lib.showWarnings evaled.config.warnings;
          in
          self.lib.uncheckedWrap pkgs (baseSystemAssertWarn evaled.config);
      };
    }
    // builtins.listToAttrs (
      map
        (x: {
          name = "${x}Modules";
          value = {
            default = self."${x}Modules".mnw;
            mnw = {
              imports = [
                (import ./modules/${x}.nix self)
                ./modules/common.nix
              ];
            };
          };
        })
        [
          "nixos"
          "homeManager"
          "darwin"
        ]
    );
}
