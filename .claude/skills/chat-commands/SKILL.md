---
name: chat-commands
description: "For creating in-game chat commands that players can invoke."
---
# Chat Commands

Annotate a procedure with `@chat_command` to make it invocable via `/proc_name` in chat. Commands run on the server.

```csl
heal_player :: proc(player: Player, amount: int = 50) {
    player.health += amount;
    Notifier.notify(player, "Healed for %!", {amount});
} @chat_command @any
```

Use `Notifier.notify(player, ...)` to send feedback -- it sends an RPC to that player's client.

## Permission Annotations

| Annotation | Who Can Use |
|------------|-------------|
| `@any` | All players |
| `@vip` | VIP players and admins |
| `@youtuber` | Youtuber players and admins |
| (none) | Admins only |

## Parameter Rules

First parameter must be `Player`. Supported additional types: `string`, `int`/`s64`, `float`/`f64`, `bool`, `Player` (resolved by name). Default values make parameters optional.

```csl
spawn_enemy :: proc(player: Player, enemy_type: string = "zombie", count: int = 1) {
    for i: 0..count-1 {
        spawn_enemy_at(player.entity.world_position, enemy_type);
    }
} @chat_command @any
```

String arguments with spaces require quotes: `/say "Hello everyone!"`

Players append `?` to see usage: `/spawn_enemy?`
