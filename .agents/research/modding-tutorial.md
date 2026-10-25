# Wiki modding tutorial (written for 2.0)

Source: the wiki page "Tutorial:Modding tutorial" (`wiki.factorio.com`), pasted into the session by the owner on 2026-10-25. It is **Secondary**: it was written for Factorio 2.0 and the page itself warns that minor changes may have happened since. Where the 2.1.23 JSON could confirm a name, that is noted. The tutorial's example `info.json` is where this repo's placeholder `"author": "You"` and the `base >= ...` dependency style came from.

## Practical setup

- Put the mod in `<user data directory>/mods/<mod-name>/` (the user data directory is sometimes called `.factorio`). The folder must carry the mod's name: here `blueprint-generation`. Zip only for sharing: zip the folder and name the archive `<mod-name>_<version>`.
- Control-stage changes need no game restart: reloading the save re-runs `control.lua`. Changes to `data.lua` or `info.json` need a game restart (data stage runs at startup; this follows from the data lifecycle).
- In game, hovering over an item and pressing Shift+Ctrl+F opens the prototype explorer, which shows an item's prototype type and name (tutorial claim, untested).
- Editors the tutorial suggests: Emacs, Vim, Sublime Text, VS Code, Notepad++.

## Facts that resolve earlier unknowns

- **Two-part dependency versions are normal.** The tutorial's `info.json` uses `"dependencies": ["base >= 2.0"]` and `"factorio_version": "2.0"`. So this repo's `base >= 2.1` follows the same pattern. (Secondary: 2.0 tutorial.) The mod-structure page itself only shows three-part versions in its examples.
- **Dotted `require` paths work for subfolders.** The tutorial's example puts `foo.lua` in a `bar` folder and loads it with `require("bar.foo")` from `data.lua`. (Secondary: 2.0 tutorial; test in 2.1.) Together with the libraries page: requires go at the top of the file, and `control.lua` itself is run automatically, so it is never required.
- **Locale files** are `.cfg` files in `locale/<language code>/`, with any file name. Format: a `[section]` line, then `key=value` lines, for example `[item-name]` then `fire-armor=Fire armor`, and `[item-description]` for descriptions. A missing entry shows as "Unknown key" in game. The tutorial only shows `item-name` and `item-description`. The section name for a SHORTCUT's display name is NOT in any source we have; look it up before writing the locale file.

## Data stage notes

- `data:extend{ ... }` adds prototypes, and the tutorial copies an existing prototype with `table.deepcopy(data.raw["armor"]["heavy-armor"])` and edits it. `data.raw["<type>"]["<name>"]` is where all prototypes live, but only in the data stage. In the control stage, read processed values through the runtime API (for example `LuaEntityPrototype`).
- Create prototypes as early as possible (`data.lua`), because other mods' `data-updates.lua` code can react to them; `data-final-fixes.lua` is for changing other mods' prototypes.
- A recipe prototype in the tutorial: `type = "recipe"`, `name`, `enabled`, `energy_required`, `ingredients = {{type = "item", name = ..., amount = ...}}`, `results = {{type = "item", name = ..., amount = ...}}`. It has no category field, so it uses the default (`crafting`). This matches the 2.1.23 JSON.
- Migrations are static lists of renamed prototypes; avoid renaming prototypes or technologies after release.

## Control stage notes

- Handler shape: `script.on_event(defines.events.<event>, function(event) ... end)`, with the player fetched by `game.get_player(event.player_index)`. **JSON** confirms `game.get_player`, `game.players`, `game.print`, `LuaEntity.unit_number`, `LuaPlayer.controller_type`, `LuaControl.get_inventory`, `LuaSurface.create_entity` and the event `on_player_changed_position` all exist in 2.1.23.
- Printing a LuaObject (such as a player) shows only its class name ("LuaPlayer"), not its data.

## Error shapes (so they are recognised quickly)

- **Syntax error in a data-stage file** stops the game at startup: `Failed to load mod "<name>": __<name>__/data.lua:39: unfinished string near ...`. Trust the line number only to within a few lines.
- **Syntax error in `control.lua`** does NOT stop startup; it appears when a save is loaded.
- **Errors inside event handlers** show `Error while running event <mod>::<event> (ID n)` followed by the message and a traceback. A common one is `attempt to index field '?' (a nil value)`, caused by assuming something exists (for example `game.players[23]`). Check for `nil` before indexing.
- **Internal errors** (C++ crashes) are not the mod's fault, but mods can trigger them; report them to the developers.

## Multiplayer and desync rules (Secondary, consistent with the data-lifecycle page)

Every machine must reach the same game state from the same inputs. Never do these:
1. **Mutable file-level locals.** A `local` declared outside handlers that is changed at runtime and then used to alter game state desyncs. Constants are fine. Anything that changes belongs in `storage`.
2. **Conditional event subscription** (subscribing inside an `if`, a function, or another event). Subscribe at the top level. If conditional subscription is ever needed, re-subscribe in `on_load` (see [data-lifecycle.md](data-lifecycle.md)).
3. **Wrong use of `on_load`**: only re-register conditional handlers, re-set metatables, and make local references into `storage`. The game usually catches other attempts by crashing the mod.
4. **Comparing tables by reference** (`a == b`) when one may have been loaded from the server's state. LuaObjects (entities, players) are safe to compare directly, but NOT safe as table keys (`t[entity]`). Use `entity.unit_number` as the key instead.

## Design implications

- A first version made of one top-level command registration plus handlers with local variables has none of these hazards, so keep it that way: no mutable file-level state, no conditional subscription, and nothing in `on_load`.
- If a GUI needs to remember something per player, key `storage` by `player.index` (a number), not by the player object.
