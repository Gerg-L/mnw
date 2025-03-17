{
  outputs =
    { self, ... }:
    {
      lib = {
        uncheckedWrap = pkgs: pkgs.callPackage ./wrapper.nix { };
        wrap =
          pkgs: config:
          let
            inherit (pkgs) lib;
            evaled = lib.evalModules {
              specialArgs = {
                inherit pkgs;
                modulesPath = toString ./modules;
              };
              modules = [
                ./modules/common.nix
                ./modules/standalone.nix
                { programs.mnw = config; }
              ];
            };

            failedAssertions = map (x: x.message) (builtins.filter (x: !x.assertion) evaled.config.assertions);
            baseSystemAssertWarn =
              if failedAssertions != [ ] then
                throw "\nFailed assertions:\n${lib.concatMapStrings (x: "- ${x}") failedAssertions}"
              else
                lib.showWarnings evaled.config.warnings;
          in
          self.lib.uncheckedWrap pkgs (
            (builtins.removeAttrs (baseSystemAssertWarn evaled.config.programs.mnw)) [
              "enable"
              "finalPackage"
            ]
          );
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
                (import ./modules/${x}.nix {
                  inherit self;
                  install = true;
                })
                ./modules/common.nix
              ];
            };
            noInstall = {
              imports = [
                (import ./modules/${x}.nix {
                  inherit self;
                  install = false;
                })
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
