You will be developing a multiplayer game in a custom scripting language (.csl)

## Networking
> **NEVER USE `Game.is_server()`.** The engine uses client-side prediction with automatic server reconciliation. Gameplay code **must** run on both client and server for smooth behavior.

- All gameplay state is automatically synced. You do not need to write RPCs or manually replicate state.
- The client runs the same gameplay code as the server. The server's authoritative result pushed to the client every 4 frames — you get correctness **and** responsiveness for free.
- Do not forget that **multiple players will be connecting**. Avoid global state that will break with multiple players. Store these as fields on the player.

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
sprite.color = {1, 1, 1, 1}; // RGBA
sprite.layer = -5;
```

#### Prefab_Asset
```csl
p := get_asset(Prefab_Asset, "MyPrefab.prefab");
entity := instantiate(p);
```

#### Spine_Animator
Reference the Spine skill. If you are asked to make an NPC, shop vendor, or other character, you must use the $AO/streamed_character rig which has useful skins and animations! This asset id intentionally has no `.spine` suffix. All streamed_characters need the base/crewchsia skin.

### Creating Custom Components
> Create one file per component. You do not need to import them unless they're in a separate folder. 

Lifecycle methods
ao_start
ao_update
ao_late_update
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
- Reference the `world-space-ui` skill for world-space overlays, tutorial arrows, and immediate-mode helper drawing. Use interpolation for moving/following visuals.

## Interpolation

- Litmus test: if a visual is drawn from an entity/component's current transform, or inside an anchored component callback, you do not need manual interpolation.
- You must use interpolation for custom immediate-mode/world-space drawing that follows a moving entity outside an anchored callback, or for non-entity positions that you update yourself.

Example: drawing a world-space prompt that follows an entity from player UI code:
```csl
UI.begin_world_space_ui(target_entity);
defer UI.end_world_space_ui();

UI.text(rect, ts, "+1 Gold");
```

HP MUST be overlayed above players in world space, never screen space UI text. Use the minimal amount of UI to convey what is needed, which is sometimes none at all.
Never abbreviate words, instead just use CONCISE words. Prefer using icons where you can.

## Inventory & Items
- When players acquire items (e.g. from a shop or interacting with the world), you MUST use the All Out inventory system documented in the `inventory` skill.
- For placing items in the world use the `inventory-droppable-placeable-items` skill.

## Math Functions
`sin`, `cos`, `pow`, `sqrt`, `lerp`, `clamp`, `abs`, `min`, `max`, `length`, `length_squared`, `normalize`

### Player_Base Reference
- p.is_local_or_server() -> bool // true on the local client and on the server; must only be used for UI. 
- p.is_local() -> bool // true only on the local client; use for purely cosmetic effects (not UI); do not set any persisted state here or it will be wiped. 
- p.get_username()
- p.get_user_id() -> string
- p.avatar_color -> Color_Replace_Color 
- p.device_kind -> .PHONE, .TABLET, .PC 
- p.add_freeze_reason(reason: string) - NOT idempotent. If you call this repeatedly the player will get permanently stuck.
- p.add_invisibility_reason(reason: string)
- p.add_name_invisibility_reason(reason: string)
- p.remove_name_invisibility_reason(reason: string)

### Leaderboard
If leaderboards are requested `import "core:global_leaderboard"` and add `Global_Leaderboard` to a scene entity
Set `leaderboard_id` on the component, call `Global_Leaderboard.increment_score(player, leaderboard_id, amount)`

## Best Practices
- Do not write your own input. Movement is handled by default (speed = 300). player.agent.input_this_frame and ability buttons are available
- When unsure about an API signature find the appropriate skill. If none you may grep the core library in scripts/.ao_core
- You MUST fundamentally design your games to account for multiple players. Everything must either be plot based (tycoons) or round based (shooters)
- If asked for Brainrot use get_remote_assets_that_work_well_with tool with catalogId 05604152b758f509 (these are usually collection based games where brainrots obtained are placed in your plot and generate money)
- All games with plots start the player in their plot and have a UIK button to teleport back. Plots MUST have very clear visual boundaries
- Only use the Notifier API for critical messages there is no other way to convey. Skip notifications if there's a more natural way to convey something
- For player onboarding use world-space objective arrows insetad of tutorial text. Reference the `world-space-ui` skill and use `Tutorial_Arrow.default_options()` + `Tutorial_Arrow.draw(player, target_position, options)`. Pay special attention to avoid pointing an arrow somewhere a player can't go (already mined resource, collider blocking, teleport actually required to get there)
- Any games involving weapons MUST clone https://github.com/All-Out-Games/reusable-weapons-csl.git repo with curl and follow its README

### Text / copy
- Don't use text in UI if a texture icon would suffice. Players won't spend time reading text
- If you use text in UI make CERTAIN it fits within its container. UIK does not wrap automatically and you have a tendancy to overflow container bounds. Meticulously check that everything fits with screenshot tests. 
- Don't explain the game with UI/text. Put effort into making the game clear via INTUITIVE GAMEPLAY

### Maps
- Every map must be a large comprehensive game **world**, not a demo.
- Layer 0 is best for most items like towers, world props, trees, since it naturally layers with the player. 

After you make script changes run the All Out MCP compile tool.
Do exactly what the users asks for and nothing more.
