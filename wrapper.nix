{
  lib,
  makeShellWrapper,
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
    extraBuilderArgs,
    ...
  }@mnwWrapperArgs:
  let

    python3 = providers.python3.package;

    devPlugins = builtins.attrValues (
      builtins.mapAttrs (_: v: builtins.getAttr (if dev then "impure" else "pure") v) plugins.dev
    );

    getName =
      x:
      if x.passthru.vimPlugin or false then
        lib.removePrefix "vimplugin-" (lib.getName x)
      else
        lib.getName x;

    # ensure there's only one plugin with each name
    # ideally this would be fixed in the module system
    foldPlugins =
      p:
      builtins.attrValues (
        builtins.foldl' (
          a: b:
          let
            expr = {
              "${getName b}" = b;
            };
          in
          # Don't override explicit plugins with dependencies
          if b.dep or false then expr // a else a // expr
        ) { } p
      );

    optPlugins = foldPlugins plugins.opt;

    startPlugins =
      let
        /*
          Stolen from viperML
          about the same speed as using concatMap but removes a let in
        */
        findDeps =
          dep:
          builtins.foldl' (
            x: y:
            builtins.concatLists [
              x
              [
                (y // { inherit dep; })
              ]
              (findDeps true y.dependencies)
            ]
          ) [ ];
      in
      /*
        optional plugin's dependencies are loaded non-optionally
        only nixpkgs plugins have dependencies though
        so it should be okay
      */
      foldPlugins (
        lib.optionals (!dev) devPlugins
        ++ (lib.subtractLists optPlugins ((findDeps false plugins.start) ++ (findDeps false optPlugins)))
      );

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

      writeText "init.lua" # lua
        ''
          mnw = { configDir = "$out" }
          vim.env.PATH =  vim.env.PATH .. ":${lib.makeBinPath ([ providersEnv ] ++ extraBinPath)}"
          package.path = "${luaLib.genLuaPathAbsStr luaEnv};$LUA_PATH" .. package.path
          package.cpath = "${luaLib.genLuaCPathAbsStr luaEnv};$LUA_CPATH" .. package.cpath
          ${sourceLua}
          ${sourceVimL}
        '';

    configDir = stdenvNoCC.mkDerivation {
      name = "mnw-configDir";
      nativeBuildInputs = [ envsubst ];
      __structuredAttrs = true;

      sourcesArray = startPlugins ++ optPlugins;
      pathsArray =
        let
          fn = name: list: map (x: "pack/mnw/${name}/" + getName x) list;

        in
        (fn "start" startPlugins) ++ (fn "opt" optPlugins);

      buildCommand = # bash
        ''
          mkdir -p "$out/nix-support"
          for i in $(find -L "$out" -name 'propagated-build-inputs'); do
            cat "$i" >> "$out/nix-support/propagated-build-inputs"
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
          for ((i = 0; i < "''${#pathsArray[@]}"; i++ ))
          do
            path="''${pathsArray["$i"]}"
            source="''${sourcesArray["$i"]}"
            if [[ -e "$source/doc" && ! -e "$source/doc/tags" ]]; then
              mkdir -p "$out/$path/doc"
              ln -ns "$source/doc"* -t "$out/$path/doc"
            fi
          done

          ${lib.getExe neovim} --headless -n -u NONE -i NONE \
            -c "set packpath=$out" \
            -c "packloadall" \
            -c "helptags ALL" \
            "+quit!"

          mkdir -p "$out/parser"

          shopt -s extglob
          for ((i = 0; i < "''${#pathsArray[@]}"; i++ ))
          do
            path="''${pathsArray["$i"]}"
            source="''${sourcesArray["$i"]}"

            mkdir -p "$out/$path"

            tolink=("$source/"!(doc|parser))
            if (( ''${#tolink} )); then
              ln -ns "''${tolink[@]}"  -t "$out/$path"
            fi

            if [[ -e "$source/parser" && -n "$(ls -A "$source/parser")" ]]; then
              ln -nsf "$source/parser/"* -t "$out/parser"
            fi

            if [[ -e "$source/doc" && ! -e "$out/$path/doc" ]]; then
              ln -ns "$source/doc" -t "$out/$path"
            fi
          done
          shopt -u extglob

          for path in "$out/pack/mnw/"*/*
          do
            if [[ -d "$path" && -z "$(ls -A $path)" ]]; then
              rmdir $path
            fi
          done

          ${lib.optionalString (allPython3Dependencies python3.pkgs != [ ]) ''
            mkdir -p "$out/pack/mnw/start/__python3_dependencies"
            ln -s '${python3.withPackages allPython3Dependencies}/${python3.sitePackages}' "$out/pack/mnw/start/__python3_dependencies/python3"
          ''}
        '';
    }

    ;

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
            makeWrapper '${lib.getExe pythonEnv}' "$out/bin/neovim-python3-host" \
                --unset PYTHONPATH \
                --unset PYTHONSAFEPATH
          ''}

          ${lib.optionalString providers.perl.enable ''ln -s '${lib.getExe perlEnv}' "$out/bin/neovim-perl-host"''}
        '';
      };

    wrapperArgsStr = lib.escapeShellArgs (
      [
        "--add-flags"
        (
          "--cmd \"lua "
          + lib.concatStringsSep ";" (
            [
              "vim.opt.packpath:prepend('${configDir}')"
              "vim.opt.runtimepath:prepend('${configDir}')"
            ]
            ++ (lib.optionals (dev && devPlugins != [ ]) [
              "vim.opt.runtimepath:prepend('${lib.concatStringsSep "," devPlugins}')"
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
        "source ${configDir}/init.lua"
      ]
      ++ wrapperArgs
    );

  in

  stdenvNoCC.mkDerivation (
    {
      # overrideable arguments
      pname = "mnw";
      version = lib.getVersion neovim;

      dontUnpack = true;
      strictDeps = true;

      # Massively reduces build times
      dontFixup = true;
    }
    // extraBuilderArgs
    // {

      # non-overrideable or concatenated arguments
      nativeBuildInputs = extraBuilderArgs.nativeBuildInputs or [ ] ++ [
        makeShellWrapper
        lndir
      ];

      installPhase = ''
        runHook preInstall

        # symlinkJoin
        mkdir -p "$out"
        lndir -silent '${neovim}' "$out"

        wrapProgramShell "$out/bin/nvim" ${wrapperArgsStr}

        ${lib.concatMapStringsSep "\n" (x: ''ln -s "$out/bin/nvim" "$out/bin/"'${x}' '') aliases}

        ${lib.optionalString (!desktopEntry) ''rm -rf "$out/share/applications"''}

        runHook postInstall
      '';

      # For debugging
      passthru =
        {
          inherit configDir;
          config = mnwWrapperArgs;
        }
        // lib.optionalAttrs (!dev) {
          devMode = (callPackage ./wrapper.nix callPackageArgs) (mnwWrapperArgs // { dev = true; });
        }
        // extraBuilderArgs.passthru or { };

      meta = {
        inherit (neovim.meta)
          mainProgram
          ;
        # prefer wrapper over the package
        priority = (neovim.meta.priority or 0) - 2;
      } // extraBuilderArgs.meta or { };
    }
  )
)
