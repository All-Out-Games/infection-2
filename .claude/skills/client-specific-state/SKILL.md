---
name: client-specific-state
description: Per-player presentation of synced world state - objects only one player can see or pick up, hiding/disabling/restyling entities on one client, reapplying client overrides after server syncs via ao_on_state_sync, and late-join/rejoin visual correctness.
---
Every server sync wipes client-local changes to synced state, then calls `ao_on_state_sync :: method()` on implementing components — but NOT on components disabled in synced state (keep the controller enabled; hide children instead). Client-only, never server; fires after each sync AND at drop-in (ao_start isn't replayed for late joiners). Reapply every sync; one-shots flicker back. Small + idempotent: derive presentation (enabled, color, materials) from synced fields. Never: gameplay writes, spawn/destroy (wiped next sync), scene sweeps, drawing. Owner = user-id STRING (empty = public; Player/Entity refs die on disconnect).

```csl
set_owner :: method(p: Player) {
  owner_user_id = {};
  if p != null { owner_user_id = p.get_user_id(); }
  refresh();
}
ao_on_state_sync :: method() { refresh(); }
refresh :: method() {
  if Game.is_server() return; // presentation-only guard this specific case bypasses the broader AGENTS.md rule
  visible := true;
  if owner_user_id.count > 0 {
    if lp, ok := Game.get_local_player(); ok {
      if owner_user_id != lp.get_user_id() { visible = false; }
    }
  }
  entity.set_local_enabled(visible);
}
can_use :: method(p: Player) -> bool { // gate REQUIRED
  return owner_user_id.count == 0 || p.get_user_id() == owner_user_id;
}
```

- Hiding is client-only; the object stays live elsewhere - without can_use it's still usable by ineligible players. set_local_enabled in shared code runs everywhere.
- Game.get_local_player() -> (Player, bool); ok false on server/early frames - default visible.
- Core: Dropped_Item.spawn(position, item); set_exclusive(player) (null = public) handles visibility, gate, despawn, claims. Ghosting: color/alpha, keep gate.
