---
name: inventory-droppable-items
description: "When an inventory should have items that can be dropped into the world."
---
# Dropped Items System
> Used when you want a player to be able to drop an item from their inventory into the world, allowing it to be picked up by other players etc...

### Import

```csl
import "core:dropped_items"
```

### Core Concepts

1. **Items spawn at a position** - Use `Dropped_Item.spawn()` to create a dropped item entity
2. **Animate after spawning** - Call `do_spawn_animation()` to make items arc and land at a random nearby position
3. **Auto-despawn** - Items automatically despawn after 40 seconds (30s warning + 10s countdown bar)
4. **Interactable pickup** - Players hold to pick up items via the interactable system

## Basic Usage

### Spawning an Item

```csl
// Create an item instance from a definition
item := Items.create_item_instance(my_item_definition);

// Spawn it in the world
dropped := Dropped_Item.spawn(player.entity.world_position, item);

// Animate it bouncing to a random nearby position. The navmesh parameter is optional.
dropped->do_spawn_animation(ref server_rng, navmesh);
```

### Handling Hotbar Drops

When using `Items.draw_hotbar()`, players can drag items out to drop them. Use `handle_dropped_item()` to process this:

## Dropped Item API

### Dropped_Item.spawn

Creates a dropped item entity at the specified position.

```csl
spawn :: proc(position: v2, item: Item_Instance) -> Dropped_Item
```

**Parameters:**
- `position` - World position to spawn the item at
- `item` - The item instance to drop (created via `Items.create_item_instance()`)

**Returns:** The `Dropped_Item` component attached to the new entity

**Example:**
```csl
item := Items.create_item_instance(apple_definition);
dropped := Dropped_Item.spawn(enemy.entity.world_position, item);
```

**Notes:**
- Creates a complete entity with sprite, starburst effect (colored by tier), and shadow
- Automatically adds an `Interactable` component for player pickup
- The item starts at `position` and stays there until `do_spawn_animation()` is called

### do_spawn_animation

Animates the dropped item arcing to a random nearby position.

```csl
do_spawn_animation :: method(rng: ref u64, snap_to_navmesh: Navmesh = null)
```

**Parameters:**
- `rng` - Reference to a random seed (will be modified)
- `snap_to_navmesh` - Optional navmesh to constrain the landing position to walkable areas

**Example:**
```csl
dropped := Dropped_Item.spawn(position, item);
dropped->do_spawn_animation(ref server_rng, g_game_manager.navmesh);
```

**Notes:**
- Picks a random target position within 1-2 units of the spawn position
- If `snap_to_navmesh` is provided, clamps the target to the nearest point on the navmesh
- The item animates in an arc from `start_position` to `target_position` over 0.5 seconds

### Dropped_Item.handle_dropped_item

Helper function to process items dropped from the hotbar UI.

```csl
handle_dropped_item :: proc(hotbar_result: Draw_Hotbar_Result, position: v2, out_item: ref Dropped_Item) -> bool
```

**Parameters:**
- `hotbar_result` - The result from `Items.draw_hotbar()`
- `position` - World position to spawn the dropped item at (usually the player position)
- `out_item` - Output parameter that receives the created `Dropped_Item`

**Returns:** `true` if an item was dropped, `false` otherwise

**Example:**
```csl
result := Items.draw_hotbar(this, default_inventory, desc);
dropped: Dropped_Item;
if Dropped_Item.handle_dropped_item(result, entity.world_position, ref dropped) {
    // Item was dropped - animate it
    dropped->do_spawn_animation(ref server_rng, navmesh);
}
```

**Notes:**
- Automatically removes the item from its inventory before spawning
- Only returns `true` if `hotbar_result.dropped_item` is not null
- You should call `do_spawn_animation()` on the result to animate the drop

### set_exclusive

Makes the dropped item exclusive to a specific player. Only that player will be able to see and pick up the item.

```csl
set_exclusive :: method(player: Player)
```

**Parameters:**
- `player` - The player who should have exclusive access to this item

**Example:**
```csl
dropped := Dropped_Item.spawn(enemy.entity.world_position, item);
dropped->do_spawn_animation(ref server_rng, navmesh);
dropped->set_exclusive(player_who_killed_enemy);
```

**Notes:**
- The item becomes invisible to all other players
- Other players cannot interact with the item even if they know its position
- Pass `null` to remove the exclusivity and make the item visible to everyone again

### Dropped_Item Class Fields

```csl
Dropped_Item :: class : Component {
    item: Item_Instance;           // The item being held
    sprite: Sprite_Renderer;       // Main item icon
    starburst: Sprite_Renderer;    // Rotating effect behind item (colored by tier)
    shadow: Sprite_Renderer;       // Ground shadow
    interactable: Interactable;    // For player pickup
    
    spawn_time: float;             // When the item was created
    despawn_time_start: float;     // When despawn timer started (reset on player interaction)
    start_position: v2;            // Initial spawn position
    target_position: v2;           // Where the item lands after animation
    
    claimed: bool;                 // True when a player picks it up
    exclusive_to_player: string;   // If set, only this player can see/pick up the item
    
    DESPAWN_WARNING_TIME :: 30.0;  // Seconds before despawn bar appears
    DESPAWN_DURATION :: 10.0;      // Seconds the bar counts down
}
```

### Despawn Behavior

- Items exist for 40 seconds total (30s normal + 10s warning)
- After 30 seconds, a red countdown bar appears above the item
- When a player holds the interact button on an item, the despawn timer resets
- When picked up, the item plays a fade-out animation before being destroyed

## #Visual Effects

The dropped item system automatically creates:

1. **Item Icon** - Scaled to ~1 world unit, rendered at the item's position
2. **Starburst** - Rotating effect behind the item, colored based on item tier:
   - Size scales with tier (0.75 to 1.0 world units)
   - Color matches `get_tier_color(defn.tier)`
3. **Shadow** - Small oval shadow beneath the item
4. **Arc Animation** - Items bounce in an arc when `do_spawn_animation()` is called
5. **Pickup Animation** - Items stretch upward and fade when collected

### Complete Dropped Item Example

```csl
import "core:dropped_items"

server_rng: u64;
game_navmesh: Navmesh;

// Drop a random item when an enemy dies
on_enemy_death :: proc(enemy: Enemy) {
    // Create and spawn the item
    reward := get_random_reward();
    item := Items.create_item_instance(reward);
    dropped := Dropped_Item.spawn(enemy.entity.world_position, item);
    
    // Animate it bouncing to a nearby position on the navmesh
    dropped->do_spawn_animation(ref server_rng, game_navmesh);
}

// Handle player dropping items from their inventory
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
        if this->is_local_or_server() {
            desc := Inventory_Draw_Options.default();
            result := Items.draw_hotbar(this, default_inventory, desc);
            
            dropped: Dropped_Item;
            if Dropped_Item.handle_dropped_item(result, entity.world_position, ref dropped) {
                dropped->do_spawn_animation(ref server_rng, game_navmesh);
            }
        }
    }
}
```

## Best Practices

1. **Always call `do_spawn_animation()`** after spawning to make items land naturally
2. **Pass a navmesh** to `do_spawn_animation()` to keep items in walkable areas
3. **Use a server-side RNG** for multiplayer consistency
4. **Handle hotbar drops** whenever you call `Items.draw_hotbar()`
