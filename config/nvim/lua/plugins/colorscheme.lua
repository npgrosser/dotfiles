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

local function query_terminal_background()
  -- Query terminal background color via OSC 11 escape sequence.
  -- Works over SSH because it queries the local terminal, not the remote OS.
  local handle = io.popen([[bash -c '
    exec < /dev/tty
    oldstty=$(stty -g)
    stty raw -echo min 0 time 1
    printf "\033]11;?\033\\"
    dd bs=1 count=50 2>/dev/null
    stty "$oldstty"
  ' 2>/dev/null]])
  if handle then
    local result = handle:read("*a")
    handle:close()
    local r, g, b = result:match("rgb:(%x+)/(%x+)/(%x+)")
    if r and g and b then
      r = tonumber(r:sub(1, 2), 16)
      g = tonumber(g:sub(1, 2), 16)
      b = tonumber(b:sub(1, 2), 16)
      local luminance = 0.299 * r + 0.587 * g + 0.114 * b
      return luminance < 128 and "dark" or "light"
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

-- Set background early, before any plugin loads
-- Try OS-level detection first, fall back to terminal query (OSC 11)
-- which works over SSH since it queries the local terminal
local detected = detect_os_appearance() or query_terminal_background()
if detected then
  vim.o.background = detected
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
