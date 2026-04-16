---
name: spine
description: You must load this tool when working with Spine animators or player animations, it provides the Spine API surface you must adhere to. 
---
# Spine Animation System

Two ways to use Spine animations:
1. **Spine_Animator** (Component) - Animated entity in the scene
2. **Spine_Instance** (Standalone) - UI animations

## Spine_Animator (Component)
For runtime-spawned non-player entities:
```csl
entity := Scene.create_entity();
animator := entity.add_component(Spine_Animator);
animator.awaken();  // REQUIRED before calling animation methods
animator.set_skeleton(get_asset(Spine_Asset, "anims/rig.spine"));
animator.set_skin("call spine_rig_info to know what skin you MUST use"); // REQUIRED or spine will be invisible 
animator.refresh_skins(); // REQUIRED after any skin change
animator.set_animation("Idle", true, 0); // name, loop, track, speed = 1
animator.scale = v2{0.9, 0.9}; // reference the worldSize returned by the spine_rig_info tool and compute the best value here given the world/player/use case. 

**You MUST call `awaken()` before calling any animation methods** if your component and the Spine_Animator start at the same time on the same entity.

## Player Animations
The engine builds the player's skeleton and state machine automatically. Access it via `player.animator.state_machine`. The `moving` bool is driven by velocity — everything else you trigger from CSL.

```csl
sm := player.animator.state_machine;

// Kill the player (must RESET to recover)
sm.set_trigger("death");

// Reset back to Idle from any state
sm.set_trigger("RESET");

// Play a flinch/hit-react (returns to Idle automatically)
sm.set_trigger("flinch");

// Dodge roll (returns to Idle automatically)
sm.set_trigger("dodge_roll");

// Melee attack (plays on the attack layer, track 1)
sm.set_trigger("attack");

