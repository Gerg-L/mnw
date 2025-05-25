-- you have to set leader before loading lazy
vim.keymap.set("n", " ", "<Nop>", { silent = true, remap = false })
vim.g.mapleader = " "

-- mnw is a global set by mnw
-- so if it's set this config is being ran from nix
if mnw ~= nil then
  require("lazy").setup({
    root = mnw.configDir .. "/pack/mnw/opt",

    -- keep rtp/packpath the same
    performance = {
      reset_packpath = false,
      rtp = {
        reset = false,
      },
    },

    install = {
      -- allow missing plugins
      missing = false,
    },

    checker = {
      -- version checks
      enabled = false,
    },

    spec = {
      { import = "plugins" },
    },
  })
else
-- otherwise we have to bootstrap lazy ourself
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out,                            "WarningMsg" },
        { "\nPress any key to exit..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end
  vim.opt.rtp:prepend(lazypath)

  require("lazy").setup({
    spec = {
      { import = "plugins" },
    },
  })
end
