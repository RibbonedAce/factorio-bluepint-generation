-- data.lua
-- Runs once while the game starts up (the "data stage"). Its only job is to
-- tell Factorio which new things exist. Nothing here can touch a running game.

-- `data:extend` is the standard way to register new prototypes. The colon is
-- Lua shorthand: `data:extend(x)` means `data.extend(data, x)`, i.e. "call the
-- extend function that lives inside the table `data`, passing `data` itself as
-- the first argument". It takes a list (a Lua table written with { }) of
-- prototypes, and each prototype is itself a table of named fields.
data:extend({
  {
    type = "shortcut",
    name = "blueprint-generation-open",

    -- "lua" means: when clicked, Factorio raises the on_lua_shortcut event and
    -- our control.lua decides what to do (it opens the generation window).
    action = "lua",

    -- A LocalisedString: a list whose first entry is "section.key" in a locale
    -- file. The text itself lives in locale/en/blueprint-generation.cfg.
    localised_name = {"blueprint-generation.shortcut-name"},

    -- "__blueprint-generation__" stands for this mod's own folder.
    -- icon_size / small_icon_size are the height of ONE icon in the image
    -- (the files hold a full-size icon plus a half-size copy side by side,
    -- which is why they are wider than tall). 56 and 24 match the official
    -- shortcut example in the 2.1.23 prototype docs.
    icon = "__blueprint-generation__/graphics/icons/shortcut-toolbar/mip/blueprint-generation-x56.png",
    icon_size = 56,
    small_icon = "__blueprint-generation__/graphics/icons/shortcut-toolbar/mip/blueprint-generation-x24.png",
    small_icon_size = 24,
  },
})
