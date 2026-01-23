---
name: abilities
description: Reference this when implementing player abilities.
---
# CSL Ability System

The ability system provides a framework for creating player abilities with cooldowns, input handling, and UI buttons.

## Core Concepts

1. **Abilities are per-player** - Each player has their own list of abilities
2. **Draw in `ao_late_update`** - Ability buttons are drawn in the player's late update inside `is_local_or_server()` check
3. **Implement callbacks** - Abilities define `on_init`, `on_update`, and optionally `can_use` and `on_draw_button`

## Creating a Basic Ability

```csl
My_Ability :: class : Ability_Base {
    // Called once when a player joins and ability instances are created for them
    on_init :: method() {
        name = "My Ability";
        icon = get_asset(Texture_Asset, "icons/my_ability.png");
    }

    // Optional: Return false to gray out the button
    can_use :: method() -> bool {
        return player.some_resource > 0;
    }

    // Called every frame when the ability button exists
    on_update :: method(params: ref Ability_Update_Params) {
        // Always check can_use here, which will automatically check cooldown etc...
        if params.clicked && params.can_use {
            // Activate the ability
            do_ability_effect(player);

            // You always need to set the cooldown after activating an ability
            current_cooldown = 2.0;
        }
    }
}
```

## Drawing Abilities

Abilities must be drawn in the player's `ao_late_update` using the `draw_ability_button` helper function. You do not need to make your own UI for ability buttons. 
```csl
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
        // Always check `is_local_or_server`! 
        if this->is_local_or_server() && !health.is_dead {
            // Draw ability buttons - index 0 is the big primary button
            draw_ability_button(this, Shoot_Ability, 0);
            draw_ability_button(this, Dodge_Roll, 1);
            draw_ability_button(this, Sprint_Ability, 4);
        }
    }
}
```

## Button Layout

The ability button indices correspond to fixed screen positions:

- **Index 0**: Large primary button (bottom-right, closest to corner)
- **Index 1-5**: Smaller secondary buttons arranged around index 0

```csl
// Button positions (offsets from bottom-right):
// Index 0: {-105, 90}   - Big button
// Index 1: {-295, 40}   - Small, left of big
// Index 2: {-290, 180}  - Small, upper-left
// Index 3: {-180, 290}  - Small, upper
// Index 4: {-40, 295}   - Small, upper-right
// Index 5: {-440, 40}   - Small, far left
```

## Ability_Update_Params

The `params` passed to `on_update` contains interaction state:

```csl
on_update :: method(params: ref Ability_Update_Params) {
    // Basic interaction (inherited from Interact_Result)
    params.hovering;        // Mouse over button
    params.just_pressed;    // Just started pressing
    params.active;          // Being held
    params.released;        // Just released
    params.clicked;         // Was clicked (pressed and released)

    // Ability-specific
    params.can_use;         // True if ability passed can_use check and not on cooldown
    params.drag_offset;     // Normalized drag vector for aimed abilities (0-1)
    params.drag_direction;  // Unit direction of drag
}
```

## Ability Types

### Simple Click Ability

Activates immediately on click:

```csl
Simple_Ability :: class : Ability_Base {
    on_init :: method() {
        name = "Simple";
        icon = get_asset(Texture_Asset, "icons/simple.png");
    }

    on_update :: method(params: ref Ability_Update_Params) {
        if params.clicked && params.can_use {
            // Do the thing
            current_cooldown = 1.0;
        }
    }
}
```

### Hold Ability

Active while the button is held. Use `Ability_Utilities.update_holding_ability` to handle both PC keybind and mobile button holding.

```csl
Sprint_Ability :: class : Ability_Base {
    on_init :: method() {
        name = "Sprint";
        keybind_override = keybind_sprint;    // Must be registered in ao_before_scene_load
        draw_but_dont_use_keybind = true;     // Show keybind but handle input via update_holding_ability
    }

    can_use :: method() -> bool {
        return player.stamina > 0;
    }

    on_update :: method(params: ref Ability_Update_Params) {
        holding := Ability_Utilities.update_holding_ability(player, ref params, keybind_sprint);
        
        if holding.active && player.stamina > 0 {
            player.is_sprinting = true;
        }
        else {
            player.is_sprinting = false;
        }
    }
}
```

### Aimed Ability (Always Aiming on PC)

Use `Ability_Utilities.full_update_aimed_ability`. On PC, mouse position determines aim and click activates. On mobile, press-drag-release to aim and activate.

