---
name: effects
description: "Reference this when implementing effects for abilities, animations, and state-based behaviors."
---
# CSL Effect System

Effects temporarily take control of an entity to execute complex behaviors like dashes, attacks, eating animations, or death sequences. Effects can be applied to Players, NPCs, or any other entity.

## Core Concepts

1. **Two types of effects** - Active effects (one at a time, interrupt each other) and passive effects (multiple allowed, stack)
2. **Callbacks are optional** - Implement only the callbacks you need
3. **Works with any entity** - Use `entity` for general access, `player` is populated only for Player entities
4. **Effects are a linked list** - Iterate with `effect_iterator` or manually via `first_effect`/`next_effect`

## Creating a Basic Effect

```csl
My_Effect :: class : Effect_Base {
    // Custom state for this effect
    some_value: float;
    target_position: v2;

    // Called once when effect starts
    effect_start :: method() {
        player_specific.freeze_player = true;  // Player can't move
        player->player_set_trigger("my_animation");
    }

    // Called every frame
    effect_update :: method(dt: float) {
        entity->lerp_local_position(target_position, 20 * dt);
        if get_elapsed_time() > 1.0 {
            remove_effect(false);
            return;  // Effect is invalid after removal
        }
    }

    // Called when effect ends
    effect_end :: method(interrupt: bool) {
        if !interrupt {
            entity->set_local_position(target_position);
        }
        player->player_set_trigger("RESET");
    }
}
```

## Activating Effects

### Active Effects (One at a Time)

Use `set_active_effect` for effects that should be mutually exclusive. Setting a new active effect ends the current one with `interrupt = true`.

```csl
effect := new(My_Effect);
effect.target_position = target.world_position;
entity->set_active_effect(effect);
```

### Passive Effects (Multiple Allowed)

Use `add_passive_effect` for effects that can stack (slows, buffs, status effects).

```csl
slow_effect := new(Slow_Effect);
slow_effect.speed_multiplier = 0.5;
slow_effect->set_duration(4);  // Auto-remove after 4 seconds
entity->add_passive_effect(slow_effect);
```

## Effect_Base Fields

```csl
Effect_Base :: class {
    entity: Entity;        // The entity this effect is attached to
    player: Player;        // Populated only for Player entities, null for NPCs

    player_specific: struct {
        freeze_player: bool;           // Lock player position entirely
        disable_movement_inputs: bool; // Ignore movement input but allow code to move
    };

    start_time: float;     // Time when effect started (read-only)
    next_effect: Effect_Base;  // Next effect in linked list (read-only)
    prev_effect: Effect_Base;  // Previous effect in linked list (read-only)
}
```

## Effect Methods

### get_elapsed_time

Returns time since effect started.

```csl
if get_elapsed_time() > 0.5 {
    remove_effect(false);
}
```

### set_duration

Automatically removes the effect after the specified time. Can be called when creating the effect or in `effect_start`.

```csl
// When creating
effect := new(My_Effect);
effect->set_duration(4.0);
entity->set_active_effect(effect);

// Or in effect_start
effect_start :: method() {
    set_duration(0.5);
}
```

### remove_effect

Ends the effect. Pass `false` for natural completion, `true` for forced/interrupted end.

**Important:** After calling `remove_effect()`, the effect is invalid. Return immediately.

```csl
if get_elapsed_time() > 0.5 {
    remove_effect(false);
    return;  // Effect is now invalid, must return immediately
}
```

## Callbacks Reference

### effect_start

Called once when effect is added. Use to:
- Set `player_specific.freeze_player` or `player_specific.disable_movement_inputs`
- Trigger animations
- Store initial state
- Call `set_duration` for timed effects

```csl
effect_start :: method() {
    player_specific.disable_movement_inputs = true;
    original_friction = player.agent.friction;
    player.agent.friction = 0;
    player->player_set_trigger("dash");
    set_duration(0.5);
}
```

### effect_update

Called every frame. Use to:
- Move the entity
- Check completion conditions
- Handle ongoing effects

```csl
effect_update :: method(dt: float) {
    player.agent.velocity = direction * 10;
}
```

### effect_late_update

Called every frame after `effect_update`. Use for:
- Drawing UI
- Camera effects

```csl
effect_late_update :: method(dt: float) {
    if player->is_local() {
        World_Progress_Bar.draw(player.entity.world_position, get_elapsed_time() / 0.5, {});
    }
}
```

### effect_end

Called when effect ends. `interrupt` is true if ended by another effect or forced.

```csl
effect_end :: method(interrupt: bool) {
    player.agent.friction = original_friction;
    player->player_set_trigger("RESET");
    
    if !interrupt {
        // Ended naturally - maybe chain to next effect
    }
}
```

## Iterating Through Effects

Use `effect_iterator` with `foreach`:

```csl
foreach effect: effect_iterator(entity) {
    if effect.#type == Slow_Effect {
        agent.movement_speed *= effect.(Slow_Effect).speed_multiplier;
    }
}
```

Manual iteration:

```csl
effect := entity.first_effect;
while effect != null {
    defer effect = effect.next_effect;
    // Process effect...
}
```

