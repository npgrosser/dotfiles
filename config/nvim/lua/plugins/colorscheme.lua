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

local function pick_colorscheme()
  if vim.o.background == "dark" then
    return "onedark"
  else
    return "github_light_high_contrast"
  end
end

-- Set background early, before any plugin loads.
-- TERM_BG is set by zshrc_dotfiles via an OSC 11 terminal query.
-- Fall back to OS-level detection for local sessions.
vim.o.background = detect_os_appearance() or vim.env.TERM_BG or "dark"

return {
  -- One Dark for dark mode — tuned to match Hydra terminal's default palette
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "darker",
      colors = {
        bg0 = "#181818", -- main background (exact Hydra match)
        bg1 = "#1f1f1f", -- lighter bg (statusline, etc.)
        bg2 = "#252525", -- selection, visual
        bg3 = "#363636", -- borders, indent guides
        bg_d = "#0f0f0f", -- darker bg (matches Hydra tab bar)
      },
    },
    config = function(_, opts)
      require("onedark").setup(opts)
      if vim.o.background == "dark" then
        require("onedark").load()
      end
    end,
  },
  -- GitHub theme for light mode
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      if vim.o.background == "light" then
        vim.cmd.colorscheme("github_light_high_contrast")
      end
    end,
  },
  -- Switch colorscheme when background changes
  {
    "LazyVim/LazyVim",
    opts = function()
      return { colorscheme = pick_colorscheme() }
    end,
    init = function()
      vim.api.nvim_create_autocmd("OptionSet", {
        pattern = "background",
        callback = function()
          vim.cmd.colorscheme(pick_colorscheme())
        end,
      })
    end,
  },
}
