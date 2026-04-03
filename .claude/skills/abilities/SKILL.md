---
name: abilities
description: Reference this when implementing player abilities.
---
# CSL Ability System

## Creating an Ability

```csl
My_Ability :: class : Ability_Base {
    on_init :: method() {
        name = "My Ability";
        icon = get_asset(Texture_Asset, "icons/my_ability.png");
    }

    // Optional: Return false to gray out the button
    can_use :: method() -> bool {
        return player.some_resource > 0;
    }

    on_update :: method(params: ref Ability_Update_Params) {
        if params.clicked && params.can_use {
            do_ability_effect(player);
            current_cooldown = 2.0;  // Must set cooldown after activating
        }
    }
}
```

## Drawing Abilities

Draw in the player's `ao_late_update` inside `is_local_or_server()`. Do not make custom UI for ability buttons.

```csl
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
        if this->is_local_or_server() && !health.is_dead {
            draw_ability_button(this, Shoot_Ability, 0);
            draw_ability_button(this, Dodge_Roll, 1);
            draw_ability_button(this, Sprint_Ability, 4);
        }
    }
}
```

## Button Layout

- **Index 0**: Large primary button (bottom-right, closest to corner)
- **Index 1-5**: Smaller secondary buttons arranged around index 0

```
// Offsets from bottom-right:
// 0: {-105, 90}   Big     1: {-295, 40}   Small, left
// 2: {-290, 180}  Upper-left   3: {-180, 290}  Upper
// 4: {-40, 295}   Upper-right  5: {-440, 40}   Far left
```

## Ability_Update_Params

```csl
on_update :: method(params: ref Ability_Update_Params) {
    params.hovering;        // Mouse over button
    params.just_pressed;
    params.active;          // Being held
    params.released;
    params.clicked;         // Pressed and released
    params.can_use;         // Passed can_use check and not on cooldown
    params.drag_offset;     // Normalized drag vector (0-1) for aimed abilities
    params.drag_direction;  // Unit direction of drag
}
```

## Hold Ability

Use `Ability_Utilities.update_holding_ability` for abilities active while held. Handles both PC keybind and mobile button.

```csl
Sprint_Ability :: class : Ability_Base {
    on_init :: method() {
        name = "Sprint";
        keybind_override = keybind_sprint;
        draw_but_dont_use_keybind = true;  // Show keybind but handle input via update_holding_ability
    }

    can_use :: method() -> bool {
        return player.stamina > 0;
    }

    on_update :: method(params: ref Ability_Update_Params) {
        holding := Ability_Utilities.update_holding_ability(player, ref params, keybind_sprint);
        player.is_sprinting = holding.active && player.stamina > 0;
    }
}
```

## Aimed Ability (Always Aiming on PC)

`Ability_Utilities.full_update_aimed_ability` -- PC: mouse aim + click. Mobile: press-drag-release.
Returns `{ direction: v2, activate: bool }`.

```csl
Shoot_Ability :: class : Ability_Base {
    on_init :: method() {
        name = "Shoot";
        disable_keybind = true;
        is_aimed_ability = true;
    }

    on_update :: method(params: ref Ability_Update_Params) {
        activation := Ability_Utilities.full_update_aimed_ability(player, ref params);
        if activation.activate {
            current_cooldown = 0.5;
            shoot_projectile(player.entity.world_position, activation.direction * 10.0);
        }
    }
}
```

## Targeted Aimed Ability (Click to Enter Aim Mode)

`Ability_Utilities.full_update_targeted_aimed_ability` -- PC: click button to aim, click to fire, right-click to cancel. Mobile: press-drag-release.
Returns `{ direction: v2, activate: bool }`.

```csl
Dodge_Roll :: class : Ability_Base {
    on_init :: method() {
        name = "Roll";
        is_aimed_ability = true;
        keybind_override = keybind_dodge_roll;
    }

    on_update :: method(params: ref Ability_Update_Params) {
        activation := Ability_Utilities.full_update_targeted_aimed_ability(player, this, ref params);
        if activation.activate {
            current_cooldown = 1.5;
            effect := new(Roll_Effect);
            effect.direction = activation.direction;
            player.entity->set_active_effect(effect);  // See effects skill
        }
    }
}
```

## Low-Level Utilities

- `update_aiming_ability` -- Returns `{ aim: bool, activate: bool, cancel: bool, aim_direction: v2 }`. Use `full_update_aimed_ability` unless you need custom aiming UI.
- `update_targeted_ability` -- Returns `{ targeting: bool }`. Sets `player.active_ability` to this ability.

## Ability_Base Fields

```csl
Ability_Base :: class {
    player: Player;
    name: string;
    icon: Texture_Asset;
    current_cooldown: float;           // Remaining cooldown (0 = ready)
    type: typeid;
    is_aimed_ability: bool;            // Show aim indicator on button
    mouse_position_on_press: v2;

    keybind_override: Keybind;         // Custom keybind (0 = use default)
    disable_keybind: bool;             // Don't show or use any keybind
    draw_but_dont_use_keybind: bool;   // Show keybind but handle input manually
}
```

## Keybinds

Register in `ao_before_scene_load`, then reference via `keybind_override`:

```csl
keybind_dodge_roll: Keybind;

ao_before_scene_load :: proc() {
    keybind_dodge_roll = Keybinds.register("Roll", .SPACE);
}
```

Default keybinds by button index: 0=Q, 1=Z, 2=X, 3=C, 4=R, 5=F.

## Conditional Ability Display

```csl
ao_late_update :: method(dt: float) {
    if this->is_local_or_server() && !health.is_dead {
        if is_carrying_item {
            draw_ability_button(this, Drop_Item_Ability, 0);
        } else {
            switch team {
                case .SURVIVOR: {
                    draw_ability_button(this, Shoot_Ability, 0);
                    draw_ability_button(this, Dodge_Roll, 1);
                }
                case .ZOMBIE: {
                    draw_ability_button(this, Slash_Ability, 0);
                }
            }
        }
    }
}
```

## Player Ability Restrictions

`ao_can_use_ability` on your Player adds game-wide restrictions, called after the ability's own `can_use` and cooldown checks. Use for global rules (dead, cutscene). Use ability's `can_use` for ability-specific rules (stamina, ammo).

```csl
Player :: class : Player_Base {
    ao_can_use_ability :: method(ability: Ability_Base) -> bool {
        if health.is_dead return false;
        if g_game.state == .CUTSCENE return false;
        return true;
    }
}
```

## Custom Button Drawing

Implement `on_draw_button` on your ability class to draw custom content on the ability button (e.g., ammo count, charge indicator):

```csl
My_Ability :: class : Ability_Base {
    ammo: int;

    on_draw_button :: method(rect: Rect) {
        ts := UI.default_text_settings();
        ts.size = 24;
        ts.halign = .RIGHT;
        ts.valign = .BOTTOM;
        UI.text(rect->inset(5), ts, "%", {ammo});
    }
}
```
