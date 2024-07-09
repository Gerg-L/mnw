{
  symlinkJoin,
  lib,
  makeBinaryWrapper,
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
  }:
  let

    pluginsNormalized = map (x: x.plugin or x) plugins;

    pluginRC = lib.foldl (
      acc: p:
      let
        config = p.config or null;
      in
      if (config != null && config != "") then acc ++ [ config ] else acc
    ) [ ] pluginsNormalized;

    packpathDir =
      let

        pluginsPartitioned = lib.partition (x: x.optional or false) pluginsNormalized;
      in
      {
        start = pluginsPartitioned.wrong;
        opt = pluginsPartitioned.right;
      };

    packedDir =
      let
        inherit (packpathDir) start opt;
      in
      buildEnv {
        name = "vim-pack-dir";
        paths =
          let
            allPlugins =
              let
                findDependenciesRecursively =
                  let
                    transitiveClosure = plugin: [ plugin ] ++ map transitiveClosure plugin.dependencies or [ ];
                  in
                  lib.flip lib.pipe [
                    transitiveClosure
                    lib.flatten
                    lib.unique
                  ];
              in
              lib.unique (
                (findDependenciesRecursively start) ++ (lib.subtractLists opt (findDependenciesRecursively opt))
              );

            allPython3Dependencies =
              ps:
              lib.pipe allPlugins [
                (map (plugin: (plugin.python3Dependencies or (_: [ ])) ps))
                lib.flatten
                lib.unique
              ];

            vimFarm =
              prefix: name: drvs:
              linkFarm name (
                map (drv: {
                  name = "${prefix}/${lib.getName drv}";
                  path = drv;
                }) drvs
              );

            packPath = "pack/gerg-wrapper";
          in
          [
            (vimFarm "${packPath}/start" "packdir-start" allPlugins)
            (vimFarm "${packPath}/opt" "packdir-opt" opt)
          ]
          ++ lib.optional (allPython3Dependencies python3.pkgs != [ ]) (
            runCommand "vim-python3-deps" { } ''
              mkdir -p $out/${packPath}/start/__python3_dependencies
              ln -s ${python3.withPackages allPython3Dependencies}/${python3.sitePackages} $out/${packPath}/start/__python3_dependencies/python3
            ''
          );
      };

    rubyEnv = bundlerEnv {
      name = "neovim-ruby-env";
      gemdir = ./ruby_provider;
      postBuild = ''
        ln -sf ${ruby}/bin/* $out/bin
      '';
    };

    python3Env = python3Packages.python.withPackages (
      ps:
      lib.unique (
        lib.flatten [
          ps.pynvim
          (extraPython3Packages ps)
          (map (f: f ps) (
            map (plugin: plugin.python3Dependencies or (_: [ ])) (packpathDir.start ++ packpathDir.opt)
          ))
        ]
      )
    );

    luaEnv = neovim.lua.withPackages extraLuaPackages;

    perlEnv = perl.withPackages (p: [
      p.NeovimExt
      p.Appcpanminus
    ]);

    wrapperArgsStr = lib.escapeShellArgs (
      let
        binPath = lib.makeBinPath (
          lib.optionals withRuby [ rubyEnv ] ++ lib.optionals withNodeJs [ nodejs ] ++ extraBinPath
        );
        inherit (neovim.lua.pkgs.luaLib) genLuaPathAbsStr genLuaCPathAbsStr;
      in
      [
        "--set"
        "NVIM_SYSTEM_RPLUGIN_MANIFEST"
        "${placeholder "out"}/rplugin.vim"

        "--add-flags"
        "-u ${placeholder "out"}/init.lua"

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
        binPath
      ]
      ++ lib.optionals withRuby [
        "--set"
        "GEM_HOME"
        "${rubyEnv}/${rubyEnv.ruby.gemPath}"
      ]
      ++ wrapperArgs
    );
  in

  symlinkJoin {
    name = "neovim-${lib.getVersion neovim}";

    paths = [ neovim ];

    nativeBuildInputs = [ makeBinaryWrapper ];

    postBuild = ''

      ${lib.optionalString withPython3 ''
        makeWrapper ${python3Env.interpreter} $out/bin/nvim-python3 \
          --unset PYTHONPATH \
          --unset PYTHONSAFEPATH
      ''}
      ${lib.optionalString withRuby "ln -s ${rubyEnv}/bin/neovim-ruby-host $out/bin/nvim-ruby"}

      ${lib.optionalString withNodeJs "ln -s ${lib.getExe nodePackages.neovim} $out/bin/nvim-node"}

      ${lib.optionalString withPerl "ln -s ${lib.getExe perlEnv} $out/bin/nvim-perl"}

      cat << EOF > $out/init.lua

      ${lib.optionalString (packpathDir.start != [ ] || packpathDir.opt != [ ]) ''
        vim.opt.runtimepath:append('${packedDir}')
        vim.opt.packpath:append('${packedDir}')
      ''}
      ${lib.concatLines (
        lib.mapAttrsToList
          (
            prog: withProg:
            if withProg then
              "vim.g.${prog}_host_prog='${placeholder "out"}/bin/nvim-${prog}'"
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
      EOF

      echo "Generating remote plugin manifest"
      export NVIM_RPLUGIN_MANIFEST=$out/rplugin.vim
      export HOME="$(mktemp -d)"
      if ! $out/bin/nvim \
        -u $out/init.lua \
        -i NONE -n \
        -V1rplugins.log \
        +UpdateRemotePlugins +quit! > outfile 2>&1; then
        cat outfile
        echo -e "\nGenerating rplugin.vim failed!"
        exit 1
      fi

      wrapProgram $out/bin/nvim ${wrapperArgsStr}

      cat << EOF >> $out/init.lua

      vim.opt.runtimepath:remove(vim.fn.expand('~/.config/nvim'))
      vim.opt.packpath:remove(vim.fn.expand('~/.local/share/nvim/site'))

      ${lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
        vimlFiles
        ++ lib.optional (initViml != "") (writeText "init.vim" initViml)
        ++ lib.optional (pluginRC != "") (writeText "pluginRC.vim" pluginRC)
      )}

      ${lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
        luaFiles ++ lib.optional (initLua != "") (writeText "init.lua" initLua)
      )}
      EOF

      ${lib.optionalString vimAlias "ln -s $out/bin/nvim $out/bin/vim"}

      ${lib.optionalString viAlias "ln -s $out/bin/nvim $out/bin/vi"}

      ${extraBuildCommands}
    '';

    meta = neovim.meta // {
      # To prevent builds on hydra
      hydraPlatforms = [ ];
      # prefer wrapper over the package
      priority = (neovim.meta.priority or 0) - 1;
    };
  }
)
