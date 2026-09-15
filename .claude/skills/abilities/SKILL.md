---
name: abilities
description: Reference this when implementing player abilities or action buttons - attacks, dashes, sprint/hold actions, aimed or projectile shots, item-use actions, cooldowns, ability keybinds, role/state-dependent ability sets, or ammo/charge indicators on ability buttons.
---
# CSL Ability System
Subclass `Ability_Base` + call `draw_ability_button`; engine owns discovery, instances, button UI, cooldown ticking, keybinds, grey-out, aim indicators

## Lifecycle
- Subclasses auto-discovered; one instance per class per player at player start, then optional `on_init :: method()` (`player` already assigned). Never instantiate/register manually.
- Per-ability state = fields on the ability or player (per-player, synced); never module globals.
- `on_update :: method(params: ref Ability_Update_Params)` required; `on_init`/`can_use`/`on_draw_button` optional. It has no `dt` parameter: use `get_fixed_delta_time()` for per-tick timing.
- `on_update` runs ONLY inside `draw_ability_button`; draw in `Player.ao_late_update` under `is_local_or_server()` (predicted on client, authoritative on server — under `is_local()` the server never runs it and reconciliation reverts all effects). Undrawn button = on_update never runs; branch draw calls to show/hide, never park logic in a hidden ability. `current_cooldown` keeps ticking while hidden (never decrement it yourself).

