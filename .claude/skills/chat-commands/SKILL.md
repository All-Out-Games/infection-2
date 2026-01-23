---
name: chat-commands
description: "For creating in-game chat commands that players can invoke."
---
# Chat Commands

Chat commands let players trigger game actions by typing in chat. Commands are procedures annotated with `@chat_command`.

## Basic Usage

```csl
heal_player :: proc(player: Player, amount: int = 50) {
    player.health += amount;
    Notifier.notify(player, "Healed for %!", {amount});
} @chat_command @any
```

Players type `/heal_player 100` in chat to invoke.

> Chat commands run on the server. Use `Notifier.notify(player, ...)` to send feedback—it automatically sends an RPC to that player's client.

## Permission Annotations

| Annotation | Who Can Use |
|------------|-------------|
| `@any` | All players |
| `@vip` | VIP players and admins |
| `@youtuber` | Youtuber players and admins |
| (none) | Admins only |

```csl
ping :: proc(player: Player) {
    Notifier.notify(player, "Pong!");
} @chat_command @any

tp_spawn :: proc(player: Player) {
    player.entity->set_local_position(g_spawn_point);
} @chat_command @vip

skip_wave :: proc(player: Player) {
    // Admin only - no @any, @vip, or @youtuber
    g_wave_manager->skip_to_next_wave();
} @chat_command
```

## Supported Parameter Types

The first parameter must always be `Player`. Additional parameters can be:

| Type | Example Input |
|------|---------------|
| `string` | `hello` or `"hello world"` |
| `int`, `s64`, etc. | `42`, `-10` |
| `float`, `f64` | `3.14` |
| `bool` | `true`, `false`, `1`, `0` |
| `Player` | Player name (e.g. `josh`) |

## Optional Parameters

Use default values to make parameters optional:

```csl
spawn_enemy :: proc(player: Player, enemy_type: string = "zombie", count: int = 1) {
    for i: 0..count-1 {
        spawn_enemy_at(player.entity.world_position, enemy_type);
    }
} @chat_command @any
```

Players can call:
- `/spawn_enemy` → spawns 1 zombie
- `/spawn_enemy skeleton` → spawns 1 skeleton
- `/spawn_enemy skeleton 5` → spawns 5 skeletons

## Getting Command Usage

Players can append `?` to see parameter info:

```
/spawn_enemy?
```

Output:
```
spawn_enemy, 2 parameter(s):
enemy_type: string (optional)
count: int (optional)
```

## String Arguments with Spaces

Use quotes for string arguments containing spaces:

```csl
say :: proc(player: Player, message: string) {
    broadcast_message(format_string("%: %", {player->get_username(), message}));
} @chat_command @any
```

```
/say "Hello everyone!"
```

## Complete Example

```csl
tp :: proc(player: Player, target: Player) {
    player.entity->set_world_position(target.entity.world_position);
    Notifier.notify(player, "Teleported to %", {target->get_username()});
} @chat_command @any

set_speed :: proc(player: Player, multiplier: float = 2.0) {
    player.speed_multiplier = multiplier;
    Notifier.notify(player, "Speed set to %x", {multiplier});
} @chat_command @vip

reset_progress :: proc(player: Player, target: Player = null) {
    // Admin only
    p := target != null ? target : player;
    Save.delete_key(p, "xp");
    Save.delete_key(p, "level");
    Notifier.notify(player, "Reset progress for %", {p->get_username()});
} @chat_command
```

## Best Practices

1. **Provide defaults** - Make parameters optional when sensible
2. **Keep names short** - Players type these manually
