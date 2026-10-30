-- spec/grid_spec.lua
-- A tile is the top-left tile an entity covers; a position is its centre.
-- The expected numbers are written out by hand, so a mistake in grid.lua cannot
-- hide behind the same mistake elsewhere.
---@diagnostic disable: undefined-field  -- luassert's `assert` has fields (`assert.are`, `assert.is_nil`, ...) the editor cannot see

local grid = require("scripts.grid")

describe("grid", function()
  describe("position", function()
    it("puts a 1x1 entity on tile (0, 0) half a tile in from each edge", function()
      local position = grid.position(0, 0)

      assert.are.same({x = 0.5, y = 0.5}, position)
    end)

    it("keeps a 1x1 entity further along half a tile from its tile's corner", function()
      local position = grid.position(4, 7)

      assert.are.same({x = 4.5, y = 7.5}, position)
    end)

    it("centres a 2x2 entity on tile (2, 0) on the corner shared by its four tiles", function()
      local position = grid.position(2, 0, 2, 2)

      assert.are.same({x = 3, y = 1}, position)
    end)

    it("centres a 3x3 entity a tile and a half in", function()
      local position = grid.position(10, 20, 3, 3)

      assert.are.same({x = 11.5, y = 21.5}, position)
    end)

    it("centres a 1x2 entity half a tile across and a tile down", function()
      local position = grid.position(1, 1, 1, 2)

      assert.are.same({x = 1.5, y = 2}, position)
    end)

    it("works the same way for negative tiles", function()
      local position = grid.position(-3, -1)

      assert.are.same({x = -2.5, y = -0.5}, position)
    end)
  end)

  describe("top_left_tile", function()
    it("finds tile (0, 0) for a 1x1 entity centred at (0.5, 0.5)", function()
      local tile = grid.top_left_tile({x = 0.5, y = 0.5})

      assert.are.same({x = 0, y = 0}, tile)
    end)

    it("finds tile (2, 0) for a 2x2 entity centred at (3, 1)", function()
      local tile = grid.top_left_tile({x = 3, y = 1}, 2, 2)

      assert.are.same({x = 2, y = 0}, tile)
    end)

    it("gives a tile with a fraction for an entity centred off the grid", function()
      local tile = grid.top_left_tile({x = 1.25, y = 0.5})

      assert.are.same({x = 0.75, y = 0}, tile)
    end)

    it("gives back the same tile after converting to a position and back, for any size", function()
      local position = grid.position(6, 9, 3, 2)

      local tile = grid.top_left_tile(position, 3, 2)

      assert.are.same({x = 6, y = 9}, tile)
    end)
  end)
end)
