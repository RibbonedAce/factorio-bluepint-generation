-- scripts/config.lua
-- Everything the generator hardcodes for now, kept in one place. Later
-- iterations will replace these constants with choices made from the
-- player's research and settings.
--
-- A file that ends with `return <value>` is a "module": `require` runs the file
-- once and hands that value to whoever asked for it.

return {
  -- The first-tier building blocks used in every blueprint.
  entities = {
    belt = "transport-belt",
    inserter = "inserter",
    pole = "small-electric-pole",
  },

  -- What can be generated: the product item, and how it is made.
  -- `recipe` and `machine` are prototype names; `fuel` is the item the machine burns.
  products = {
    ["iron-plate"] = {recipe = "iron-plate", machine = "stone-furnace", fuel = "coal"},
    ["copper-plate"] = {recipe = "copper-plate", machine = "stone-furnace", fuel = "coal"},
  },
}
