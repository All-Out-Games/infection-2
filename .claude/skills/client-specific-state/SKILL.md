---
name: client-specific-state
description: Only read if you need to display player specific world state
---
### Client-Side State Overrides: ao_on_state_sync

After the client receives a state sync from the server, it may need to apply local overrides to the synced state. For example, you might want to hide entities that should only be visible to certain players, or disable components that shouldn't run on this particular client.

The `ao_on_state_sync` component method is called on the client immediately after a component's state has been synchronized from the server. This gives you a hook to apply client-local modifications.

```csl
// This method is only called on clients, never on the server.
ao_on_state_sync :: method()
```

### Use Cases

- **Player-exclusive visibility** - Hide entities that belong to other players
- **Local entity disabling** - Disable entities that shouldn't exist on this client
- **Client-specific state** - Override synced values with client-local versions

### Example: Player-Exclusive Dropped Items

```csl
Dropped_Item :: class : Component {
    exclusive_to_player: Player;
    
    ao_on_state_sync :: method() {
        // After receiving state from server, check if this item is exclusive
        visible := true;
        if exclusive_to_player != null {
            local_player := Game.try_get_local_player();
            if exclusive_to_player != local_player {
                visible = false;
            }
        }
        entity->set_local_enabled(visible);
    }
}
```

### ⚠️ Beware of Client-Server Desync with `ao_on_state_sync`

When you use `ao_on_state_sync` to hide or disable things on the client, remember that the server still has the original state. This divergence can cause unexpected behavior.

**Example:** If you disable an entity with an `Interactable` component on the client, the interactable is still active on the server. When the player presses the interact button, the server will still detect and consume the input—even though the player can't see the object.

To handle this correctly, you must also add server-side checks. For the dropped items example, we check `exclusive_to_player` in `can_use`:

```csl
can_use :: method(player: Player) -> bool {
    // Server-side check: prevent other players from interacting
    if exclusive_to_player != null && player != exclusive_to_player {
        return false;
    }
}
```
**Rule of thumb:** If you hide something from a player using `ao_on_state_sync`, also add a corresponding server-side check to prevent that player from interacting with it.
