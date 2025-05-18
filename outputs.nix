self:
{
  lib = {
    npinsToPlugins = pkgs: pkgs.callPackage ./npinsToPlugins.nix { };
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
            (import ./modules/options.nix false)
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
// (builtins.listToAttrs (
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
))
// (
  let
    lib = import (sources.nixpkgs + /lib);
    forEachSystems = lib.genAttrs [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    sources = import ./npins;
  in
  {
    packages = forEachSystems (
      system:
      let
        pkgs = import sources.nixpkgs { inherit system; };
      in
      pkgs.nixosOptionsDoc {
        inherit
          (
            (lib.evalModules {
              specialArgs = { inherit pkgs; };
              modules = [
                (import ./modules/options.nix true)
              ];
            })
          )
          options
          ;
      }
      // {
        docs = pkgs.callPackage ./docs/package.nix {
          inherit (self.packages.${system}) optionsJSON;
        };
      }
    );

    devShells = forEachSystems (
      system:
      let
        pkgs = import sources.nixpkgs { inherit system; };
      in
      {
        default = pkgs.mkShellNoCC {
          # use npm run dev
          packages = [
            pkgs.nodejs
          ];
          env.MNW_OPTIONS_JSON = self.packages.${system}.optionsJSON;
        };
      }
    );
  }
)
