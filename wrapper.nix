{
  lib,
  makeShellWrapper,
  linkFarm,
  runCommand,
  buildEnv,
  writeText,
  lndir,
  stdenvNoCC,
  envsubst,
  callPackage,
}@callPackageArgs:
lib.makeOverridable (
  {
    neovim,
    extraLuaPackages,
    plugins,
    aliases,
    extraBinPath,
    wrapperArgs,
    vimlFiles,
    luaFiles,
    initViml,
    initLua,
    appName,
    desktopEntry,
    providers,

    devExcludedPlugins,
    devPluginPaths,
    dev ? false,
    ...
  # ^This is needed because of the renamed options
  # remove when they are removed
  }@mnwWrapperArgs:
  let
    python3 = providers.python3.package;

    splitPlugins = lib.partition (x: x.optional) (plugins ++ lib.optionals (!dev) devExcludedPlugins);

    optPlugins = splitPlugins.right;

    startPlugins =
      let
        /*
          Stolen from viperML

          Can't call lib.unique here because of module system errors
          about the same speed as using concatMap but removes a let in
        */
        findDeps = builtins.foldl' (
          x: y:
          builtins.concatLists [
            x
            [
              y
            ]
            (findDeps y.dependencies)
          ]
        ) [ ];
      in
      /*
        Gross edge case of optional plugin's
        dependency being loaded non-optionally
        only nixpkgs plugins have dependencies though
        so it should be okay
      */
      lib.unique (lib.subtractLists optPlugins ((findDeps splitPlugins.wrong) ++ (findDeps optPlugins)));

    allPython3Dependencies =
      ps:
      lib.pipe startPlugins [
        (lib.concatMap (plugin: plugin.python3Dependencies ps))
        lib.unique
      ];
    generatedInitLua =
      let
        luaEnv = neovim.lua.withPackages extraLuaPackages;
        inherit (neovim.lua.pkgs) luaLib;

        sourceLua = lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
          (lib.optional (initLua != "") (writeText "init.lua" initLua)) ++ luaFiles
        );
        sourceVimL = lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
          (lib.optional (initViml != "") (writeText "init.vim" initViml)) ++ vimlFiles
        );
      in

      writeText "init.lua" ''
        vim.env.PATH =  vim.env.PATH .. ":${lib.makeBinPath ([ providersEnv ] ++ extraBinPath)}"
        package.path = "${luaLib.genLuaPathAbsStr luaEnv};$LUA_PATH" .. package.path
        package.cpath = "${luaLib.genLuaCPathAbsStr luaEnv};$LUA_CPATH" .. package.cpath
        ${sourceLua}
        ${sourceVimL}
      '';

    builtConfigDir = buildEnv {
      name = "neovim-pack-dir";

      nativeBuildInputs = [ envsubst ];

      paths =
        let
          vimFarm =
            name: plugins:
            linkFarm "${name}-configdir" (
              map (drv: {
                name = "pack/mnw/${name}/${lib.getName drv}";
                path = drv.outPath;
              }) plugins
            );
        in
        [
          (vimFarm "start" startPlugins)
          (vimFarm "opt" optPlugins)
        ]
        ++ lib.optional (allPython3Dependencies python3.pkgs != [ ]) (
          runCommand "vim-python3-deps" { } ''
            mkdir -p $out/pack/mnw/start/__python3_dependencies
            ln -s ${python3.withPackages allPython3Dependencies}/${python3.sitePackages} $out/pack/mnw/start/__python3_dependencies/python3
          ''

        );
      postBuild = ''
        mkdir $out/nix-support
        for i in $(find -L $out -name propagated-build-inputs ); do
          cat "$i" >> $out/nix-support/propagated-build-inputs
        done

        # Semi-cursed helptag generation
        mkdir -p $out/doc
        pushd $out/doc
        for ppath in ../pack/mnw/*/*/doc
        do
        if [ ! -e "$ppath/tags" ]; then
          PLUGIN_DIR=$(basename ''${ppath::-4})
          ln -snf "$ppath" "$PLUGIN_DIR"
        fi
        done
        if [ -n "$(ls $out/doc)" ]; then
          ${lib.getExe neovim} -es --headless -N -u NONE -i NONE -n -V1 \
            -c "helptags $out/doc" -c "quit!"
        fi
        popd

        source '${neovim.lua}/nix-support/utils.sh'
        if declare -f -F "_addToLuaPath" > /dev/null; then
          _addToLuaPath "$out"
          if [[ -v LUA_PATH ]]; then
            LUA_PATH="$LUA_PATH;"
          fi
          if [[ -v LUA_CPATH ]]; then
            LUA_CPATH="$LUA_CPATH;"
          fi
        fi
        envsubst < '${generatedInitLua}' > "$out/init.lua"
      '';
    };

    providersEnv =
      let
        pythonEnv = python3.withPackages (
          ps: providers.python3.extraPackages ps ++ allPython3Dependencies ps
        );

        perlEnv = providers.perl.package.withPackages providers.perl.extraPackages;
      in
      buildEnv {
        name = "neovim-providers";

        paths =
          lib.optionals providers.nodeJs.enable [
            providers.nodeJs.package
            providers.nodeJs.neovimClientPackage
          ]
          ++ lib.optionals providers.ruby.enable [
            providers.ruby.env
            providers.ruby.package
          ];

        nativeBuildInputs = [ makeShellWrapper ];

        postBuild = ''
          ${lib.optionalString providers.python3.enable ''
            makeWrapper ${lib.getExe pythonEnv} $out/bin/neovim-python3-host \
                --unset PYTHONPATH \
                --unset PYTHONSAFEPATH
          ''}

          ${lib.optionalString providers.perl.enable "ln -s ${lib.getExe perlEnv} $out/bin/neovim-perl-host"}
        '';
      };
    providerLua =
      lib.pipe
        {
          node = providers.nodeJs.enable;
          python = false;
          python3 = providers.python3.enable;
          ruby = providers.ruby.enable;
          perl = providers.perl.enable;
        }
        [
          (lib.mapAttrsToList (
            prog: withProg:
            if withProg then
              "vim.g.${prog}_host_prog='${providersEnv}/bin/neovim-${prog}-host'"
            else
              "vim.g.loaded_${prog}_provider=0"
          ))
          (lib.concatStringsSep ";")
        ];

    wrapperArgsStr = lib.escapeShellArgs (

      [
        "--add-flags"
        (lib.concatStrings (
          [
            ''--cmd "lua ''
            ''vim.opt.packpath:append('${builtConfigDir}');''
            ''vim.opt.runtimepath:append('${builtConfigDir}');''
          ]
          ++ (lib.optionals (dev && devPluginPaths != [ ]) [
            ''vim.opt.runtimepath:append('${lib.concatStringsSep "," devPluginPaths}');''
            ''vim.opt.runtimepath:append('${lib.concatMapStringsSep "," (p: "${p}/after") devPluginPaths}');''
          ])

          ++ [
            providerLua
            ''"''
          ]
        ))
        "--set"
        "NVIM_APPNAME"
        appName

        "--set"
        "VIMINIT"
        "source ${builtConfigDir}/init.lua"
      ]
      ++ wrapperArgs
    );

  in

  stdenvNoCC.mkDerivation {
    pname = "mnw";
    version = lib.getVersion neovim;

    nativeBuildInputs = [
      makeShellWrapper
      lndir
    ];

    dontUnpack = true;
    strictDeps = true;

    # Massively reduces build times
    dontRewriteSymlinks = true;

    installPhase = ''
      runHook preInstall

      # symlinkJoin
      mkdir -p "$out"
      lndir -silent '${neovim}' "$out"

      wrapProgram $out/bin/nvim ${wrapperArgsStr}

      ${lib.concatMapStringsSep "\n" (x: "ln -s $out/bin/nvim $out/bin/'${x}'") aliases}

      ${lib.optionalString (!desktopEntry) "rm -rf $out/share/applications"}

      runHook postInstall
    '';

    # For debugging
    passthru =
      {
        inherit builtConfigDir;
      }
      // lib.optionalAttrs (!dev) {
        devMode = (callPackage ./wrapper.nix callPackageArgs) (mnwWrapperArgs // { dev = true; });
      };

    # From nixpkgs
    meta = {
      inherit (neovim.meta)
        mainProgram
        license
        platforms
        ;
      # prefer wrapper over the package
      priority = (neovim.meta.priority or 0) - 2;
    };
  }
)
