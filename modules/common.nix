{ lib, pkgs, ... }:
{

  options.programs.mnw = {
    enable = lib.mkEnableOption "mnw (Minimal Neovim Wrapper)";

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
    };
    neovim = lib.mkPackageOption pkgs "neovim-unwrapped" { };

    appName = lib.mkOption {
      type = lib.types.str;
      default = "nvim";
      description = "What to set $NVIM_APPNAME to";
      example = "gerg";
    };

    luaFiles = lib.mkOption {
      type = lib.types.listOf lib.types.pathInStore;
      default = [ ];
      description = "lua config files to load at startup";
      example = ''
        [
          (pkgs.writeText "init.lua" '''
            print('hello world')
          ''')
        ]
      '';
    };

    initLua = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "lua config text to load at startup";
      example = ''
        print('hello world')
      '';
    };

    vimlFiles = lib.mkOption {
      type = lib.types.listOf lib.types.pathInStore;
      default = [ ];
      description = "VimL config files to load at startup";
      example = ''
        [
          (pkgs.writeText "init.vim" '''
            echomsg 'hello world'
          ''')
        ]
      '';
    };

    initViml = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "VimL config text to load at startup";
      example = ''
        echomsg 'hello world'
      '';
    };

    viAlias = lib.mkEnableOption "symlinking nvim to vi";
    vimAlias = lib.mkEnableOption "symlinking nvim to vim";

    withRuby = (lib.mkEnableOption "configuring and enabling the ruby provider") // {
      default = true;
    };

    withNodeJs = lib.mkEnableOption "configuring and enabling the node provider";
    withPerl = lib.mkEnableOption "configuring and enabling the perl provider";

    withPython3 = (lib.mkEnableOption "configuring and enabling the python3 provider") // {
      default = true;
    };

    extraPython3Packages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "A function which returns a list of extra needed python3 packages";
      example = ''
        py: [ py.pybtex ]
      '';
    };

    extraLuaPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "A function which returns a list of extra needed lua packages";
      example = ''
        ps: [ ps.jsregexp ]
      '';
    };

    loadDefaultRC = lib.mkEnableOption "loading nix external neovim configuration (~/.config/$NVIM_APPNAME/init.lua usually)";

    plugins = lib.mkOption {
      type = lib.types.listOf (
        lib.types.oneOf [
          lib.types.package
          (lib.mkOptionType {
            name = "pathLiteral";
            description = "literal path";
            descriptionClass = "noun";
            check = builtins.isPath;
            merge = lib.mergeEqualOption;
          })
        ]
      );
      default = [ ];
      description = "A list of plugins to load";
      example = ''
        [
          pkgs.vimPlugins.fzf-lua;
          pkgs.vimPlugins.nvim-treesitter.withAllGrammars
        ]
      '';
    };

    extraBinPath = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to be put in neovim's PATH";
      example = ''
        [
          pkgs.rg
          pkgs.fzf
        ]
      '';
    };

    wrapperArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "A list of arguments to be passed to makeWrapper";
      example = ''
        [
          "--set-default"
          "FZF_DEFAULT_OPTS"
          "--layout=reverse --inline-info"
        ];
      '';
    };
  };
}
