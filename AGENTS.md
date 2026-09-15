You will be developing a multiplayer game in a custom scripting language (.csl)

## Networking
> **NEVER gate gameplay on `Game.is_server()`.** The engine uses client-side prediction with automatic server reconciliation. Gameplay code **must** run on both client and server for smooth behavior. The only sanctioned uses are the two the skills spell out: the presentation-only guard in `client-specific-state` and the deliberate latency-for-CPU trade in `performance-optimization`.

- All gameplay state is automatically synced. You do not need to write RPCs or manually replicate state.
- The client runs the same gameplay code as the server. The server's authoritative result pushed to the client every 4 frames — you get correctness **and** responsiveness for free.
- Do not forget that **multiple players will be connecting**. Avoid global state that will break with multiple players. Store these as fields on the player.
- `ao_start()` is not replayed for late-joining clients (nor after a script hotload: live instances keep their current values for every field that still exists with the same type, so only newly added or retyped fields pick up their declared initializer; a changed initializer on an existing field or an `ao_start`-derived value needs a game restart) — rebuild client-local presentation from synced state in `ao_on_state_sync()` (see the client-specific-state skill); spawn/destroy networked entities in the shared predicted path (never gated to server or local); and store cross-entity ownership as user-id strings (`player.get_user_id()`), never as synced Player/Entity references or entity-creation order.

There are two player methods that control where code runs:
```csl
player.is_local_or_server() {
    // ONLY/MUST used for UI, and all UI must be drawn in player late_update
}

player.is_local() {
    // ONLY used for player specific cosmetic effects like controlling visibility for player specific items. You cannot store any persistent state here, it will be wiped every time the server updates.  
}
```

These are NOT standalone global functions, they must be called from within or on your player class. 

## Imports
All imports go in main.csl in the /scripts folder only. You only import folders not individual scripts.
```csl
// main.csl
import "core:ao"
import "ui" // add folder imports here if needed
```

Find assets with the MCP asset_local_search (query: "tree")
When referencing assets use <path>.<ext>, omit /res from the path. 

### Asset Types
```csl
texture := get_asset(Texture_Asset, "ui/button.png");
sound := get_asset(SFX_Asset, "sfx/click.wav");
spine := get_asset(Spine_Asset, "anims/dog/dog.spine");
```

## Entities
Players auto-flip X scale; child visuals should keep local X positive. Don't flip yourself.

Runtime spawned entities:
```csl
e := Scene.create_entity();
e.set_local_position({10, 20});
e.set_local_scale({2.5, 2.5});
e.set_local_rotation(0);
e.set_local_enabled(false);

my_comp := e.add_component(My_Component);
other := e.get_component(Other_Component);

e.destroy();
```
`add_component()` runs the new component's `ao_start()` before returning; use its `on_before_start` callback for any fields that startup must read instead of assigning them afterward.

### Iterating Entities
```csl
for entity: entity_iterator() {
}
```

### Iterating Children
visit :: proc(entity: Entity) {
    // logic

    current := entity.get_first_child();
    while current != null {
        visit(current);
        current = current.get_next_sibling();
    }
}

## Components
#### Sprite_Renderer
```csl
sprite := entity.get_component(Sprite_Renderer);
sprite.set_texture(texture);
sprite.color = {1, 1, 1, 1}; // RGBA (the editor/MCP property name for this field is `tint`)
sprite.layer = -5;
```

#### Prefab_Asset
```csl
p := get_asset(Prefab_Asset, "MyPrefab.prefab");
entity := Scene.instantiate(p);
```

#### Spine_Animator
Reference the Spine skill. If you are asked to make a humanoid NPC, shop vendor, or other human character, you must use the $AO/streamed_character rig which has useful skins and animations! Animals, monsters and props use their own rigs from asset search. This asset id intentionally has no `.spine` suffix. All streamed_characters need the base/crewchsia skin.

### Creating Custom Components
> Create one file per component. You do not need to import them unless they're in a separate folder. 

Lifecycle methods
ao_start
ao_update
ao_late_update
ao_draw - cosmetic-only; skipped on resim. Interactive UI must use ao_update/ao_late_update.
ao_end - when destroyed

```csl
// orbiter.csl
Orbiter :: class : Component {
    follow_entity: Entity @ao_serialize; // Exposes a field in the editor (can be modified with the modify_scene mcp tool). Prefer serialized fields, do not look up entities with e.get_name(); 
    radius: float @ao_serialize;
    speed: float @ao_serialize;
    angle: float;
    
    ao_start :: method() {
        radius = 2.0;
        speed = 1.0;
        angle = 0.0;

        if #alive(follow_entity) {
            entity.set_local_position(v2{follow_entity.local_position.x + radius, follow_entity.local_position.y});
        }
    }
    
    ao_update :: method(dt: float) {
        if !#alive(follow_entity) {
            return;
        }
        angle += speed * dt;
        
        offset_x := cos(angle) * radius;
        offset_y := sin(angle) * radius;
        
        center := follow_entity.local_position;
        new_pos := v2{center.x + offset_x, center.y + offset_y};
        entity.set_local_position(new_pos);
    }
}

// on_before_start initializes fields before Orbiter.ao_start() reads them.
add_orbiter :: proc(entity: Entity, follow_entity: Entity) -> Orbiter {
    return entity.add_component(
        Orbiter,
        on_before_start=proc(orbiter: Orbiter) {
            orbiter.follow_entity = follow_entity;
        },
    );
}
```
You can add components to entities in the scene using the modify_scene tool

