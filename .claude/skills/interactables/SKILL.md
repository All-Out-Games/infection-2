---
name: interactables
description: "Interactable system for allowing players to interact with entities in the world (pickups, buttons, NPCs, etc.)."
---
# CSL Interactable System

## Creating an Interactable

Inherit from `Interactable`, call `this->set_listener(this)` in `ao_start`, and implement `can_use` / `on_interact`:

```csl
My_Pickup :: class : Interactable {
    item_value: int @ao_serialize;
    is_picked_up: bool;

    ao_start :: method() {
        this->set_listener(this);
    }

    can_use :: method(player: Player) -> bool {
        if is_picked_up return false;
        return true;
    }

    on_interact :: method(player: Player) {
        is_picked_up = true;
        Economy.deposit_currency(player, "Coins", item_value.(s64));
        entity->destroy();
    }
}
```

The engine automatically shows interaction prompts when players are in range.

### Editor Setup
> If the interactable is designed for an already existing scene entity (i.e. you aren't adding it yourself) you must instruct the user to add the interactable component to the entity in the editor.

Add your component to an entity and configure inherited properties:
- `radius` - Interaction range in world units
- `prompt_offset` - Where to show the prompt (relative to entity)
- `required_hold_time` - Hold duration (0 = instant tap)
- `priority` - Higher takes precedence when overlapping

## Interactable Methods

```csl
this->set_listener(this);
this->set_text("Pick up");
this->set_hold_text("Picking up...");
text := this->get_text();
hold_text := this->get_hold_text();
```

### Listener Callbacks

Implement these methods on your Interactable subclass:

```csl
can_use :: method(player: Player) -> bool    // Return false to prevent interaction
on_interact :: method(player: Player)        // Called when interaction completes
on_holding :: method(player: Player)         // Called each frame while player holds the interact button
```

## Optional: Player Hooks

For game-wide checks on ALL interactables, define these on your Player component:

```csl
Player :: class : Player_Base {
    // Return false to block ALL interactions (e.g., player is dead)
    ao_can_use_interactable :: method(interactable: Interactable) -> bool {
        if health.is_dead return false;
        return true;
    }

    // Called after any on_interact (logging, achievements)
    ao_on_interactable_used :: method(interactable: Interactable) {
        total_interactions += 1;
    }

    // Called each frame while holding on a hold-to-interact
    ao_on_holding_interactable :: method(interactable: Interactable) {
    }
}
```

- `ao_can_use_interactable` for global rules; listener `can_use` for object-specific rules.
- `ao_on_interactable_used` for global side effects; listener `on_interact` for object-specific behavior.

## Dynamic Prompt Text

Change prompt text based on state using `set_text()`:

```csl
Chest :: class : Interactable {
    is_open: bool;
    contains_key: bool;

    ao_start :: method() {
        this->set_listener(this);
        update_prompt_text();
    }

    update_prompt_text :: method() {
        if is_open {
            if contains_key { this->set_text("Take Key"); }
            else { this->set_text("Empty"); }
        }
        else { this->set_text("Open Chest"); }
    }

    can_use :: method(player: Player) -> bool {
        if is_open && !contains_key return false;
        return true;
    }

    on_interact :: method(player: Player) {
        if !is_open {
            is_open = true;
        }
        else if contains_key {
            contains_key = false;
            player.has_key = true;
        }
        update_prompt_text();
    }
}
```
