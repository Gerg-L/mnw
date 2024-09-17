{
  inputs.nixpkgs = {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    ref = "nixos-unstable";
  };
  outputs = inputs: {
    packages.x86_64-linux.default = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./. {
      inherit inputs;
    };
  };
}
