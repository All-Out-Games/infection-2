---
name: ui
description: "Any UI related work **MUST** reference this before you start."
---
## Core Principles

1. **Y grows upward** - (0, 0) is the bottom-left of the screen
2. **Start from screen rects** - `UI.get_safe_screen_rect()`
3. **Push/pop pattern** - Use `defer` for automatic cleanup of UI state
4. **Mobile-first** - Avoid hover effects
5. **Only ASCII** - No emoji support
6. UI (buttons, scroll views, etc.) **must** be drawn inside the player's `ao_late_update` function.

```csl
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
        // Must wrap all UI with this->is_local_or_server to ensure it doesn't render for other clients.  
        if this->is_local_or_server() {
            draw_my_hud(this);
        }
    }
}

draw_my_hud :: proc(player: Player) {
    rect := UI.get_safe_screen_rect()->bottom_right_rect()->grow(40, 100, 40, 100)->offset(-50, 50);
    bs := UI.default_button_settings();
    ts := UI.default_text_settings();

    if UI.button(rect, bs, ts, "Action").clicked {
        // This click will be detected properly because we're in the player's update
        do_action(player);
    }
}
```

## Basic Drawing

### Quads and Images
```csl
draw_ui :: proc() {
    rect := UI.get_screen_rect()->center_rect()->grow(100); // 200x200 quad in center of screen
    texture := get_asset(Texture_Asset, "my_icon.png");
    UI.quad(rect, texture);

    // With color tint (RGBA, values 0-1)
    UI.quad(rect, texture, {1, 0, 0, 0.5});

    // Using the white sprite for solid colors
    UI.quad(rect, core_globals.white_sprite, {0, 0, 0, 0.75});
}
```

### Text
```csl
draw_text :: proc() {
    rect := UI.get_screen_rect()->center_rect()->grow(200, 300, 50, 300);

    // Get default text settings and customize
    ts := UI.default_text_settings();
    ts.size = 48;
    ts.color = {1, 1, 1, 1};
    ts.halign = .CENTER;
    ts.valign = .CENTER;

    UI.text(rect, ts, "Hello, World!");

    score := 1500;
    UI.text(rect, ts, "Score: %", {score});

    // Percentages
    // `%%` to insert a literal '%'
    pct := 67;
    UI.text(rect, ts, "% %%", {pct}); // "67 %"

    // text_sync returns the actual rendered rect (useful for dynamic layouts)
    actual_rect := UI.text_sync(rect, ts, "Dynamic text");
}
```

### Text_Settings Fields
```csl
ts := UI.default_text_settings();

ts.font = get_asset(Font_Asset, "$AO/fonts/Barlow-Black.ttf");
ts.size = 32;
ts.color = {1, 1, 1, 1};

// Alignment
ts.valign = .CENTER;  // .TOP, .CENTER, .BOTTOM
ts.halign = .CENTER;  // .LEFT, .CENTER, .RIGHT
ts.offset = {x, y};

ts.do_outline = true;
ts.outline_thickness = 3;
ts.outline_color = {0, 0, 0, 1};

ts.do_drop_shadow = true;
ts.drop_shadow_offset = {1, -1};
ts.drop_shadow_color = {0, 0, 0, 1};

ts.word_wrap = true;
ts.overflow_wrap = false;
ts.word_wrap_start_offset = 0;

ts.spacing_multiplier = 1;
ts.line_height_multiplier = 1;

// Auto-fit (shrink text to fit rect)
ts.do_autofit = true;
ts.autofit_min_size = 12;
ts.autofit_max_size = 48;
ts.autofit_iters = 4;
```

> If you want to draw left or right aligned text in a button (common for a list of selectable items), you should set `ts.offset.x` to push the text away from the edge of the button. 

## UI Layouting
NEVER create rects from scratch for screen UI. Always derive from screen rects or other rects:

