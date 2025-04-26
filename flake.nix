{
  outputs =
    { self, ... }:
    {
      lib = {
        uncheckedWrap = pkgs: pkgs.callPackage ./wrapper.nix { };
        wrap =
          args:
          let
            argsIsPkgs = args._type or null == "pkgs";
            pkgs =
              if argsIsPkgs then
                args
              else
                assert args.pkgs._type == "pkgs";
                args.pkgs;
          in
          module:
          let
            inherit (pkgs) lib;
            evaled = lib.evalModules {
              specialArgs = (if argsIsPkgs then { pkgs = args; } else args) // {
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
