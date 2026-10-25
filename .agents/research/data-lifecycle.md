# Data lifecycle and `storage`

Sources: the "Storage" page and the "Data lifecycle" page (`lua-api.factorio.com/2.1.23/auxiliary/data-lifecycle.html`), both pasted into the session by the owner on 2026-10-25 because the site refuses the assistant's fetch tool. The owner did not give an address for the Storage page. Everything here is **Verified** from those pages unless marked otherwise. `LuaBootstrap.register_metatable` was also confirmed in the 2.1.23 runtime JSON.

## The three stages

1. **Settings stage** (`settings.lua`, `settings-updates.lua`, `settings-final-fixes.lua`): mods define setting prototypes. Then the player's saved values are read from `mod-settings.dat`.
2. **Prototype stage** (`data.lua`, `data-updates.lua`, `data-final-fixes.lua`): mods add prototypes through the `data` table.
3. **Control stage** (`control.lua`): runs for the whole life of a loaded save.

Settings and prototype stages run all mods in one shared Lua state, in three rounds (`stage`, then `stage-updates`, then `stage-final-fixes`). The state is thrown away afterwards, so no variable carries over to the control stage. During them there is no game and the normal runtime API does not exist. Available globals: `data` (collects prototypes), `mods` (mod name to version for all enabled mods), and in the prototype stage `settings.startup`. Properties the game does not recognise are ignored and discarded. In the control stage `data` is gone and prototypes cannot change.

Mod load order: shorter dependency chains first, then the natural sort order of internal names. The same order is used for sending events at runtime.

## Control-stage steps

Each step runs for all appropriate mods before the next step starts.

1. **`control.lua` runs** (every time a save is created or loaded, so no game restart is needed after editing it). Use it only to register events (`script`), remote interfaces (`remote`) and custom commands (`commands`). No access to `game` or `rendering`. `storage` is not restored yet, so do not initialise it here.
2. **`on_init`** runs only for a mod that is new to the save (new game, or the mod was added to an existing save; adding `control.lua` to an existing mod counts as new). Full access to `game` and `storage`. Use it to set up initial `storage`. `on_load` does not run for that mod.
3. **Migrations** (files in the mod's `migrations` folder) run once per save; JSON migrations first, then Lua ones. Full game access.
4. **`on_load`** runs for mods that were in the save before, including when a player joins a multiplayer game. No `game` access. `storage` can be read but writing causes an error. Allowed uses only: re-set up unregistered metatables, re-subscribe conditional event handlers, create local references to data in `storage`. Anything else causes desyncs.
5. **`on_configuration_changed`** runs for all mods or none: when the game version or any mod version changed, a mod was added or removed, a startup setting changed, prototypes were added or removed, or a migration was applied. `storage` is writable and `game` is available.

A player joining a running multiplayer game only runs steps 1 and 4, so conditional event registrations must come out identical on every machine.

## `storage` rules

- `storage` is a global table, separate for each mod, saved and restored with the map. It was called `global` before 2.0. Circular references work.
- Allowed contents: `nil`, strings, numbers, booleans; tables; references to Factorio LuaObjects. **Functions are not allowed** and cause an error when saving.
- Metatables are not saved. A metatable registered with `script.register_metatable(name, metatable)` is recorded by name and reattached on load. An unregistered metatable is dropped, so the table comes back as a plain table.
- Mod variables outside `storage` are lost on save and load.

## What this means for the design

1. **Register everything at the top level of `control.lua`.** The chat command and the shortcut handler (`script.on_event(defines.events.on_lua_shortcut, ...)`) both go there. This also settles the earlier question: command registrations must be repeated on every load, and the top level of `control.lua` is where that happens.
2. **Use `game` and `prototypes` only inside handlers** (command, shortcut, GUI events), never at the top level of the file.
3. **A command-only first version needs no `storage` at all.** The planner can compute the result and place it on the cursor without remembering anything. Add `storage` only when something has to outlive an event, such as an open GUI's state or per-player settings. Do not add it earlier.
4. **When `storage` arrives:** initialise it in `on_init` (and add missing fields in `on_configuration_changed` after updates); never write to it in `on_load`; store only plain data and LuaObject references; no functions.
5. **Data needed at runtime from the data stage** (recipes, machine speeds) is read through `prototypes` at runtime (see the API reference), not carried over from the data stage, since that state is discarded.
6. **Settings** (if any): startup settings are read from `settings.startup` in the prototype stage; runtime ones come from `settings` in the control stage (see the API reference).