```csl
layout_example :: proc() {
    // Start from screen rect (full screen) or safe rect (avoids notches/safe areas)
    screen := UI.get_screen_rect();
    safe := UI.get_safe_screen_rect();

    // Get specific positions
    center := screen->center_rect(); // 0x0 rect at center
    top_left := screen->top_left_rect(); // 0x0 rect at top-left
    bottom_right := screen->bottom_right_rect(); // 0x0 rect at bottom-right
    left := screen->left_rect(); // 0x<height> rect along left edge
    top := screen->top_rect(); // <width>x0 rect along top edge

    // Grow from a point (top, right, bottom, left)
    button_rect := center->grow(50, 150, 50, 150);
    // *Will be multiplied by the current scale factor, see unscaled section when you need to work with exact pixels).

    // Or grow uniformly
    icon_rect := center->grow(64); // 128x128 square at center (this will be scaled so it might not be exactly 128x128)
}
```

### Rect Manipulation
```csl
Rect :: struct {
    min: v2;
    max: v2;
}
```

```csl
rect_demo :: proc() {
    rect := UI.get_screen_rect();

    // Inset (shrink) - values are scaled by UI scale factor
    rect->inset(top, right, bottom, left);
    rect->inset(15); // all sides equally

    // Grow (expand)
    rect->grow(top, right, bottom, left);
    rect->grow(15);

    // Cut (removes from edge and returns the cut portion) very useful for layouts like headers
    header := rect->cut_top(60); // Returns 60px from top, rect is now smaller
    footer := rect->cut_bottom(40);
    sidebar := rect->cut_left(200);

    // Offset (move without changing size)
    rect->offset(10, -20); // Move right 10, down 20

    // Scale (multiply dimensions)
    rect->scale(0.5, 0.5); // Half size
    rect->scale(2, 1); // Double width

    // Slide (move by percentage of own size)
    rect->slide(0.5, 0); // Move right by half its width
    rect->slide(0, -1); // Move down by its full height

    // Fit aspect ratio (for icons/images)
    icon := get_asset(Texture_Asset, "my_icon.png");
    rect->fit_aspect(icon->get_aspect());

    // Only use subrect for percentage based fills.
    left_half := rect->subrect(0, 0, 0.5, 1); // x1, y1, x2, y2

    // Get dimensions
    w := rect->width();
    h := rect->height();

    // Get points
    c := rect->center();
    tl := rect->top_left();
    br := rect->bottom_right();

    // Get rects
    tl := rect->top_left_rect(); // 0x0 rect at top left
    c := rect->center_rect(); // 0x0 rect at center
    r := rect->right_rect(); // 0x<height> rect along right side
    b := rect->bottom_rect(); // <width>x0 rect along bottom
}
```

### Edge Rects vs Point Rects
**Important:** `left_rect()`, `right_rect()`, `top_rect()`, and `bottom_rect()` return **line-shaped rects** (one dimension is zero, the other is the full width/height). If you `grow()` from these, the result will be **rectangular, not square**.

```csl
// WRONG: Creates a tall rectangle (e.g. 40x80) because left_rect() has full height
button := slider->left_rect()->grow(20)->offset(20, 0);

// CORRECT: Use a point rect like left_center_rect() to grow into a square
button := slider->left_center_rect()->grow(20)->offset(20, 0);
```

### Auto-scaling
The default versions of all the rect functions automatically multiply by UI.get_current_scale_factor() which is `user_screen_height / 1080.0`. This makes everything scale nicely regardless of resolution and aspect ratio.

This means that if you do:
```csl
rect := UI.get_screen_rect()->center_rect()->grow(100, 200, 100, 200);
log_info("% %", {rect->width(), rect->height()});
```

this will not print "400 200" unless the monitor is 1080 pixels tall. A common case where this can go wrong is if you do this:

```csl
rect := UI.get_screen_rect()->center_rect()->grow(100, 200, 100, 200);
left_half := rect->cut_left(rect->width() / 2);
right_half := rect;
```

