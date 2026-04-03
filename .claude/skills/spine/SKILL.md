---
name: spine
description: Any time you are working with Spine animators or player animations
---
# Spine Animation System

Two ways to use Spine animations:
1. **Spine_Animator** (Component) - Animated entity in the scene
2. **Spine_Instance** (Standalone) - UI animations or manual control

## Spine_Animator (Component)

```csl
spine := entity->get_component(Spine_Animator);
spine->awaken();  // REQUIRED before accessing spine.instance
spine.instance->set_animation("idle_loop", true, 0);
```

**You MUST call `awaken()` before accessing `spine.instance`** if your component and the Spine_Animator start at the same time on the same entity.

Properties: `spine.instance` (underlying Spine_Instance), `spine.depth_offset`, `spine.layer`.

## Spine_Instance (Standalone)

**You MUST call `destroy()` on Spine_Instance when done -- memory leak otherwise.**

If an API has `create()`, it MUST have a matching `destroy()`. Exception: APIs with a `transfer_ownership` parameter -- passing `true` transfers destroy responsibility to the receiver (e.g. `instance->set_state_machine(sm, true)`).

```csl
Popup :: class {
    spine_asset: Spine_Asset;
    spine_instance: Spine_Instance;

    init :: proc(using this: Popup) {
        spine_asset = get_asset(Spine_Asset, "anims/popup.spine");
        spine_instance = Spine_Instance.create();
        spine_instance->set_skeleton(spine_asset);
    }

    cleanup :: proc(using this: Popup) {
        spine_instance->destroy();  // REQUIRED
    }

    update :: proc(using this: Popup, dt: float) {
        spine_instance->update(dt);  // Manual update required for standalone
    }

    render :: proc(using this: Popup) {
        UI.push_screen_draw_context();
        defer UI.pop_draw_context();
        rect := UI.get_safe_screen_rect();
        // Spine assets authored in world space are ~1-2 units tall.
        // In screen space that's 1-2 pixels, so scale up for UI.
        // In world space, {1,1} is fine.
        scale := v2{100, 100};
        UI.spine(rect->center(), spine_instance, scale, 0.0);
    }
}
```

## Playing Animations

```csl
// set_animation(animation_name, loop, track, speed = 1)
spine.instance->set_animation("idle", true, 0);
spine.instance->set_animation("attack", false, 0);
spine.instance->set_animation("walk", true, 0, 1.5);  // 1.5x speed
```

## State Machine

```csl
NPC :: class : Component {
    spine: Spine_Animator @ao_serialize;
    state_machine: State_Machine;

    ao_start :: method() {
        state_machine = State_Machine.create();

        // Variables
        is_moving := state_machine->create_variable("is_moving", .BOOL);
        attack_trigger := state_machine->create_variable("attack", .TRIGGER);  // auto-resets after triggering
        die_trigger := state_machine->create_variable("die", .TRIGGER);

        // Layer maps to a Spine track
        layer := state_machine->create_layer("main", 0);

        // States -- name must match Spine animation
        // create_state(name, loop, duration = 0) -- duration pulled from spine rig
        idle_state := layer->create_state("idle", true);
        walk_state := layer->create_state("walk", true);
        attack_state := layer->create_state("attack", false);   // one-shot
        death_state := layer->create_state("death", false);

        layer->set_initial_state(idle_state);

        // create_transition(from, to, require_state_complete)
        idle_to_walk := layer->create_transition(idle_state, walk_state, false);
        idle_to_walk->create_bool_condition(is_moving, true);

        walk_to_idle := layer->create_transition(walk_state, idle_state, false);
        walk_to_idle->create_bool_condition(is_moving, false);

        // create_global_transition(to, allow_transition_to_self) -- from any state
        to_attack := layer->create_global_transition(attack_state, true);
        to_attack->create_trigger_condition(attack_trigger);

        // require_state_complete = true: waits for attack to finish
        attack_to_idle := layer->create_transition(attack_state, idle_state, true);

        to_death := layer->create_global_transition(death_state, false);
        to_death->create_trigger_condition(die_trigger);

        spine->awaken();
        spine.instance->set_state_machine(state_machine, true);  // true = transfer ownership
    }

    ao_update :: method(dt: float) {
        state_machine->set_bool("is_moving", is_moving());
    }

    on_attack :: method() { state_machine->set_trigger("attack"); }
    on_death :: method() { state_machine->set_trigger("die"); }
}
```

Variable types: `.BOOL`, `.TRIGGER`, `.INT`, `.FLOAT`. Numeric conditions accept a kind: `.GREATER`, `.GREATER_EQUAL`, `.LESS`, `.LESS_EQUAL`, `.EQUAL`.

## Skins

```csl
spine.instance->set_skin("armor_heavy");
spine.instance->refresh_skins(); // REQUIRED after any skin modification

// Combine multiple skins
spine.instance->disable_all_skins();
spine.instance->enable_skin("body_base");
spine.instance->enable_skin("armor_heavy");
spine.instance->refresh_skins();

skins := spine.instance->get_skins();
```

## Bone Positions

```csl
hand_pos := spine.instance->get_bone_position("hand_right");
```

## Accessing Editor-configured State Machine

```csl
layer := animator.instance.state_machine->try_get_layer("main");
if layer != null {
    current := layer->get_current_state();
    running_state := layer->try_get_state("Run_Fast");
}
animator.instance.state_machine->set_trigger("jump");
```

## Color

```csl
// Tint/flash (e.g. damage flash, transparency)
animator.instance.color_multiplier = {brightness, brightness, brightness, 0.25};
```

### Player Color Replacement

Clone a player's spine for UI rendering with a different color:

```csl
player: Player = ...;
player_ui_instance := Spine_Instance.create();
player_ui_instance->set_skeleton(player.animator.instance->get_skeleton());
for skin: player.animator.instance->get_skins() {
    player_ui_instance->enable_skin(skin);
}
player_ui_instance->refresh_skins();
player_ui_instance->set_color_replace_color(player.avatar_color);

// Every frame:
player_ui_instance->update(dt);
UI.spine(UI.get_screen_rect()->center(), player_ui_instance, {100, 100});
```

### Color_Replace_Color Values

```csl
Color_Replace_Color :: enum {
    NONE; RED; CYAN; GREEN; YELLOW; LIGHT_GREEN; PINK; ORANGE; BLACK;
    PURPLE; LIGHT_GRAY; BLACK2; BLUE2; BROWN1; GREEN3; ORANGE2; PURPLE2;
    PURPLE3; RED2; WHITE1;
}
```

## MCP Tools
Before using a Spine_Animator, check the available animations and skins using the All Out mcp tool.
