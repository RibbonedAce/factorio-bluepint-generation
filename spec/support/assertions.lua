-- spec/support/assertions.lua
-- Custom assertions for busted's `assert`, for things luassert does not have.
-- Loaded by spec/helper.lua. Argument order follows luassert: expected first.
--
--     assert.has_item_containing("overlaps", problems)
--     assert.is_not.has_item_containing("overlaps", problems)

local assert = require("luassert")
local say = require("say")

-- A list in which at least one string contains `text` (plain text, not a pattern).
local function has_item_containing(_, arguments)
  local text, list = arguments[1], arguments[2]
  if type(text) ~= "string" or type(list) ~= "table" then
    return false
  end
  for _, item in ipairs(list) do
    if type(item) == "string" and item:find(text, 1, true) then
      return true
    end
  end
  return false
end

say:set("assertion.has_item_containing.positive", "Expected a list with an item containing:\n%s\nbut the list was:\n%s")
say:set("assertion.has_item_containing.negative", "Expected a list with NO item containing:\n%s\nbut the list was:\n%s")
assert:register("assertion", "has_item_containing", has_item_containing,
  "assertion.has_item_containing.positive", "assertion.has_item_containing.negative")
