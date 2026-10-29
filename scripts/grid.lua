-- scripts/grid.lua
-- Converts between the two ways of saying where an entity is.
--
--   TILE:      the top-left tile the entity covers, as whole numbers. x grows to
--              the east and y grows to the south (down the page). A furnace that
--              covers tiles x 2 to 3 and y 0 to 1 is at tile (2, 0). This is how
--              the layout and the tests think.
--   POSITION:  the centre of the entity, which is what Factorio blueprints want.
--              That same furnace is at position (3, 1); a 1x1 belt on tile
--              (0, 0) is at position (0.5, 0.5).
--
-- The centre is the tile plus half the entity's size, so the "+ 0.5" lives here
-- and nowhere else. Sizes are in tiles and default to 1x1. Pure: no game access.

local grid = {}

-- The centre position of an entity whose top-left tile is (tile_x, tile_y).
function grid.position(tile_x, tile_y, width, height)
  return {x = tile_x + (width or 1) / 2, y = tile_y + (height or 1) / 2}
end

-- The top-left tile of an entity centred at `position`. The numbers are not whole
-- if the entity is not lined up with the tile grid.
function grid.top_left_tile(position, width, height)
  return {x = position.x - (width or 1) / 2, y = position.y - (height or 1) / 2}
end

return grid
