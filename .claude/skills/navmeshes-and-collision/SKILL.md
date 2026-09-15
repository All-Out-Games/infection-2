---
name: navmeshes-and-collision
description: Reference this when implementing Movement_Agent movement or knockback, tuning speed/friction/velocity, pathfinding, movement collision, collider triggers, or navmesh-based spawning.
---
Be very careful and sparing with collision. Do not add it to most entities unless collision is absolutely required (preventing players from going out of bounds). Every game flow must carefully test that no collisions accidentally block the player from moving to their intended area and never point a tutorial arrow in a direction that would block the player from moving. Never spawn the player on top of a collider. 

## Components
- Navmesh Main navigation mesh container. Handles triangulation, pathfinding, and closest-point queries.
- Navmesh_Loop Defines walkable area boundaries as polygons. Can be flipped inside-out to create holes/obstacles. Automatically updates parent navmesh.
- Movement_Agent Entity movement with navmesh pathfinding, simple collider movement, and trigger detection.
- Colliders `Box_Collider`, `Circle_Collider`, `Polygon_Collider`, and `Edge_Collider` can block Movement_Agent movement or act as trigger volumes. `Box_Collider.size` is the full width/height (centered on `offset`), not half extents; `Circle_Collider` takes `radius` in editor JSON. Both `size`/`offset` and `radius` are in the entity's local space and are multiplied by the entity's transform scale: a wall sprite scaled to `[0.25, 11.5]` with `size: [4, 4]` is a 1 x 46 world-unit box, so either give the collider `size: [4, 4]` on the scaled entity or `size: [1, 46]` on an unscaled one, never both. `get_points_local` returns the unscaled values, `get_points_world` the scaled ones. `Edge_Collider` blocks along its segments only (`is_loop` just adds the closing segment); the interior is never solid. A closed shoreline loop is therefore a fence in both directions: nothing crosses it unless the loop has a gap where the bridge is.

## Scene Setup
1. Create an entity with a `Navmesh` component
2. Create direct child entities with `Navmesh_Loop` components to define walkable areas
3. For each `Navmesh_Loop`: add at least three non-collinear points for the polygon shape; set `Flip Inside Outside` to true for obstacles/holes
4. Colliders can contribute to navmesh loops via `Make Navmesh Loop` and `Flip Navmesh Loop` in inspector. A contributing `Edge_Collider` also needs at least three non-collinear points; its point list is closed for navmesh generation regardless of `is_loop`, which only controls physical edge closure. Navmeshes automatically hash loop/collider/tilemap inputs each frame and rebuild when those inputs change. To avoid scene-wide collider scans on nested/parent navmeshes, set Navmesh `Child Colliders Only` = true; then each contributing collider must be on the Navmesh entity or one of its descendants. This flag only filters colliders and tilemaps; `Navmesh_Loop` children are always read from the navmesh's direct children and are unaffected by it.
5. Use Navmesh `Debug Enabled` and `Debug Rebuild Every Frame` to visualize with the editor screenshot tool. The screenshot tool synchronously rebuilds debug navmeshes first, so a valid walkable area is covered with triangles in the returned image. If it is not, read the components back and verify the direct-child relationship and point count.
6. Loops that do not overlap are separate walkable islands: the mesh never bridges a gap between them. A bridge between islands must lie inside a loop, so extend one island's loop across the bridge or add a bridge loop that overlaps both islands. Overlapping loops union into one connected area. Keep a bridge's collider gap and its loop in sync; when the shoreline is an `Edge_Collider`, prefer `Make Navmesh Loop` on that collider over a sibling `Navmesh_Loop` holding a second copy of the points.

`Navmesh_Loop` point editing is editor/scene-tool data. CSL currently exposes `Navmesh_Loop` as an empty component, so do not write scripts that read or mutate `Navmesh_Loop.points` directly (`Polygon_Collider` does expose read-only `get_points_local`/`get_points_world`). For script-driven shapes, use collider components with `make_navmesh_loop` / `flip_navmesh_loop`, or create/edit loop points through the editor/MCP scene tools.

### Closest Point
```csl
point: v2 = {10, 10};
result: v2;
triangle_hint: s64; // 0 = not set; reuse for repeated nearby queries for speed

if navmesh.try_find_closest_point_on_navmesh(point, ref result, ref triangle_hint) {
    spawn_entity.set_world_position(result);
}
```

There is no separate on-navmesh query: the result equals the input point when the point is inside a triangle, so `length(result - point) < 0.01` tests whether a point is on the mesh and the distance says how far off it is.

### Pathfinding with Movement_Agent
```csl
agent.agent_radius = 0.5; // pathfinding clearance radius
result := agent.set_path_target(target, speed);

if result.success {
    // result.next_point
    // result.move_direction // normalized
    if result.move_direction.x > 0.01 { sprite.flip_x = false; }
    else if result.move_direction.x < -0.01 { sprite.flip_x = true; }
}
```

