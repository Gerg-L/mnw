{
  inputs,
  pkgs,
  lib,
  stdenvNoCC,
  nixos-render-docs,
  nixosOptionsDoc,
}:
let
  revision = inputs.self.rev or inputs.self.dirtyRev or "dirty";

  evaluatedOptions =
    let
      scrubDerivations =
        namePrefix: pkgSet:
        builtins.mapAttrs (
          name: value:
          let
            wholeName = "${namePrefix}.${name}";
          in
          if builtins.isAttrs value then
            scrubDerivations wholeName value
            // lib.optionalAttrs (lib.isDerivation value) {
              inherit (value) drvPath;
              outPath = "\${${wholeName}}";
            }
          else
            value
        ) pkgSet;
    in
    (lib.evalModules {
      modules = [
        {
          _module = {
            check = false;
            args.pkgs = lib.mkForce (scrubDerivations "pkgs" pkgs);
          };
        }
        ../modules/common.nix
      ];
    }).options;

  filteredOptions = builtins.removeAttrs evaluatedOptions [ "_module" ];

  fixedOptions = nixosOptionsDoc {
    warningsAreErrors = false;
    options = filteredOptions;
    transformOptions =
      let
        gitHubDeclaration = user: repo: subpath: {
          url = "https://github.com/${user}/${repo}/blob/master/${subpath}";
          name = "<${repo}/${subpath}>";
        };
      in
      opt:
      opt
      // {
        declarations = map (
          decl:
          if lib.hasPrefix (toString ../.) (toString decl) then
            lib.pipe decl [
              toString
              (lib.removePrefix (toString ../.))
              (lib.removePrefix "/")
              (gitHubDeclaration "Gerg-L" "mnw")

            ]
          else if decl == "lib/modules.nix" then
            gitHubDeclaration "NixOS" "nixpkgs" decl
          else
            decl
        ) opt.declarations;
      };
  };
in

stdenvNoCC.mkDerivation {
  name = "mnw-manual";
  src = ./src;
  nativeBuildInputs = [ nixos-render-docs ];
  buildPhase = ''
    mkdir -p $out

    substituteInPlace ./manual.md \
      --subst-var-by \
        MNW_VERSION \
        ${revision}

    substituteInPlace ./options.md \
      --subst-var-by \
        OPTIONS_JSON \
        ${fixedOptions.optionsJSON}/share/doc/nixos/options.json

    nixos-render-docs manual html \
      --manpage-urls ${inputs.nixpkgs}/doc/manpage-urls.json \
      --revision ${revision} \
      --toc-depth 2 \
      --section-toc-depth 1 \
      manual.md \
      $out/index.xhtml
  '';
}