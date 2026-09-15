---
name: spine
description: You must load this tool when working with Spine animators or player animations, it provides the Spine API surface you must adhere to.
---
# Spine Animation System

Two ways to use Spine animations:
1. **Spine_Animator** (Component) - Animated entity in the scene
2. **Spine_Instance** (Standalone) - UI animations

## Spine_Animator (Component)

### Editor/Scene placed animators

For a rig that should already exist in the authored scene, use the world-building workflow instead of writing CSL just to configure its default pose:

1. Call `spine_rig_info` with the rig's `assetPath`. Use the exact animation and skin names it returns; do not guess them.
2. Place the `.spine` asset with `instantiate_assets`. This creates an entity with a `Spine_Animator` and selects a best-effort default skin and animation.
3. Override that default with `modify_scene` when needed. The editor property names are `initial_animation`, `loop_initial_animation`, and `ordered_skins`:

```json
instantiate_assets (assets: [
  {"assetPath": "$AO/streamed_character", "position": [4, 2], "name": "Shopkeeper", "scale": [0.9, 0.9]}
])

modify_scene (operations: [
  {
    "kind": "setComponentProperties",
    "entityName": "Shopkeeper",
    "componentType": "Spine_Animator",
    "properties": {
      "initial_animation": "Idle",
      "loop_initial_animation": true,
      "ordered_skins": ["base/crewchsia"]
    }
  }
])
```

`ordered_skins` replaces the complete skin stack, in order, so include every desired skin in the same array. `$AO/streamed_character` must include `base/crewchsia`; add any outfit skins using their exact `spine_rig_info` names. These serialized fields determine the animation and skins when the scene loads. Use `get_available_components` with `filter: "Spine_Animator"` and `includeProperties: true` to discover other editor/MCP property names rather than copying CSL member names.

On-screen rig size = the rig's `Size` from `spine_rig_info` × the entity's transform scale × `Spine_Animator.skeleton_scale` (default `[1, 1]`; the same field is `animator.scale` in CSL). Size a placed rig with the entity scale and leave `skeleton_scale` at 1; setting both (entity 5.5 and `skeleton_scale` 2.2) multiplies to 12x.

### Runtime-spawned rigs

For runtime-spawned non-player entities:
```csl
entity := Scene.create_entity();
animator := entity.add_component(Spine_Animator);
animator.set_skeleton(get_asset(Spine_Asset, "$AO/streamed_character"));
animator.disable_all_skins();
animator.enable_skin("base/crewchsia"); // Use spine_rig_info for the exact skins required by other rigs.
animator.refresh_skins(); // REQUIRED after any skin change
animator.set_animation("Idle", true, 0); // name, loop, track, speed = 1
animator.scale = v2{0.9, 0.9}; // spine_rig_info reports "Size: WxH world units" (or use query:"bounds"); pick the scale from that and the player size.
```

`add_component` awakens synchronously before returning. Use its initialization callback when fields must be set before awakening; do not call `awaken()` again.

## Player Animations
The engine builds the player's skeleton and state machine automatically. Access it via `player.animator.state_machine`. The `moving` bool is driven by velocity — everything else you trigger from CSL.

```csl
sm := player.animator.state_machine;

// Kill the player (must RESET to recover)
sm.set_trigger("death");

// Reset back to Idle from any state
sm.set_trigger("RESET");

// Play a flinch/hit-react (returns to Idle automatically)
sm.set_trigger("flinch");

// Dodge roll (returns to Idle automatically)
sm.set_trigger("dodge_roll");

// Melee attack (plays on the attack layer, track 1)
sm.set_trigger("attack");

// Enter/exit ghost form (swaps Idle/Run to ghost variants, used for spectator mode joining a match in progress etc...)
sm.set_bool("ghost_form", true);  // false to exit then RESET
```

Common built-in triggers: `death`, `RESET`, `flinch`, `dodge_roll`, `attack`, `punch`
`attack` and `punch` play on the attack layer (track 1): `attack` → `Attack_Melee_1` (with the `_mIK_AL` upper-body variant while moving), `punch` → `Punch_AL`, and ranged weapons use `Shoot_Gun_mIK_AL`. The layer's hidden `__skin_anim` state is optional, so a custom rig without it is fine.
Common built-in bools: `ghost_form`, `electrocute`, `sleep`