because `cut_left()` takes a "pixels if 1080p" value, but `width()` returns "exact pixels" then `left_half` will be wider than `right_half` if the monitor is taller than 1080, and `right_half` will be wider if it is shorter.

To cut/inset/grow/offset by exact pixels, use the `_unscaled` variants of the rect functions:

```csl
layout_with_unscaled :: proc(window_rect: Rect) {
    list_element_base := window_rect->top_rect()->grow_bottom(20); // 20 unit tall rect across the top

    for item: items {
        item_rect := list_element_base;
        draw_item(item_rect, item);

        // WRONG: This would not move down the right amount if scale factor != 1
        list_element_base = list_element_base->offset(0, list_element_base->height());

        // CORRECT: Use unscaled when using exact pixel values
        list_element_base = list_element_base->offset_unscaled(0, list_element_base->height());
    }
}
```
Available unscaled functions:
- `offset_unscaled`, `inset_unscaled`, `grow_unscaled`
- `cut_top_unscaled`, `cut_right_unscaled`, `cut_bottom_unscaled`, `cut_left_unscaled`

If you need to mix scaled and unscaled:
```csl
half_parent_height := parent->height() / 2;
// grow_unscaled() the height first, then grow() the width
rect := parent->center_rect()->grow_unscaled(half_parent_height, 0, half_parent_height, 0)->grow(0, 8, 0, 8);
```

### Cutting
The cut functions **MUST** be used for layouting. `cut` snips a portion off of a rect and then return that snipped portion.

```csl
rect := UI.get_screen_rect()->bottom_right_rect()->grow(100, 100, 0, 0); // 100x100 rect in the bottom right of the screen
b := rect->cut_bottom(25); // cut 25 off the bottom of `rect` and store it in `b`
// rect is now {(0, 25), (100, 100)}
// b is now {(0, 0), (100, 25)}
```

`a->cut()` will modify `a` and return the region that was snipped off.

### Avoid Overlapping Elements

When placing multiple UI elements horizontally or vertically, **use the cut pattern** to allocate space sequentially rather than positioning elements relative to the same rect.

- `cut_left`, `cut_right`, `cut_top`, `cut_bottom` remove space from a rect and return the removed portion
- This guarantees elements don't overlap because space is removed as you allocate it
- Never position multiple elements using `left_rect()`, `right_rect()`, `center_rect()` etc. on the same rect if they could overlap - use cuts instead

### Directional_Layout
Use `Directional_Layout` for laying out a sequence of variable-sized elements in a single direction (toolbars, button rows, stacked panels):

```csl
draw_toolbar :: proc() {
    // Layout buttons from left to right
    layout := UI.make_directional_layout(rect, .RIGHT); // direction can be RIGHT, LEFT, UP, DOWN

    if UI.button(layout->next(80), bs, ts, "Save").clicked {
    }
    if UI.button(layout->next(80), bs, ts, "Load").clicked {
    }
    if UI.button(layout->next(120), bs, ts, "Settings").clicked {
    }
}
```

The `next(size)` method cuts `size` pixels from the layout direction and returns that rect.

There is also `next_unscaled(size)` for when you want "exact pixels".

## Buttons

```csl
draw_buttons :: proc(player: Player) {
    rect := UI.get_safe_screen_rect()->bottom_center_rect()->grow(40, 150, 40, 150)->offset(0, 100);

    bs := UI.default_button_settings();
    ts := UI.default_text_settings();

    bs.sprite = get_asset(Texture_Asset, "$AO/new/modal/buttons_2/button_2.png"); // Green button
    bs.color = {1, 1, 1, 1};
    bs.hovered_color = {0.9, 0.9, 0.9, 1};
    bs.pressed_color = {0.7, 0.7, 0.7, 1};
    bs.press_scaling = 0.35; // 0.35-0.5 is a good range for this

    result := UI.button(rect, bs, ts, "Click Me!");

    if result.clicked {
        log_info("Button was clicked!");
    }

    if result.active {
        log_info("Button is being held");
    }
}
```

