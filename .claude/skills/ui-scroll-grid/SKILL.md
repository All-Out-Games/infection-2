---
name: ui-scroll-grid
description: Only for UI that requires grids or scrolling areas 
---
> Note, you MUST follow all instructions from the `ui` skill carefully first. 

### Grid_Layout
Use `Grid_Layout` for laying out a grid of equally-sized elements (inventory slots, card grids, icon grids):

```csl
// Create a 4x6 grid (4 columns, 6 rows) from element count, 8px padding
grid := UI.make_grid_layout(rect, 4, 6, .ELEMENT_COUNT, 8);
for item: items {
    UI.push_id("slot_%", {item});
    defer UI.pop_id();
    slot_rect := grid->next();
    if UI.button(slot_rect, bs, ts, item.name).clicked {
        select_item(i);
    }
}
```

Grids always start at the top left and advance to the right, then down when we hit the right edge.

There is also `.ELEMENT_SIZE` for the `make()` size source.

```csl
// 100x100 tiles. It'll go to next row as needed when we hit the edge
UI.make_grid_layout(rect, 100, 100, .ELEMENT_SIZE, 8);
```

The `next()` method returns a `Rect` and updates the grid's position fields:

```csl
slot_rect := grid->next();  // Returns the rect for this element (with padding applied)
grid.index;                 // Linear index (0, 1, 2, ...)
grid.cur_x;                 // Column index (0 to elements_per_row-1)
grid.cur_y;                 // Row index (0, 1, 2, ...)
```

`Grid_Layout` automatically expands scroll views when used inside one.

## Scroll Views

For scrollable content:

```csl
draw_scrollable_list :: proc(items: []string) {
    rect := UI.get_safe_screen_rect()->inset(50);

    scroll_bar_area := rect->cut_right(8)->inset(2);

    settings: Scroll_View_Settings;
    settings.vertical = true;
    settings.horizontal = false;
    settings.clip_padding = {10, 10, 10, 10};

    sv := UI.push_scroll_view(rect, "my_scroll_view", settings); {
        defer UI.pop_scroll_view();

        // Use sv.content_rect for laying out content
        content := sv.content_rect;
        ts := UI.default_text_settings();
        ts.size = 24;

        for i: 0..items.count-1 {
            item_rect := content->cut_top(40);
            UI.text(item_rect, ts, items[i]);
        }
    }

    scroll_bar_rect := sv->compute_scroll_bar_rect(scroll_bar_area);

    UI.quad(scroll_bar_area,   core_globals.white_sprite, {0.025, 0.025, 0.025, 1});
    UI.quad(scroll_bar_rect,   core_globals.white_sprite, {0.1, 0.1, 0.1, 1});
}
```

Note that the scroll bar MUST NOT be in the scroll view content or it will mess up the bounds of the scrollable region. Always cut the scroll area out first and then make the scroll view.
