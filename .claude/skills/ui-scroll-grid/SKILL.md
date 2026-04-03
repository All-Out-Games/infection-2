---
name: ui-scroll-grid
description: Only for UI that requires grids or scrolling areas
---
> You MUST follow all instructions from the `ui` skill first.

### Grid_Layout

```csl
// .ELEMENT_COUNT: specify columns and rows
grid := UI.make_grid_layout(rect, 4, 6, .ELEMENT_COUNT, 8); // 4 cols, 6 rows, 8px padding
for item: items {
    UI.push_id("slot_%", {item});
    defer UI.pop_id();
    slot_rect := grid->next();
    if UI.button(slot_rect, bs, ts, item.name).clicked { }
}
```

Grids start top-left, advance right, then wrap down.

```csl
// .ELEMENT_SIZE: specify element dimensions, auto-wraps at edge
UI.make_grid_layout(rect, 100, 100, .ELEMENT_SIZE, 8); // 100x100 tiles
```

`next()` returns a `Rect` and updates position fields:
```csl
slot_rect := grid->next();
grid.index;   // linear index (0, 1, 2, ...)
grid.cur_x;   // column index
grid.cur_y;   // row index
```

`Grid_Layout` automatically expands scroll views when used inside one.

## Scroll Views

**The scroll bar area must be cut out BEFORE creating the scroll view**, or it corrupts the scrollable region bounds.

```csl
draw_scrollable_list :: proc(items: []string) {
    rect := UI.get_safe_screen_rect()->inset(50);

    scroll_bar_area := rect->cut_right(8)->inset(2); // cut BEFORE push_scroll_view

    settings: Scroll_View_Settings;
    settings.vertical = true;
    settings.horizontal = false;
    settings.clip_padding = {10, 10, 10, 10};

    sv := UI.push_scroll_view(rect, "my_scroll_view", settings); {
        defer UI.pop_scroll_view();

        content := sv.content_rect;
        ts := UI.default_text_settings();
        ts.size = 24;

        for i: 0..items.count-1 {
            item_rect := content->cut_top(40);
            UI.text(item_rect, ts, items[i]);
        }
    }

    scroll_bar_rect := sv->compute_scroll_bar_rect(scroll_bar_area);
    UI.quad(scroll_bar_area, core_globals.white_sprite, {0.025, 0.025, 0.025, 1});
    UI.quad(scroll_bar_rect, core_globals.white_sprite, {0.1, 0.1, 0.1, 1});
}
```
