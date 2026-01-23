---
name: navmeshes-and-collision
description: "Reference this when implementing pathfinding, movement constraints, or navmesh-based spawning."
---
# CSL Navmesh System

Navmeshes are used for pathfinding and movement constraints in your game. They define walkable areas for the player, NPCs, enemies, or any entity that needs to navigate the game world.

## Components Overview

### Navmesh Component

The `Navmesh` component is the main container for your navigation mesh. It handles:
- Triangulation of the defined area
- Pathfinding queries
- Closest point queries

### Navmesh_Loop Component

The `Navmesh_Loop` component defines the boundaries of walkable areas. Key features:
- Defines a polygon through a series of points
- Can be flipped inside-out to create holes/obstacles
- Automatically updates parent navmesh when modified

### Movement_Agent Component

The `Movement_Agent` component handles entity movement with navmesh support:
- Automatic pathfinding to target positions
- Can be locked to a specific navmesh
- Handles velocity, friction, and movement speed

## Editor Usage
> The user will need to do these things in the editor manually to set up the navmesh. 
1. Create an entity and add a `Navmesh` component to it
2. Create child entities with `Navmesh_Loop` components to define walkable areas
3. For each `Navmesh_Loop`:
   - Add points to define the polygon shape
   - Set `Flip Inside Outside` to true if defining an obstacle/hole
   - The loop will automatically update the parent navmesh
4. Colliders can also contribute to navmesh loops using Collider `Make Navmesh Loop` and `Flip Navmesh Loop` in the inspector. Note that `Navmesh` does not automatically track colliders, so it won't rebuild if you modify colliders at runtime.
   - You can disable colliders contributing to a navmesh by setting Navmesh `Ignore Colliders` to true
5. Use Navmesh `Debug Enabled` and `Debug Rebuild Every Frame` in the inspector to visualize your navmesh

By default a `Navmesh_Loop` defines a walkable area. To punch holes in a navmesh to define unwalkable areas, toggle the `Flip Inside Outside` field on the `Navmesh_Loop`.

## Code API Usage

### Finding Closest Point on Navmesh

Use `try_find_closest_point_on_navmesh` to find the nearest valid position on a navmesh. This is useful for spawning loot or enemies to ensure they're reachable by players.

```csl
point: v2 = {10, 10};
result: v2;
triangle_hint: int;

if navmesh->try_find_closest_point_on_navmesh(point, ref result, ref triangle_hint) {
    // result now contains the closest point on the navmesh
    spawn_entity->set_local_position(result);
}
```

The `triangle_hint` parameter can be used to speed up repeated queries in the same area by reusing the previous value for subsequent nearby queries. `0` means "not set yet" so just doing `triangle_hint: int;` is fine.

### Pathfinding with Movement_Agent

The `Movement_Agent` component provides built-in pathfinding via `set_path_target`:

```csl
target: v2 = {100, 50};
speed := 5.0;

result := agent->set_path_target(target, speed);

if result.success {
    // Pathfinding succeeded. Agent will automatically path towards the given target at the given speed.
    // result.next_point - the next waypoint to move toward
    // result.move_direction - normalized direction to move

    // Flip the sprite to face towards the movement direction
    if result.move_direction.x > 0.01 {
        sprite.flip_x = false;
    }
    else if result.move_direction.x < -0.01 {
        sprite.flip_x = true;
    }
}
```

`set_path_target` is processed later in the frame in parallel with other agents so the first frame you set a new target will definitely _not_ return `success == true`.

### Locking Movement to a Navmesh

By default, an agent can walk wherever. If you want to constrain the agent's movement to a navmesh call `Movement_Agent.set_navmesh_to_lock_to()`. With this set, every frame the agent will be snapped to the closest position on that navmesh. You can call it with `null` to clear it.

```csl
agent->set_navmesh_to_lock_to(navmesh);
```

### Movement_Agent Properties

```csl
// Movement configuration
agent.movement_speed = 5.0;    // Base movement speed
agent.friction = 10.0;         // How quickly velocity decays

// Read-only state
current_velocity := agent.velocity;        // Current movement velocity
input := agent.input_this_frame;           // Input applied this frame
```

### Forcing Navmesh Rebuild

There are two ways to trigger a navmesh rebuild:

**`mark_for_rebuild`** - Deferred rebuild at the start of next frame (preferred for batching multiple changes):

```csl
navmesh->mark_for_rebuild();
```

**`rebuild_immediately`** - Forces an immediate rebuild (use when you need the updated navmesh right away):

```csl
success := navmesh->rebuild_immediately();
if !success {
    log_info("Navmesh rebuild failed", {});
}
```

When making multiple navmesh modifications, use `mark_for_rebuild` on each and let them all rebuild together at the start of the next frame. Only use `rebuild_immediately` if you need to query the updated navmesh in the same frame.

Rebuilds are typically needed when:
1. You modify colliders with `MakeNavmeshLoop` enabled at runtime
2. You modify the navmesh hierarchy (add/remove `Navmesh_Loop` children)

### Setup

1. Create an entity with a `Navmesh` component (parent)
2. Create child entities with their own `Navmesh` components
3. Each child navmesh has its own `Navmesh_Loop` children

```
Parent Entity (Navmesh)
├── Child Entity 1 (Navmesh)
│   └── Navmesh_Loop
├── Child Entity 2 (Navmesh)
│   └── Navmesh_Loop
└── Child Entity 3 (Navmesh)
    └── Navmesh_Loop
```

When the parent navmesh is rebuilt, it will:
1. Collect all points from child navmeshes
2. Preserve triangle relationships within each child
3. Calculate new neighbor relationships across navmesh boundaries
4. Create a single unified navigation mesh

### Important Notes

- **Modifying a child navmesh does not trigger a rebuild of the parent** - You must call `mark_for_rebuild()` or `rebuild_immediately()` on the parent after modifying children
- **Query the parent navmesh for pathfinding** - Individual child navmeshes only contain their local area
- **Set `IgnoreColliders` to true on parent navmeshes** - Prevents redundant work since children already process colliders

## Common Patterns

### Spawning on Navmesh

Ensure spawned entities are reachable by players:

```csl
spawn_on_navmesh :: proc(navmesh: Navmesh, desired_position: v2) -> Entity {
    spawn_pos: v2;
    hint: int;
    
    if navmesh->try_find_closest_point_on_navmesh(desired_position, ref spawn_pos, ref hint) {
        entity := create_entity();
        entity->set_local_position(spawn_pos);
        return entity;
    }
    
    return null;
}
```

### NPC Pathfinding

Basic NPC that follows a target:

```csl
NPC :: class : Component {
    agent: Movement_Agent @ao_serialize;

    target: Entity;
    
    ao_update :: method(dt: float) {
        if !#alive(target) return;
        
        result := agent->set_path_target(target.world_position, agent.movement_speed);
        
        if !result.success {
            // Target unreachable, handle accordingly
        }
    }
}
```
