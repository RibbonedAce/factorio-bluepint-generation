# Factorio 2.1 research

Researched 2026-10-24. Labels: **Verified** (primary source read), **Secondary** (someone else's summary), **Unverified** (memory or a lead). The detailed API facts are in [api-reference-2.1.23.md](api-reference-2.1.23.md).

## Release facts

- **Verified.** 2.1 was marked stable on 2026-10-23, after a summer in experimental. Source: [Friday Facts #449 - 2.1 Stable](https://factorio.com/blog/post/fff-449). So `factorio_version: "2.1"` in `info.json` is a real release target. The exact format the game expects for that field is still Unverified (the mod-structure docs page was not readable).
- **Verified.** Saves and blueprints cannot be downgraded to 2.0 once updated, so back them up first. Same source.
- **Verified.** 2.0 saves load, but the circuit Input/Output split may break existing designs. Same source. The blueprint wire format is in the API reference.
- **Verified.** Space Age can be played without Quality. The Recycler moved into its own mod, and Quality is a recommended dependency enabled by default. Same source.
- **Verified.** The API files the owner supplied are version 2.1.23. **Unverified:** whether 2.1.23 is the stable build. Forum thread titles seen in search results show experimental versions up to at least 2.1.23, but those threads could not be read.

## Blueprint-related changes

- **Verified.** Blueprints can be flipped. Drop-lane settings for machines and inserters that drop onto belts carry over when a blueprint is flipped, and the flip hotkey can change the lane. Pumpjacks and burner miners can now be flipped. Inserters always drop onto the input side of a splitter. Sources: [FFF #442 - Flip, Flow, and Fresh Paint](https://direct.factorio.com/blog/post/fff-442) and [FFF #449](https://factorio.com/blog/post/fff-449).
- Neither post mentions an API change. The JSON files are the authority for the API.

## Leads that are now resolved

These came from the changelog of a community library, [Factorio Standard Library 2.1 Continued](https://mods.factorio.com/mod/stdlib2-continued/changelog), and were checked against the 2.1.23 JSON:

- Recipe `category` is gone and `categories` (a list) replaces it. **Verified.**
- `helpers.write_file` exists, so file output lives on `helpers`. **Verified** that it exists in 2.1.23; when it moved there is unknown.
- Statistics getters take a surface argument (`LuaForce.get_item_production_statistics(surface)`). **Verified** in 2.1.23; when it changed is unknown.

## Checklist status

1. Shortcut prototype: done. The icon layout matches the official example (see the API reference); rendering is untested.
2. Shortcut click and chat command handling: done.
3. Blueprint API on item stacks and the entity format: done at the signature level. The actual in-game behavior is untested.
4. Reading recipes at runtime: done.
5. Machine and mining data: done.
6. Persistent state: **done.** Rules for `storage` and the load sequence are in [data-lifecycle.md](data-lifecycle.md).
7. GUI API: done for what the first slice uses (see the API reference). Style names were not read.
8. Quality and Space Age: done at the API level (quality fields exist and default to normal).

## Still unverified

- Confirmation in 2.1 that `base >= 2.1` and dotted `require("folder.file")` work. Both are Secondary only: the wiki tutorial for 2.0 uses these forms (see [modding-tutorial.md](modding-tutorial.md)). They will be confirmed the first time the mod loads in game.
- The contents of the `util` library and the `mod-gui` helper (the libraries page confirms `util` exists but not what is in it; see [lua-environment.md](lua-environment.md)).
- (Resolved) the shortcut display name: set `localised_name` on the prototype yourself, so no default locale section is needed.
- Anything about how blueprints behave in game: positioning and grid snapping rules, the effect of `fix_positions`, how the 16 directions are used for each entity. Test in game.
- What exactly the circuit Input/Output split changed.
