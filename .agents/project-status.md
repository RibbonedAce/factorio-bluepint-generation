# Project status

Last updated: 2026-10-25

## Goal

A Factorio 2.1 mod where the player gives only an item to produce and a rate of output, and gets a pastable blueprint that carries raw materials (ores and so on) to machines (furnaces, assemblers) to produce the final product.

## What exists

- `info.json`: mod `blueprint-generation`, version 0.0.1, `factorio_version` "2.1", dependency `base >= 2.1`, author "Ribboned Ace".
- `LICENSE`: MIT, 2026, Ribboned Ace.
- `graphics/icons/shortcut-toolbar/mip/blueprint-generation-x24.png` (36x24 px) and `-x56.png` (84x56 px): shortcut-bar icons. The owner will replace them in a later commit with prepared files (names and sizes not yet known; `data.lua` assumes the same names, `icon_size = 56`, `small_icon_size = 24`).
- `.agents/`: these notes. The API reference was written from the 2.1.23 JSON files the owner supplied.
- **First slice (written 2026-10-25, NOT yet run in game):**
  - `data.lua`: the shortcut prototype `blueprint-generation-open` (`action = "lua"`).
  - `control.lua`: handlers for `on_lua_shortcut` (open or close the window), `on_gui_click` (Generate and Close buttons) and `on_gui_closed` (Esc or E). The window is a frame holding an item chooser, a rate field (items per minute, default 60) and two buttons. Generate puts a one-chest PLACEHOLDER blueprint on the cursor. The GUI is stateless: Generate reads the values straight from the window's elements by name, so there is no `storage`.
  - `locale/en/blueprint-generation.cfg`: all texts, in a `[blueprint-generation]` section.

## Decisions

Made:
- The mod is Lua, written from scratch on `llm-main`.
- `.agents/` is tracked in git.
- Input is a GUI, opened from a shortcut-bar button (owner, 2026-10-25). The assistant had recommended a chat command first; the owner chose the GUI, and it works without `storage` as long as the GUI reads its own element values.
- Output is a blueprint item placed on the player's cursor (owner, 2026-10-25).
- Icons: the owner supplies final files in the next commit after the notes.
- Reading of the request: "resource" means the ITEM TO PRODUCE (for example iron plate); the planner works out the raw materials. The rate is in items per minute. Both are assumptions to confirm with the owner.

Open:
1. Which products and machines the first real planner supports (suggestion: start with smelting a single ore into a plate).
2. Unit of the rate (per minute is assumed; per second is the alternative).
3. Whether the planner should be able to use modules, beacons or quality machines (assume plain machines at normal quality).

## Findings that shape the design

- Recipes use `categories` (a list). Assemblers and furnaces both declare `crafting_categories`, so one lookup (recipe category to machine prototypes) can pick the machine for smelting and for crafting. Machine count is roughly: rate x craft time / (crafting speed x items per craft). Verify the formula against productivity and quality rules before relying on it.
- Furnace blueprint entities take no recipe field; assembling machines do (`recipe`, `recipe_quality`). Poles have no extra fields. See the API reference for the full list.
- Blueprint entities are plain Lua tables, so the whole blueprint can be generated in code and installed with `set_blueprint_entities`.

## Risks and flags

- **Icon files (earlier concern withdrawn).** The two PNGs are 36x24 and 84x56 px, which looks like a mipmap strip (full-size icon plus a half-size copy). The official shortcut example in the 2.1.23 prototype docs uses files with the same naming (`mip/...-x56.png`) and `icon_size = 56`, `small_icon_size = 24`, so the layout is the standard one, not a mistake. Whether these exact files render correctly is still untested. The owner is replacing them anyway.
- **Folder name.** The game only loads a mod folder named `blueprint-generation` or `blueprint-generation_0.0.1`. A clone named after the repository will not load, so the owner needs a correctly named folder or link in the Factorio mods directory to test (see `research/mod-structure.md`).
- **Lua environment.** Factorio's Lua is a modified 5.2.1 (not 5.1) with no `io`, `os` or `coroutine`, and `require` only works at file top level (see `research/lua-environment.md`). Keep modules free of those so they can be tested outside the game.
- **Load sequence.** Register events and commands only at the top level of `control.lua`; use `game` only inside handlers (see `research/data-lifecycle.md`).
- **Desync rules.** No mutable file-level locals, no conditional event subscription, nothing but the three allowed things in `on_load`, and never LuaObjects as table keys (use `unit_number` or `player.index`); see `research/modding-tutorial.md`.
- **Testing.** The assistant cannot run Factorio, and could not get any Lua interpreter on 2026-10-25 (`pip install lupa` found no version, `apt` has no `lua5.2`, `npm install fengari` hit a network error), so no code has been run or even syntax-checked by a real parser. The only checks so far are reading against the JSON and a crude script that confirms blocks and brackets balance. Consequences: the owner's first load in game is the real syntax check, and a `control.lua` syntax error only appears when a save is loaded (a `data.lua` one stops startup). Proposal: keep the planning logic (item and rate in, machine counts and layout out) in plain Lua modules that do not call the game API, and keep `control.lua` as thin glue, so the logic can later be tested outside the game if an interpreter becomes available.
- **Unverified in the first slice** (from memory or untested, check on first run): the base item names `blueprint` and `iron-chest`; the shortcut button may need adding to the shortcut bar from the selection popup; whether `set_blueprint_entities` moves the chest's position when `fix_positions` is left at its default.

## Next steps

1. Owner applies the code patch, loads the mod in game and reports what happens (does the button appear, does the window open, does Generate put a blueprint on the cursor, any errors).
2. Fix whatever the first run shows.
3. Design the planning logic and the blueprint layout rules, starting with the smallest useful case (smelting one ore into a plate), keeping the planner in plain Lua modules.
4. Replace the placeholder chest with real generated entities.
5. Close the remaining items in `research/factorio-2.1.md` as they become relevant.
