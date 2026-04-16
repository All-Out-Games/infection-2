You will be developing a multiplayer game in a custom scripting language (.csl)

## Networking
> **NEVER wrap gameplay logic in `Game.is_server()`.** The engine uses client-side prediction with automatic server reconciliation. Gameplay code **must** run on both client and server for smooth behavior.

- All gameplay state is automatically synced. You do not need to write RPCs or manually replicate state.
- The client runs the same gameplay code as the server. The server's authoritative result is reconciled automatically — you get correctness **and** responsiveness for free, but **only if the code runs on both sides**.
- Do not forget that **multiple players will be connecting**. Avoid global state that will break with multiple players. Store these as fields on the player.

### is_local_or_server() vs is_local()
Both are **methods on Player_Base** — they are NOT standalone global functions.

- Inside a `Player_Base` subclass method: call as bare `is_local_or_server()`
- From any other component that has a player reference: call `player_ref.is_local_or_server()`

```csl
// ✅ Correct
Player :: class : Player_Base {
    ao_late_update :: method(dt: float) {
        if is_local_or_server() {
            draw_ability_button(this, Shoot_Ability, 0);
            UI.text(..., "Waiting for host to start the game...");
        }
        if is_local() {
            // Local only SFX
        }
    }
}

// ✅ Correct — from a non-Player component with a player reference
My_Component :: class : Component {
    player: Player;

    ao_update :: method(dt: float) {
        if player == null return;
        if player.is_local_or_server() {
            // gameplay logic
        }
    }
}

// ❌ Wrong — is_local_or_server() is not a global free function
My_Component :: class : Component {
    ao_update :: method(dt: float) {
        if is_local_or_server() { } // ERROR: Unresolved identifier
    }
}
```

## Imports
All imports go in main.csl (in the /scripts folder) only. You only need to import folders, not individual scripts.
```csl
// main.csl
import "core:ao"
import "ui" // add folder imports here if needed
```

Find assets with the MCP: 
asset_local_search (query: "tree")
When referencing assets use <path>.<ext>, omit /res from the path. 

### Asset Types
```csl
texture := get_asset(Texture_Asset, "ui/button.png");
sound := get_asset(SFX_Asset, "sfx/click.wav");
spine := get_asset(Spine_Asset, "anims/dog/dog.spine");
```

## Entities
Place entities with the mcp tools, except for dynamically spawned entities:
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

    current := entity.first_child;
    while current != null {
        visit(current);
        current = current.next_sibling;
    }
}

## Components
### Out-of-the-box components
#### Sprite_Renderer
```csl
sprite := entity.get_component(Sprite_Renderer);
sprite.set_texture(texture);
sprite.color = {1, 1, 1, 1}; // RGBA
sprite.layer = -5;
```

#### Prefab_Asset
```csl
prefab := get_asset(Prefab_Asset, "MyPrefab.prefab");
entity := instantiate(prefab);
```

#### Spine_Animator
Reference the Spine skill. If you are asked to make an NPC, shop vendor, or other character, you must use the $AO/streamed_character rig which has a ton of skins and animations! If adding through code, note that all streamed_characters will need at least the base/crewchsia skin added. 

### Creating Custom Components
> Make new components in dedicated files. You do not need to import them unless they're in a separate folder. 

Can override these lifecycle methods:

- ao_start
- ao_update
- ao_late_update
- ao_end - when destroyed

```csl
// orbiter.csl
Orbiter :: class : Component {
    // Use `@ao_serialize` to expose a field in the editor (can be modified with the modify_scene mcp tool). Prefer serialized fields, do not look up entities with e.get_name(); 

    follow_entity: Entity @ao_serialize;
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
> You can add components you've made to entities in the scene using the modify_scene tool. 

#### Iterating Components
```csl
for player: component_iterator(My_Player) {
}
```

#### Finding components close to the player
> csl does not have collision callbacks instead get components near them and check distance
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

## Strings
```csl
format_string("Value: %", {42});
format_string("health: 100%%");

hp := 67;
// %0 as alias for % when you want either multiple args next to eachother ("%0%") or an arg then a percent literal ("%0%%")
format_string("health: %0%%", {hp}); // health: 67%

// Use Format_Float wrapper struct for decimal rounding
value := 3.14159;
format_string("pi: %", {format_float(value, decimals=2)}); // "pi: 3.14"
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
// For sounds only one player should hear (UI clicks), wrap play calls with is_local
sound_id := SFX.play(sound_asset, desc);

SFX.stop(sound_id);
```

## Economy
> Automatically persists currencies (cash, points, etc...)
```csl
Economy.register_currency("Coins", coin_texture_asset);

balance := Economy.get_balance(player, "Coins");

Economy.deposit_currency(player, "Coins", 100);

COST :: 50;
if Economy.can_withdraw_currency(player, "Coins", COST) {
    Economy.withdraw_currency(player, "Coins", COST);
}

Any time players receive item or currencies you MUST play a sick animation of the item/coins going up or lerping over and have tactile sfx. 

Round based games should reset economy on ao_start with economy_delete_save_data()
```

## UI
- Reference the `UIK` skill if the user's request requires game UI. Do not mix UIK and UI APIs. 

## Inventory & Items
- When players acquire items (e.g. from a shop or interacting with the world), you MUST use the All Out inventory system documented in the `inventory` skill.
- For placing items in the world use the `inventory-droppable-items` skill. 

## Math Functions
`sin`, `cos`, `pow`, `sqrt`, `lerp`, `clamp`, `abs`, `min`, `max`, `length`, `length_squared`, `normalize` there are no other math functions. 

### Player_Base Reference
- p.is_local_or_server() -> bool  // true on the local client and on the server; must be used for UI. 
- p.is_local() -> bool            // true only on the local client; use for purely cosmetic effects (not UI)
- p.get_username()
- p.get_user_id() -> string
- p.avatar_color -> Color_Replace_Color 
- p.device_kind -> .PHONE, .TABLET, .PC 
- p.add_freeze_reason(reason: string)
- p.add_invisibility_reason(reason: string)

## Best Practices
- CSL does not have closures, instead use `userdata: Object` passed to callbacks. Class instances can be stored in an `Object` variable and cast back to its original type.
- Do not write your own input. Movement is handled by default. If you need to consume it, use player.agent.inputs_this_frame and ability buttons. 
- When unsure about an API signature, find the appropriate skill. If no results are found, you may grep api_references/core/ao/[core/generated].csl_engine which is a massive file with ALL engine APIs. 

After you make script changes, run the All Out MCP compile tool.
When the prompt requires building a game world, do so using the allout MCP scene editing tools instead of scripts. 

To add weapons to your game clone the https://github.com/All-Out-Games/reusable-weapons-csl.git repo with curl and follow its README. 

Start with the scene_summary tool. Do exactly what the users asks for and nothing more. 