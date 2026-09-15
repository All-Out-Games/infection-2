---
name: chat-commands
description: Add in-game chat commands that developers can use to make their testing process easier (e.g. setting coins, resetting progress, admin tools)
---
Annotate a procedure with `@chat_command` to make it invocable via `/proc_name` in chat. The procedure name is the command verbatim: name it `lobby` for `/lobby` (a `cmd_lobby` proc is `/cmd_lobby`). Commands run on the server.

```csl
heal :: proc(player: Player, amount: int = 50) {
    player.health += amount;
    Notifier.notify(player, `Healed for {amount}!`);
} @chat_command @owner
```

## Permission Annotations

`@any` All players
`@vip` All Out VIP subscribers
`@youtuber` Verified YouTubers
`@owner` Game owner
`@owner_or_editor` Game owner and their team (this is what most people want when they say "admin commands"; also the default when no permission annotation is given)

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

## Runtime Behavior
- Command invocation ignores surrounding whitespace. Names prefer an exact-case match, then fall back to a case-insensitive match.
- A `Player` argument is the whole token (quote names containing spaces: `/kick "Big Bob"`; names with digits or underscores such as `Editor_1001` need no quotes) and is matched against display names exactly (case-sensitive). If nobody matches, the command is aborted.
- Arguments that fail to parse abort the command; missing optional arguments take their defaults.
- Permission is granted by `@any`, platform admin status, `@vip`/`@youtuber` flags, or game owner/editor status for `@owner`/`@owner_or_editor`.
- Games launched from the editor (including `run_tests` and `start_game`) bypass permission checks entirely, so test with the permission you ship in mind.
