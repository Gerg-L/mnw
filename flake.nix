{ outputs = _: { lib.wrap = x: x.callPackage ./wrapper.nix { }; }; }
