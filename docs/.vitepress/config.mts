import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Minimal Neovim Wrapper",
  description: "A VitePress Site",
  // base: "/mnw/", // Manually pass with --base
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      // { text: 'Home', link: '/' },
      // { text: 'Options', link: '/options' }
    ],

    sidebar: [
      {
        // text: 'Examples',
        items: [
          { text: 'Documentation', link: '/documentation' },
          { text: 'Options', link: '/options' },
        ]
      }
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
