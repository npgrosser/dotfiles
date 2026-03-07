local function detect_os_appearance()
  if vim.fn.has("mac") == 1 then
    local handle = io.popen("defaults read -g AppleInterfaceStyle 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result:match("Dark") then
        return "dark"
      end
    end
    return "light"
  elseif vim.fn.has("linux") == 1 then
    local handle = io.popen("gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null")
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result:match("prefer%-dark") then
        return "dark"
      elseif result:match("default") or result:match("prefer%-light") then
        return "light"
      end
    end
  end
  return nil
end

local function github_colorscheme()
  if vim.o.background == "dark" then
    return "github_dark_high_contrast"
  else
    return "github_light_high_contrast"
  end
end

-- Set background early, before any plugin loads.
-- TERM_BG is set by zshrc_custom via OSC 11 terminal query (works over SSH).
-- Fall back to OS-level detection for local sessions.
vim.o.background = detect_os_appearance() or vim.env.TERM_BG or "dark"

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
