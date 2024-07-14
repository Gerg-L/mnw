# Minimal NeoVim Wrapper

This flake exists because the nixpkgs neovim wrapper is a pain

and I conceptually disagree with nixvim

### About

There is no flake inputs.


The wrapper takes a pkgs argument 

so you can resume whatever nixpkgs instance you have lying around

God knows there's too many already in your config...

### Usage

Add the flake input
```nix
mnw.url = "github:Gerg-L/mnw";
```

and use `mnw.lib.wrap`

or `callPackage` /wrapper.nix and use that

The wrapper takes two arguments `pkgs` and then an attribute set of config options
here's a small example


```nix
mnw.lib.wrap pkgs {
  # The neovim package to wrap 
  # Ensure you're using the -unwrapped variant
  neovim = pkgs.neovim-unwrapped;

  # Sets NVIMAPP_NAME
  appName = "nvim";

  # Extra arguments passed to makeWrapper
  wrapperArgs = [ ];

  # Lua init files to load
  luaFiles = [ ];
  # Lua init string to load
  initLua = "";
  # VimL init files to load
  vimlFiles = [ ];
  # VimLinit string to load
  initViml = "";

  # Symlink vi/vim to nvim
  viAlias = false;
  vimAlias = false;

  # Setup language providers for you
  withRuby = true;
  withNodeJs = false;
  withPerl = false;
  withPython3 = true;
  extraPython3Packages = p: [ ];

  # Extra luaPackages which may be needed by plugins
  extraLuaPackages = _: [ ];

  # Whether to load ~/.config/nvim/init.lua
  loadDefaultRC = false;

  plugins = [
    # You can pass a directory 
    # and use it just like it was 
    # ~/.config/nvim/init.lua
    {
      # name or pname+version is required
      name = "myLuaConfig";
      # Setting outPath is a bit of a hack
      # But it works fine
      outPath = ./myLuaConfig;
    }
    # or you can pass nixpkgs vimPlugins
    pkgs.vimPlugins.fzf-lua
  ];
  # or you can use plugins from a npins generated file
  # to track the newest commits of a plugin
  # check my config for an example

  # Lsps and fzf/rg go here and get appended to PATH
  extraBinPath = [ pkgs.nil ];

  # idk why you'd need this exactly but it's here
  extraBuildCommands = "";
}

```

### Full usage examples

[Mine](https://github.com/Gerg-L/nvim-flake)

[NotAShelf](https://github.com/notashelf/nvf)

If you would like your example here PR it
