local function detect_system_appearance()
  if vim.fn.has("mac") == 1 then
    local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result:match("Dark") then
        return "dark"
      end
    end
  elseif vim.fn.has("linux") == 1 then
    local handle = io.popen("gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result:match("prefer%-dark") then
        return "dark"
      end
    end
  end
  return "light"
end

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
      -- Set background from macOS appearance on startup
      vim.o.background = detect_system_appearance()

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
