---
name: ui
description: "Any UI related work **MUST** reference this before you start."
---
## Core Principles

1. **Y grows upward** - (0, 0) is bottom-left of screen
2. **NEVER create rects from scratch** - Always derive from `UI.get_safe_screen_rect()` or `UI.get_screen_rect()`
3. **Push/pop pattern** - Use `defer` for cleanup
4. **Mobile-first** - No hover effects
5. **Only ASCII** - No emoji support
6. UI **must** be drawn inside the player's `ao_late_update`, wrapped in `is_local_or_server()`

```csl
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
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
        do_action(player);
    }
}
```

## Basic Drawing

### Quads and Images
```csl
rect := UI.get_screen_rect()->center_rect()->grow(100);
texture := get_asset(Texture_Asset, "my_icon.png");
UI.quad(rect, texture);
UI.quad(rect, texture, {1, 0, 0, 0.5}); // color tint RGBA 0-1
UI.quad(rect, core_globals.white_sprite, {0, 0, 0, 0.75}); // solid color
```

### Text
```csl
rect := UI.get_screen_rect()->center_rect()->grow(200, 300, 50, 300);
ts := UI.default_text_settings();
ts.size = 48;
ts.color = {1, 1, 1, 1};
ts.halign = .CENTER;  // .LEFT, .CENTER, .RIGHT
ts.valign = .CENTER;  // .TOP, .CENTER, .BOTTOM

UI.text(rect, ts, "Hello, World!");

score := 1500;
UI.text(rect, ts, "Score: %", {score}); // format with %
UI.text(rect, ts, "67 %%"); // literal % via %%

// text_sync returns the actual rendered rect (useful for dynamic layouts)
actual_rect := UI.text_sync(rect, ts, "Dynamic text");
```

### Text_Settings Fields
```csl
ts := UI.default_text_settings();
ts.font = get_asset(Font_Asset, "$AO/fonts/Barlow-Black.ttf");
ts.size = 32;
ts.color = {1, 1, 1, 1};
ts.valign = .CENTER;
ts.halign = .CENTER;
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

> For left/right aligned text in a button, set `ts.offset.x` to push text away from the edge.

## Rect Manipulation

```csl
Rect :: struct { min: v2; max: v2; }
```

All rect methods that take pixel values are **auto-scaled** by `UI.get_current_scale_factor()` (`user_screen_height / 1080.0`). Values represent "pixels at 1080p". Use `_unscaled` variants for exact pixels.

```csl
rect := UI.get_screen_rect();

// Inset/Grow (top, right, bottom, left) or uniform
rect->inset(top, right, bottom, left);
rect->inset(15);
rect->grow(top, right, bottom, left);
rect->grow(15);

// Cut - removes from edge, returns the cut portion, modifies original
header := rect->cut_top(60);
footer := rect->cut_bottom(40);
sidebar := rect->cut_left(200);

// Movement
rect->offset(10, -20);
rect->slide(0.5, 0); // move by percentage of own size

// Scale dimensions
rect->scale(0.5, 0.5);

// Fit aspect ratio for images
rect->fit_aspect(texture->get_aspect());

// Percentage-based subdivision
left_half := rect->subrect(0, 0, 0.5, 1); // x1, y1, x2, y2

// Dimensions and points
w := rect->width();  h := rect->height();
c := rect->center(); tl := rect->top_left(); br := rect->bottom_right();

// Point rects (0x0) - grow into usable rects
tl := rect->top_left_rect();
c := rect->center_rect();
// Also: bottom_left_rect, bottom_right_rect, top_right_rect, left_center_rect, right_center_rect, top_center_rect, bottom_center_rect

// Edge rects (one dimension is full width/height, other is 0)
r := rect->right_rect();  // 0 x height
b := rect->bottom_rect(); // width x 0
// Also: left_rect, top_rect
```

### Edge Rects vs Point Rects

`left_rect()`, `right_rect()`, `top_rect()`, `bottom_rect()` return **line-shaped rects** (one dimension is zero, the other is full width/height). Use point rects like `left_center_rect()` when you need to grow into a square.

```csl
// Use a point rect to grow into a square
button := slider->left_center_rect()->grow(20)->offset(20, 0);
```

### Auto-scaling Gotcha

`cut/inset/grow/offset` take "pixels at 1080p" values (scaled), but `width()/height()` return exact pixels. Mixing them causes bugs:

```csl
rect := UI.get_screen_rect()->center_rect()->grow(100, 200, 100, 200);
// cut_left takes scaled value, but width() returns exact pixels - mismatch!
left_half := rect->cut_left(rect->width() / 2); // WRONG proportions unless at 1080p
```

Use `_unscaled` variants when working with computed pixel values:

```csl
list_element_base := window_rect->top_rect()->grow_bottom(20);
for item: items {
    item_rect := list_element_base;
    draw_item(item_rect, item);
    list_element_base = list_element_base->offset_unscaled(0, -list_element_base->height());
}
```

Available unscaled: `offset_unscaled`, `inset_unscaled`, `grow_unscaled`, `cut_top_unscaled`, `cut_right_unscaled`, `cut_bottom_unscaled`, `cut_left_unscaled`

Mixing scaled and unscaled:
```csl
half_parent_height := parent->height() / 2;
rect := parent->center_rect()->grow_unscaled(half_parent_height, 0, half_parent_height, 0)->grow(0, 8, 0, 8);
```

### Cutting for Layout

Use cuts to allocate space sequentially and prevent overlapping:

```csl
rect := UI.get_screen_rect()->bottom_right_rect()->grow(100, 100, 0, 0);
b := rect->cut_bottom(25); // b = bottom 25px, rect shrinks
// rect is now {(0, 25), (100, 100)}, b is {(0, 0), (100, 25)}
```

### Directional_Layout

For laying out variable-sized elements in a single direction:

```csl
layout := UI.make_directional_layout(rect, .RIGHT); // .RIGHT, .LEFT, .UP, .DOWN
if UI.button(layout->next(80), bs, ts, "Save").clicked { }
if UI.button(layout->next(80), bs, ts, "Load").clicked { }
if UI.button(layout->next(120), bs, ts, "Settings").clicked { }
// next_unscaled(size) for exact pixels
```

## Buttons

```csl
rect := UI.get_safe_screen_rect()->bottom_center_rect()->grow(40, 150, 40, 150)->offset(0, 100);
bs := UI.default_button_settings();
ts := UI.default_text_settings();
bs.sprite = get_asset(Texture_Asset, "$AO/new/modal/buttons_2/button_2.png");
bs.press_scaling = 0.35;

