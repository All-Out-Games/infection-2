---
name: inventory-droppable-items
description: "When an inventory should have items that can be dropped into the world."
---
# Dropped Items System

Allows players to drop items from inventory into the world for other players to pick up.

### Import

```csl
import "core:dropped_items"
```

## Spawning a Dropped Item

```csl
item := Items.create_item_instance(my_item_definition);
dropped := Dropped_Item.spawn(player.entity.world_position, item);
dropped->do_spawn_animation(ref server_rng, navmesh);
```

`spawn` creates a complete entity with sprite, starburst effect (colored by tier), shadow, and an `Interactable` for pickup. Items auto-despawn after 40 seconds (30s normal + 10s with countdown bar). Holding the interact button resets the despawn timer.

## API

### Dropped_Item.spawn

```csl
spawn :: proc(position: v2, item: Item_Instance) -> Dropped_Item
```

### do_spawn_animation

Animates the item arcing to a random position 1-2 units away over 0.5 seconds.

```csl
do_spawn_animation :: method(rng: ref u64, snap_to_navmesh: Navmesh = null)
```

If `snap_to_navmesh` is provided, clamps landing position to the nearest walkable point.

### Dropped_Item.handle_dropped_item

Processes items dragged out of the hotbar UI. Automatically removes the item from inventory before spawning.

```csl
handle_dropped_item :: proc(hotbar_result: Draw_Hotbar_Result, position: v2, out_item: ref Dropped_Item) -> bool
```

Returns `true` if an item was dropped. Call `do_spawn_animation()` on the result.

```csl
result := Items.draw_hotbar(this, default_inventory, desc);
dropped: Dropped_Item;
if Dropped_Item.handle_dropped_item(result, entity.world_position, ref dropped) {
    dropped->do_spawn_animation(ref server_rng, navmesh);
}
```

### set_exclusive

Makes the item visible and interactable only to a specific player. Pass `null` to remove exclusivity.

```csl
set_exclusive :: method(player: Player)
```

```csl
dropped := Dropped_Item.spawn(enemy.entity.world_position, item);
dropped->do_spawn_animation(ref server_rng, navmesh);
dropped->set_exclusive(player_who_killed_enemy);
```

### Class Fields

```csl
Dropped_Item :: class : Component {
    item: Item_Instance;
    sprite: Sprite_Renderer;
    starburst: Sprite_Renderer;
    shadow: Sprite_Renderer;
    interactable: Interactable;

    visual_root: Entity;

    spawn_time: float;
    despawn_time_start: float;
    start_position: v2;
    target_position: v2;

    is_animating: bool;
    claimed: bool;
    time_claimed: float;

    exclusive_to_player: string;

    DESPAWN_WARNING_TIME :: 30.0;
    DESPAWN_DURATION :: 10.0;
}
```
