return {
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "Normal", { bg = "#f8f8f8" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#f8f8f8" })
        end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "github_light_high_contrast",
    },
  },
}