`set_path_target` queues the new target and returns the previous processed pathfind result. Ignore the first call's return, and treat the result as one-frame stale when changing targets.

`agent_radius` controls pathfinding clearance. Increase it when an agent should route wider around corners or stay farther from navmesh edges. To fully avoid walls during actual movement, the agent should also have a collider, usually a `Circle_Collider`, with a matching radius.

### Locking Movement to a Navmesh
```csl
agent.set_navmesh_to_lock_to(navmesh);
agent.set_navmesh_to_lock_to(null); // clear
```

The lock clamps the agent's position to the nearest point of that navmesh every physics tick, including direct WASD/joystick movement; an off-mesh agent snaps back onto it. If the referenced navmesh is disabled or has no valid triangles the agent silently falls back to the nearest navmesh in the scene. So a player who still walks somewhere they should not is walking on a mesh that covers that area (check the loop points), not ignoring the lock.

### Movement_Agent Properties
```csl
agent.movement_speed = 300.0; // input tuning value: ~5 world units/s at friction 0.5
agent.friction = 0.5;
current_velocity := agent.velocity; // writable, in world units per second
agent.input_this_frame = dir; // write-only from scripts: consumed and zeroed by the movement update before your callbacks run, so reading it always gives {0,0}
input := player.input_this_frame; // what the local player is actually pressing this frame
```

`movement_speed` is not a velocity. It is an acceleration-like input tuning value processed through `friction`; with constant full input, `movement_speed = 300` and `friction = 0.5` settle at approximately 5 world units/s. `velocity` is the actual world-space velocity: the physics step advances position by `velocity * dt`, so `{0, 5}` means 5 world units/s upward. For knockback, choose or add a `velocity` in world-units-per-second terms, not in the `movement_speed` tuning scale.

`friction` is the fraction of velocity lost per 1/60-second reference frame, adjusted by the engine so behavior is stable at other simulation rates: `0` preserves velocity and `0.5` halves it every reference frame. For constant full input and `0 < friction < 1`, terminal speed is approximately `movement_speed * (1 - friction) / (60 * friction)`.

### CSL Movement Physics and Triggers
Agent's enabled non-trigger colliders block against enabled non-trigger world colliders taking `category_bits` / `mask_bits` filtering into account. These filter fields are configured in editor/native data and are not currently exposed in `core:ao`.

Filtering: two colliders interact only when each one's `mask_bits` contains the other's `category_bits`. Both are u32 bitmasks. Every collider defaults to `category_bits: 1` and `mask_bits: 4294967295` (all bits). The player's collider is set by the engine at spawn to `category_bits: 2` with `mask_bits` = everything except bit 2, so players never collide with each other. Leave both fields at their defaults; setting `mask_bits: 1` on a wall makes the player walk straight through it (the wall's mask no longer contains the player's category 2), and setting `category_bits: 2` on a wall does the same (the player's mask excludes 2). To ignore only the player, clear bit 2 from the mask: `mask_bits: 4294967293`. `-1` is accepted and normalized to `4294967295`.

```csl
Trigger_Listener :: class : Component {
    ao_start :: method() {
        trigger_collider := entity.get_component(Circle_Collider); // requires is_trigger
        trigger_collider.on_trigger_start = proc(self: Collider, other: Collider) {}; // and on_trigger_stay/end
    }
}
```

For a stationary trap, teleporter, pickup zone, or similar trigger volume, add a trigger collider and assign callbacks. Add `Movement_Agent` only if the entity itself needs agent-driven movement or collision.

`rebuild_immediately()` Use only when you need to query the updated navmesh in the same frame.

CSL exposes `child_colliders_only` and `enable_automatic_rebuilds` on `Navmesh`. The editor/C# inspector also has an `Ignore Colliders` setting, but it is not currently exposed as a CSL field in `core:ao`.

### Parent/Child Navmesh Setup
Parent Navmesh Entity (Navmesh component)
+-- Child Navmesh Entity (Navmesh component)
    +-- Boundary / obstacle loops (Navmesh_Loop or collider navmesh loops)
+-- More child navmeshes...

Use this when building a large map out of smaller local navmesh regions. The parent rebuild collects all child navmesh points and creates one unified navigation mesh with cross-boundary neighbor relationships. Query the parent navmesh for pathfinding; child navmeshes only contain their local area.

- Nested navmeshes refresh child-first -- parent navmeshes automatically pick up child mesh input changes.
- Set `child_colliders_only` / "Child Colliders Only" on parent navmeshes

## Pathfinding
```csl
NPC :: class : Component {
    agent: Movement_Agent @ao_serialize;
    target: Entity;

    ao_update :: method(dt: float) {
        if !#alive(target) return;
        result := agent.set_path_target(target.world_position, agent.movement_speed);
    }
}
```
