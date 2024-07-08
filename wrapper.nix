{
  lib,
  makeWrapper,
  nodePackages,
  python3,
  perl,
  bundlerEnv,
  ruby,
  python3Packages,
  nodejs,
  linkFarm,
  runCommand,
  buildEnv,
  writeText,
  neovim-unwrapped,
  lndir,
  stdenvNoCC,
}:
lib.makeOverridable (
  {
    neovim ? neovim-unwrapped,
    withPython3 ? true,
    # the function you would have passed to python3.withPackages
    extraPython3Packages ? (_: [ ]),
    withNodeJs ? false,
    withRuby ? true,
    withPerl ? false,
    # the function you would have passed to lua.withPackages
    extraLuaPackages ? (_: [ ]),

    plugins ? [ ],
    viAlias ? false,
    vimAlias ? false,
    extraBinPath ? [ ],
    wrapperArgs ? [ ],
    vimlFiles ? [ ],
    luaFiles ? [ ],
    initViml ? "",
    initLua ? "",
    extraBuildCommands ? "",
    loadDefaultRC ? false,
    appName ? "nvim",
  }:
  let
    allPlugins =
      let
        findDependenciesRecursively =
          let

            transitiveClosure =
              plugin: [ plugin ] ++ (lib.unique (lib.concatMap transitiveClosure plugin.dependencies or [ ]));
          in
          lib.concatMap transitiveClosure;
      in
      lib.unique (findDependenciesRecursively plugins);

    allPython3Dependencies =
      ps:
      lib.pipe allPlugins [
        (lib.concatMap (plugin: (plugin.python3Dependencies or (_: [ ])) ps))
        lib.unique
      ];

    packedDir = buildEnv {
      name = "neovim-pack-dir";
      paths =
        let
          packPath = "pack/gerg-wrapper";
        in
        lib.singleton (
          linkFarm "packdir" (
            map (drv: {
              name = "${packPath}/start/${lib.getName drv}";
              path = drv;
            }) allPlugins
          )
        )
        ++ lib.optional (allPython3Dependencies python3.pkgs != [ ]) (
          runCommand "vim-python3-deps" { } ''
            mkdir -p $out/${packPath}/start/__python3_dependencies
            ln -s ${python3.withPackages allPython3Dependencies}/${python3.sitePackages} $out/${packPath}/start/__python3_dependencies/python3
          ''
        );
    };

    providers =
      let
        pythonEnv = python3Packages.python.withPackages (
          ps: lib.unique ([ ps.pynvim ] ++ (extraPython3Packages ps) ++ (allPython3Dependencies ps))
        );

        perlEnv = perl.withPackages (p: [
          p.NeovimExt
          p.Appcpanminus
        ]);
      in
      buildEnv {
        name = "neovim-providers";

        paths =
          lib.optionals withNodeJs [
            nodejs
            nodePackages.neovim
          ]
          ++ lib.optionals withRuby [
            (bundlerEnv {
              name = "neovim-ruby-env";
              gemdir = ./ruby_provider;
              postBuild = ''
                rm $out/bin/{bundle,bundler}
              '';
            })
            ruby
          ];

        nativeBuildInputs = [ makeWrapper ];

        postBuild = ''
          ${lib.optionalString withPython3 ''
            makeWrapper ${lib.getExe pythonEnv} $out/bin/neovim-python3-host \
                --unset PYTHONPATH \
                --unset PYTHONSAFEPATH
          ''}

          ${lib.optionalString withPerl "ln -s ${lib.getExe perlEnv} $out/bin/neovim-perl-host"}
        '';
      };

    wrapperArgsStr = lib.escapeShellArgs (
      let
        luaEnv = neovim.lua.withPackages extraLuaPackages;
        inherit (neovim.lua.pkgs.luaLib) genLuaPathAbsStr genLuaCPathAbsStr;
      in
      [
        "--add-flags"
        "--cmd \"luafile ${placeholder "out"}/init.lua\""

        "--prefix"
        "LUA_PATH"
        ";"
        (genLuaPathAbsStr luaEnv)

        "--prefix"
        "LUA_CPATH"
        ";"
        (genLuaCPathAbsStr luaEnv)

        "--suffix"
        "PATH"
        ":"
        (lib.makeBinPath ([ providers ] ++ extraBinPath))

        "--set-default"
        "NVIM_APPNAME"
        appName
      ]
      ++ wrapperArgs
    );

    luaConfig = writeText "init.lua" ''
      ${lib.optionalString (!loadDefaultRC)
        #Stolen from nixvim
        ''
          vim.opt.runtimepath:remove(vim.fn.stdpath('config'))              -- ~/.config/nvim
          vim.opt.runtimepath:remove(vim.fn.stdpath('config') .. "/after")  -- ~/.config/nvim/after
          vim.opt.runtimepath:remove(vim.fn.stdpath('data') .. "/site")     -- ~/.local/share/nvim/site
        ''
      }

      ${lib.concatLines (
        lib.mapAttrsToList
          (
            prog: withProg:
            if withProg then
              "vim.g.${prog}_host_prog='${providers}/bin/neovim-${prog}-host'"
            else
              "vim.g.loaded_${prog}_provider=0"
          )
          {
            node = withNodeJs;
            python = false;
            python3 = withPython3;
            ruby = withRuby;
            perl = withPerl;
          }
      )}

      ${lib.optionalString (allPlugins != [ ]) ''
        vim.opt.packpath:append('${packedDir}')
      ''}

      ${lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
        vimlFiles ++ lib.optional (initViml != "") (writeText "init.vim" initViml)
      )}

      ${lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
        lib.optional (initLua != "") (writeText "init.lua" initLua) ++ luaFiles
      )}
    '';
  in

  stdenvNoCC.mkDerivation {
    pname = "neovim";
    version = lib.getVersion neovim;

    nativeBuildInputs = [
      makeWrapper
      lndir
    ];

    dontUnpack = true;
    strictDeps = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out

      lndir -silent ${neovim} $out

      ln -s ${luaConfig} $out/init.lua

      wrapProgram $out/bin/nvim ${wrapperArgsStr}

      ${lib.optionalString vimAlias "ln -s $out/bin/nvim $out/bin/vim"}

      ${lib.optionalString viAlias "ln -s $out/bin/nvim $out/bin/vi"}

      ${extraBuildCommands}

      runHook postInstall
    '';

    passthru = {
      inherit
        providers
        allPlugins
        luaConfig
        wrapperArgsStr
        wrapperArgs
        packedDir
        ;
    };

    meta = (builtins.removeAttrs neovim.meta [ "position" ]) // {
      # To prevent builds on hydra
      hydraPlatforms = [ ];
      # prefer wrapper over the package
      priority = (neovim.meta.priority or 0) - 1;
    };
  }
)
