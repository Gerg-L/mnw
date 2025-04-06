import{_ as e,c as i,o as s,ae as t}from"./chunks/framework.CFEco924.js";const c=JSON.parse('{"title":"Documentation","description":"","frontmatter":{"title":"Documentation"},"headers":[],"relativePath":"documentation.md","filePath":"documentation.md"}'),n={name:"documentation.md"};function l(o,a,p,r,h,d){return s(),i("div",null,a[0]||(a[0]=[t(`<h1 id="minimal-neovim-wrapper" tabindex="-1">Minimal NeoVim Wrapper <a class="header-anchor" href="#minimal-neovim-wrapper" aria-label="Permalink to &quot;Minimal NeoVim Wrapper&quot;">​</a></h1><p>This flake exists because the nixpkgs neovim wrapper is a pain</p><p>and I conceptually disagree with nixvim</p><h2 id="about" tabindex="-1">About <a class="header-anchor" href="#about" aria-label="Permalink to &quot;About&quot;">​</a></h2><p>Based off the nixpkgs wrapper but:</p><ul><li>in one place</li><li>more error checking</li><li>a sane interface</li><li><code>evalModules</code> &quot;type&quot; checking</li><li>more convenience options</li><li>doesn&#39;t take two functions to wrap</li></ul><p>There are no flake inputs.</p><h2 id="usage" tabindex="-1">Usage <a class="header-anchor" href="#usage" aria-label="Permalink to &quot;Usage&quot;">​</a></h2><p>Add the flake input</p><div class="language-nix vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">nix</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">mnw</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">url</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;"> =</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> &quot;github:Gerg-L/mnw&quot;</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;">;</span></span></code></pre></div><p>or <code>import</code> the base of this repo using <a href="https://github.com/edolstra/flake-compat" target="_blank" rel="noreferrer">flake-compat</a></p><p>Then use one of the modules or <code>mnw.lib.wrap</code></p><h3 id="wrapper-function" tabindex="-1">Wrapper function <a class="header-anchor" href="#wrapper-function" aria-label="Permalink to &quot;Wrapper function&quot;">​</a></h3><p>The wrapper takes two arguments <code>pkgs</code> and then an attribute set of config options</p><div class="language-nix vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">nix</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">let</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">  neovim</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;"> mnw</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">lib</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">wrap</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;"> pkgs</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    #config options</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">  };</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">in</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">...</span></span></code></pre></div><p>then add it to <code>environment.systemPackages</code> or <code>users.users.&lt;name&gt;.packages</code> or anywhere you can add a package</p><h3 id="modules" tabindex="-1">Modules <a class="header-anchor" href="#modules" aria-label="Permalink to &quot;Modules&quot;">​</a></h3><p>Import <code>{nixosModules,darwinModules,homeManagerModules}.mnw</code> into your respective config</p><p>and use the <code>programs.mnw</code> options</p><div class="language-nix vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">nix</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">programs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">mnw</span><span style="--shiki-light:#B31D28;--shiki-light-font-style:italic;--shiki-dark:#FDAEB7;--shiki-dark-font-style:italic;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">  enable</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> true</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">;</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">  #config options</span></span></code></pre></div><p>and it&#39;ll install the wrapped neovim to <code>environment.systemPackages</code> or <code>home.packages</code></p><p>to not install by default use the <code>.dontInstall</code> module instead and add <code>config.programs.mnw.finalPackage</code> where you want</p><h3 id="config-options" tabindex="-1">Config Options <a class="header-anchor" href="#config-options" aria-label="Permalink to &quot;Config Options&quot;">​</a></h3><p>See the generated docs: <a href="https://gerg-l.github.io/mnw/options.html" target="_blank" rel="noreferrer">https://gerg-l.github.io/mnw/options.html</a></p><h3 id="examples" tabindex="-1">Examples <a class="header-anchor" href="#examples" aria-label="Permalink to &quot;Examples&quot;">​</a></h3><p><a href="https://github.com/Gerg-L/mnw/tree/master/examples/nixos" target="_blank" rel="noreferrer">Simple NixOS example</a></p><p><a href="https://github.com/Gerg-L/mnw/tree/master/examples/easy-dev" target="_blank" rel="noreferrer">Standalone, easy development</a></p><p><a href="https://github.com/Gerg-L/nvim-flake" target="_blank" rel="noreferrer">My Neovim flake</a></p><p><a href="https://github.com/notashelf/nvf" target="_blank" rel="noreferrer">NotAShelf</a></p><p>Make a PR to add your config 😄</p>`,30)]))}const g=e(n,[["render",l]]);export{c as __pageData,g as default};
