---
name: navmeshes-and-collision
description: "Reference this when implementing pathfinding, movement constraints, or navmesh-based spawning."
---
# CSL Navmesh System

## Components

- **Navmesh** -- Main navigation mesh container. Handles triangulation, pathfinding, and closest-point queries.
- **Navmesh_Loop** -- Defines walkable area boundaries as polygons. Can be flipped inside-out to create holes/obstacles. Automatically updates parent navmesh.
- **Movement_Agent** -- Entity movement with navmesh pathfinding support. Handles velocity, friction, speed.

## Editor Setup

> The user must do these steps manually in the editor.

1. Create an entity with a `Navmesh` component
2. Create child entities with `Navmesh_Loop` components to define walkable areas
3. For each `Navmesh_Loop`: add points for the polygon shape; set `Flip Inside Outside` to true for obstacles/holes
4. Colliders can contribute to navmesh loops via `Make Navmesh Loop` and `Flip Navmesh Loop` in inspector. **Navmesh does not automatically track colliders** -- it won't rebuild if you modify colliders at runtime.
   - Disable collider contribution with Navmesh `Ignore Colliders` = true
5. Use Navmesh `Debug Enabled` and `Debug Rebuild Every Frame` to visualize

## Code API

### Finding Closest Point on Navmesh

```csl
point: v2 = {10, 10};
result: v2;
triangle_hint: s64;  // 0 = not set; reuse for repeated nearby queries for speed

if navmesh->try_find_closest_point_on_navmesh(point, ref result, ref triangle_hint) {
    spawn_entity->set_local_position(result);
}
```

### Pathfinding with Movement_Agent

```csl
result := agent->set_path_target(target, speed);

if result.success {
    // result.next_point - next waypoint
    // result.move_direction - normalized direction
    if result.move_direction.x > 0.01 { sprite.flip_x = false; }
    else if result.move_direction.x < -0.01 { sprite.flip_x = true; }
}
```

**`set_path_target` is processed later in the frame in parallel with other agents, so the first frame you set a new target will NOT return `success == true`.**

### Locking Movement to a Navmesh

```csl
agent->set_navmesh_to_lock_to(navmesh);  // constrains agent to navmesh each frame
agent->set_navmesh_to_lock_to(null);     // clear constraint
```

### Movement_Agent Properties

```csl
agent.movement_speed = 5.0;
agent.friction = 10.0;
current_velocity := agent.velocity;       // read-only
input := agent.input_this_frame;          // read-only
```

### Forcing Navmesh Rebuild

- **`mark_for_rebuild()`** -- Deferred rebuild at start of next frame. Preferred for batching multiple changes.
- **`rebuild_immediately()`** -- Immediate rebuild. Use only when you need to query the updated navmesh in the same frame. Returns success bool.

Rebuilds needed when: modifying colliders with `MakeNavmeshLoop` at runtime, or modifying the navmesh hierarchy.

### Parent/Child Navmesh Setup

```
Parent Entity (Navmesh)
+-- Child Entity 1 (Navmesh)
|   +-- Navmesh_Loop
+-- Child Entity 2 (Navmesh)
|   +-- Navmesh_Loop
+-- Child Entity 3 (Navmesh)
    +-- Navmesh_Loop
```

Parent rebuild collects all child navmesh points and creates a unified navigation mesh with cross-boundary neighbor relationships.

**Critical gotchas:**
- **Modifying a child navmesh does NOT trigger parent rebuild** -- you must call `mark_for_rebuild()` / `rebuild_immediately()` on the parent yourself.
- **Query the parent navmesh for pathfinding** -- child navmeshes only contain their local area.
- **Set `IgnoreColliders` to true on parent navmeshes** -- prevents redundant work since children already process colliders.

## NPC Pathfinding Example

```csl
NPC :: class : Component {
    agent: Movement_Agent @ao_serialize;
    target: Entity;

    ao_update :: method(dt: float) {
        if !#alive(target) return;  // #alive checks entity validity
        result := agent->set_path_target(target.world_position, agent.movement_speed);
    }
}
```
