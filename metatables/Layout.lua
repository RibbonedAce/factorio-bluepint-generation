package.path = "../?.lua"

local util = require("util")
local Position = require("metatables.Position")


local Layout = {}
Layout.mt = {}

function Layout.new()
    local layout = {
        entities={}, 
        positions={}, 
        box={}, 
        item_input_positions={}, 
        item_output_positions={}, 
        fluid_input_positions={}, 
        fluid_output_positions={}, 
        num_entities=0,
        excluded_entities={}
    }
    setmetatable(layout, Layout.mt)

    layout.add = Layout.add
    layout.add_all = Layout.add_all
    layout.move = Layout.move
    layout.exclude_from_box = Layout.exclude_from_box

    return layout
end

function Layout.exclude_from_box(self, entity_name)
    self.excluded_entities[entity_name] = true
end

function Layout.add(self, entity)
    local m_direction = entity.direction or north

    local selection_box = prototypes.entity[entity.name].selection_box

    local box_dims = Position.from{
        math.ceil(math.abs(selection_box.left_top.x - selection_box.right_bottom.x)),
        math.ceil(math.abs(selection_box.left_top.y - selection_box.right_bottom.y))
    }

    if m_direction % 8 ~= 0 then
        box_dims = Position.from{box_dims.y, box_dims.x}
    end

    local planned_box = {
        {x=math.floor(entity.position.x + 0.5 - box_dims.x / 2), y=math.floor(entity.position.y + 0.5 - box_dims.y / 2)},
        {x=math.floor(entity.position.x + 0.5 + box_dims.x / 2), y=math.floor(entity.position.y + 0.5 + box_dims.y / 2)},
    }

    local new_positions = {}

    for x = planned_box[1].x, planned_box[2].x - 1 do
        for y = planned_box[1].y, planned_box[2].y - 1 do
            local new_position = tostring(Position.from{x, y})

            if self.positions[new_position] then
                local old_positions = self.entities[self.positions[new_position]]
                self.entities[self.positions[new_position]] = nil
                for _, position in ipairs(old_positions) do
                    self.positions[tostring(position)] = nil
                end
                self.num_entities = self.num_entities - 1
            end

            self.positions[new_position] = entity
            table.insert(new_positions, Position.from{x, y})
            
            if not self.excluded_entities[entity.name] then
                if not self.box.left_top then
                    self.box.left_top = Position.from{x, y}
                else
                    self.box.left_top.x = math.min(x, self.box.left_top.x)
                    self.box.left_top.y = math.min(y, self.box.left_top.y)
                end

                if not self.box.right_bottom then
                    self.box.right_bottom = Position.from{x, y}
                else
                    self.box.right_bottom.x = math.max(x, self.box.right_bottom.x)
                    self.box.right_bottom.y = math.max(y, self.box.right_bottom.y)
                end
            end
        end
    end

    self.entities[entity] = new_positions

    self.num_entities = self.num_entities + 1
end

function Layout.add_all(self, other)
    for other_entity, _ in pairs(other.entities) do
        self:add(other_entity)
    end

    self.item_input_positions = other.item_input_positions
    self.item_output_positions = other.item_output_positions
    self.fluid_input_positions = other.fluid_input_positions
    self.fluid_output_positions = other.fluid_output_positions
end

function Layout.move(self, displacement)
    self.positions = {}

    for entity, e_positions in pairs(self.entities) do
        entity.position = entity.position + displacement
        self.positions[tostring(entity.position)] = entity

        for i = 1, #e_positions do
            e_positions[i] = e_positions[i] + displacement
        end
    end

    self.box.left_top = self.box.left_top + displacement
    self.box.right_bottom = self.box.right_bottom + displacement

    for i = 1, #self.item_input_positions do
        self.item_input_positions[i] = self.item_input_positions[i] + displacement
    end

    for i = 1, #self.item_output_positions do
        self.item_output_positions[i] = self.item_output_positions[i] + displacement
    end

    for i = 1, #self.fluid_input_positions do
        self.fluid_input_positions[i] = self.fluid_input_positions[i] + displacement
    end

    for i = 1, #self.fluid_output_positions do
        self.fluid_output_positions[i] = self.fluid_output_positions[i] + displacement
    end
end

Layout.mt.__tostring = function(self)
    return "Layout(entities: " .. self.num_entities .. ", box: " .. serpent.block(self.box) .. ")"
end

return Layout