// Enter/exit ghost form (swaps Idle/Run to ghost variants, used for spectator mode joining a match in progress etc...)
sm.set_bool("ghost_form", true);  // false to exit then RESET
```

Available triggers: `death`, `RESET`, `flinch`, `dodge_roll`, `attack`, `punch`
Available bools: `ghost_form`, `electrocute`, `sleep`

## Non-Player State Machine
For complex non-player spines, you can create your own custom state machine for those spines: 

```csl
Enemy_NPC :: class : Component {
    animator: Spine_Animator @ao_serialize;
    state_machine: State_Machine;

    ao_start :: method() {
        state_machine = State_Machine.create();

        // Variable types: `.BOOL`, `.TRIGGER`, `.INT`, `.FLOAT`. Numeric conditions accept a kind: `.GREATER`, `.GREATER_EQUAL`, `.LESS`, `.LESS_EQUAL`, `.EQUAL`.
        is_moving := state_machine.create_variable("is_moving", .BOOL);
        attack_trigger := state_machine.create_variable("attack", .TRIGGER);  // auto-resets after triggering
        die_trigger := state_machine.create_variable("die", .TRIGGER);

        // Layer maps to a Spine track
        layer := state_machine.create_layer("main", 0);

        // States -- name must match Spine animation
        // create_state(name, loop, duration = 0) -- duration pulled from spine rig
        idle_state := layer.create_state("idle", true);
        walk_state := layer.create_state("walk", true);
        attack_state := layer.create_state("attack", false);   // one-shot
        death_state := layer.create_state("death", false);

        layer.set_initial_state(idle_state);

        // create_transition(from, to, require_state_complete)
        idle_to_walk := layer.create_transition(idle_state, walk_state, false);
        idle_to_walk.create_bool_condition(is_moving, true);

        walk_to_idle := layer.create_transition(walk_state, idle_state, false);
        walk_to_idle.create_bool_condition(is_moving, false);

        // create_global_transition(to, allow_transition_to_self) -- from any state
        to_attack := layer.create_global_transition(attack_state, true);
        to_attack.create_trigger_condition(attack_trigger);

        // require_state_complete = true: waits for attack to finish
        attack_to_idle := layer.create_transition(attack_state, idle_state, true);

        to_death := layer.create_global_transition(death_state, false);
        to_death.create_trigger_condition(die_trigger);

        animator.awaken();
        animator.set_state_machine(state_machine, true);  // true = transfer ownership
    }

    ao_update :: method(dt: float) {
        state_machine.set_bool("is_moving", is_moving());
    }

    on_attack :: method() { state_machine.set_trigger("attack"); }
    on_death :: method() { state_machine.set_trigger("die"); }
}
```

## Skins
You must use the spine_rig_info tool before using any spine to know what skin(s) to select, plus scaling and animations to use. 

```csl
// Combine multiple skins 
animator.disable_all_skins();
animator.enable_skin("base/crewchsia"); // (required when using the streamed character skeleton)
animator.enable_skin("body/alien");
animator.refresh_skins();
```

## Bone Positions
```csl
hand_pos := animator.get_bone_local_position("Hand_R");
```

```csl
layer := animator.state_machine.try_get_layer("main");
if layer != null {
    current := layer.get_current_state();
    running_state := layer.try_get_state("Run_Fast");
}
animator.state_machine.set_trigger("jump");
```

## Color
// All spines that can take damage or you want to draw attention to should color_multiplier to apply effects (red flash, glow, etc...)

```csl
// Tint/flash (e.g. damage flash, transparency)
animator.color_multiplier = {brightness, brightness, brightness, 0.25};
```

## Spine_Instance (Standalone for UI)
**You MUST call `destroy()` on Spine_Instance when done to avoid leaks.**

If an API has `create()`, it MUST have a matching `destroy()`. Exception: APIs with a `transfer_ownership` parameter -- passing `true` transfers destroy responsibility to the receiver (e.g. `instance.set_state_machine(sm, true)`).

```csl
Popup :: class {
    spine_asset: Spine_Asset;
    spine_instance: Spine_Instance;

    init :: proc(using this: Popup) {
        spine_asset = get_asset(Spine_Asset, "anims/popup.spine");
        spine_instance = Spine_Instance.create();
        spine_instance.set_skeleton(spine_asset);
    }

    cleanup :: proc(using this: Popup) {
        spine_instance.destroy();  // REQUIRED
    }

    update :: proc(using this: Popup, dt: float) {
        spine_instance.update(dt);  // Manual update required for standalone
    }

    render :: proc(using this: Popup) {
        UI.push_screen_draw_context();
        defer UI.pop_draw_context();
        rect := UI.get_safe_screen_rect();
        // Spine assets authored in world space are ~1-2 units tall.
        // In screen space that's 1-2 pixels, so scale up for UI.
        // In world space, {1,1} is fine.
        scale := v2{100, 100};
        UI.spine(rect.center(), spine_instance, scale, 0.0);
    }
}
```

### Player UI Clone Example (voting screens, PiP displays)
Clones a player to display them in UI, etc...

```csl
player: Player = ...;
player_ui_instance := Spine_Instance.create();
player_ui_instance.set_skeleton(player.animator.get_skeleton());
for skin: player.animator.get_skins() {
    player_ui_instance.enable_skin(skin);
}
player_ui_instance.refresh_skins();
player_ui_instance.set_color_replace_color(player.avatar_color);

// Every frame:
player_ui_instance.update(dt);
UI.spine(UI.get_screen_rect().center(), player_ui_instance, {100, 100});
```

```csl
Color_Replace_Color :: enum {
    NONE; RED; CYAN; GREEN; YELLOW; LIGHT_GREEN; PINK; ORANGE; BLACK;
    PURPLE; LIGHT_GRAY; BLACK2; BLUE2; BROWN1; GREEN3; ORANGE2; PURPLE2;
    PURPLE3; RED2; WHITE1;
}
```

