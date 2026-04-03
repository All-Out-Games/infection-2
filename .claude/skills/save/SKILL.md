---
name: save
description: "For persisting player data across joins if required  "
---
# CSL Save System

Per-player key-value store that persists across sessions.

## Save API Reference

```csl
Save :: struct {
    set_string :: proc(player: Player, key: string, value: string);
    get_string :: proc(player: Player, key: string, default: string) -> string;

    set_int    :: proc(player: Player, key: string, value: s64);
    get_int    :: proc(player: Player, key: string, default: s64) -> s64;

    set_f64    :: proc(player: Player, key: string, value: f64);
    get_f64    :: proc(player: Player, key: string, default: f64) -> f64;

    // For complex data — see the json skill
    set_json     :: proc(player: Player, key: string, value: ref $T);
    try_get_json :: proc(player: Player, key: string, out: ref $T) -> bool;

    delete_key :: proc(player: Player, key: string);
}
```

## Basic Usage

Load in `ao_start`, save on change:

```csl
Player :: class : Player_Base {
    current_xp: s64;
    current_level: s64;

    ao_start :: method() {
        current_xp = Save.get_int(this, "xp", 0);
        current_level = Save.get_int(this, "level", 1);
    }
}

// Save when data changes
Save.set_int(player, "xp", player.current_xp);
Save.set_string(player, "selected_skin", "knight");
Save.set_f64(player, "music_volume", 0.8);
```

## Boolean Storage

No native bool save — store as int:

```csl
Save.set_int(player, "tutorial_complete", tutorial_complete ? 1 : 0);
tutorial_complete = Save.get_int(player, "tutorial_complete", 0) != 0;
```

## Save Versioning

Use a version key to handle migrations when save format changes:

```csl
ao_start :: method() {
    save_version := Save.get_int(this, "version", 0);

    if save_version < 5 {
        save_version = 5;
        Save.delete_key(this, "xp");
        Save.delete_key(this, "level");
    }

    if save_version < 6 {
        save_version = 6;
        hp := Save.get_int(this, "hp", 0);
        Save.delete_key(this, "hp");
        Save.set_f64(this, "hp", hp.(f64));
    }

    Save.set_int(this, "version", save_version);

    // Load data after migration
    current_xp = Save.get_int(this, "xp", 0);
    current_level = Save.get_int(this, "level", 1);
    hp = Save.get_f64(this, "hp", 100);
}
```

## Game-Level Save API

For data shared across all players (global state, not per-player):

```csl
Save :: struct {
    set_game_string      :: proc(key: string, value: string);
    get_game_string      :: proc(key: string, default: string) -> string;
    get_all_game_strings :: proc() -> []Save_Game_String;

    increment_game_int   :: proc(key: string, amount: s64, optimistic_update: bool = true);
    get_game_int         :: proc(key: string, default: s64) -> s64;
    get_all_game_ints    :: proc() -> []Save_Game_Int;
}

Save_Game_String :: struct { key: string; value: string; }
Save_Game_Int    :: struct { key: string; value: s64; }
```

```csl
Save.set_game_string("world_record_holder", player->get_username());
difficulty := Save.get_game_string("server_difficulty", "normal");

// Atomically increment — safe for concurrent updates from multiple players
// optimistic_update (default true) updates local value immediately while server confirms
Save.increment_game_int("total_games_played", 1);
total_games := Save.get_game_int("total_games_played", 0);
```

### Iterating All Game Data

```csl
all_strings := Save.get_all_game_strings();
for entry: all_strings {
    log_info("Key: %, Value: %", {entry.key, entry.value});
}
```

### Game-Level vs Player-Level

| Use Case | API |
|----------|-----|
| Player XP, inventory, preferences | `Save.set_int(player, ...)` / `Save.set_string(player, ...)` |
| Global counters (kills, games played) | `Save.increment_game_int(...)` |
| World records, server config | `Save.set_game_string(...)` |
