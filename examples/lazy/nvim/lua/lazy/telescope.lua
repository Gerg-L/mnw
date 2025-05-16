return {
  "telescope.nvim",
  cmd = "Telescope",

  event = "DeferredUIEnter",

  after = function()
    require("telescope").setup()
  end,
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