Triggers only select the corresponding state. They are no-ops when the generated player rig does not include that state's animation clip; `player_rig_info.includedAnimations` is the source of truth. For example, `set_trigger("punch")` and `set_trigger("flinch")` do nothing unless `Punch_AL` and `Flinch_Big` are included. The engine writes a session warning when a state has no animation data, but the game will not synthesize or download a missing clip.

After clearing `electrocute` or `sleep`, trigger `RESET` to leave the end animation.

### Extra Player Animations
The shipped player rig can be stripped down per project. Before writing CSL that depends on a player animation outside the normal trigger set, use MCP to make sure the generated player rig contains it.

Workflow:
- Call `player_rig_info` to inspect `availableAnimations`, `includedAnimations`, `availableSkins`, and `includedSkins`. The full list is hundreds of names — pass `{"filter":"keg"}` (case-insensitive substring) to narrow it.
- Pick exact animation names from `availableAnimations`; do not guess names.
- Call `player_rig_ensure_animations` with `{"animations":["Exact/Animation/Name"],"skins":["Optional/Skin/Name"],"setAsDefaultPlayerRig":true}` for every player animation and optional player skin your feature needs.
- `base/crewchsia` defaults to included and appears in `availableSkins`/`includedSkins` like other skins.
- `skins` are validated against the player source rig (`$AO/player/skinless/playercharacter.spine`), NOT `$AO/streamed_character`. Streamed-character outfit skins cannot be applied to the player rig; the error response names the source rig and lists `availableSkins`.
- Use the exact returned names in custom state machine or animation code.

`setAsDefaultPlayerRig: true` selects the generated rig as the project's default player rig and enables new cosmetics.

Pass `includeAnimationDetails: true` when you need per-animation `animationDetails` in the response. It contains each clip's duration, the attachment names it animates (these are `override_attachment_sprite` targets — held items, props), and its spine events with timings (hook them with `set_on_event` to sync gameplay to animation moments like a throw release). Details are omitted by default to keep the response small. `spine_rig_info` gives the same detail for any rig via `animation:"name"`, and `query:"slots"` / `query:"attachments"` list everything overridable.

### Playing Extra Player Animations (custom layer pattern)
The built-in player state machine only has the standard trigger states. To play other rig animations on the player, add your own layer to the player's live state machine. Do NOT replace the player's state machine, and do NOT call `set_animation` directly on reserved tracks.

- Tracks 0 (main), 1 (attack), 2 (invis), and 10 (skin anim) are reserved by the engine. Use tracks 3–9 for game layers.
- A new layer MUST get `set_initial_state` in the same function that creates it — the next state machine update asserts otherwise. Use a `__CLEAR_TRACK__` state as the empty default so your layer only overrides the body when it should.
- Run setup and triggers on every sim: never wrap state machine setup, triggers, or attachment overrides in `is_local()` — the server and all clients need identical animation state (replication and server-side test assertions both depend on it).

```csl
on_player_spine_event :: proc(userdata: Object, event: Spine_Event_Data) {
    if event.event == "Fire_Ranged" {
        // The throw animation reached its release moment — spawn the projectile here.
    }
}

Player :: class : Player_Base {
    ao_start :: method() {
        sm := animator.state_machine;
        var_held  := sm.create_variable("keg_held", .BOOL);
        var_throw := sm.create_variable("keg_throw", .TRIGGER);

        layer := sm.create_layer("keg_game", 5); // free track, see reserved list above
        empty_state := layer.create_state("__CLEAR_TRACK__", true);
        hold_state  := layer.create_state("fishermon/holding_keg_idle", true);
        throw_state := layer.create_state("fishermon/throw_keg", false);
        layer.set_initial_state(empty_state);

        layer.create_transition(empty_state, hold_state, false).create_bool_condition(var_held, true);
        layer.create_global_transition(throw_state, false).create_trigger_condition(var_throw);
        layer.create_transition(throw_state, hold_state, true).create_bool_condition(var_held, true); // return to holding once the throw finishes
        layer.create_transition(hold_state, empty_state, false).create_bool_condition(var_held, false);

        animator.instance.set_on_event(null, on_player_spine_event);
    }

    // Later, from gameplay code (on every sim, not just the local client):
    //   animator.state_machine.set_bool("keg_held", true);
    //   animator.state_machine.set_trigger("keg_throw");
}
```