## Common Patterns

### Movement Effect (Dash/Roll)

```csl
Roll_Effect :: class : Effect_Base {
    direction: v2;
    original_friction: float;

    effect_start :: method() {
        player_specific.disable_movement_inputs = true;
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player->player_set_trigger("dodge_roll");
        player->set_facing_right(direction.x > 0);
        set_duration(0.5);
    }

    effect_update :: method(dt: float) {
        player.agent.velocity = direction * 8;
    }

    effect_end :: method(interrupt: bool) {
        player.agent.friction = original_friction;
    }
}

// Usage:
effect := new(Roll_Effect);
effect.direction = activation.direction;
player.entity->set_active_effect(effect);
```

### Passive Status Effect (Slow)

```csl
Slow_Effect :: class : Effect_Base {
    speed_multiplier: float;
}

// Apply slow
slow_effect := new(Slow_Effect);
slow_effect.speed_multiplier = 0.5;
slow_effect->set_duration(4);
entity->add_passive_effect(slow_effect);

// Check for slow in player update
foreach effect: effect_iterator(entity) {
    if effect.#type == Slow_Effect {
        agent.movement_speed *= effect.(Slow_Effect).speed_multiplier;
    }
}
```

### Attack Effect

```csl
Slash_Effect :: class : Effect_Base {
    direction: v2;
    original_friction: float;
    already_hit_list: [..]Player;

    effect_start :: method() {
        player_specific.disable_movement_inputs = true;
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player->player_set_trigger("attack");
        player->set_facing_right(direction.x > 0);
    }

    effect_update :: method(dt: float) {
        // Check for hits
        foreach other: component_iterator(Player) {
            if other.team == player.team continue;
            if !in_range(other.entity.world_position - player.entity.world_position, 0.75) continue;
            if already_hit_list->contains(other) continue;
            
            other->take_damage(1);
            already_hit_list->append(other);
        }

        player.agent.velocity = direction * 10;
        
        if get_elapsed_time() > 0.3 {
            remove_effect(false);
            return;
        }
    }

    effect_end :: method(interrupt: bool) {
        player.agent.friction = original_friction;
        player->player_set_trigger("RESET");
    }
}
```

### Death Effect

```csl
Death_Effect :: class : Effect_Base {
    effect_start :: method() {
        player_specific.freeze_player = true;
        player->add_name_invisibility_reason("death");
        player->player_set_trigger("death");
    }

    effect_update :: method(dt: float) {
        time_until_respawn := 5.0 - get_elapsed_time();
        
        if player->is_local() {
            ts := UI.default_text_settings();
            ts.size = 64;
            rect := UI.get_screen_rect()->bottom_center_rect()->offset(0, 150);
            UI.text(rect, ts, "Respawning in %s", {time_until_respawn.(int) + 1});
        }
        
        if time_until_respawn <= 0 {
            remove_effect(false);
            return;
        }
    }

    effect_end :: method(interrupt: bool) {
        player->remove_name_invisibility_reason("death");
        respawn_player(player);
        player.health->reset();
        player->player_set_trigger("RESET");
    }
}
```

## NPC Effects

For NPCs, `player` is null. Store a reference to the NPC component and use `entity` for position/transform.

```csl
NPC_Death_Effect :: class : Effect_Base {
    npc: NPC;

    effect_update :: method(dt: float) {
        t := Ease.out_quad(Ease.T(get_elapsed_time(), 1.0));
        npc.sprite.color.w = lerp(1.0, 0.0, t);

        if get_elapsed_time() > 5.0 {
            entity->destroy();
        }
    }
}

// Usage:
effect := new(NPC_Death_Effect);
effect.npc = this;
entity->set_active_effect(effect);
```

Skip normal behaviour while effect is active:

```csl
ao_update :: method(dt: float) {
    if entity.active_effect != null {
        return;  // Effect is controlling this entity
    }
    // Normal behaviour...
}
```

## Checking Effects

```csl
// Check for active effect
if entity.active_effect != null {
    // Has an active effect
}

// Check specific type
if entity.active_effect != null && entity.active_effect.#type == Eating_Effect {
    entity.active_effect.(Eating_Effect)->chomp();
}

// Remove all effects
remove_all_effects(entity);
```

## freeze_player vs disable_movement_inputs

- **`player_specific.freeze_player = true`**: Position locked entirely
- **`player_specific.disable_movement_inputs = true`**: Ignores input but code can still move player

Use `disable_movement_inputs` for dashes/rolls (need to set velocity).
Use `freeze_player` for eating/interacting (stay in place).

## Best Practices

1. **Choose the right effect type**: `set_active_effect` for exclusive control, `add_passive_effect` for stackable buffs/debuffs
2. **Use `set_duration` for timed effects** - cleaner than manual time checks
3. **Store and restore state** - save `agent.friction` etc. and restore in `effect_end`
4. **Check `interrupt` in `effect_end`** - handle forced vs natural ends differently
5. **Reset animations with `player->player_set_trigger("RESET")`**
6. **Use `remove_effect(false)` for natural completion**
