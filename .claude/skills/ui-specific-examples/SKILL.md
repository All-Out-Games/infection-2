---
name: ui-specific-examples
description: Only for tutorial arrows, custom aiming lines, or drawing players characters specifically in UI
---
> You MUST follow all instructions from the `ui` skill first.

### Character Preview (Spine in UI)
```csl
draw_character_preview :: proc(spine: Spine_Instance) {
    rect := UI.get_screen_rect();
    UI.spine(rect->center(), spine, v2{100, 100}, 0.0); // pos, spine, scale, rotation
}
```

### Player-Specific Materials
For rendering player characters with their cosmetics:
```csl
draw_player_icon :: proc(player: Player) {
    rect := UI.get_screen_rect()->top_left_rect()->grow(50)->offset(60, -60);

    UI.push_player_material(player);   // or UI.push_unlit_player_material(player)
    defer UI.pop_material();
}
```

### Tutorial Arrow
Points players toward objectives:
```csl
draw_objective_arrow :: proc(player: Player, target: v2) {
    options := Tutorial_Arrow.default_options();
    options.alpha = 1;
    options.far = true;
    options.near = true;
    options.bob_scale = 0.5;
    options.bob_bias = 1.5;

    Tutorial_Arrow.draw(player, target, options);
}
```

### World Progress Bar
```csl
draw_capture_progress :: proc(position: v2, progress: float) {
    options := World_Progress_Bar.default_options();
    options.y_bias = 1;
    options.width = 1.2;
    options.height = 0.15;
    options.scale = 1;

    World_Progress_Bar.draw(position, progress, options);
}
```

### Aiming Lines
> Not needed when using `full_update_targeted_aimed_ability`, only for custom aiming.

```csl
draw_aim_indicator :: proc(player: Player, direction: v2) {
    scale := 1.0 / player.camera.size * 4;
    draw_thin_aiming_line(player.entity.world_position, direction, scale);
    draw_aiming_line(player.entity.world_position, direction, scale); // thick, with arrows
}
```

### Animation with Easing
```csl
draw_animated_element :: proc(show_t: float) {
    t := Ease.out_back(show_t);
    offset_y := lerp(-200.0, 0.0, t);

    rect := UI.get_screen_rect()->bottom_center_rect()->grow(50, 150, 50, 150)->offset(0, 100 + offset_y);

    UI.push_color_multiplier({1, 1, 1, t});
    defer UI.pop_color_multiplier();

    UI.quad(rect, core_globals.white_sprite, {0.2, 0.2, 0.2, 0.9});
}
```
