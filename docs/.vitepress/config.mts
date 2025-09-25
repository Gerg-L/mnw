import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Minimal Neovim Wrapper",
  description: "",
  // base: "/mnw/", // Manually pass with --base
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    search: {
      provider: 'local'
    },
    sidebar: [
      {
        items: [
          { text: 'Home', link: '/index' },
          { text: 'Usage', link: '/usage' },
          { text: 'Options', link: '/options' },
          { text: 'Examples', link: '/examples' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/Gerg-L/mnw' }
    ],

    outline: {
      level: "deep",
    },
  },
  vite: {
    ssr: {
      noExternal: 'easy-nix-documentation',
    }
  }
})
