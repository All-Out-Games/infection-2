---
name: effects
description: Reference this when implementing effects for abilities, animations, and state-based behaviors — any bounded-duration behavior that takes over an entity (dash, roll, attack window, stun, eat lockout, death/respawn) or temporarily modifies it (slow, buff, fade/despawn).
---
# CSL Effect System (`Effect_Base`)

Bounded-duration behaviors that take over or temporarily modify an entity MUST be `Effect_Base` subclasses — never hand-rolled bools + timers + freeze-reason calls. Plain timers (cooldowns, spawn schedules) don't need one. NOT components: `new()`, never `add_component`; no `@ao_serialize`.

## API
```csl
Effect_Base :: class {
    entity: Entity;  // set by attach
    player: Player;  // set by attach; null on non-players — never deref then
    player_specific: struct {
        freeze_player: bool;           // agent velocity forced to 0
        disable_movement_inputs: bool; // input ignored; your code can still drive agent.velocity
    };
    start_time: float #read_only;  // don't shadow (nor next_effect/prev_effect)
    get_elapsed_time       :: method() -> float;
    get_duration_remaining :: method() -> float;  // 0 if no duration set
    set_duration  :: method(duration: float);  // auto-remove after (interrupt=false); >0 unchecked; legal before attach
    remove_effect :: method(interrupt: bool);  // idempotent
}
set_active_effect  :: proc(entity, e: $T);  // exclusive: interrupts current active
add_passive_effect :: proc(entity, e: $T);  // stackable (slows, buffs, invuln)
has_effect :: proc(entity, $T, mode := Try_Get_Effect_Mode.EXACT_MATCH) -> bool;
get_effect :: proc(entity, $T, mode := .EXACT_MATCH) -> (T, bool);
remove_effect :: proc(entity, type: typeid, interrupt: bool) -> bool; // first exact-type match
remove_all_effects :: proc(entity);  // interrupt=true
entity.get_active_effect() -> Effect_Base;  // null if none — gate AI/ability logic on this
it := effect_iterator(entity); while it.next() { /* it.current */ }
```
`.ALLOW_INHERITANCE` matches subclasses. The active effect is also in the chain.

## Callbacks
Bound at attach by compile-time name lookup; a MISNAMED callback (`on_start`, `update`) compiles fine and SILENTLY never runs (wrong signature on a correct name = compile error). All optional:
```csl
effect_start       :: method()                // fires synchronously INSIDE the attach call
effect_update      :: method(dt: float)
effect_late_update :: method(dt: float)       // player effects: screen UI legal here; guard is_local_or_server()
effect_draw        :: method(dt: float)       // cosmetic-only; skipped on resim, interactive UI must use `effect_update`/`effect_late_update`.
effect_end         :: method(interrupt: bool) // the ONLY place cleanup may live
```
Attach the concrete instance from `new(My_Effect)` — don't upcast to `Effect_Base` first (binding uses the attach-site type).

## Attach
`set_active_effect` first ends the current active with `interrupt=true` (its `effect_end` runs BEFORE your effect starts; asserts if it installs a replacement active). Attach sets fields, links chain, calls `effect_start`, THEN adds counted freeze/input reasons per flags, then re-applies pre-attach `set_duration`.
- Assign every field `effect_start` reads BEFORE attaching — attach-then-assign = zero-values.
- Set `player_specific` flags in `effect_start` or before attach; NEVER flip mid-effect — removal re-reads flags → leaked/double-removed reason (stuck player).
- Never call `add_freeze_reason`/`add_disable_movement_input_reason` yourself for effect locking — framework owns the pairing.

## Removal
`remove_effect(interrupt)`: removes reasons per flags, clears slot, unlinks, then calls `effect_end(interrupt)`, then un-roots.
- After self-removal inside update callbacks, `return` immediately — `this`/fields are invalid.
- Never reuse a removed instance — its "already ending" latch never resets; `new()` per activation.
- interrupt=false: natural completion (own remove, duration expiry). interrupt=true: displaced by `set_active_effect`, `remove_all_effects`, entity destroy.
- Restore UNCONDITIONALLY in `effect_end` everything you mutated (friction, velocity, alpha, animation). Gate only completion logic (respawn/reward/chaining) on `!interrupt`.
- `effect_end` with interrupt=true must NOT install a new active effect — engine assert (destroy path: no assert, still broken); chain only on interrupt=false.
- `entity.destroy()` is deferred; still `return` after calling it from a callback; don't also self-remove.

## Movement
- `freeze_player`: agent zeroes velocity every step — no agent-driven movement; transform sets still move it; stationary states only.
- `disable_movement_inputs`: input zeroed, agent still simulates — drive `player.agent.velocity` in `effect_update` (correct move path, not transform teleports).
- `player.override_movement_input_for_next_step(input)` replaces input for one movement step, including with `{0,0}`. Call it from each `effect_update` that needs scripted input; it is applied after and therefore bypasses disabled-input reasons.

## Timing / multiplayer
- Fixed 32 Hz sim: dt = 0.03125 (0.3 s ≈ 10 ticks).
- Prefer `set_duration` over manual elapsed checks — removal guaranteed even without `effect_update`. `get_duration_remaining()` for countdowns.
- Effects are synced/predicted/rolled-back sim state: attach/remove in the shared predicted path, never server/local-gated. Per-swing state (hit-dedup user-id lists) lives on the effect instance, not globals.
- An interpolation anchor wraps `effect_update`/`late_update`/`draw`; `effect_start`/`end` run at the attach/remove call site under the CALLER's anchor.
- Effects update just before the owner's `ao_update`; gate normal logic: `if entity.get_active_effect() != null return;`

## Player state machine (`player.animator.state_machine`)
- Auto-return-to-Idle one-shots: "dodge_roll", "collect_item", "flinch", "grow_big".
- Stick until "RESET": "death", "start_eating"; "fall_hurt"/"fall_safe" (auto-chain into Get_Up — no exit); electrocute/sleep end poses.
- "teleport_away" holds until you fire "teleport_appear", which then auto-returns to Idle.
- Bools: "electrocute"/"sleep" true=enter loop, false exits into a TERMINAL end pose — still fire "RESET". "ghost_form" false returns to locomotion itself. "moving"/"use_ik" engine-managed — don't touch.
- Attack layer (overlays locomotion, auto-clears, no RESET): "attack", "punch", "shoot".
- "RESET" = global return to Idle. `effect_end`: always for stick states; for one-shots on `interrupt`.

## Patterns
- Dash: `disable_movement_inputs`; save+zero friction; "dodge_roll"; `set_duration`; drive `agent.velocity`; `effect_end` restores friction, zeroes velocity, "RESET" if interrupt.
- Passive modifiers (slow/invuln): empty marker effect + `set_duration`; consumer recomputes from base each frame via `effect_iterator`/`has_effect` — never `*=` a persistent field per frame.
