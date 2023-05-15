
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

-- Wibar (Bar)
myKeyboardLayout = awful.widget.keyboardlayout()
myTextClock = wibox.widget.textclock()

screen.connect_signal("request::desktop_decoration", function(s) 
	-- Each screen has its own tag table
	awfult.tag({"1","2","3","4","5","6","7","8","9"}, s, awful.layout.layouts[1])
	
	-- Create a prompt box for each screen
	s.myPromptBox = awful.widget.prompt()

	-- Create an imagebox widget which will contain an icon indicating which layout we're using
	-- We need one layoutbox per screen
	s.myLayoutBox = awful.widget.layoutbox 
	{
		screen = s,
		buttons = 
		{
			awful.button({ }, 1, function() awful.layout.inc( 1) end),
			awful.button({ }, 3, function() awful.layout.inc( -1) end),
			awful.button({ }, 4, function() awful.layout.inc( -1) end),
			awful.button({ }, 5, function() awful.layout.inc( 1) end),
		}
	
	}

	-- Create a taglist widget
	s.myTaglist = awful.widget.taglist 
	{
		screen = s,
		filter = awful.widget.taglist.filter.all,
		buttons = 
		{
			awful.button({ }, 1, function(t) t:view_only() end),
			awful.button({ modkey }, 1, function(t)
				if client.focus
				then
					client.focus:move_to_tag(t)
				end
			end),
			awful.button({ }, 3, awful.tag.viewtoggle),
			awful.button({ }, 3, function(t) 
				if client.focus
				then
					client.focus:toggle_tag(t)
				end
			end),
			awful.button({ }, 4, function(t) awful.tag.viewprev(t.screen) end),
			awful.button({ }, 5, function(t) awful.tag.viewnext(t.screen) end),
		}
	}

	-- Create a task list widget
	s.myTaskList = awful.widget.tasklist
	{
		screen = s,
		filter = awful.widget.tasklist.filter.currenttags,
		buttons = 
		{
			awful.button({ }, 1, function(c) 
				c:activate 
				{
					context = "tasklist",
					action = "toggle_minimization"
				}
			end),
			awful.button({ }, 3, function() awful.menu.client_list { theme = { width = 250 } } end),
			awful.button({ }, 4, function() awful.client.focus.byidx(-1) end),
			awful.button({ }, 5, function() awful.client.focus.byidx(1) end),
		}
	}
	
	-- Create the wibox
	s.myWibox = awful.wibar
	{
		position = "top",
		screen = s,
		widget = 
		{
			layout = wibox.layout.align.horizontal,
			{
				-- Left widgets
				layout = wibox.layout.fixed.horizontal,
				myLauncher,
				s.myTaglist,
				s.myPromptBox,
			},
			-- Middle widgets
			s.myTasklist,
			{
				-- Right widgets
				layout = wibox.layout.fixed.horizontal,
				myKeyboardLayout,
				wibox.widget.systray(),
				myTextClock,
				s.myLayoutBox,
			},
		}
	}
end)

-- Mouse bindings
awful.mouse.append_global_mousebindings({
	awful.button({ }, 3, function() myMainMenu:toggle() end),
	awful.button({ }, 4, awful.tag.viewprev),
	awful.button({ }, 5, awful.tag.viewnext),
})

-- Key bindings
-- General 
awful.keyboard.append_global_keybindings({
	awful.key({ modkey, }, "s", hotkeys_popup.show_help, {description="show help", group = "awesome"}),
	awful.key({ modkey, }, "w", function() myMainMenu:show() end, {description="show main menu", group = "awesome"}),
	awful.key({ modkey, "Control" }, "r", awesome.restart, {description="reload awesome", group = "awesome"}),
	awful.key({ modkey, "Shift" }, "q", awesome.quit, {description="quit awesome", group = "awesome"}),
	awful.key({ modkey }, "x",
		function() 
			awful.prompt.run 
			{
				prompt = "Run Lua code: ",
				textbox = awful.screen.focused().myPromptBox.widget,
				exe_callback = awful.util.eval,
				history_path = awful.util.get_cache_dir() .. "/history_eval"
			}
		end,
		{description="lua execute prompt", group = "awesome"}),
	awful.key({ modkey, }, "Return", function() awful.spawn(terminal) end, {description="open a terminal", group = "launcher"}),
	awful.key({ modkey }, "r", function() awful.screen.focused().myPromptBox:run() end, {description="run prompt", group = "launcher"}),
	awful.key({ modkey }, "p", function() menubar.show() end, {description="show the menubar", group = "launcher"}),
})

-- Tags related keybindings
awful.keyboard.append_global_keybindings({
	awful.key({ modkey, }, "Left", awful.tag.viewprev, {description="view previous", group = "tag"}),
	awful.key({ modkey, }, "Right", awful.tag.viewnext, {description="view next", group = "tag"}),
	awful.key({ modkey, }, "Escape", awful.tag.history.restore, {description="go back", group = "tag"}),
})

-- Focus related keybindings
awful.keyboard.append_global_keybindings({
	awful.key({ modkey, }, "j", 
	function() 
		awful.client.focus.byidx( 1)	
	end, {description="focus next by idx", group = "client"}),
	awful.key({ modkey, }, "k", 
	function()
		awful.client.focus.byidx(-1)
	end, {description="focus previous by idx", group = "client"}),
	awful.key({ modkey, }, "Tab",
	function()
		awful.client.focus.history.previous()
		if client.focus
		then
			client.focus::raise()
		end
	end, {description="go back", group = "client"}),
	awful.key({ modkey, "Control" }, "j", function() awful.screen.focus_relative( 1) end, {description="focus the next screen", group = "screen"}),
	awful.key({ modkey, "Control" }, "k", function() awful.screen.focus_relative( -1) end, {description="focus the previous screen", group = "screen"}),
	awful.key({ modkey, "Control" }, "n",
	function()
		local c = awful.client.restore()
		-- Focused restored client
		if c 
		then
			c:activate { raise = true, context = "key.unminimize" }
		end
	end, {description="restore minimized", group = "client"}),

})

-- Layout related keybindings

