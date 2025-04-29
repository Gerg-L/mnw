return {
  "oil.nvim",

  -- equivalent of VeryLazy with lazy.nvim
  event = "DeferredUIEnter",

  after = function ()
    require("oil").setup()
  end,

  -- takes the options of `vim.keymap.set`
  keys = {
    -- mode is "n" by default, just here to show that you can use the option
    { "<leader>o", "<CMD>Oil<CR>", mode = "n", desc = "Open oil" }
  }
}
