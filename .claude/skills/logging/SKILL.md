---
name: logging
description: Only for advanced logging/debugging use cases
---
## Debugging and Logging

The client constantly resimulates frames, so client logs are filled with duplicates. Prefer server logs for gameplay debugging.

To log on the client without duplicates, guard with `Game.is_predicted_frame()` (returns `false` for resimulated frames, always `true` on server):

```csl
if Game.is_predicted_frame() {
    log_info("Player position: %", {player.entity.world_position});
}
```
