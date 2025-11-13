---
title: Options
---

# {{ $frontmatter.title }}

<script setup>
import { data } from "./mnw.data.js";
import { RenderDocs } from "easy-nix-documentation";
</script>

<RenderDocs :options="data" :exclude="/providers\.*|plugins\.*/" />

## Plugins Configuration

Plugins are a package, a relative path, or an attribute set with a `name`/`pname` and a `src`:
```nix
{
  pname = "hello";
  src = <package or relative path>;
}
```

> [!TIP]
> Use `dev.<name>` for your config see [usage](usage.md) and then [examples](examples.md) for full examples

`start` and `startAttrs` are added to `/start` and are `require()`-able
while `opt` and `optAttrs` are added to `/opt` and must be `packadd`'d or loaded by `lz.n/lazy.nvim` before being `require()`'d

Everything in `opt/start` have their `.dependencies` added to `startAttrs` as well (for nixpkgs compatibility)
plugins added directly to `*Attrs` do not resolve `.dependencies`

The assignment to `*Attrs` is done by resolving the `pname` or `name` of the package.
so `{ pname = "foo"; ...` would be put at `*Attrs.foo`

While if it's a path it'll be added by the path name and then the hash of the path
so it's recommended to use `*Attrs` for path plugins:

```nix
{
  plugins.startAttrs.fzf-lua = ./fzf-lua;
}
```

`*Attrs` plugins can be set to null to stop them from being installed like:
```nix
{
  plugins.startAttrs.fzf-lua = null;
}
```
this is useful for not installing `.dependencies` from nixpkgs plugins

Any plugin in `opt` will override the plugin of the same name in `start` when propagating to `*Attrs` to ensure it's not loaded automatically.

> [!TIP]
> there's no reason to use `buildVimPlugin` as all it does is copy files generate help tags and run checks.
> with mnw help tags are generated in the mnw builder

### Full example:

```nix
{
  plugins = {
    # Plugins which can be reloaded without rebuilding
    # see dev mode in the docs
    dev.myconfig = {
      # This is the recommended way of passing your config
      pure = "myconfig";
      impure = "/home/user/nix-config/nvim";
    };

    # List of plugins to load automatically
    start = [
      # you can pass vimPlugins from nixpkgs
      pkgs.vimPlugins.lz-n

      # path plugin
      ./plugin

      # Custom plugin example
      {
        pname = "customPlugin";

        src = pkgs.fetchFromGitHub {
          owner = "";
          repo = "";
          ref = "";
          hash = "";
        };

        # Plugins can have other plugins as dependencies
        # this is mainly used in nixpkgs
        # avoid it if possible
        dependencies = [ ];
      }
    ];

    # Attribute set of plugins to load automatically
    startAttrs = {
      # nixpkgs plugin
      oil-nvim = pkgs.vimPlugins.oil-nvim;

      # Stop a dependency from a nixpkgs plugin from being installed
      someDependency = null;

      # Path plugin
      foo = ./bar;
    };

    # List of plugins to not load automatically
    # (load with packadd or a lazy loading plugin )
    opt = [
      pkgs.vimPlugins.oil-nvim
    ];

    # Attribute set of plugins to not load automatically
    optAttrs = {
      # nixpkgs plugin
      fzf-lua = pkgs.vimPlugins.fzf-lua;

      # Disable an optional plugin
      disableMe = null;

      # Path plugin
      bar = ./baz;
    };

  };
}
```

<RenderDocs :options="data" :include="/plugins\.*/" />

## Provider Configuration

<RenderDocs :options="data" :include="/providers\.*/" />
