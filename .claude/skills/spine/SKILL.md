---
name: spine
description: Any time you are working with Spine animators or player animations
---
# Spine Animation System

There are two ways to use Spine animations in CSL:

1. **Spine_Animator** (Component) - Use when you need an animated entity in the scene
2. **Spine_Instance** (Standalone) - Use for UI animations or when you need manual control

## Spine_Animator (Component)

`Spine_Animator` is a component that wraps a `Spine_Instance`. They can be added to an entity in the editor or added in code with `Entity.add_component(Spine_Animator);`.

```csl
My_Component :: class : Component {
    ao_start :: method() {
        spine := entity->get_component(Spine_Animator);
        spine->awaken();  // REQUIRED before accessing spine.instance
        spine.instance->set_animation("idle_loop", true, 0);
    }
}
```

### Key Properties
- `spine.instance` - The underlying `Spine_Instance` (read-only)
- `spine.depth_offset` - Rendering depth offset
- `spine.layer` - Rendering layer

### Important: awaken() Requirement
Always call `spine->awaken()` before accessing `spine.instance` if your component and the Spine_Animator are on the same entity and start at the same time.

## Spine_Instance (Standalone)

Use `Spine_Instance` directly for UI animations or when you don't need an entity.

**⚠️ IMPORTANT: You MUST call `destroy()` on Spine_Instance when done, otherwise there is a memory leak!**

> **API Pattern:** In our APIs, if there is a `create()` function, there MUST be a matching `destroy()` call. This applies to `Spine_Instance.create()`, `State_Machine.create()`, and similar APIs.
>
> **Exception:** Some APIs have a `transfer_ownership` parameter. If you pass `true`, the receiving object takes responsibility for calling `destroy()`. For example, `instance->set_state_machine(state_machine, true)` transfers ownership to the instance—it will destroy the state machine when the instance is destroyed, so you don't need to call `state_machine->destroy()` yourself.

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
        spine_instance->destroy();  // REQUIRED to avoid memory leak!
    }
    
    update :: proc(using this: Popup, dt: float) {
        spine_instance->update(dt);  // Manual update required
    }
    
    render :: proc(using this: Popup) {
        UI.push_screen_draw_context();
        defer UI.pop_draw_context();

        rect := UI.get_safe_screen_rect();

        /*
        The scale you want to use depends on how the spine asset has been
        authored. For a character, the artist probably authored it thinking
        in world space, so the character is probably 1-2 units tall. If we
        draw this in screen space then it will only be 1-2 pixels tall
        which is not very useful, so we use a bigger scale most of the time
        for UI spines. If we were drawing in world space then a scale of {1, 1}
        would be fine.
        */
        scale := v2{100, 100};
        UI.spine(rect->center(), spine_instance, scale, 0.0);
    }
}
```

## Playing Animations

### Manual Animation Control
Use `set_animation` to directly play animations:

```csl
// set_animation(animation_name, loop, track, speed = 1)
spine.instance->set_animation("idle", true, 0);           // Loop idle on track 0
spine.instance->set_animation("attack", false, 0);        // Play once
spine.instance->set_animation("walk", true, 0, 1.5);      // 1.5x speed
```

- **animation_name**: Name of the animation in the Spine file
- **loop**: `true` to loop, `false` to play once
- **track**: Animation track (use 0 for single-track animations)
- **speed**: Playback speed multiplier (default 1.0)

### State Machine (Automatic Transitions)

For complex animation logic, use a `State_Machine` to handle transitions automatically based on variables.

```csl
NPC :: class : Component {
    spine: Spine_Animator @ao_serialize;
    state_machine: State_Machine;
    
    ao_start :: method() {
        state_machine = State_Machine.create();
        
        // 1. Create variables
        is_moving := state_machine->create_variable("is_moving", .BOOL);
        attack_trigger := state_machine->create_variable("attack", .TRIGGER);
        die_trigger := state_machine->create_variable("die", .TRIGGER);
        
        // 2. Create layer (maps to Spine track)
        layer := state_machine->create_layer("main", 0);
        
        // 3. Create states (name must match Spine animation)
        // create_state(name, loop, duration = 0) - duration always pulled from spine rig when used with Spine_Instance
        idle_state := layer->create_state("idle", true);       // looping
        walk_state := layer->create_state("walk", true);       // looping
        attack_state := layer->create_state("attack", false);  // one-shot
        death_state := layer->create_state("death", false);    // one-shot
        
        // 4. Set initial state
        layer->set_initial_state(idle_state);
        
        // 5. Create transitions with conditions
        
        // Bidirectional transitions based on bool
        idle_to_walk := layer->create_transition(idle_state, walk_state, false);
        idle_to_walk->create_bool_condition(is_moving, true);
        
        walk_to_idle := layer->create_transition(walk_state, idle_state, false);
        walk_to_idle->create_bool_condition(is_moving, false);
        
        // Global transition (can trigger from any state)
        to_attack := layer->create_global_transition(attack_state, true);
        to_attack->create_trigger_condition(attack_trigger);
        
        // Return to idle after attack completes (require_state_complete = true)
        attack_to_idle := layer->create_transition(attack_state, idle_state, true);
        
        // Death transition (allow_transition_to_self = false)
        to_death := layer->create_global_transition(death_state, false);
        to_death->create_trigger_condition(die_trigger);
        
        // 6. Connect state machine to spine instance
        spine->awaken();
        spine.instance->set_state_machine(state_machine, true);  // true = transfer ownership
    }
    
    ao_update :: method(dt: float) {
        // Update variables based on gameplay - state machine handles transitions
        state_machine->set_bool("is_moving", is_moving());
    }
    
    on_attack :: method() {
        state_machine->set_trigger("attack");
    }
    
    on_death :: method() {
        state_machine->set_trigger("die");
    }
}
```

### Variable Types
- `.BOOL` - Use `set_bool(name, value)` and `create_bool_condition(var, value)`
- `.TRIGGER` - Use `set_trigger(name)` and `create_trigger_condition(var)` - auto-resets after triggering
- `.INT` - Use `set_int(name, value)` and `create_int_condition(var, value, kind)`
- `.FLOAT` - Use `set_float(name, value)` and `create_float_condition(var, value, kind)`

### Numeric Condition Kinds
For INT and FLOAT conditions:
- `.GREATER`, `.GREATER_EQUAL`, `.LESS`, `.LESS_EQUAL`, `.EQUAL`

### Transition Types
- `create_transition(from, to, require_state_complete)` - Only from specific state
- `create_global_transition(to, allow_transition_to_self)` - Can trigger from any state

## Skins

```csl
// Set a single skin (replaces current)
spine.instance->set_skin("armor_heavy");
spine.instance->refresh_skins(); // Always have to call refresh_skins after modifying skins