To swap the art of a held item the animation shows (e.g. upgraded item tiers), override its attachment on the player instance — the attachment names come from `animationDetails`:
```csl
tex := get_asset(Texture_Asset, "kegs/keg_tier_2.png");
override_id := animator.instance.override_attachment_sprite("RAND004/Pirate/powder_keg/powder_keg", tex);
// Calling override_attachment_sprite again on the same attachment just swaps the texture (same id) — perfect for item tier upgrades.
// clear_attachment_sprite_override(override_id) restores the rig's original art.
```

## Non-Player State Machine
For complex non-player spines, you can create your own custom state machine for those spines. A `State_Machine` can also be attached to a standalone `Spine_Instance` via `instance.set_state_machine(sm, true)`, such as for UI. Call `instance.update(dt)`; it updates the attached state machine automatically.

```csl
Enemy_NPC :: class : Component {
    animator: Spine_Animator @ao_serialize;
    state_machine: State_Machine;

    ao_start :: method() {
        state_machine = State_Machine.create();

        // Variable types: `.BOOL`, `.TRIGGER`, `.INT`, `.FLOAT`.
        // Numeric conditions accept: `.GREATER`, `.GREATER_EQUAL`, `.LESS`, `.LESS_EQUAL`, `.EQUAL`.
        // Transition methods: create_int_condition(variable, value, kind), create_float_condition(variable, value, kind).
        // Examples: transition.create_int_condition(count_var, 3, .EQUAL);
        //           transition.create_float_condition(speed_var, 0.5, .GREATER);
        is_moving := state_machine.create_variable("is_moving", .BOOL);
        attack_trigger := state_machine.create_variable("attack", .TRIGGER); // auto-resets after triggering
        die_trigger := state_machine.create_variable("die", .TRIGGER);

        // A layer maps 1:1 to a Spine track. Multiple layers run concurrently,
        // which is how you get additive anims like attack-while-running on track 1.
        layer := state_machine.create_layer("main", 0);

        // States -- name must match the Spine animation name EXACTLY.
        // create_state(name, loop, duration) -- duration pulled from spine rig if duration parameter is 0
        // if setting duration, make sure to update this if / when needed.
        // Lowercase names here are placeholders for a custom rig. `$AO/streamed_character`
        // uses exact case-sensitive names like `Idle`, `Run`/`Run_Fast`,
        // `Attack_Melee_1`, and `Death_No_HP`.

        // Clearing a track: pass "__CLEAR_TRACK__" as the state name.
        idle_state := layer.create_state("idle", true);
        walk_state := layer.create_state("walk", true);
        attack_state := layer.create_state("attack", false);   // one-shot
        death_state := layer.create_state("death", false);

        layer.set_initial_state(idle_state);

        // create_transition(from, to, require_state_complete)
        idle_to_walk := layer.create_transition(idle_state, walk_state, false);
        idle_to_walk.create_bool_condition(is_moving, true);

        walk_to_idle := layer.create_transition(walk_state, idle_state, false);
        walk_to_idle.create_bool_condition(is_moving, false);

        // create_global_transition(to, allow_transition_to_self) -- from any state
        to_attack := layer.create_global_transition(attack_state, true);
        to_attack.create_trigger_condition(attack_trigger);

        // require_state_complete = true: waits for attack to finish
        attack_to_idle := layer.create_transition(attack_state, idle_state, true);

        to_death := layer.create_global_transition(death_state, false);
        to_death.create_trigger_condition(die_trigger);

        animator.set_state_machine(state_machine, true);  // true = transfer ownership
    }

    ao_update :: method(dt: float) {
        state_machine.set_bool("is_moving", is_moving());
    }

    on_attack :: method() { state_machine.set_trigger("attack"); }
    on_death :: method() { state_machine.set_trigger("die"); }
}
```

### One-shot anim with return-to-Idle pattern
```csl
var   := sm.create_variable("my_action", .TRIGGER);
state := layer.create_state("my_action_anim", false, 1.2);
layer.create_global_transition(state, false).create_trigger_condition(var);
layer.create_transition(state, idle_state, true); // require_state_complete=true returns to idle when duration elapses
```

### Splitting large setups
Many `create_state` / `create_transition` calls can exhaust the VM's register budget. Split setup across multiple procs that share `sm`, `layer`, and `idle_state` if required.

