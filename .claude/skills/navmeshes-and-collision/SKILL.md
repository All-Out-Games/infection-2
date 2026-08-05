---
name: navmeshes-and-collision
description: Reference this when implementing pathfinding, Movement_Agent movement collision, collider trigger callbacks for traps/teleporters/pickups, or navmesh-based spawning.
---
Be very careful and sparing with collision. Do not add it to most entities unless collision is absolutely required (preventing players from going out of bounds). Every collider/navmesh MUST have a test ensuring the player can move correctly. Never spawn the player on top of a collider. It's very hard for you to visualize colliders hence why it's so important to be sparing and careful here.  

## Components
- Navmesh Main navigation mesh container. Handles triangulation, pathfinding, and closest-point queries.
- Navmesh_Loop Defines walkable area boundaries as polygons. Can be flipped inside-out to create holes/obstacles. Automatically updates parent navmesh.
- Movement_Agent Entity movement with navmesh pathfinding, simple collider movement, and trigger detection.
- Colliders `Box_Collider`, `Circle_Collider`, `Polygon_Collider`, and `Edge_Collider` can block Movement_Agent movement or act as trigger volumes.

## Scene Setup
1. Create an entity with a `Navmesh` component
2. Create child entities with `Navmesh_Loop` components to define walkable areas
3. For each `Navmesh_Loop`: add points for the polygon shape; set `Flip Inside Outside` to true for obstacles/holes
4. Colliders can contribute to navmesh loops via `Make Navmesh Loop` and `Flip Navmesh Loop` in inspector. Navmeshes automatically hash loop/collider/tilemap inputs each frame and rebuild when those inputs change. To avoid scene-wide collider scans on nested/parent navmeshes, set Navmesh `Child Colliders Only` = true
5. Use Navmesh `Debug Enabled` and `Debug Rebuild Every Frame` to visualize with the editor screenshot tool. The walkable area _should_ be covered with triangles in this case. 

`Navmesh_Loop` point editing is editor/scene-tool data. CSL currently exposes `Navmesh_Loop` as an empty component, so do not write scripts that read or mutate `Navmesh_Loop.points` directly. For script-driven shapes, use collider components with `make_navmesh_loop` / `flip_navmesh_loop`, or create/edit loop points through the editor/MCP scene tools.

### Closest Point
```csl
point: v2 = {10, 10};
result: v2;
triangle_hint: s64; // 0 = not set; reuse for repeated nearby queries for speed

if navmesh.try_find_closest_point_on_navmesh(point, ref result, ref triangle_hint) {
    spawn_entity.set_local_position(result);
}
```

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

`set_path_target` is processed later in the frame in parallel with other agents, so the first frame you set a new target will NOT return `success == true`

`agent_radius` controls pathfinding clearance. Increase it when an agent should route wider around corners or stay farther from navmesh edges. To fully avoid walls during actual movement, the agent should also have a collider, usually a `Circle_Collider`, with a matching radius.

### Locking Movement to a Navmesh
```csl
agent.set_navmesh_to_lock_to(navmesh);
agent.set_navmesh_to_lock_to(null); // clear
```

### Movement_Agent Properties
```csl
agent.movement_speed = 300.0; // default
agent.friction = 0.5;
current_velocity := agent.velocity; // readonly
input := agent.input_this_frame; // readonly
```

### CSL Movement Physics and Triggers
Agent's enabled non-trigger colliders block against enabled non-trigger world colliders taking `category_bits` / `mask_bits` filtering into account

```csl
Trigger_Listener :: class : Component {
    ao_start :: method() {
        trigger_collider := entity.get_component(Circle_Collider); // requires is_trigger
        trigger_collider.on_trigger_start = proc(self: Collider, other: Collider) {}; // and on_trigger_stay/end
    }
}
```

Movement_Agent has velocity/friction fields but you do not have to use them. For a stationary trap, teleporter, pickup zone, or similar trigger volume, add a Movement_Agent and a trigger collider to the entity and assign trigger callbacks.

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