// Combine multiple skins
spine.instance->disable_all_skins();
spine.instance->enable_skin("body_base");
spine.instance->enable_skin("armor_heavy");
spine.instance->enable_skin("helmet_iron");
spine.instance->refresh_skins(); // Apply combined skins

// Get available skins
skins := spine.instance->get_skins();
```

## Bone Positions

Get world position of a bone (useful for attaching effects):

```csl
hand_pos := spine.instance->get_bone_position("hand_right");
spawn_effect_at(hand_pos);
```

## Accessing State Machine from Spine_Animator

If a Spine_Animator has a state machine configured in the editor:

```csl
layer := animator.instance.state_machine->try_get_layer("main");
if layer != null {
    current := layer->get_current_state();
    running_state := layer->try_get_state("Run_Fast");
}

// Set triggers on existing state machine
animator.instance.state_machine->set_trigger("jump");
```

## Color Replacement

### Color multiplier
Any Spine Instance can have its color multiplier set (e.g. to make spines flash red when damaged or become transparent)
`animator.instance.color_multiplier = {brightness, brightness, brightness, 0.25};`

### Player color replacement
For players, you can set a color replace color that intelligently tints the character to be a different color. Common use-case is to create a new spine instance for rendering a clone of the player in UI.

```csl
player: Player = ...;
player_ui_instance := Spine_Instance.create();
player_ui_instance->set_skeleton(player.animator.instance->get_skeleton());
for skin: player.animator.instance->get_skins() {
    player_ui_instance->enable_skin(skin);
}
player_ui_instance->refresh_skins();
player_ui_instance->set_color_replace_color(player.avatar_color);

// Later, every frame:
player_ui_instance->update(dt);
UI.spine(UI.get_screen_rect()->center(), player_ui_instance, {100, 100});
```

### Available Colors

```csl
Color_Replace_Color :: enum {
    NONE;
    RED;
    CYAN;
    GREEN;
    YELLOW;
    LIGHT_GREEN;
    PINK;
    ORANGE;
    BLACK;
    PURPLE;
    LIGHT_GRAY;
    BLACK2;
    BLUE2;
    BROWN1;
    GREEN3;
    ORANGE2;
    PURPLE2;
    PURPLE3;
    RED2;
    WHITE1;
}
```

## MCP Tools
Before using a Spine_Animator, check the available animations and skins using the All Out mcp tool. 