### Modifying existing anims — checklist
- If a spine anim has been **renamed**, update every `create_state("…")` string that references it (exact match, case-sensitive).
- If a spine anim has **changed length**, update the `duration` argument on its `create_state(…)` (unless it uses 0)
- If you **rename a trigger/bool**, update both the `create_variable(…)` name and every `set_trigger` / `set_bool` call site.

## Skins
You must use the spine_rig_info tool before using any spine to know what skin(s) to select, plus scaling and animations to use.

```csl
// Combine multiple skins
animator.disable_all_skins();
animator.enable_skin("base/crewchsia"); // (required when using the streamed character skeleton)
animator.enable_skin("body/alien");
animator.refresh_skins();
```

## Bone Transforms
```csl
hand_pos := animator.get_bone_local_position("Hand_R");

hand, found := animator.try_get_bone_local_transform("Hand_R");
if found {
    // Map an offset in the bone's own axes into skeleton-local space.
    tip_pos := hand.position + hand.x_axis * 0.5 + hand.y_axis * 0.2;
}
```

`get_bone_local_position` is convenient when you only need the bone origin. Use `try_get_bone_local_transform` for placement: it reports whether the bone exists plus its current skeleton-local `position`, `x_axis`, and `y_axis`. A bone-local point `{x, y}` maps to `position + x_axis*x + y_axis*y`. The rig is Y-up, but a bone's axes include its rotation, scale, shear, and mirroring, so do not assume positive X is visual right or positive Y is visual up.

```csl
layer := animator.state_machine.try_get_layer("main");
if layer != null {
    current := layer.get_current_state();
    running_state := layer.try_get_state("Run_Fast");
}
animator.state_machine.set_trigger("jump");
```

## Attachment Overrides
Use attachment APIs when you need to replace an existing rig attachment or draw an extra sprite/rig over or under a slot. This is the right tool for item-in-hand moments, equipment swaps, muzzle flashes, held props, or drawing a separate animated rig attached to a body slot. The calls return a `u64` ID for you to save so you can clear it later if you want to.

These methods live on `Spine_Instance`.

Before tuning placement, call `spine_rig_info` with `query: "layout"`. Add `skin`, or `animation` plus `time`, to inspect that exact pose; use `filter: "Hand_R|weapon"` to narrow the bone, slot, or attachment. The result includes bone/slot position and axes plus the current attachment's skeleton-space bounds.

For a held sprite, set the texture asset's pivot to the grip point. A pivot of `{0, 0}` is the center, `{-1, 0}` puts the origin on the left edge, and `{1, 0}` puts it on the right edge. Then `rotation_degrees` rotates around the grip and `offset` directly says where the grip sits in the slot bone's local axes. `Texture_Asset.get_world_size()` returns the unscaled source size in world units, which is useful for offsets expressed as fractions of the art:

```csl
sword := get_asset(Texture_Asset, "items/sword.png");
size := sword.get_world_size();

desc := Attachment_Desc.default();
desc.offset = {size.x, size.y * 0.25}; // one width along local X, quarter length along local Y
desc.rotation_degrees = -35;
sword_id := instance.add_attachment_sprite("Hand_R", sword, desc);
```

The transform order is texture size and pivot, then `desc.scale`, then `rotation_degrees`, then `offset`, then the slot bone transform. Multiply `get_world_size()` by `desc.scale` when reasoning about the final local dimensions.

```csl
// Replace an existing Spine attachment by attachment name.
// Good for hotswapping the art used by a rig attachment, like Link holding up a different item.
item_tex := get_asset(Texture_Asset, "items/boomerang.png");
override_id := instance.override_attachment_sprite("held_item", item_tex);

// Later, restore the rig's original attachment art.
instance.clear_attachment_sprite_override(override_id);
```

```csl
// Draw an extra sprite on a slot without replacing the slot's normal attachment.
desc := Attachment_Desc.default();
desc.draw_mode = .IN_FRONT; // .BEHIND draws under the slot attachment
desc.offset = {0, 0.25};
// desc also has scale (defaulted to (1, 1)), rotation_degrees, and color (defaulted to (1,1,1,1))

sparkle_id := instance.add_attachment_sprite("Hand_R", get_asset(Texture_Asset, "fx/sparkle.png"), desc);

// Later, remove just this added sprite.
instance.clear_attachment_sprite(sparkle_id);
```

