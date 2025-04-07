import{_ as s,c as a,o as e,ae as t}from"./chunks/framework.CFEco924.js";const c=JSON.parse('{"title":"Documentation","description":"","frontmatter":{"title":"Documentation"},"headers":[],"relativePath":"documentation.md","filePath":"documentation.md"}'),n={name:"documentation.md"};function l(p,i,o,h,r,k){return e(),a("div",null,i[0]||(i[0]=[t(`<h1 id="minimal-neovim-wrapper" tabindex="-1">Minimal NeoVim Wrapper <a class="header-anchor" href="#minimal-neovim-wrapper" aria-label="Permalink to &quot;Minimal NeoVim Wrapper&quot;">​</a></h1><p>This flake exists because the nixpkgs neovim wrapper is a pain</p><p>and I conceptually disagree with nixvim</p><h2 id="about" tabindex="-1">About <a class="header-anchor" href="#about" aria-label="Permalink to &quot;About&quot;">​</a></h2><p>Based off the nixpkgs wrapper but:</p><ul><li>in one place</li><li>more error checking</li><li>a sane interface</li><li><code>evalModules</code> &quot;type&quot; checking</li><li>more convenience options</li><li>doesn&#39;t take two functions to wrap</li></ul><p>There are no flake inputs.</p><h2 id="usage" tabindex="-1">Usage <a class="header-anchor" href="#usage" aria-label="Permalink to &quot;Usage&quot;">​</a></h2><p>Add the flake input</p><div class="language-nix vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">nix</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">mnw</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">url</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;"> =</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> &quot;github:Gerg-L/mnw&quot;</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;">;</span></span></code></pre></div><p>or <code>import</code> the base of this repo which has <a href="https://github.com/edolstra/flake-compat" target="_blank" rel="noreferrer">flake-compat</a></p><p>Then use one of the modules or <code>mnw.lib.wrap</code></p><h3 id="wrapper-function" tabindex="-1">Wrapper function <a class="header-anchor" href="#wrapper-function" aria-label="Permalink to &quot;Wrapper function&quot;">​</a></h3><p>The wrapper takes two arguments <code>pkgs</code> and then a module</p><div class="language-nix vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">nix</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">let</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">  neovim</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;"> mnw</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">lib</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">wrap</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;"> pkgs</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    # Your config</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">  };</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">  # or</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">  neovim</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;"> mnw</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">lib</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">wrap</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;"> pkgs</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> ./config.nix</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">;</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">in</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">...</span></span></code></pre></div><div class="tip custom-block github-alert"><p class="custom-block-title">TIP</p><p><code>mnw.lib.wrap</code> uses <code>evalModules</code>you can use <code>imports</code>, <code>options</code>, and <code>config</code>!</p></div><p>Then add it to <code>environment.systemPackages</code> or <code>users.users.&lt;name&gt;.packages</code> or anywhere you can add a package</p><h3 id="modules" tabindex="-1">Modules <a class="header-anchor" href="#modules" aria-label="Permalink to &quot;Modules&quot;">​</a></h3><p>Import <code>mnw.&lt;module&gt;.mnw</code> into your config</p><p>Where <code>&lt;module&gt;</code> is:</p><p><code>nixosModules</code> for NixOS,</p><p><code>darwinModules</code> for nix-darwin</p><p><code>homeManagerModules</code>for home-manager</p><p>Then use the <code>programs.mnw</code> options</p><div class="language-nix vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">nix</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">programs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">mnw</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">  enable</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> true</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">;</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">  #config options</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">}</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;">;</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;"># or</span></span>
<span class="line"><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">programs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">mnw</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;"> =</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> ./config.nix</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;">;</span></span></code></pre></div><div class="tip custom-block github-alert"><p class="custom-block-title">TIP</p><p><code>programs.mnw</code> is a submodule you can use <code>imports</code>, <code>options</code>, and <code>config</code>!</p></div><p>and mnw will install the wrapped neovim to <code>environment.systemPackages</code> or <code>home.packages</code></p><p>Alternatively set <code>programs.mnw.enable = false;</code> and add <code>config.programs.mnw.finalPackage</code> where you want manually</p><h3 id="config-options" tabindex="-1">Config Options <a class="header-anchor" href="#config-options" aria-label="Permalink to &quot;Config Options&quot;">​</a></h3><p>See the generated docs: <a href="https://gerg-l.github.io/mnw/options.html" target="_blank" rel="noreferrer">https://gerg-l.github.io/mnw/options.html</a></p><h3 id="examples" tabindex="-1">Examples <a class="header-anchor" href="#examples" aria-label="Permalink to &quot;Examples&quot;">​</a></h3><p><a href="https://github.com/Gerg-L/mnw/tree/master/examples/nixos" target="_blank" rel="noreferrer">Simple NixOS example</a></p><p><a href="https://github.com/Gerg-L/mnw/tree/master/examples/easy-dev" target="_blank" rel="noreferrer">Standalone, easy development</a></p><p><a href="https://github.com/Gerg-L/nvim-flake" target="_blank" rel="noreferrer">My Neovim flake</a></p><p><a href="https://github.com/notashelf/nvf" target="_blank" rel="noreferrer">nvf</a></p><p><a href="https://github.com/viperML/dotfiles/blob/master/packages/neovim/module.nix" target="_blank" rel="noreferrer">viperML</a></p><p>Make a PR to add your config 😄</p>`,37)]))}const g=s(n,[["render",l]]);export{c as __pageData,g as default};
