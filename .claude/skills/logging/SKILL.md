---
name: logging
description: Only for advanced logging/debugging use cases
---
## Debugging and Logging

Because the client constantly resimulates frames, the client log is usually filled with duplicate messages. This makes print-debugging difficult.

### Recommended Approaches

1. **Look at server logs** - Usually the simplest solution for gameplay debugging
2. **Use `Game.is_predicted_frame()`** - Returns `false` for resimulated frames

```csl
// Only logs once per frame, not during resimulation
if Game.is_predicted_frame() {
    log_info("Player position: %", {player.entity.world_position});
}
```

**Note:** `Game.is_predicted_frame()` always returns `true` on the server.

### When to Use Each Approach

| Debugging Target | Approach |
|-----------------|----------|
| Gameplay logic | Check server logs |
| Local-only cosmetics | Use `is_predicted_frame()` check |
| Client-server disagreements | Compare both logs |