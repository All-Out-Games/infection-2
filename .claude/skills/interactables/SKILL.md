---
name: interactables
description: "Interactable system for allowing players to interact with entities in the world (pickups, buttons, NPCs, etc.)."
---
# CSL Interactable System

## Core Concepts

1. **Inherit from Interactable** - Your component inherits from `Interactable` and is added to entities in the editor
2. **Self-listener pattern** - Call `this->set_listener(this)` in `ao_start` and your `can_use` and `on_interact` methods are called automatically
3. **Optional global hooks** - `ao_can_use_interactable` and `ao_on_interactable_used` for game-wide checks (e.g., is the player dead?)
4. **Automatic UI** - The engine shows interaction prompts when players are in range

## Creating an Interactable

### Step 1: Create the Interactable Component

Inherit from `Interactable` and implement `can_use` and `on_interact`:

```csl
My_Pickup :: class : Interactable {
    // Your custom data
    item_value: int @ao_serialize;
    is_picked_up: bool;

    ao_start :: method() {
        // Register this component as its own listener
        this->set_listener(this);
    }

    // Return true if the player can interact with this object
    can_use :: method(player: Player) -> bool {
        if is_picked_up return false;
        return true;
    }

    // Called when the player interacts
    on_interact :: method(player: Player) {
        is_picked_up = true;
        Economy.deposit_currency(player, "Coins", item_value.(s64));
        entity->destroy();
    }
}
```

