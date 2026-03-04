local function github_colorscheme()
  if vim.o.background == "dark" then
    return "github_dark_high_contrast"
  else
    return "github_light_high_contrast"
  end
end

return {
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "background",
        callback = function()
          vim.cmd.colorscheme(github_colorscheme())
        end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = function()
      return { colorscheme = github_colorscheme() }
    end,
  },
}