#### Iterating Components
```csl
for player: component_iterator(My_Player) {
}
```

#### Finding components close to the player
```csl
nearby: [..]Enemy;
Scene.get_all_components_in_range(player_pos, 5.0, ref nearby);

closest, found := Scene.get_closest_component_in_range(player_pos, 2.0, Pickup);
```

## Random
```csl
rng: u64 = rng_root_seed();

// Range values are inclusive.
random_float := rng_range_float(ref rng, 0, 1);
random_int := rng_range_int(ref rng, 1, 10);
```

## String Templating
NO $ before the interpolated pieces. Just plain {value}

```csl
`Value: {42}`;
`health: 100%`;

hp := 67;
`health: {hp}%`; // health: 67%

// Decimal rounding
`pi: {format_float(PI, decimals=2)}`; // "pi: 3.14"
```

my_str.count gets length 

## Time
```csl
current_time := get_time(); // Float seconds since game start
frame := get_frame_number(); // u64
```

## SFX
```csl
// Most things that happen in the game should have sound! Find sounds with asset_local_search and asset_remote_search. 
desc := SFX.default_sfx_desc();
desc.entity_to_follow = entity.id; // Always set if the SFX "emits" from a specific entity. 
desc.delay = 0; // For lining up with animations
desc.loop = false;
desc.volume = 0.4;
desc.speed_perturb = 0.1;
desc.specific_to_player = player; // For sounds only one player should hear (UI clicks, coin earning, music, etc). Do NOT wrap any SFX calls with is_local
sound_id := SFX.play(sound_asset, desc);

SFX.stop(sound_id);
```

## Economy
> Persists across sessions
```csl
Economy.register_currency("Coins", coin_texture_asset);

balance := Economy.get_balance(player, "Coins");

Economy.deposit_currency(player, "Coins", 100);

COST :: 50;
if Economy.can_withdraw_currency(player, "Coins", COST) {
    Economy.withdraw_currency(player, "Coins", COST);
}
```
When players receive items or currencies you MUST play a sick animation of the item/coins going up or lerping over and have tactile sfx.

## UI
- Reference the `uidoc` skill for screen-space game UI.
- Reference the `tutorials` skill for onboarding, guided steps, tutorial progress, Start/Restart, and world/UI guidance.
- Reference the `world-space-ui` skill for world-space overlays, tutorial arrows, and immediate-mode helper drawing. Use interpolation for moving/following visuals.

## Interpolation
EVERY piece of world space text must adhere to the render-interpolation skill.
- If a visual is drawn from an entity/component's current transform, or inside an anchored component callback, you do not need manual interpolation.
- You must use interpolation for custom immediate-mode/world-space drawing that follows a moving entity outside an anchored callback, or for non-entity positions that you update yourself.

Example: drawing a world-space prompt that follows an entity from player UI code:
```csl
UI.begin_world_space_ui(target_entity);
defer UI.end_world_space_ui();

UI.text(rect, ts, "+1 Gold");
```

HP MUST be overlayed above players in world space, never screen space UI text. Use the minimal amount of UI to convey what is needed, which is sometimes none at all.
Prefer concise words over abbreviation. Prefer using icons where you can.

## Inventory & Items
- When players acquire items (e.g. from a shop or interacting with the world), you MUST use the All Out inventory system documented in the `inventory` skill.
- For placing items in the world use the `inventory-droppable-placeable-items` skill.

