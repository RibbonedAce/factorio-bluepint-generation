# Project status

Last updated: 2026-10-26

## Goal

A Factorio 2.1 mod where the player gives only an item to produce and a rate of output, and gets a pastable blueprint that carries raw materials (ores and so on) to machines (furnaces, assemblers) to produce the final product.

## What exists

- `info.json`, `LICENSE`, `.gitignore`, and the shortcut icons in `graphics/` (the owner will replace the icons later; `data.lua` assumes the same file names, `icon_size = 56`, `small_icon_size = 24`).
- `data.lua`: the shortcut prototype `blueprint-generation-open` (`action = "lua"`).
- `control.lua`: events and GUI only. Shortcut opens or closes a window (item picker filtered to supported products, rate field in items per minute, Close and Generate buttons). Generate calls `generator.generate`, then puts the blueprint on the cursor. The GUI is stateless (values are read from the window's elements by name), so there is no `storage`.
- `scripts/config.lua`: every hardcoded choice (first-tier belt, inserter and pole names; supported products and their recipe, machine and fuel). Numbers that the game already knows about those entities are NOT stored here (see Decisions).
- `scripts/planner.lua`: pure maths (small private helpers for each step, and `plan` is an outline of them), item and rate in, machine count out (float-safe rounding), plus `lane_items_per_minute(belt_speed)`, the lane capacity of a belt.
- `scripts/layout.lua`: pure, machine count in, blueprint entities out (see "Layout" below). Written in tile coordinates.
- `scripts/grid.lua`: pure, converts between a TILE (the top-left tile an entity covers, whole numbers, y grows down) and a POSITION (the entity's centre, which Factorio blueprints use): `grid.position(tile_x, tile_y, width, height)` and `grid.top_left_tile(position, width, height)`; sizes default to 1x1. The only place the "+ half the size" lives (owner request 2026-10-27). The validator deliberately does NOT use it, so a mistake in `grid` cannot hide behind the same mistake in the checker.
- `scripts/generator.lua`: the only module that reads `prototypes` (recipe, furnace crafting speed, belt speed); builds plain tables and numbers for the planner and layout, and the messages.
- `locale/en/blueprint-generation.cfg`: all texts in a `[blueprint-generation]` section.
- `spec/`: the test suite, run with busted outside the game (see "Testing"). `<thing>_spec.lua` files hold the tests; `helper.lua` (fake `defines`, loads the custom assertions), `support/assertions.lua` (custom luassert assertion), `support/builders.lua` (setup helpers) are the toolkit. `.busted` in the repo root is busted's config.
- `spec/support/blueprint_validator.lua`: layout-independent sanity checks for any list of blueprint entities (see "Testing"). Test tooling only; the game never loads it.

## Iteration ladder

The owner wants the mod built very iteratively: for each step, the simplest solution that is still good code, meeting only the current criteria. The order follows a normal playthrough, with products getting more complex over time. First-tier belts and inserters are hardcoded.

1. Done and confirmed in game by the owner (happy path): shortcut, window, placeholder blueprint on the cursor.
2. Written 2026-10-25, NOT yet run in game: iron and copper plates. One recipe step with two inputs (ore and coal), one output, one machine (stone furnace). Provenance: this code, its tests and an earlier version of these notes were already in the working copy when the current session reached it (the session did not write them; that first version already had poles and wires in the blueprint). The session read all of it and ran the tests. It removed the poles when the owner answered "no poles", then put them back the same day when the owner changed their mind (see Decisions).
3. Next criteria are for the owner to set. Candidates the assistant could suggest when asked (not decided): steel plate (a second smelting step fed by iron plate), assembler recipes with several ingredients, higher rates (more than one belt lane), better machines and belts chosen from research.

## Decisions

- The mod is Lua, written from scratch on `llm-main`. `.agents/` is tracked in git.
- Input is a GUI opened from a shortcut-bar button. Output is a blueprint on the cursor.
- "Resource" means the ITEM TO PRODUCE (for example iron plate). The rate is in items per minute (assumption, confirm with the owner).
- Plates: ore and coal share ONE input belt (one item per lane); the player decides which lane holds which. The planner assumes a recipe with exactly one ingredient plus fuel.
- One column only: more than 24 furnaces (450 plates/min, one belt lane) is refused with a message that names the maximum, instead of building several columns. Several columns is a candidate later iteration.
- Inserters are the electric `inserter`, and the blueprint INCLUDES `small-electric-pole`s with copper wires between them; the player connects the poles to their grid. History: the owner first answered "no poles" (2026-10-25), then changed their mind later that day and asked for the poles to be coded in. Burner inserters were rejected (their output side would run out of fuel).
- Numbers that belong to a hardcoded entity are read from the game at runtime instead of stored in `config` (owner, 2026-10-26). Done so far: the belt lane capacity, computed from the belt's `belt_speed` (`speed x 4 items per lane per tile x 60 ticks x 60 seconds`; 450 per minute for the standard belt), alongside the furnace crafting speed and the recipe that were already read. Candidates for later, not done yet: the pole's supply area and wire reach (the layout still assumes 2.5 and 4 tiles), the furnace's size (`tile_width`, `tile_height`; the layout assumes 2x2), and the inserters' pickup and drop positions (which would also settle the direction question).
- Testing scaffolding (owner, 2026-10-26): build generic test tooling now, but do NOT build a general production-chain model yet; generalize from the second or third real example (steel plate is the first true chain). Unit tests use made-up numbers on purpose, so they hold whatever the game numbers are; no fixtures from real `data.raw`. The blueprint validator deliberately does NOT check belt paths (later layouts may bend belts to save space) or item flow (a game-specific quirk).
- Pure modules (`planner`, `layout`, `config`) may read the constant table `defines` but never `game`, `prototypes`, `storage` or `script`.

## Layout (scripts/layout.lua)

One column of furnaces, items flowing south. Columns by tile x: 0 input belt, 1 input inserters, 2 and 3 furnace (2x2, top-left tile x = 2), 4 output inserters, 5 output belt. Furnace `i` (from 0) covers tile rows `2i` and `2i + 1`; the inserters sit in its top row (tile row `2i`). In the finished blueprint the furnace's centre position is (3, 2i + 1) and a belt on tile (0, 0) is at position (0.5, 0.5); `grid.position` does that conversion. Poles sit in the free bottom-row tiles of columns 1 and 4, for every second furnace, and are wired one after another down each side with one cross-link at the top. Belts are `2N` tiles long, so a blueprint of N furnaces holds exactly `7N + 2 * ceil(N / 2)` entities: `4N` belts, `N` furnaces, `2N` inserters and the poles. Numbers behind it: a furnace makes 18.75 plates/min (3.2 s recipe, speed 1); a standard belt lane carries 450/min (computed at runtime from the belt's speed).

## Refactor for smaller functions (2026-10-27)

Owner request: lower the size and cyclomatic complexity of the long functions. Measured before and after with a small counting script (1 + each `if`, `elseif`, `for`, `while`, `and`, `or`; not in the repo):

| Function | Before (lines / complexity) | After |
|---|---|---|
| `validator.validate` (spec/support/blueprint_validator.lua) | 148 / 42 | 8 / 1, plus one private function per check (largest 19 / 4 apart from `new_network`, which holds three small inner functions) |
| `layout.build` | 54 / 5 | 8 / 1, plus `add_belts`, `add_machine_row`, `wire_poles` and others (largest 14) |
| `generator.generate` | 52 / 9 | 25 / 4, plus `read_game_data`, `refusal_message`, `success_message` and others |
| `planner.plan` | 29 / 5 | 20 / 3, plus `is_supported`, `rates_per_machine`, `machines_needed`, `machines_per_lane` |

Behaviour was compared old against new on about 30,000 lines of output (layouts of 1 to 60 furnaces, thousands of planner rates, nine generator scenarios, and about 4,000 randomly damaged blueprints through the validator): identical except for one bug fix. The bug: the validator crashed ("table index is nil") when a wire pointed at a pole that was already reported as misaligned; it now reports the problems normally and ignores that pole in the network count. 72 of the 4,000 damaged blueprints used to crash.

NOT done: `control.lua` is unchanged. Its longest functions are `generate_blueprint` (45 lines, complexity 9) and `open_window` (35 lines, no branching, building the window). It is not covered by the test suite, so it needs a fake-GUI test file first (fake `script`, `game`, player and GUI elements; see `research/lua-environment.md`) before it is safe to split. Offered to the owner as the next step.

## Tile coordinates (owner request 2026-10-27)

Layout code and tests think in tiles, not centres, so there are no `+ 0.5` fudges outside `scripts/grid.lua`. Convention for EVERY entity size: the position written in code is the top-left tile the entity covers; y grows downward; `grid.position` adds half the entity's width and height to get the centre. A furnace at tile (2, 0) is at position (3, 1). `spec/support/builders.lua` (`belt`, `furnace`, `inserter`, `pole`) take tile coordinates, and fractions build deliberately misaligned entities (`inserter(0.75, 0, ...)`). Possible later issue: an entity rotated a quarter turn swaps its width and height; today every entity is square, so nothing handles that yet. Checked: layout output for 1 to 60 furnaces is identical to before the change.

## Testing

- The assistant cannot run Factorio. Tests run with busted 2.3.0 on a real Lua 5.2.3 (built from GitHub in the assistant's scratch folder; recipe in `instructions.md`). Run `busted` from the repo root. 109 examples at the last run, all passing. Moved from a hand-rolled framework (`tests/`, `assert_that`, matchers; 119 cases) to busted on 2026-10-28 at the owner's request; every old test was ported one-to-one, and the old framework's own tests were dropped because busted and luassert are tested upstream. Only the one custom assertion has specs. The suite follows the owner's given/when/then style rule in `instructions.md`. Remember luassert takes the EXPECTED value first.
- Mutation checks, 2026-10-26, 2026-10-27 and again 2026-10-28 against busted (about 82 deliberate breakages in a scratch copy, one at a time, 0 survivors at the end): planner (float guard, items per lane, ticks, off-by-one limit, minimum of one machine, two ingredients, wrong product, rounding down, ingredient amount, speed, reported maximum), layout (both inserter directions, each wire, pole spacing, furnace and pole positions, belt direction and length, entity numbering, wire connector), generator (fixed lane limit, pole name, belt speed required, message order, number trimming, description, wrong ore name, missing prototype and recipe checks, unsupported item, too-high message), validator (every check removed or weakened) and the custom assertion (plain text versus pattern, list and text type guards, non-strings skipped, only first item checked, always true, message text). The first busted run left two survivors in the custom assertion (pattern instead of plain text, type guard removed); both fixed with new specs. Earlier findings, all fixed with tests: planner minimum of one machine (a near-zero rate would have produced zero machines), planner ingredient amount (every test used 1), a recipe that takes no time, a furnace without a crafting speed, an entity without a number, and a wire to a misaligned pole hiding separate networks. A harness script (copy `scripts` and `spec`, apply one text replacement, run busted, expect failure) lived in the assistant's scratch folder, not in the repo; re-create it if needed.
- Earlier mutation history (2026-10-25, before the rewrite): deliberate breakages in a scratch copy were each caught by the tests (inserter direction, a missing belt tile, a furnace one tile off, no float guard in the planner, a wrong lane limit, a missing pole cross-link, an unwired pole chain, poles too sparse or too far apart, a wrong wire connector, a pole on top of an inserter, and a generator that forgot the pole name). The last one first SURVIVED, which exposed a gap (nothing checked the names of the generated entities); a generator test for that was added. For the runtime belt speed (2026-10-26) the mutations were: a wrong items-per-lane constant, a wrong tick rate, a generator that went back to a fixed 450, and a generator that no longer required a belt speed; all caught.
- `spec/support/blueprint_validator.lua` takes the entity list plus a catalog (name to kind, size, needs_power, supply_radius, wire_reach; numbers made up in the tests) and returns a list of problems. It checks: known entity names and unique numbers, grid alignment (odd sizes on half tiles, even on whole), no overlapping tiles, every inserter picks up from and drops onto a belt or machine with at least one end a machine, every entity that needs power is inside a pole supply area (footprint overlap), wires join two poles within the shorter reach using the copper connector and start on the entity that lists them, and all poles form one network. The layout-specific checks (counts, numbering, belts south, which inserter does what) stay in `check_layout`. The validator has its own tests (`spec/blueprint_validator_spec.lua`): tiny hand-built blueprints, each broken in one specific way, and each break must be reported; boundary cases (a pole exactly at the edge of its supply area, a wire exactly as long as the reach) are covered both ways. Mutation checks on the validator code (2026-10-26) first left three survivors (supply area ignoring entity size, an inserter allowed to pick up from anything, wire reach using the longer of two poles), each fixed with a new test; a fourth (supply area ignoring height) was found and fixed the same way. Two mutants fail by crashing rather than a clean failure (unknown names allowed; wire kinds unchecked); still detected.
- The validator shares the inserter-direction assumption with the layout (direction = side picked up from), so it cannot catch that assumption being wrong; only the in-game run can.
- An earlier note said `control.lua` was exercised against fake GUI, player and game objects in a scratch harness (29 checks). That harness is not in the repo and was not re-run this session; `control.lua` itself was not changed by the pole removal.
- What this proves: the logic is self-consistent and the code parses. What it does NOT prove: that Factorio accepts the blueprint, and anything about real item names, inserter orientation or wires. Only the owner's in-game run proves that.

## Unverified in iteration 2 (check on the first in-game run)

1. **Inserter orientation.** `layout.lua` sets `direction = west` on both inserters, assuming an inserter's direction is the side it PICKS UP from (so they move items east). If the inserters point the wrong way in game, swap to `east` in `layout.lua` (the layout test then needs the same change). Source: memory, not the JSON.
2. **Wire format.** Each wire is stored once, on the entity it starts from, as a four-entry list (this entity's number, connector, other entity's number, connector), using `defines.wire_connector_id.pole_copper`. The JSON describes a `BlueprintWire` as "a single wire" with a source and a target, which fits one entry per wire, but the docs do not say whether `wires` should list a wire on both ends. If the poles come out unconnected in game, try listing each wire on both poles.
3. **Entity names** `stone-furnace`, `transport-belt`, `inserter`, `small-electric-pole`, `coal`: standard base names from memory. The generator checks the entities exist and reports a message if not.
4. **Small pole range.** Spacing assumes a supply area reaching 2.5 tiles and wire reach of at least 4 tiles (the farthest wire is 4 tiles). The runtime can report real values (`get_supply_area_distance`, `get_max_wire_distance` on the entity prototype); the layout does not read them yet.
5. **Runtime `belt_speed`.** The generator treats `prototypes.entity["transport-belt"].belt_speed` as the same raw value the prototype docs call `speed` (0.03125 for the standard belt). The runtime docs say only "the speed of this transport belt". To check in game: ask for a rate above the limit (for example 1000 per minute); the message must say the maximum is 450 per minute. A different number means the unit differs.
6. **Dotted `require`** (`require("scripts.generator")`) is used for the first time. It follows the 2.0 wiki tutorial and passed under busted; confirm in 2.1.
7. **Item picker filter** (`elem_filters` by name) is verified against the JSON but untested in game.
8. Whether `set_blueprint_entities` repositions entities (the `fix_positions` default is not documented); the layout keeps entities on valid tile positions either way.

## Risks and flags

- **Icon files.** The owner is replacing them; sizes assumed as above.
- **Folder name.** The game only loads a mod folder named `blueprint-generation` or `blueprint-generation_0.0.1` (see `research/mod-structure.md`).
- **Lua environment.** Modified Lua 5.2.1 (not 5.1, and not the 5.3 of `texlua`): no `io`, `os`, `coroutine`; `require` only at file top level. Avoid 5.3-only syntax (`//`, bitwise operators, `utf8`, `math.type`), and format numbers with `string.format`, because 5.3 prints `3.0` where 5.2 prints `3`.
- **Load sequence and desync rules.** See `research/data-lifecycle.md` and `research/modding-tutorial.md`.

## Next steps

1. Owner applies the patches, loads the mod, generates iron plate and copper plate blueprints, and reports: do the pieces look right (inserter directions, belts, poles, wires), does pasting and powering it work, does the furnace produce plates.
2. Fix whatever the run shows; update `.agents` so the unverified list shrinks.
3. Owner chooses the next criteria on the ladder.
