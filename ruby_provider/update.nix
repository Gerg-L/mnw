{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShellNoCC {

  packages = [
    pkgs.bundler
    pkgs.bundix
    pkgs.nixfmt
  ];

  shellHook = ''
    rm -f gemset.nix Gemfile.lock

    bundler lock --update
    bundix
    nixfmt gemset.nix

    exit 0
  '';
}