```csl
Shoot_Ability :: class : Ability_Base {
    on_init :: method() {
        name = "Shoot";
        disable_keybind = true;       // No keybind shown (always aiming)
        is_aimed_ability = true;      // Shows aim indicator on button
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

### Targeted Aimed Ability (Click to Enter Aim Mode)

Use `Ability_Utilities.full_update_targeted_aimed_ability`. On PC, click button to enter aim mode, then click to activate (right-click to cancel). On mobile, press-drag-release.

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
            
            // Start an effect for the roll (see effects.mdc)
            effect := new(Roll_Effect);
            effect.direction = activation.direction;
            player.entity->set_active_effect(effect);
        }
    }
}
```

## Ability_Utilities Reference

### full_update_aimed_ability

Complete solution for "always aiming" abilities. Draws the aiming line automatically.

- **PC:** Mouse position determines aim direction. Click anywhere on screen to activate.
- **Mobile:** Press and hold ability button, drag to aim. Release to activate (if dragged far enough).

Returns `Full_Aimed_Ability_Result`:
- `direction: v2` - Unit vector of aim direction
- `activate: bool` - Should activate this frame

### full_update_targeted_aimed_ability

Complete solution for "click to aim" abilities. Draws the aiming line automatically.

- **PC:** Click ability button to enter aim mode. Move mouse to aim. Click to activate, right-click to cancel.
- **Mobile:** Press and hold ability button, drag to aim. Release to activate (if dragged far enough).

Returns `Full_Targeted_Aimed_Ability_Result`:
- `direction: v2` - Unit vector of aim direction
- `activate: bool` - Should activate this frame

### update_holding_ability

For abilities that are active while held (e.g., sprint).

- **PC:** Active while keybind is held down.
- **Mobile:** Active while ability button is held down.

Returns `Holding_Ability_Result`:
- `active: bool` - Currently being held

### update_aiming_ability (Low-level)

Low-level helper for custom aiming implementations. Generally use `full_update_aimed_ability` or `full_update_targeted_aimed_ability` instead.

Returns `Aiming_Ability_Result`:
- `aim: bool` - Currently aiming
- `activate: bool` - Should activate this frame
- `cancel: bool` - Right-clicked to cancel (PC only)
- `aim_direction: v2` - Unit vector of aim direction

### update_targeted_ability (Low-level)

Low-level helper for custom targeting implementations. Sets `player.active_ability` to this ability.

Returns `Targeted_Ability_Result`:
- `targeting: bool` - Currently in targeting mode

## Ability_Base Fields

```csl
Ability_Base :: class {
    player: Player;                    // The owning player
    name: string;                      // Display name
    icon: Texture_Asset;               // Button icon
    current_cooldown: float;           // Remaining cooldown (0 = ready)
    type: typeid;                      // The ability's type
    is_aimed_ability: bool;            // Show aim indicator on button
    mouse_position_on_press: v2;       // Mouse pos when button was pressed

    keybind_override: Keybind;         // Custom keybind (0 = use default)
    disable_keybind: bool;             // Don't show or use any keybind
    draw_but_dont_use_keybind: bool;   // Show keybind but handle input manually
}
```

## Keybinds (not required)

Keybinds must be registered in `ao_before_scene_load`:

```csl
// Global keybind variable
keybind_dodge_roll: Keybind;

ao_before_scene_load :: proc() {
    keybind_dodge_roll = Keybinds.register("Roll", .SPACE);
}
```

Then reference in the ability:

```csl
Dodge_Roll :: class : Ability_Base {
    on_init :: method() {
        keybind_override = keybind_dodge_roll;
    }
}
```

Default ability keybinds (if no override):
- Index 0: Q
- Index 1: Z
- Index 2: X
- Index 3: C
- Index 4: R
- Index 5: F

## Effects for Complex Abilities

For abilities that take control of the player (dashes, channels, etc.), use Effects. See `effects.mdc` for full documentation.

```csl
// In ability on_update:
if activation.activate {
    effect := new(Roll_Effect);
    effect.direction = activation.direction;
    player.entity->set_active_effect(effect);
}
```

## Conditional Ability Display

Show different abilities based on game state:

```csl
ao_late_update :: method(dt: float) {
    if this->is_local_or_server() && !health.is_dead {
        if is_carrying_item {
            draw_ability_button(this, Drop_Item_Ability, 0);
        }
        else {
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

Define `ao_can_use_ability` on your Player to add game-wide restrictions. Called after the ability's `can_use` and cooldown checks.

```csl
Player :: class : Player_Base {
    ao_can_use_ability :: method(ability: Ability_Base) -> bool {
        if health.is_dead return false;
        if g_game.state == .CUTSCENE return false;
        return true;
    }
}
```

**When to use `ao_can_use_ability` vs ability's `can_use`:**
- Use `ao_can_use_ability` for game-wide rules (dead players can't use abilities, abilities blocked during cutscenes)
- Use ability's `can_use` for ability-specific rules (sprint needs stamina, shoot needs ammo)
