---
name: ui-specific-examples
description: Only for tutorial arrows, custom aiming lines, or drawing players characters specifically in UI
---
> Note, you MUST follow all instructions from the `ui` skill carefully first. 

```csl
draw_character_preview :: proc(spine: Spine_Instance) {
    rect := UI.get_screen_rect();
    scale := v2{100, 100};
    rotation := 0.0;

    UI.spine(rect->center(), spine, scale, rotation);
}
```

## Player-Specific Materials
For rendering player characters with their cosmetics:

```csl
draw_player_icon :: proc(player: Player) {
    rect := UI.get_screen_rect()->top_left_rect()->grow(50)->offset(60, -60);

    UI.push_player_material(player);
    defer UI.pop_material();

    // or for unlit version:
    // UI.push_unlit_player_material(player);

    // Draw the player's spine or icon here
}
```

### Tutorial Arrow
Points players toward objectives:

```csl
draw_objective_arrow :: proc(player: Player, target: v2) {
    options := Tutorial_Arrow.default_options();
    options.alpha = 1;
    options.far = true;    // Show when target is far
    options.near = true;   // Show when target is near
    options.bob_scale = 0.5;
    options.bob_bias = 1.5;

    Tutorial_Arrow.draw(player, target, options);
}
```

### World Progress Bar
For progress indicators in world space:

```csl
draw_capture_progress :: proc(position: v2, progress: float) {
    options := World_Progress_Bar.default_options();
    options.y_bias = 1;      // Height above position
    options.width = 1.2;
    options.height = 0.15;
    options.scale = 1;

    World_Progress_Bar.draw(position, progress, options);
}
```

### Aiming Lines
>  Not needed when using full_update_targted_aimed_ability but can be used for custom stuff

```csl
draw_aim_indicator :: proc(player: Player, direction: v2) {
    // Thin line for subtle aiming
    scale := 1.0 / player.camera.size * 4;
    draw_thin_aiming_line(player.entity.world_position, direction, scale);

    // Or thick line with arrows for emphasis
    draw_aiming_line(player.entity.world_position, direction, scale);
}
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
