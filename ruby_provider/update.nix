{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShellNoCC {

  packages = [
    (pkgs.ruby.withPackages (p: [ p.msgpack ]))
    pkgs.bundix
  ];

  shellHook = ''
    bundle update
    bundix
    exit 0
  '';
}
