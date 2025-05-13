{
  lib,
  makeShellWrapper,
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
    dev ? false,
    plugins,
    ...
  # ^This is needed because of the renamed options
  # remove when they are removed
  }@mnwWrapperArgs:
  let

    python3 = providers.python3.package;

    devPlugins = builtins.attrValues (
      builtins.mapAttrs (_: v: builtins.getAttr (if dev then "impure" else "pure") v) plugins.dev
    );

    stripPlugins =
      x:
      lib.unique (
        map (
          v:
          # This is required because of builtins.elem not working on functions
          {
            inherit (v) outPath python3Dependencies dependencies;
          }
          // (lib.optionalAttrs (v ? pname) { inherit (v) pname; })
          // (lib.optionalAttrs (v ? name) { inherit (v) name; })
        ) x
      );

    optPlugins = stripPlugins plugins.opt;

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
      stripPlugins (
        lib.optionals (!dev) devPlugins
        ++ (lib.subtractLists optPlugins ((findDeps plugins.start) ++ (findDeps optPlugins)))
      );

    allPython3Dependencies = lib.pipe (startPlugins ++ optPlugins) [
      (lib.concatMap (plugin: plugin.python3Dependencies))
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

    builtConfigDir =
      let
        pack =
          name: list: lib.concatMapStringsSep ";" (x: "fn '${x}' 'pack/mnw/${name}/${lib.getName x}'") list;
      in
      runCommand "builtConfigDir"
        {
          nativeBuildInputs = [ envsubst ];
        }
        ''
           # lua
           mkdir -p $out/nix-support
           for i in $(find -L $out -name propagated-build-inputs ); do
             cat "$i" >> $out/nix-support/propagated-build-inputs
           done
           source '${neovim.lua}/nix-support/utils.sh'
           if declare -f -F "_addToLuaPath" > /dev/null; then
             _addToLuaPath "$out"
           fi

           if [[ "$LUA_PATH" == ";;" ]]; then
             export LUA_PATH=""
           else
             export LUA_PATH="''${LUA_PATH:-}"
           fi
           if [[ "$LUA_CPATH" == ";;" ]]; then
             export LUA_CPATH=""
           else
             export LUA_CPATH="''${LUA_CPATH:-}"
           fi
           envsubst < '${generatedInitLua}' > "$out/init.lua"

           # plugin stuff
           fn () {
             mkdir -p "$out/$2"
             ln -ns "$1/"* -t "$out/$2"
             if [[ -e "$1/doc" ]] && [[ ! -e "$1/doc/tags" ]]; then
               rm "$out/$2/doc"
               mkdir -p "$out/$2/doc"
               ln -ns "$1/doc/"* -t "$out/$2/doc"
             fi
           }

          ${pack "start" startPlugins}
          ${pack "opt" optPlugins}

          mkdir -p "$out/doc"
          cd "$out/doc"

          ${lib.getExe neovim} --headless -n -u NONE -i NONE \
            -c "set packpath=$out" \
            -c "packloadall" \
            -c "helptags ALL" \
            "+quit!"

        ''
      + lib.optionalString (allPython3Dependencies != [ ]) ''
        # python stuff
        mkdir -p "$out/pack/mnw/start/__python3_dependencies"
        ln -s '${python3.withPackages allPython3Dependencies}/${python3.sitePackages}' "$out/pack/mnw/start/__python3_dependencies/python3"
      ''

    ;

    providersEnv =
      let
        pythonEnv = python3.withPackages (p: (providers.python3.extraPackages p) ++ allPython3Dependencies);

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

    wrapperArgsStr = lib.escapeShellArgs (
      [
        "--add-flags"
        (
          "--cmd \"lua "
          + lib.concatStringsSep ";" (
            [
              "vim.opt.packpath:append('${builtConfigDir}')"
              "vim.opt.runtimepath:append('${builtConfigDir}')"
            ]
            ++ (lib.optionals (dev && devPlugins != [ ]) [
              "vim.opt.runtimepath:append('${lib.concatStringsSep "," devPlugins}')"
              "vim.opt.runtimepath:append('${lib.concatMapStringsSep "," (p: "${p}/after") devPlugins}')"
            ])
            ++ (lib.mapAttrsToList
              (
                prog: withProg:
                if withProg then
                  "vim.g.${prog}_host_prog='${providersEnv}/bin/neovim-${prog}-host'"
                else
                  "vim.g.loaded_${prog}_provider=0"
              )
              {
                node = providers.nodeJs.enable;
                python = false;
                python3 = providers.python3.enable;
                ruby = providers.ruby.enable;
                perl = providers.perl.enable;
              }
            )
          )
          + "\""
        )
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
    dontFixup = true;

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
        config = mnwWrapperArgs;
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
