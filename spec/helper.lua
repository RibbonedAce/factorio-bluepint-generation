-- spec/helper.lua
-- Runs once before the specs (see .busted).
--
-- Factorio never loads this folder. The game's own tables are replaced by small
-- fakes, so these specs prove the logic is self-consistent, NOT that the game
-- accepts the result. Only loading the blueprint in Factorio proves that.
--
-- `defines` is faked here: real Factorio uses numbers, strings are enough and
-- make failures readable. Specs that need `prototypes` assign their own fake
-- (see spec/support/builders.lua).

-- `rawset(_G, ...)` instead of `_G.defines = ...`: the result is the same at run
-- time, but the editor does not take it as the declaration of `defines`, so it
-- keeps using Factorio's real types for the production code.
rawset(_G, "defines", {
  direction = {north = "north", east = "east", south = "south", west = "west"},
  wire_connector_id = {pole_copper = "pole_copper"},
})

require("spec.support.assertions")