### Button_Settings Fields

```csl
bs := UI.default_button_settings();

// Colors apply to both the sprite and the text of a button
bs.color = {1, 1, 1, 1};
bs.hovered_color = {0.7, 0.7, 0.7, 1};
bs.pressed_color = {0.45, 0.45, 0.45, 1};
bs.disabled_color = {0.25, 0.25, 0.25, 1};
bs.color_multiplier = {1, 1, 1, 1};         // Applied to all states
bs.background_color_multiplier = {1, 1, 1, 1}; // Applied just to the sprite, not the text

// Sprites
bs.sprite = get_asset(Texture_Asset, "$AO/new/modal/buttons_2/button_2.png");
bs.sprite_padding = {10, 10, 10, 10}; // Optional padding inside sprite

// Animation
bs.press_scaling = 0.35;
bs.hover_offset = {0, 2};
bs.text_pressed_offset = {0, -2};
bs.text_unpressed_offset = {0, 0};

// Sound
bs.click_sound = get_asset(SFX_Asset, "$AO/click.wav");
bs.click_sound_speed = 1;

// Behavior
bs.stay_hot_while_active = false;
bs.return_to_center_to_cancel = false;
```

### Interact_Result Fields

```csl
result := UI.button(rect, bs, ts, "Button");
result.pressed;

// Useful rects
result.rect;            // The button's rect (may be scaled)
result.mouse_position;  // Current mouse position
result.ui_scale;        // Current UI scale factor
```

### Begin/End Button Pattern
For buttons with custom content:

```csl
draw_custom_button :: proc() {
    rect := UI.get_screen_rect()->center_rect()->grow(75, 100, 75, 100);
    bs := UI.default_button_settings();
    ts := UI.default_text_settings();

    // EVERYTHING in a button will be multiplied by the button color so if you
    // do bs.color = {0.1, 0.1, 0.1, 1} trying to just get a dark button, the text
    // and icons below will also be darker which is usually undesirable. use
    // `bs.background_color_multiplier` instead to configure button background color

    result := UI.begin_button(rect, bs, ts, ""); {
        defer UI.end_button();

        // Draw custom content inside the button
        content_rect := result.rect->inset(10);
        text_rect := content_rect->cut_bottom(40);  // Take 40px from bottom for text
        icon_rect := content_rect;  // Remaining space for icon

        icon := get_asset(Texture_Asset, "$AO/icon.png");
        UI.quad(icon_rect->fit_aspect(icon->get_aspect()), icon);

        ts.size = 24;
        UI.text(text_rect, ts, "Custom");
    }

    if result.clicked {
        // Handle click
    }
}
```

## Button Asset Paths
You must use one of these sprites when drawing buttons:
- `"$AO/new/modal/buttons_2/button_1.png"` - Orange
- `"$AO/new/modal/buttons_2/button_2.png"` - Green
- `"$AO/new/modal/buttons_2/button_3.png"` - Red
- `"$AO/new/modal/buttons_2/button_5.png"` - Blue
- `"$AO/new/modal/buttons_2/button_7.png"` - Pink
- `"$AO/new/modal/buttons_2/button_8.png"` - Grey
- `"$AO/new/modal/buttons_2/button_9.png"` - White

## UI State Management

### Push/Pop Pattern with Defer
Use `defer` to ensure proper cleanup:

```csl
draw_layered_ui :: proc() {
    // Drawing context
    UI.push_screen_draw_context();
    defer UI.pop_draw_context();

    // Layers (higher = drawn on top)
    UI.push_layer(100);
    defer UI.pop_layer();

    // Or relative layers
    UI.push_layer_relative(10);
    defer UI.pop_layer();

    // Z depth (for 3D sorting)
    UI.push_z(5.0);
    defer UI.pop_z();

    // Scale factor
    UI.push_scale_factor(1.5);
    defer UI.pop_scale_factor();

    // Color multiplier
    UI.push_color_multiplier({1, 1, 1, 0.5}); // 50% transparent
    defer UI.pop_color_multiplier();

    // Disabled state
    UI.push_disabled(true);
    defer UI.pop_disabled();

    // Custom material
    UI.push_material(my_material);
    defer UI.pop_material();

    // Matrix transform
    matrix := Matrix4.rotate(45, {0, 0, 1});
    UI.push_matrix(matrix);
    defer UI.pop_matrix();

    // Draw your UI here...
}
```