## Math Functions
`ceil`, `floor`, `round`, `sin`, `cos`, `atan2`, `pow`, `sqrt`, `Math.exp`, `Math.log`, `lerp`, `clamp`, `abs`, `sign`, `min`, `max`, `length`, `length_squared`, `normalize`, `dot`, `to_degrees`, `to_radians`, `linear_step`, `next_power_of_two`, `mix_u64`, `rng_mix`.
Floating-point rounding and angle conversions have `f32`/`f64` overloads and preserve the input precision. `round` chooses the nearest integer, with halfway cases away from zero (`round(-2.5)` is `-3.0`). Use `ceil(x).(int)` when an integer is needed and the result is finite and fits. Integer casts truncate toward zero; `floor` rounds toward negative infinity. See [the math reference](docs/scripting/random-math-and-more.md#math-functions) for signatures and behavior.

### Player_Base Reference
- p.is_local_or_server() -> bool // true on the local client and on the server; must only be used for UI. 
- p.is_local() -> bool // true only on the local client; use for purely cosmetic effects (not UI); do not set any persisted state here or it will be wiped. 
- p.get_username()
- p.get_user_id() -> string
- p.avatar_color -> Color_Replace_Color 
- p.device_kind -> .PHONE, .TABLET, .PC 
- p.add_freeze_reason(reason: string) / p.remove_freeze_reason(reason: string) - counted, NOT idempotent: one remove per add. Calling add every frame will permanently stick the player (the engine logs a warning once a reason stacks 32 deep).
- p.has_freeze_reason(reason: string) -> bool - check before adding if you need set-like (idempotent) behavior. Every `*_reason` family below has a matching `has_*_reason` and `has_any_*_reason()` query.
- p.add_disable_movement_input_reason(reason: string) / p.remove_disable_movement_input_reason(reason: string) - for a multi-frame input lock outside an Effect, add once and remove once; never add every frame.
- p.override_movement_input_for_next_step(input: v2) - replaces input for exactly the next movement step, including with `{0,0}`. It bypasses disable-movement-input reasons; call it once per step for continuous scripted movement, not to implement a stun.
- p.add_ghost_reason(reason: string)
- p.remove_ghost_reason(reason: string)
- p.has_ghost_reason(reason: string) -> bool
  - Reasons are synchronized player state and are restored automatically for late joiners. Do not reapply them in `ao_on_state_sync()`.
  - They are counted, not idempotent: every add stores another occurrence and each remove removes one matching occurrence. Adding the same reason twice requires two removes. Removing an absent reason is a safe no-op.
  - While any reason remains, the built-in player rig is half-visible to that player and other ghosted players, and hidden (along with its built-in name/message) from non-ghosted players. This does not change collision, movement, targeting/damage, or entity/component iteration; custom visuals and gameplay filters must handle ghosting explicitly.
- p.add_invisibility_reason(reason: string)
- p.add_name_invisibility_reason(reason: string)
- p.remove_name_invisibility_reason(reason: string)

### Leaderboard
If leaderboards are requested `import "core:global_leaderboard"` and add `Global_Leaderboard` to a scene entity
Set `leaderboard_id` on the component (in the scene, or via `add_component`'s `on_before_start` callback; the component refreshes as soon as the id is non-empty), call `Global_Leaderboard.increment_score(player, leaderboard_id, amount)`

## Best Practices
- Do not write your own input. Movement is handled by default (`agent.movement_speed = 300` is a tuning value, roughly 5 world units/s with the default friction 0.5 — not units per second). `player.input_this_frame` (the movement stick/WASD vector) and ability buttons are available. Read `player.input_this_frame`, not `player.agent.input_this_frame`: the agent's copy is consumed and zeroed by the movement update before any Player callback runs, so it always reads {0,0} from scripts
- `Notifier.notify(text)` is local-only (a no-op on the server). In server-side handlers such as chat commands or save callbacks use `Notifier.notify(player, text)`.
- When unsure about an API signature find the appropriate skill. If none you may grep the core library in scripts/.ao_core
- You MUST fundamentally design your games to account for multiple players. Everything must either be plot based (tycoons) or round based (shooters)
- If asked for Brainrot use get_remote_assets_that_work_well_with tool with catalogId 05604152b758f509 (these are usually collection based games where brainrots obtained are placed in your plot and generate money)
- All games with plots start the player in their plot and have a button to teleport back. Plots MUST have very clear visual boundaries
- Only use the Notifier API for critical messages there is no other way to convey. Skip notifications if there's a more natural way to convey something
- For guided onboarding use the managed `Tutorial` API in the `tutorials` skill. It owns per-player progress, saves, instruction/progress presentation, and world/UI cues. Use standalone cues when requested or for isolated hints. Point to a reachable target or waypoint.
- Any games involving weapons MUST use the reusable-weapons library: `curl.exe -fL https://github.com/All-Out-Games/reusable-weapons-csl/archive/refs/heads/master.zip -o reusable-weapons.zip && tar.exe -xf reusable-weapons.zip`, then follow `reusable-weapons-csl-master/README.md`
- Leverage the tools available to you, like asset generation to make the game unique and incredibly high quality. 

### Text / copy
- Don't use text in UI if a texture icon would suffice. Players won't spend time reading text
- Don't explain the game with UI/text. Put effort into making the game clear via INTUITIVE GAMEPLAY

### Maps
- Every map must be cohesive, focused, and built to support gameplay with clear paths, uniform consistent plots if required, pixel perfect layouts, and no randomly scattered objects.
- Layer 0 is best for most items like towers, world props, trees, since it naturally layers with the player. `layer` picks the draw bucket; `depth_offset` only nudges ordering inside layer 0's Y-sort and never substitutes for a layer change. 
