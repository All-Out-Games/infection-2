---
name: interactables
description: "Interactable system for allowing players to interact with entities in the world (pickups, buttons, NPCs, etc.)."
---
## Creating an Interactable
Inherit from `Interactable`, call `this.set_listener(this)` in `ao_start`, and implement `can_use` / `on_interact`:

```csl
My_Pickup :: class : Interactable {
    item_value: int @ao_serialize;
    is_picked_up: bool;

    ao_start :: method() {
        this.set_listener(this);
        this.set_text("Pick up");
        this.required_hold_time = 0.7; // 0 for non destructive/tactile actions
    }

    can_use :: method(player: Player) -> bool {
        if is_picked_up return false; // Return can_use false to hide interactables if they aren't relevant to the player right now. 
        return true;
    }

    on_interact :: method(player: Player) {
        is_picked_up = true;
        Economy.deposit_currency(player, "Coins", item_value.(s64));
        entity.destroy();
    }
}
```
The engine automatically shows interaction prompts when players are in range.

### Listener Callbacks
Implement these methods on your Interactable subclass:

```csl
can_use :: method(player: Player) -> bool    // Return false to prevent interaction
on_interact :: method(player: Player)        // Called when interaction completes
on_holding :: method(player: Player)         // Called each frame while player holds the interact button (optional)
```

## Optional: Player Hooks
For game-wide checks on ALL interactables, define these on your Player component:

```csl
Player :: class : Player_Base {
    // Return false in your player to block ALL interactions (e.g., player is dead)
    ao_can_use_interactable :: method(interactable: Interactable) -> bool {
        if health.is_dead return false;
        return true;
    }
}
```

## Dynamic Prompt Text
- Use `Notifier.notify(player, "message")` to send feedback on interactions that don't otherwise have feedback (e.g. "you don't have enough money") but don't overuse this because it can be annoying. 
