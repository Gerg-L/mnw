{ lib, pkgs, ... }:
let
  inherit (lib) types;
  enabledOption =
    x:
    lib.mkEnableOption x
    // {
      default = true;
      example = false;
    };
in
{
  options.programs.mnw = {
    enable = lib.mkEnableOption "mnw (Minimal Neovim Wrapper)";

    finalPackage = lib.mkOption {
      type = types.package;
      readOnly = true;
    };

    neovim = lib.mkPackageOption pkgs "neovim-unwrapped" { };

    appName = lib.mkOption {
      type = types.str;
      default = "mnw";
      description = "What to set $NVIM_APPNAME to";
      example = "gerg";
    };

    luaFiles = lib.mkOption {
      type = types.listOf types.pathInStore;
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
      type = types.lines;
      default = "";
      description = "lua config text to load at startup";
      example = ''
        print('hello world')
      '';
    };

    vimlFiles = lib.mkOption {
      type = types.listOf types.pathInStore;
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
      type = types.lines;
      default = "";
      description = "VimL config text to load at startup";
      example = ''
        echomsg 'hello world'
      '';
    };

    viAlias = lib.mkEnableOption "symlinking nvim to vi";
    vimAlias = lib.mkEnableOption "symlinking nvim to vim";

    withRuby = enabledOption "configuring and enabling the ruby provider";

    withNodeJs = lib.mkEnableOption "configuring and enabling the node provider";
    withPerl = lib.mkEnableOption "configuring and enabling the perl provider";

    withPython3 = enabledOption "configuring and enabling the python3 provider";

    extraPython3Packages = lib.mkOption {
      type = types.functionTo (types.listOf types.package);
      default = _: [ ];
      description = "A function which returns a list of extra needed python3 packages";
      example = ''
        py: [ py.pybtex ]
      '';
    };

    extraLuaPackages = lib.mkOption {
      type = types.functionTo (types.listOf types.package);
      default = _: [ ];
      description = "A function which returns a list of extra needed lua packages";
      example = ''
        ps: [ ps.jsregexp ]
      '';
    };

    plugins =
      let
        pluginType = types.submodule (
          { config, options, ... }:
          {
            freeformType = types.attrs;

            options = {
              pname = lib.mkOption {
                type = types.str;
                description = "Versionless name of plugin";
              };
              version = lib.mkOption {
                type = types.str;
                description = "Version of plugin";
              };

              name = lib.mkOption {
                type = types.str;
                description = "Name of plugin";
              };

              src = lib.mkOption {
                type = types.pathInStore;
                description = "Path in store to plugin";
              };

              outPath = lib.mkOption {
                type = types.pathInStore;
                description = "Path in store to plugin";
              };

              dependencies = lib.mkOption {
                type = types.listOf pluginType;
                description = "Dependencies of plugin";
                default = [ ];
              };

              python3Dependencies = lib.mkOption {
                type = types.functionTo (types.listOf types.package);
                description = "A function which returns a list of extra needed python3 packages";
                default = _: [ ];
              };

              optional = lib.mkOption {
                type = types.bool;
                description = "Wether to not load plugin automatically at startup";
                default = false;
              };

              plugin = lib.mkOption {
                apply = _: ''
                  The "plugin" attribute of plugins is not supported by mnw
                  please remove it from plugin: ${config.name}
                '';
              };
              config = lib.mkOption {
                apply = _: ''
                  The "config" attribute of plugins is not supported by mnw
                  please remove it from plugin: ${config.name}
                '';
              };
            };

            config =

              {
                name = lib.mkIf (options.pname.isDefined && options.version.isDefined) (
                  lib.mkDefault "${config.pname}-${config.version}"
                );

                outPath = lib.mkIf options.src.isDefined (lib.mkDefault config.src);
              };
          }
        );

        pathCheck =
          x:
          !lib.isDerivation x
          && (lib.isStringLike x && builtins.match "${builtins.storeDir}/[^.].*" (toString x) != null);

      in

      lib.mkOption {
        type = types.listOf (
          types.oneOf [
            (lib.mkOptionType {
              name = "path";
              description = "literal path";
              descriptionClass = "noun";
              check = pathCheck;
              merge = lib.mergeEqualOption;
            })

            pluginType
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
        apply = map (
          x:
          if pathCheck x then
            {

              name = "path-plugin-${builtins.substring 0 7 (builtins.hashString "md5" (toString x))}";
              python3Dependencies = _: [ ];
              outPath = x;
            }
          else
            x
        );
      };

     extraBinPath = lib.mkOption {
      type = types.listOf types.package;
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