### UI IDs

When drawing multiple similar elements (like list or buttons), you must push unique IDs:

```csl
draw_list :: proc(items: []Item) {
    rect := UI.get_safe_screen_rect()->inset(20);
    bs := UI.default_button_settings();
    ts := UI.default_text_settings();

    for i: 0..items.count-1 {
        UI.push_id("item_%", {i});  // Unique ID for each button
        defer UI.pop_id();

        item_rect := rect->cut_top(60);
        if UI.button(item_rect, bs, ts, items[i].name).clicked {
            select_item(i);
        }
    }
}
```

## World Space UI
> For UI that exists in the game world (health bars, name tags, etc.):

**Use meters for world space UI sizing. If you use regular units text and other items will be MASSIVE.**

```csl
draw_world_ui :: proc(entity: Entity) {
    UI.push_world_draw_context();
    defer UI.pop_draw_context();

    // In world space, units are in meters (character is ~1 meter tall. ~1.5 with nameplate above head)
    pos := entity.world_position;

    // Push Z for proper depth sorting
    UI.push_z(pos.y);
    defer UI.pop_z();

    // Draw a health bar above the entity
    bar_pos := pos + v2{0, 1.5}; // 1.5 meters above
    bar_rect := Rect{bar_pos, bar_pos}->grow(0.1, 0.5, 0.1, 0.5);

    // Background
    UI.quad(bar_rect, core_globals.white_sprite, {0, 0, 0, 0.8});

    // Fill - subrect is appropriate here for percentage-based width
    health_pct := entity.health / entity.max_health;
    fill_rect := bar_rect->inset(0.02)->subrect(0, 0, health_pct, 1);
    fill_color := lerp(v4{1, 0, 0, 1}, {0, 1, 0, 1}, health_pct);
    UI.quad(fill_rect, core_globals.white_sprite, fill_color);
}
```

### Coordinate Conversion

```csl
// Convert world position to screen position
screen_pos := world_to_screen(entity.world_position);

// Convert screen position to world position
world_pos := screen_to_world(get_mouse_screen_position());
```
### Animation with Easing

```csl
draw_animated_element :: proc(show_t: float) {
    // Ease the transition
    t := Ease.out_back(show_t);

    // Slide in from bottom
    offset_y := lerp(-200.0, 0.0, t);
    alpha := t;

    rect := UI.get_screen_rect()->bottom_center_rect()->grow(50, 150, 50, 150)->offset(0, 100 + offset_y);

    UI.push_color_multiplier({1, 1, 1, alpha});
    defer UI.pop_color_multiplier();

    UI.quad(rect, core_globals.white_sprite, {0.2, 0.2, 0.2, 0.9});
}
```

## Common Sizes
Unless otherwise specified, you must use these sizes for text and rects:

- Text
    - Title: 52
    - Body: 36
    - World space text 0.30
- Rects
    - Simple dialog: 600x400
    - Standard button: 210x74
    - Exit button: 65x65

## Best Practices

1. **Always use defer for push/pop pairs** - Prevents state leaks
2. **Push IDs for repeated elements** - Ensures correct interaction tracking
3. **Use unscaled functions when using computed dimensions** - Prevents double-scaling
4. **Fit aspect ratio for icons** - Prevents stretched images: `rect->fit_aspect(texture->get_aspect())`
5. **Check is_local_or_server() before drawing interactive UI like buttons** - Prevents UI showing for wrong players