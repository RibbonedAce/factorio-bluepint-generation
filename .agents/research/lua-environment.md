# Factorio's Lua environment

Source: the "Libraries and functions" page (`lua-api.factorio.com/2.1.23/auxiliary/libraries.html`), pasted into the session by the owner on 2026-10-25 because the site refuses the assistant's fetch tool. Items marked **JSON** were also checked against the 2.1.23 runtime JSON. Items marked **General Lua** are the assistant's own knowledge of Lua 5.2, NOT from the page, and need testing in game.

## What the page says (Verified)

- The base language is a MODIFIED Lua 5.2.1 (not 5.1, and not stock 5.2): extra functions and libraries are added, some modules are removed, and several standard functions behave differently (`pairs`, `require`, `math.random`, the math functions, `load`, `debug`). Never assume stock Lua behavior without checking this page or testing in game. `string.pack`, `string.packsize` and `string.unpack` are backported from Lua 5.4.6.
- `serpent` is a global library. `serpent.block(t)` pretty-prints a table for debugging. It cannot print LuaObjects such as a `LuaEntity`. Combine it with `log`, for example `log(serpent.block(my_table))`.
- `log(LocalisedString)` writes to the Factorio log file. `localised_print` writes to stdout and is meant for external tools. `print()` also goes only to stdout, so it never appears in the log. For debugging use `log()` or `game.print` (chat message to all players; **JSON**: it takes `message` and optional `print_settings`, and skips an identical message sent in the last 60 ticks by default).
- `table_size(t)` counts entries of a table with gaps in its keys. It does NOT work on a `LuaCustomTable`. Use the length operator instead (**JSON**: `LuaCustomTable` has `index` and `length` operators, so `#prototypes.recipe` style access is the way; `prototypes.recipe`, `force.recipes` and similar are all `LuaCustomTable`s).
- Not available: `loadfile`, `dofile`, `coroutine`, `io` and `os`. Factorio supplies its own `package` and `debug` (only `debug.getinfo` and `debug.traceback` by default).
- `pairs()` and `next()` are deterministic: keys iterate in insertion order, and the first 1024 numbered keys always iterate 1 to 1024 regardless of insertion order. So `pairs` on an array-like table is fine.
- `require()`:
  - Absolute paths start at the mod root. `.` and `..` are disabled, so a mod cannot load files outside its own folder.
  - `require("util")` loads Factorio's `util` helper library from the core mod's `lualib` folder.
  - Another mod's file: `require("__mod-name__.file")`.
  - `require` cannot be used in the console, in event handlers, or during `remote.call()`. It expects files to end in `.lua`.
- `math.random()` is deterministic. It uses the map's shared generator, and cannot be used outside events or while loading. Non-integer arguments are floored. `math.randomseed()` does nothing. For an independent generator use `LuaRandomGenerator` (**JSON**: created by `game.create_random_generator`, called like a function, with a `re_seed` method).
- `load()` ignores its `mode` argument and does not load binary chunks. All trigonometric, exponential and logarithmic math functions are Factorio's own deterministic versions.

## What this means for the design

1. **Call `require` only at the top level of a file.** Do all requires at the top of `control.lua` (and `data.lua`), never inside a handler. Verified restriction.
2. **No file I/O, no clock.** `io` and `os` do not exist, so mod code cannot read or write files itself. Use `helpers.write_file` for file output (see the API reference), and do not use `os.time` or `os.clock`.
3. **Deterministic results.** Factorio multiplayer runs the same code on every player's machine, so the blueprint generator must give the same output for the same input. No randomness is needed here, and `pairs` iteration is already deterministic.
4. **Testing outside the game.** Planning-logic modules should stay plain Lua that avoids `io`, `os`, `coroutine`, `game`, `script`, `prototypes`, `storage` and `serpent`, so the same file loads both in the game and under a standalone Lua interpreter. No interpreter was found in the assistant's workspace yet (see `../project-status.md`).
5. **Debugging.** `log(serpent.block(t))` for plain tables; `game.print(...)` to show something in chat; `print()` is useless inside the game.
6. **Lua 5.2 base means older syntax (General Lua, not from the page).** For standalone tests, the closest match is a stock Lua 5.2 interpreter, but it will not reproduce Factorio's changes, so a passing standalone test is not proof the code works in game. No integer type or `//` operator (all numbers are floating point), no bitwise operators, and `goto` exists. `math.floor` and `math.ceil` are the way to round. This matters for the owner, who is new to Lua: a walkthrough should be explicit about it.
7. **`util` library.** It exists and loads with `require("util")`. Its contents are NOT documented in the pages we have; do not use any function from it without checking its source or docs first.

## Still unknown

- Whether `require` accepts dotted subpaths for files inside the mod in 2.1. The wiki tutorial (written for 2.0) uses `require("bar.foo")` for a file `bar/foo.lua`, see [modding-tutorial.md](modding-tutorial.md). Dotted paths are the form to use; confirm in game before building a folder of modules.
- The contents of `util` (for example `util.table.deepcopy`) and the `mod-gui` helper.
- Whether `bit32` is available (not mentioned).
