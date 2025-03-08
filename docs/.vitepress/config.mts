import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Minimal Neovim Wrapper",
  description: "A VitePress Site",
  base: "/mnw/",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      // { text: 'Home', link: '/' },
      // { text: 'Options', link: '/options' }
    ],

    // sidebar: [
    //   {
    //     // text: 'Examples',
    //     items: [
    //       { text: 'Options', link: '/options' },
    //     ]
    //   }
    // ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/vuejs/vitepress' }
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
