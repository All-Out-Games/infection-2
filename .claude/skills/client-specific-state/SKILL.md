---
name: client-specific-state
description: Only read if you need to display player specific world state
---
### Client-Side State Overrides: ao_on_state_sync

The `ao_on_state_sync` component method is called on the client immediately after a component's state has been synchronized from the server. Use it to apply client-local modifications (hiding entities, disabling components per-player).

```csl
// Only called on clients, never on the server.
ao_on_state_sync :: method()
```

### Example: Player-Exclusive Dropped Items

```csl
Dropped_Item :: class : Component {
    exclusive_to_player: Player;

    ao_on_state_sync :: method() {
        visible := true;
        if exclusive_to_player != null {
            if local_player, ok := Game.get_local_player(); ok {
                if exclusive_to_player != local_player {
                    visible = false;
                }
            }
        }
        entity.set_local_enabled(visible);
    }
}
```

### Client-Server Desync Warning

When you hide/disable something via `ao_on_state_sync`, the server still has the original state. If an entity has an `Interactable`, the server will still detect interactions even though the client can't see it. Always add a corresponding server-side check:

```csl
can_use :: method(player: Player) -> bool {
    if exclusive_to_player != null && player != exclusive_to_player {
        return false;
    }
}
```
