return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  event = "VeryLazy",
  opts = {},
  keys = {
    {
      "<leader>tp",
      function()
        require("telescope.builtin").find_files()
      end,
    },
    {
      "<leader>tg",
      function()
        require("telescope.builtin").live_grep()
      end,
    },
  },
}
