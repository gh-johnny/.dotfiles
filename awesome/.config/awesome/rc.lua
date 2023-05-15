
-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")

-- Widget and layout library
local wibox = require("wibox")

-- Theme handling library
local beautiful = require("beautiful")

-- Notification library
local naughty = require("naughty")

-- Declarative object management
local ruled = require("ruled")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
require("awful.hotkeys_popup.keys")

-- Error handling
naughty.connect_signal("request::display_error", function(message, startup)
	naughty.notification {
		urgency = "critical",
		title = "Oopsy Daisy, an error happened"..(startup and " during startup!" or "!"),
		message = message
	}
end)

-- Variable definitions
beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")
terminal = "Alacritty"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor
modkey = "Mod4"

-- Menu
myAwesomeMenu = {
	{ "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
	{ "manual", terminal .. " -e man awesome" },
	{ "edit config", editor_cmd .. " " .. awesome.conffile },
	{ "restart", awesome.restart },
	{ "quit", function() awesome.quit() end },
}

myMainMenu = {
	awful.menu({ 
		items = 
		{
			{ "awesome", myAwesomeMenu, beautiful.awesome_icon },
			{ "terminal", terminal }
			
		}
	})
}

myLauncher = awful.widget.launcher({
	image = beautiful.awesome_icon,
	menu = myMainMenu
})

-- Menu bar config
menubar.utils.terminal = terminal

-- Tag layout 
tag.connect_signal("request::default_layouts", function()
	-- Order matters
	awful.layout.append_default_layouts({
		awful.layout.suit.floating,
		awful.layout.suit.tile,
		awful.layout.suit.tile.left,
		awful.layout.suit.tile.bottom,
		awful.layout.suit.tile.top,
		awful.layout.suit.fair,
		awful.layout.suit.fair.horizontal,
		awful.layout.suit.spiral,
		awful.layout.suit.spiral.dwindle,
		awful.layout.suit.max,
		awful.layout.suit.max.fullscreen,
		awful.layout.suit.magnifier,
		awful.layout.suit.corner.nw,
	})	
end)

-- Wallpaper
screen.connect_signal("request::wallpaper", function(s) 
	awful.wallpaper {
		screen = s,
		widget = 
		{
			{
				image = beautiful.wallpaper,
				upscale = true,
				downscale = true,
				widget = wibox.widget.imagebox,
			},
		valing = "center",
		haling = "center",
		tiled = false,
		widget = wibox.container.tile,
		}
	}
end)