## Activation gate
on_init sets `name` and `icon` (Texture_Asset; null = name-text fallback). On fire set `current_cooldown`; run effects in the shared predicted path, no guards.
To support `Tutorial_Step.use_ability`, call `Tutorial.report_ability_used(this)` once after applying a successful action, including any cooldown/resource changes. The call uses this ability's owner and type. Do not report starting/cancelling aim or rejected actions; sustained abilities report their successful start once. Use the shared predicted gameplay path without tutorial-stage or server-only guards.
`params.can_use` order: 1) `current_cooldown <= 0` (on cooldown, `can_use()` isn't called), 2) your `can_use() -> bool`, 3) `Player.ao_can_use_ability(ability)`. False anywhere greys the button. Never fire while false; never re-implement these checks.

## Drawing buttons
`draw_ability_button(this, Shoot_Ability, 0);`
- Indices 0-5 only (out-of-range faults); 0 = big primary near bottom-right, 1-5 small around it; main action at 0. Asserts if T isn't an Ability_Base subclass.
- Fully automatic (icon/name fallback, pressed sprite, device scaling, PC keybind sprite, grey-out, cooldown numeral); custom cooldown text/radial/timer on/near it = defect; no custom buttons/hotbars.
- Greying is visual only — greyed buttons still report presses; gate on `params.can_use`. (`Test.use_ability` refuses to press a greyed slot.)

## Ability_Update_Params (extends Interact_Result)
`can_use, hovering, just_pressed, active (held), released, clicked, drag_offset (press-relative, radius=1, len<=1), drag_direction (unit), right.clicked`
- Pointer: just_pressed press-start frame; active while held; released on end; clicked on release if press started AND ended on button.
- PC slot keybind: key-down sets `clicked` only; never just_pressed/active/released.
- Tap = `clicked && can_use` (mouse/touch/keybind). Firing on just_pressed drops keybind activations.
- Hold/charge phases are pointer-only; read keys via `update_holding_ability`/`Keybinds.get_keybind_held` — `params.active` never reflects a held key.
- just_pressed only stamps state (charge start time); fire on clicked (tap) or released (charge), with can_use.
- Drag fields valid only while `active || clicked || released`. `mouse_position_on_press` auto-captured; don't cache your own.
- Params/keybinds/helpers are the ONLY input sources; never poll raw input.

Directions: derive from inputs, never position deltas (breaks under teleports/reconciliation): `activation.direction` (unit); `player.input_this_frame` ({0,0} idle; `player.agent.input_this_frame` is already consumed and zeroed by the time Player callbacks run, so never read that one); `player.last_aim_direction` (zero until first aim — fall back if zero).

## Hold ability
`Ability_Utilities.update_holding_ability(player, ref params, keybind = 0) -> { active: bool }` — active = button held (all platforms) OR keybind held (PC). Gate on `.active && params.can_use`.
- `draw_but_dont_use_keybind = true` draws the key hint but zeroes the widget's keybind so key-down doesn't also fire a spurious `clicked`; set whenever a shown keybind is read via this helper.
- `Keybinds.get_keybind_held/down/up(player, keybind)` are prediction-safe.
- Sustained abilities usually set no cooldown; end on release or can_use false.

## Aimed abilities
Set `is_aimed_ability = true` in on_init; act ONLY on the returned `{ direction: v2, activate: bool }` — helpers draw the aim line and gate `activate` on can_use (no re-check, no manual indicator, no mutual-exclusion code).

`Ability_Utilities.full_update_aimed_ability(player, ref params)` — always-aiming primaries (set `disable_keybind = true`; on PC the ability button is display-only):
- PC: continuous mouse aim; press/hold in the game view to fire. `activate` is true EVERY held frame — cooldown IS the fire rate; always set one (0 = every sim frame).
- Mobile: hold and drag past 0.25 button radius to aim; `activate` is true on release. A bare tap does nothing.
- Auto-suspends while `player.active_ability != null`.

`Ability_Utilities.full_update_targeted_aimed_ability(player, this, ref params)` — click-to-target (pass `this` 2nd):
- PC: button click/keybind enters targeting; click anywhere fires; right-click cancels. Mobile: press-drag-release. Other slots grey while an aimed button is held.
- Dash/roll movement: effects skill (`player.entity.set_active_effect`), not ad-hoc timers.

Cancel aim mode: `player.active_ability` is the single truth for targeting; helpers set/clear it on fire/cancel. Clear it (`active_ability = null;`) in the shared predicted path when stun/kit-swap invalidates aiming — entering targeting is NOT blocked by can_use (only final activate is) and greyed buttons still take presses, so a stun leaves the player stuck aiming; a no-longer-drawn button's on_update can never clear stale active_ability, permanently suspending every always-aim ability.

Low-level (custom aim visuals only): `update_aiming_ability(player, ref params) -> { aim, activate, cancel: bool, aim_direction: v2 }` — no line, no can_use gate; `update_targeted_ability(player, ability, ref params) -> { targeting: bool }` — maintains player.active_ability.

## Keybinds
- Slot defaults: 0=Q, 1=Z, 2=X, 3=C, 4=R, 5=F. Keybind sprites PC-only.
- `Keybinds.register(name: string, default: Input) -> Keybind` — global `ao_before_scene_load` only (defaults finalize + saved rebindings apply right after); store in a global var; assign to `keybind_override` in on_init.
- Asserts on duplicate names; "Ability 1"-"Ability 6" already registered; names appear in the rebinding UI.
- Input enum (partial): .A-.Z, .SPACE, .LEFT_SHIFT, .NR_0-.NR_9, .F1-.F25, .UP/.DOWN/.LEFT/.RIGHT.
- `keybind_override = 0` = slot default; `disable_keybind = true` = no key shown/used. Don't override to another drawn slot's default.

## Conditional sets & global rules
Every ability instance exists on every player; visibility = which draw calls you issue this frame (branch on role/state). Game-wide rules (dead, cutscene) go in ONE place — `Player.ao_can_use_ability(ability: Ability_Base) -> bool`; greys, doesn't hide. Per-ability resources go in its `can_use`; don't duplicate global checks per ability.

## Button extras & access
Ammo/charge display: `on_draw_button :: method(rect: Rect)` runs inside the button draw; non-cooldown extras only; never place separate screen-space UI over the button.
Access from elsewhere: `for i: 0..player.abilities.count-1 { if player.abilities[i].type == T { player.abilities[i].(T).ammo += 30; } }`
