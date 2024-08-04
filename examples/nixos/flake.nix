{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    mnw.url = "../.";
    # If you're actually using this, change your input to this:
    #mnw.url = "github:Gerg-L/mnw";
  };
  outputs =
    { nixpkgs, ... }@inputs:
    {
      nixosConfigurations = {
        your_hostname = nixpkgs.lib.nixosSystem {
          modules = [ ./configuration.nix ];
          specialArgs = {
            inherit inputs;
          };
        };
      };
    };
}