```csl
// Attach another animated Spine rig to a slot.
child := Spine_Instance.create();
child.set_skeleton(get_asset(Spine_Asset, "items/animated_sword.spine"));
child.set_animation("Idle", true, 0);

desc := Attachment_Desc.default();
desc.draw_mode = .IN_FRONT;
rig_id := instance.add_attachment_rig("Hand_R", child, desc, true); // true transfers destroy ownership

// Later, remove it. If transfer_ownership was true, the parent owns cleanup.
instance.clear_attachment_rig(rig_id);
```

Attachment API summary:
- `override_attachment_sprite(attachment_name, texture) -> u64`: replace an existing attachment's sprite by attachment name.
- `clear_attachment_sprite_override(id)`: remove a replacement made by `override_attachment_sprite`.
- `add_attachment_sprite(slot_name, texture, desc) -> u64`: draw an extra texture on a slot.
- `clear_attachment_sprite(id)`: remove an extra sprite.
- `add_attachment_rig(slot_name, rig, desc, transfer_ownership) -> u64`: draw another `Spine_Instance` on a slot.
- `clear_attachment_rig(id)`: remove an attached rig.

Use `attachment_name` when replacing art already authored in the rig. Use `slot_name` when adding a new over/under draw on top of the animated slot. Spine slots do not have their own transform: `Attachment_Desc.offset`, `scale`, and `rotation_degrees` are local to the slot's bone. `draw_mode` controls whether the added sprite/rig is drawn `.BEHIND` or `.IN_FRONT` of the slot attachment.

## Color
All spines that can take damage or you want to draw attention to should color_multiplier to apply effects (red flash, glow, etc...)

```csl
// Tint/flash like damage flash, transparency
animator.color_multiplier = {brightness, brightness, brightness, 0.25};
```

## Spine_Instance (Standalone for UI)
**You MUST call `destroy()` on Spine_Instance when done to avoid leaks.**

If an API has `create()`, it MUST have a matching `destroy()`. Exception: APIs with a `transfer_ownership` parameter -- passing `true` transfers destroy responsibility to the receiver like `instance.set_state_machine(sm, true)`.

```csl
Popup :: class {
    spine_asset: Spine_Asset;
    spine_instance: Spine_Instance;

    init :: proc(using this: Popup) {
        spine_asset = get_asset(Spine_Asset, "anims/popup.spine");
        spine_instance = Spine_Instance.create();
        spine_instance.set_skeleton(spine_asset);
    }

    cleanup :: proc(using this: Popup) {
        spine_instance.destroy();  // REQUIRED
    }

    update :: proc(using this: Popup, dt: float) {
        spine_instance.update(dt);  // Manual update required for standalone
    }

    render :: proc(using this: Popup) {
        UI.push_screen_draw_context();
        defer UI.pop_draw_context();
        rect := UI.get_safe_screen_rect();
        // Spine assets authored in world space are ~1-2 units tall. In screen space that's 1-2 pixels, so scale up for UI. In world space, {1,1} is fine.
        scale := v2{100, 100};
        UI.spine(rect.center(), spine_instance, scale, 0.0);
    }
}
```

### Player UI Clone Example (voting screens, PiP displays)
Clones a player to display them in UI, etc...

```csl
player: Player = ...;
player_ui_instance := Spine_Instance.create();
player_ui_instance.set_skeleton(player.animator.get_skeleton());
for skin: player.animator.get_skins() {
    player_ui_instance.enable_skin(skin);
}
player_ui_instance.refresh_skins();
player_ui_instance.set_color_replace_color(player.avatar_color);

// Every frame:
player_ui_instance.update(dt);
UI.spine(UI.get_screen_rect().center(), player_ui_instance, {100, 100});

// When the UI closes:
player_ui_instance.destroy();
```

```csl
Color_Replace_Color :: enum {
    NONE; RED; CYAN; GREEN; YELLOW; LIGHT_GREEN; PINK; ORANGE; BLACK;
    PURPLE; LIGHT_GRAY; BLACK2; BLUE2; BROWN1; GREEN3; ORANGE2; PURPLE2;
    PURPLE3; RED2; WHITE1;
}
```
