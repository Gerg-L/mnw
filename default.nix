(import (
  let
    pin = (builtins.fromJSON (builtins.readFile ./sources.json)).pins.flake-compat;
  in
  fetchTarball {
    inherit (pin) url;
    sha256 = pin.hash;
  }
) { src = ./.; }).defaultNix
