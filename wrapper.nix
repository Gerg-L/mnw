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
  }:
  let
    packDir =
      packages:
      buildEnv {
        name = "vim-pack-dir";
        paths = lib.flatten (
          lib.mapAttrsToList (
            packageName:
            {
              start ? [ ],
              opt ? [ ],
            }:
            let
              findDependenciesRecursively =
                let

                  transitiveClosure =
                    plugin:
                    [ plugin ]
                    ++ (lib.unique (builtins.concatLists (map transitiveClosure plugin.dependencies or [ ])));
                in
                plugins: lib.concatMap transitiveClosure plugins;

              allPlugins = lib.unique (
                (findDependenciesRecursively start) ++ (lib.subtractLists opt (findDependenciesRecursively opt))
              );

              allPython3Dependencies =
                ps: lib.flatten (map (plugin: (plugin.python3Dependencies or (_: [ ])) ps) allPlugins);

              vimFarm =
                prefix: name: drvs:
                linkFarm name (
                  map (drv: {
                    name = "${prefix}/${lib.getName drv}";
                    path = drv;
                  }) drvs
                );
            in
            [
              (vimFarm "pack/${packageName}/start" "packdir-start" allPlugins)
              (vimFarm "pack/${packageName}/opt" "packdir-opt" opt)
            ]
            ++ lib.optional (allPython3Dependencies python3.pkgs != [ ]) (
              runCommand "vim-python3-deps" { } ''
                mkdir -p $out/pack/${packageName}/start/__python3_dependencies
                ln -s ${python3.withPackages allPython3Dependencies}/${python3.sitePackages} $out/pack/${packageName}/start/__python3_dependencies/python3
              ''
            )
          ) packages
        );
      };

    myVimPackage =
      let
        pluginsPartitioned = lib.partition (x: x.optional) (
          let
            defaultPlugin = {
              plugin = null;
              config = null;
              optional = false;
            };
          in
          map (x: defaultPlugin // (if (x ? plugin) then x else { plugin = x; })) plugins
        );
      in
      {
        start = map (x: x.plugin) pluginsPartitioned.wrong;
        opt = map (x: x.plugin) pluginsPartitioned.right;
      };

    packpathDirs.myNeovimPackages = myVimPackage;

    rubyEnv = bundlerEnv {
      name = "neovim-ruby-env";
      gemdir = ./ruby_provider;
      postBuild = ''
        ln -sf ${ruby}/bin/* $out/bin
      '';
    };
    python3Env = python3Packages.python.withPackages (
      ps:
      [ ps.pynvim ]
      ++ (extraPython3Packages ps)
      ++ (lib.concatMap (f: f ps) (
        map (plugin: plugin.python3Dependencies or (_: [ ])) (
          myVimPackage.start or [ ] ++ myVimPackage.opt or [ ]
        )
      ))
    );

    luaEnv = neovim-unwrapped.lua.withPackages extraLuaPackages;

    perlEnv = perl.withPackages (p: [
      p.NeovimExt
      p.Appcpanminus
    ]);

    wrapperArgsStr =
      wrapperArgs
      ++ (
        let
          binPath = lib.makeBinPath (
            lib.optionals withRuby [ rubyEnv ] ++ lib.optionals withNodeJs [ nodejs ] ++ extraBinPath
          );
        in
        lib.optionals (binPath != "") [
          "--suffix"
          "PATH"
          ":"
          binPath
        ]
      )
      ++ [
        "--prefix"
        "LUA_PATH"
        ";"
        (neovim-unwrapped.lua.pkgs.luaLib.genLuaPathAbsStr luaEnv)
        "--prefix"
        "LUA_CPATH"
        ";"
        (neovim-unwrapped.lua.pkgs.luaLib.genLuaCPathAbsStr luaEnv)
      ]
      ++ lib.optionals withRuby [
        "--set"
        "GEM_HOME"
        "${rubyEnv}/${rubyEnv.ruby.gemPath}"
      ]
      ++
        lib.optionals
          (packpathDirs.myNeovimPackages.start != [ ] || packpathDirs.myNeovimPackages.opt != [ ])
          [
            "--add-flags"
            "-u ${
              writeText "init.lua" (
                ''
                  vim.opt.runtimepath:remove(vim.fn.expand('~/.config/nvim'))
                  vim.opt.packpath:remove(vim.fn.expand('~/.local/share/nvim/site'))

                  vim.opt.runtimepath:append('${packDir packpathDirs}')
                  vim.opt.packpath:append('${packDir packpathDirs}')

                ''
                + lib.concatLines (
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
                )
                + lib.concatMapStringsSep "\n" (x: "vim.cmd('source ${x}')") (
                  vimlFiles ++ lib.optional (initViml != "") (writeText "init.vim" initViml)
                )
                + lib.concatMapStringsSep "\n" (x: "dofile('${x}')") (
                  luaFiles ++ lib.optional (initLua != "") (writeText "init.lua" initLua)
                )
              )
            }"
          ];
  in

  symlinkJoin {
    name = "neovim-${lib.getVersion neovim-unwrapped}";

    paths = [ neovim-unwrapped ];

    nativeBuildInputs = [ makeBinaryWrapper ];

    postBuild =
      lib.optionalString withPython3 ''
        makeWrapper ${python3Env.interpreter} $out/bin/nvim-python3 \
          --unset PYTHONPATH \
          --unset PYTHONSAFEPATH
      ''
      + lib.optionalString withRuby ''
        ln -s ${rubyEnv}/bin/neovim-ruby-host $out/bin/nvim-ruby
      ''
      + lib.optionalString withNodeJs ''
        ln -s ${lib.getExe nodePackages.neovim} $out/bin/nvim-node
      ''
      + lib.optionalString withPerl ''
        ln -s ${lib.getExe perlEnv} $out/bin/nvim-perl
      ''
      + ''
        wrapProgram $out/bin/nvim ${lib.escapeShellArgs wrapperArgsStr}
      ''
      + lib.optionalString vimAlias ''
        ln -s $out/bin/nvim $out/bin/vim
      ''
      + lib.optionalString viAlias ''
        ln -s $out/bin/nvim $out/bin/vi
      '';

    meta = neovim-unwrapped.meta // {
      # To prevent builds on hydra
      hydraPlatforms = [ ];
      # prefer wrapper over the package
      priority = (neovim-unwrapped.meta.priority or 0) - 1;
    };
  }
)
