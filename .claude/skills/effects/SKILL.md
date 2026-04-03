---
name: effects
description: "Reference this when implementing effects for abilities, animations, and state-based behaviors."
---
# CSL Effect System

Effects temporarily take control of an entity to execute complex behaviors (dashes, attacks, death sequences). Works with Players, NPCs, or any entity.

## Creating an Effect

```csl
My_Effect :: class : Effect_Base {
    target_position: v2;

    effect_start :: method() {
        player_specific.freeze_player = true;
        player.animator.instance.state_machine->set_trigger("my_animation");
    }

    effect_update :: method(dt: float) {
        entity->lerp_local_position(target_position, 20 * dt);
        if get_elapsed_time() > 1.0 {
            remove_effect(false);
            return;  // Effect is invalid after removal -- must return immediately
        }
    }

    effect_end :: method(interrupt: bool) {
        if !interrupt {
            entity->set_local_position(target_position);
        }
        player.animator.instance.state_machine->set_trigger("RESET");
    }
}
```

## Activating Effects

**Active effects** (`set_active_effect`) -- one at a time, setting a new one ends the current with `interrupt = true`:
```csl
effect := new(My_Effect);
effect.target_position = target.world_position;
entity->set_active_effect(effect);
```

**Passive effects** (`add_passive_effect`) -- multiple allowed, stack (slows, buffs):
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
        freeze_player: bool;           // Lock position entirely (use for eat/interact)
        disable_movement_inputs: bool; // Ignore input but code can still move (use for dash/roll)
    };

    start_time: float;
    next_effect: Effect_Base;  // Linked list traversal
    prev_effect: Effect_Base;
}
```

## Key Methods

- `get_elapsed_time()` -- Time since effect started.
- `set_duration(seconds)` -- Auto-remove after time. Call when creating or in `effect_start`.
- `remove_effect(interrupt: bool)` -- End the effect. Pass `false` for natural completion, `true` for forced. **Effect is invalid after this call -- return immediately.**

## Callbacks

All optional. Implement only what you need.

- `effect_start` -- Set freeze/movement flags, trigger animations, store initial state, call `set_duration`.
- `effect_update(dt: float)` -- Per-frame logic: move entity, check completion.
- `effect_late_update(dt: float)` -- Post-update: draw UI, camera effects. Use `player->is_local()` to gate local-only visuals.
- `effect_end(interrupt: bool)` -- Restore saved state, reset animations with `player.animator.instance.state_machine->set_trigger("RESET")`.

## Iterating Effects

```csl
foreach effect: effect_iterator(entity) {
    if effect.#type == Slow_Effect {
        agent.movement_speed *= effect.(Slow_Effect).speed_multiplier;
    }
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
        player.animator.instance.state_machine->set_trigger("dodge_roll");
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
```

### Attack Effect (Hit Detection)

Key pattern: use `already_hit_list` to avoid hitting the same target twice, and `component_iterator` to find targets.

```csl
Slash_Effect :: class : Effect_Base {
    direction: v2;
    original_friction: float;
    already_hit_list: [..]Player;

    effect_start :: method() {
        player_specific.disable_movement_inputs = true;
        original_friction = player.agent.friction;
        player.agent.friction = 0;
        player.animator.instance.state_machine->set_trigger("attack");
        player->set_facing_right(direction.x > 0);
    }

    effect_update :: method(dt: float) {
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
        player.animator.instance.state_machine->set_trigger("RESET");
    }
}
```

### Death/Respawn Effect

Shows timed respawn with local-only UI via `player->is_local()`. Assumes your Player class defines a `health` field and a `respawn_player` procedure.

```csl
// Your Player class would define these:
// health: Health_Component;
// respawn_player :: proc(player: Player) { ... }

Death_Effect :: class : Effect_Base {
    effect_start :: method() {
        player_specific.freeze_player = true;
        player->add_name_invisibility_reason("death");
        player.animator.instance.state_machine->set_trigger("death");
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
        player.animator.instance.state_machine->set_trigger("RESET");
    }
}
```

### NPC Effects

For NPCs, `player` is null. Store a reference to the NPC component and use `entity` for transforms.

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

Skip normal behavior while an effect is active:
```csl
ao_update :: method(dt: float) {
    if entity.active_effect != null return;
    // Normal behaviour...
}
```

## Checking Effects

```csl
if entity.active_effect != null && entity.active_effect.#type == Eating_Effect {
    entity.active_effect.(Eating_Effect)->chomp();
}

remove_all_effects(entity);  // Remove all active and passive effects
```
