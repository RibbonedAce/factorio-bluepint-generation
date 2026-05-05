local styles = data.raw["gui-style"].default

styles.bpgn_header = {
    type = "horizontal_flow_style",
    parent = "frame_header_flow",
    vertically_stretchable = "off"
}

styles.bpgn_title = {
    type = "label_style",
    parent = "frame_title",
    bottom_padding = 3,
    top_padding = -3,
    vertically_stretchable = "on",
    horizontally_squashable = "on"
}

styles.bpgn_header_filler = {
    type = "empty_widget_style",
    parent = "draggable_space_header",
    height = 24,
    natural_height = 24,
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    right_margin = 4
}

styles.bpgn_footer_filler = {
    type = "empty_widget_style",
    parent = "draggable_space",
    horizontally_stretchable = "on",
    vertically_stretchable = "on"
}

data:extend({
    {
      type = "shortcut",
      name = "blueprint-generation",
      action = "lua",
      localised_name = {"bpgn.shortcut_name"},
      style = "blue",
      icon = "__blueprint-generation__/graphics/icons/shortcut-toolbar/mip/blueprint-generation-x56.png",
      icon_size = 56,
      small_icon = "__blueprint-generation__/graphics/icons/shortcut-toolbar/mip/blueprint-generation-x24.png",
      small_icon_size = 24
    }
})