result := UI.button(rect, bs, ts, "Click Me!");
if result.clicked { }
if result.active { } // being held
```

### Button_Settings Fields

```csl
bs := UI.default_button_settings();
bs.color = {1, 1, 1, 1};
bs.hovered_color = {0.7, 0.7, 0.7, 1};
bs.pressed_color = {0.45, 0.45, 0.45, 1};
bs.disabled_color = {0.25, 0.25, 0.25, 1};
bs.color_multiplier = {1, 1, 1, 1};           // applied to all states (sprite + text)
bs.background_color_multiplier = {1, 1, 1, 1}; // applied only to sprite, not text

bs.sprite = get_asset(Texture_Asset, "$AO/new/modal/buttons_2/button_2.png");
bs.sprite_padding = {10, 10, 10, 10};

bs.press_scaling = 0.35;
bs.hover_offset = {0, 2};
bs.text_pressed_offset = {0, -2};
bs.text_unpressed_offset = {0, 0};

bs.click_sound = get_asset(SFX_Asset, "$AO/click.wav");
bs.click_sound_desc.speed = 1;

bs.stay_hot_while_active = false;
bs.return_to_center_to_cancel = false;
```

### Interact_Result Fields

```csl
result := UI.button(rect, bs, ts, "Button");
result.pressed;
result.rect;
result.mouse_position;
result.ui_scale;
```

### Begin/End Button (Custom Content)

```csl
result := UI.begin_button(rect, bs, ts, ""); {
    defer UI.end_button();

    // WARNING: bs.color multiplies ALL content inside the button (text, icons).
    // Use bs.background_color_multiplier to tint only the button background.

    content_rect := result.rect->inset(10);
    text_rect := content_rect->cut_bottom(40);
    icon_rect := content_rect;

    icon := get_asset(Texture_Asset, "$AO/icon.png");
    UI.quad(icon_rect->fit_aspect(icon->get_aspect()), icon);

    ts.size = 24;
    UI.text(text_rect, ts, "Custom");
}
if result.clicked { }
```

## Button Asset Paths

- `"$AO/new/modal/buttons_2/button_1.png"` - Orange
- `"$AO/new/modal/buttons_2/button_2.png"` - Green
- `"$AO/new/modal/buttons_2/button_3.png"` - Red
- `"$AO/new/modal/buttons_2/button_5.png"` - Blue
- `"$AO/new/modal/buttons_2/button_7.png"` - Pink
- `"$AO/new/modal/buttons_2/button_8.png"` - Grey
- `"$AO/new/modal/buttons_2/button_9.png"` - White

## UI State (Push/Pop)

All use `defer` for cleanup:

```csl
UI.push_screen_draw_context(); defer UI.pop_draw_context();
UI.push_layer(100); defer UI.pop_layer();
UI.push_layer_relative(10); defer UI.pop_layer();
UI.push_z(5.0); defer UI.pop_z();
UI.push_scale_factor(1.5); defer UI.pop_scale_factor();
UI.push_color_multiplier({1, 1, 1, 0.5}); defer UI.pop_color_multiplier();
UI.push_disabled(true); defer UI.pop_disabled();
UI.push_material(my_material); defer UI.pop_material();
UI.push_matrix(Matrix4.rotate(45, {0, 0, 1})); defer UI.pop_matrix();
```

### UI IDs

Required for repeated elements (loops of buttons, list items):

```csl
for i: 0..items.count-1 {
    UI.push_id("item_%", {i});
    defer UI.pop_id();

    item_rect := rect->cut_top(60);
    if UI.button(item_rect, bs, ts, items[i].name).clicked {
        select_item(i);
    }
}
```

## World Space UI

Units are in **meters** (character is ~1m tall). Regular pixel-scale values will be MASSIVE.

```csl
draw_world_ui :: proc(entity: Entity) {
    UI.push_world_draw_context();
    defer UI.pop_draw_context();

    pos := entity.world_position;
    UI.push_z(pos.y);
    defer UI.pop_z();

    bar_pos := pos + v2{0, 1.5};
    bar_rect := Rect{bar_pos, bar_pos}->grow(0.1, 0.5, 0.1, 0.5);

    UI.quad(bar_rect, core_globals.white_sprite, {0, 0, 0, 0.8});

    health_pct := entity.health / entity.max_health;
    fill_rect := bar_rect->inset(0.02)->subrect(0, 0, health_pct, 1);
    fill_color := lerp(v4{1, 0, 0, 1}, {0, 1, 0, 1}, health_pct);
    UI.quad(fill_rect, core_globals.white_sprite, fill_color);
}
```

### Coordinate Conversion

```csl
screen_pos := world_to_screen(entity.world_position);
world_pos := screen_to_world(get_mouse_screen_position());
```

## Common Sizes

- Text: Title 52, Body 36, World space 0.30
- Rects: Simple dialog 600x400, Standard button 210x74, Exit button 65x65
