# Mod structure and info.json rules

Source: the "Mod Structure" page (`lua-api.factorio.com/2.1.23/auxiliary/mod-structure.html`), pasted into the session by the owner on 2026-10-25, because the site refuses the assistant's fetch tool. The page's own examples still show `"factorio_version": "2.0"`, which is just a sample value. Labels: **Verified** means stated on that page.

## Folder naming (Verified)

- An unzipped mod folder must be named `{mod-name}_{version}` or just `{mod-name}`. For this mod: `blueprint-generation` or `blueprint-generation_0.0.1`.
- A zip must be named `{mod-name}_{version}`; the folder inside it can have any name.
- The name and version come from `info.json`.
- Consequence: a git clone folder named after the repository will NOT load as a mod unless the repository name is exactly `blueprint-generation`. To test in game, the owner needs a folder or link with the mod's name inside the Factorio mods folder.

## Files the game reads (Verified)

- `info.json` (the only mandatory file), `changelog.txt` (strict format), `thumbnail.png` (ideally 144x144 px).
- Settings stage: `settings.lua`, `settings-updates.lua`, `settings-final-fixes.lua`.
- Data stage: `data.lua`, `data-updates.lua`, `data-final-fixes.lua` (load order is explained on the Data Lifecycle page, which was not read).
- Runtime: `control.lua`.
- Folders: `locale/<language code>/*.cfg` (translations; `en` for English), `scenarios`, `campaigns`, `tutorials`, `migrations`.

## info.json fields (Verified)

| Field | Rule |
|---|---|
| `name` | Mandatory. The game accepts anything up to 100 characters. The mod portal wants alphanumerics, dashes and underscores, longer than 3 and shorter than 50 characters. |
| `version` | Mandatory. `number.number.number`, each part 0 to 65535. |
| `title` | Mandatory. At most 100 characters (the game rejects longer). A locale entry can override it. |
| `author` | Mandatory. Free text. The portal ignores it and shows the uploader. |
| `factorio_version` | Format `"number.number"` (major version only). A third number makes the portal reject the mod. A mod can match only one major version. |
| `dependencies` | Default `["base"]`. Each entry is `"<prefix> name <operator> <version>"`. Prefixes: `!` incompatible, `?` optional, `+` recommended, `(?)` hidden optional, `~` no effect on load order, none for a hard requirement. Operators: `<`, `<=`, `=`, `>=`, `>`. |
| `description` | Optional. Shown in the in-game mod browser. |
| `contact`, `homepage` | Optional. |
| `migrates_from` | Optional list of mod names. If one of those mods is removed, its saved data moves into this mod's `storage._migrated["mod-name"]`. |

Space Age feature flags (optional booleans, all default false): `quality_required`, `rail_bridges_required`, `spoiling_required`, `freezing_required`, `segmented_units_required`, `expansion_shaders_required`, `expansion_required`, `space_travel_required`. Setting one requires the player to own Space Age. This mod does not need any of them, so leave them unset.

## `storage` (Verified)

This page refers to "its storage table" and to `storage._migrated`. The rules for what it can hold and when it can be touched are in [data-lifecycle.md](data-lifecycle.md).

## Check of this repo's `info.json` against the page

- `name`, `version`, `title`, `author`: valid.
- `factorio_version: "2.1"`: matches the required `number.number` format.
- `dependencies: ["base >= 2.1"]`: matches the syntax. This page's version examples are three-part (`4.2.0`), but the wiki modding tutorial's own `info.json` uses a two-part version (`base >= 2.0`), see [modding-tutorial.md](modding-tutorial.md), so this is fine in practice (Secondary; confirm when the mod loads). Since the default is `["base"]`, the entry mostly duplicates what `factorio_version` already requires.
- No thumbnail or changelog yet. Both are optional for local testing and expected for publishing. The page says the thumbnail should be 144x144 px.
- A `locale/en/*.cfg` file will be needed for the shortcut's display name and any text the mod shows. The page confirms the folder layout but not the key names, so look those up before writing it.