### Step 2: Set Up in Editor
> If the interactable is designed for an already existing scene entity (i.e. you aren't adding it yourself) you must instruct the user to add the interactable component to the entity in the editor. 

1. Add your interactable component (e.g., `My_Pickup`) to your entity
2. Configure the inherited interactable properties:
   - `radius` - How close the player must be to interact
   - `prompt_offset` - Where to show the interaction prompt (relative to entity)
   - `required_hold_time` - Time to hold for hold-to-interact (0 = instant)
   - `priority` - Higher priority interactables take precedence when overlapping

That's it! When `set_listener(this)` is called, the system automatically wires up callbacks to your `can_use` and `on_interact` methods.

## Optional: Player Hooks

For game-wide checks that apply to ALL interactables, you can define these optional methods on your Player component:

```csl
Player :: class : Player_Base {
    // Called before any interactable's can_use - return false to block ALL interactions
    ao_can_use_interactable :: method(interactable: Interactable) -> bool {
        // Block all interactions if player is dead
        if health.is_dead return false;
        
        // Block during cutscenes
        if g_game.in_cutscene return false;
        
        return true;
    }

    // Called after any interactable's on_interact - for logging, achievements, etc.
    ao_on_interactable_used :: method(interactable: Interactable) {
        // Track total interactions for achievements
        total_interactions += 1;
        
        // Analytics logging
        log_info("Player % used interactable %", {this->get_username(), interactable.entity->get_name()});
    }

    // Called once per frame while the player is holding on a hold-to-interact
    ao_on_holding_interactable :: method(interactable: Interactable) {
        // Custom logic while holding (e.g., play looping sound, show progress)
    }
}
```

**When to use player hooks vs listener methods:**
- Use `ao_can_use_interactable` for game-wide rules (dead players can't interact, frozen during cutscenes)
- Use listener's `can_use` for object-specific rules (this chest is locked, player needs a key)
- Use `ao_on_interactable_used` for global side effects (achievements, analytics)
- Use listener's `on_interact` for object-specific behavior (open the chest, give the item)
- Use `ao_on_holding_interactable` for continuous feedback during hold interactions

## Interactable Properties

These properties are inherited when your class extends `Interactable`:

```csl
Interactable :: class : Component {
    prompt_offset: v2;       // Offset for the "Press E" prompt display
    radius: float;           // Interaction range in world units
    required_hold_time: float; // Hold duration for hold-to-interact (0 = tap)
    priority: s64;           // Higher = takes precedence when multiple in range
}
```

Access and modify these directly on `this` since your component inherits from `Interactable`:

```csl
ao_start :: method() {
    this->set_listener(this);
    required_hold_time = 1.5;  // Set hold time to 1.5 seconds
    priority = 10;             // Higher priority than default
}
```

## Interactable Methods

```csl
// Register this component as its own listener - automatically calls can_use and on_interact
this->set_listener(this);

// Get/set the prompt text shown to the player
text := this->get_text();
this->set_text("Pick up");

// Get/set the hold prompt text (shown during hold interactions)
hold_text := this->get_hold_text();
this->set_hold_text("Picking up...");
```

## Example: Sell Zone

A zone where players can sell items:

```csl
Sell_Zone :: class : Interactable {
    particle_target: Entity @ao_serialize;

    ao_start :: method() {
        this->set_listener(this);
    }

    can_use :: method(player: Player) -> bool {
        // Only usable if player has food to sell
        food_count := Economy.get_balance(player, "Food");
        return food_count > 0;
    }

    on_interact :: method(player: Player) {
        food_count := Economy.get_balance(player, "Food");
        
        // Convert food to coins
        Economy.withdraw_currency(player, "Food", food_count);
        Economy.deposit_currency(player, "Coins", food_count);
        
        // Play effects
        sfx := SFX.default_sfx_desc();
        sfx->set_position(entity.world_position);
        SFX.play(get_asset(SFX_Asset, "sfx/sell.wav"), sfx);
    }
}
```

## Example: Pickup Item

An item that can be picked up and carried:

```csl
Fuel_Canister :: class : Interactable {
    is_picked_up: bool;
    carrier: Player;

    ao_start :: method() {
        this->set_listener(this);
    }

    can_use :: method(player: Player) -> bool {
        // Can't pick up if already picked up
        if is_picked_up return false;
        
        // Can't pick up if player is already carrying something
        if is_player_carrying_item(player) return false;
        
        // Only survivors can pick up
        if player.team != .SURVIVOR return false;
        
        return true;
    }

    on_interact :: method(player: Player) {
        is_picked_up = true;
        carrier = player;
        
        player->add_notification("Picked up fuel canister!");
        
        sfx := SFX.default_sfx_desc();
        sfx->set_position(entity.world_position);
        SFX.play(get_asset(SFX_Asset, "sfx/pickup.wav"), sfx);
    }
}
```

## Example: Delivery Point

A destination where carried items are delivered:

```csl
Fuel_Delivery_Point :: class : Interactable {
    ao_start :: method() {
        this->set_listener(this);
    }

    can_use :: method(player: Player) -> bool {
        // Only usable if carrying a fuel canister
        item := get_player_carried_item(player);
        if item == null return false;
        
        canister := item.entity->get_component(Fuel_Canister);
        return canister != null;
    }

    on_interact :: method(player: Player) {
        item := get_player_carried_item(player);
        canister := item.entity->get_component(Fuel_Canister);
        
        // Update game state
        g_game.fuel_deposited += 1;
        
        // Play feedback
        sfx := SFX.default_sfx_desc();
        sfx->set_position(entity.world_position);
        SFX.play(get_asset(SFX_Asset, "sfx/deposit.wav"), sfx);
        
        // Destroy the delivered item
        canister.entity->destroy();
        
        // Notify player
        player->add_notification(format_string("Fuel delivered! (% / %)", {g_game.fuel_deposited, REQUIRED_FUEL}));
    }
}
```

## Example: Task-Gated Interaction

An interaction that's only available during certain game states:

```csl
Escape_Pod :: class : Interactable {
    ao_start :: method() {
        this->set_listener(this);
    }

    can_use :: method(player: Player) -> bool {
        // Only available during escape phase
        if g_game.current_task != .ESCAPE return false;
        
        // Only survivors can escape
        if player.team != .SURVIVOR return false;
        
        // Can't escape if already escaped
        if player.has_escaped return false;
        
        return true;
    }

    on_interact :: method(player: Player) {
        player.has_escaped = true;
        player->add_notification("You escaped!");
        
        // Notify other players
        foreach p: component_iterator(Player) {
            if p != player {
                p->add_notification("A survivor escaped!");
            }
        }
    }
}
```

## Dynamic Prompt Text

Change the prompt text based on state:

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
            if contains_key {
                this->set_text("Take Key");
            }
            else {
                this->set_text("Empty");
            }
        }
        else {
            this->set_text("Open Chest");
        }
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

## Best Practices

1. **Always call `this->set_listener(this)` in `ao_start`** - This wires up automatic callbacks to your `can_use` and `on_interact` methods
2. **Use global hooks for global rules only** - Game-wide checks like "is player dead" belong in `ao_can_use_interactable`, not in every listener
3. **Check object-specific state in `can_use`** - Conditions specific to this interactable (is it already used? does player have required item?)
4. **Play feedback in `on_interact`** - Sound effects, particles, and notifications make interactions feel good
5. **Use `priority`** - When interactables overlap, higher priority ones take precedence
6. **Update prompt text dynamically** - Call `this->set_text()` when the interaction meaning changes
