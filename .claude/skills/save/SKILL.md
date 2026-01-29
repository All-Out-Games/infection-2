---
name: save
description: "For persisting player data across joins if required  "
---
# CSL Save System

The Save system provides a simple key-value store for persisting player data across sessions. Data is stored per-player and persists between game sessions.

## Core Concepts

1. **Data is per-player** - Each player has their own isolated save data
2. **Key-value storage** - Data is stored using string keys
3. **Type-specific methods** - Use the appropriate getter/setter for your data type
4. **Default values** - Getters return a default value if the key doesn't exist

## Save API Reference

```csl
Save :: struct {
    set_string :: proc(player: Player, key: string, value: string);
    get_string :: proc(player: Player, key: string, default: string) -> string;
    
    set_int    :: proc(player: Player, key: string, value: s64);
    get_int    :: proc(player: Player, key: string, default: s64) -> s64;
    
    set_f64    :: proc(player: Player, key: string, value: f64);
    get_f64    :: proc(player: Player, key: string, default: f64) -> f64;
    
    // JSON (for complex data structures)
    set_json     :: proc(player: Player, key: string, value: ref $T);
    try_get_json :: proc(player: Player, key: string, out: ref $T) -> bool;
    
    delete_key :: proc(player: Player, key: string);
}
```

## Basic Usage

### Saving Data

Save data whenever it changes:

```csl
// Save player progress
Save.set_int(player, "xp", player.current_xp);
Save.set_int(player, "level", player.current_level);

// Save player preferences
Save.set_string(player, "selected_skin", "knight");
Save.set_f64(player, "music_volume", 0.8);
```

### Loading Data

Load data when the player joins, typically in `ao_start`:

```csl
Player :: class : Player_Base {
    current_xp: s64;
    current_level: s64;
    total_things_eaten: s64;

    ao_start :: method() {
        // Load with default values for new players
        current_xp = Save.get_int(this, "xp", 0);
        current_level = Save.get_int(this, "level", 1);
        total_things_eaten = Save.get_int(this, "total_things_eaten", 0);
    }
}
```

## Save Versioning

When you change your save data format, use a version key to handle migrations:

```csl
ao_start :: method() {
    save_version := Save.get_int(this, "version", 0);

    if save_version < 5 {
        // Reset data for old save versions
        save_version = 5;
        Save.delete_key(this, "xp");
        Save.delete_key(this, "level");
        Items.destroy_all_items(default_inventory);
    }

    if save_version < 6 {
        // Health is now a float
        save_version = 6;
        hp := Save.get_int(this, "hp", 0);
        Save.delete_key(this, "hp");
        Save.set_f64(this, "hp", hp.(f64));
    }

    Save.set_int(this, "version", save_version);

    // Now load data normally
    current_xp = Save.get_int(this, "xp", 0);
    current_level = Save.get_int(this, "level", 1);
    hp = Save.get_f64(this, "hp", 100);
}
```

## Complete Example

### Player Stats System

```csl
Player :: class : Player_Base {
    mouth_stat: s64;
    stomach_stat: s64;
    chew_stat: s64;
    total_things_eaten: s64;

    ao_start :: method() {
        // Load stats from save with defaults
        mouth_stat         = Save.get_int(this, "mouth_level", 1);
        stomach_stat       = Save.get_int(this, "stomach_level", 1);
        chew_stat          = Save.get_int(this, "chew_level", 1);
        total_things_eaten = Save.get_int(this, "total_things_eaten", 0);
    }

    upgrade_stat :: method(stat_name: string) {
        switch stat_name {
            case "mouth": {
                mouth_stat += 1;
                Save.set_int(this, "mouth_level", mouth_stat);
            }
            case "stomach": {
                stomach_stat += 1;
                Save.set_int(this, "stomach_level", stomach_stat);
            }
            case "chew": {
                chew_stat += 1;
                Save.set_int(this, "chew_level", chew_stat);
            }
        }
    }
}
```

### Tracking Progress

```csl
on_eat_food :: proc(player: Player, food: Food) {
    player.total_things_eaten += 1;
    Save.set_int(player, "total_things_eaten", player.total_things_eaten);
}
```

### XP and Leveling System

```csl
add_xp :: proc(player: Player, amount: s64) {
    player.current_xp += amount;
    
    // Check for level up
    while true {
        xp_needed := get_xp_for_level(player.current_level + 1);
        if player.current_xp < xp_needed {
            break;
        }
        player.current_level += 1;
        player.current_xp -= xp_needed;
    }
    
    // Save XP progress
    Save.set_int(player, "xp", player.current_xp);
    Save.set_int(player, "level", player.current_level);
}
```

## Supported Data Types

| Type | Setter | Getter |
|------|--------|--------|
| String | `Save.set_string` | `Save.get_string` |
| Integer (s64) | `Save.set_int` | `Save.get_int` |
| Float (f64) | `Save.set_f64` | `Save.get_f64` |
| Complex structures | `Save.set_json` | `Save.try_get_json` |

## Saving Complex Data (JSON)

For data structures with multiple fields, use `Save.set_json` / `Save.try_get_json`. Only fields marked with `@ao_serialize` are saved.

```csl
Player_Progress :: class {
    version: int @ao_serialize;
    max_health: int @ao_serialize;
    unlocked_skins: [..]string @ao_serialize;
}

// Save
Save.set_json(player, "progress", ref progress);

// Load
progress: Player_Progress;
if !Save.try_get_json(player, "progress", ref progress) {
    // Key doesn't exist or parse failed - use defaults
    progress.max_health = 100;
}
```

See the **json** skill for schema versioning and migration patterns.

## Best Practices

1. **Load in `ao_start`** - Load all saved data when the player joins
2. **Save on change** - Save data immediately when it changes, not periodically
3. **Use meaningful key names** - Keys like `"level"` or `"total_kills"` are clear and maintainable
4. **Always provide sensible defaults** - New players will get the default value
5. **Use versioning** - Track a `"version"` key to handle save format migrations
6. **Delete obsolete keys** - Use `Save.delete_key` when migrating away from old data

## Common Patterns

### Boolean Storage

Store booleans as integers:

```csl
// Save
Save.set_int(player, "tutorial_complete", tutorial_complete ? 1 : 0);

// Load
tutorial_complete = Save.get_int(player, "tutorial_complete", 0) != 0;
```

### Resetting Player Data

```csl
reset_player_progress :: proc(player: Player) {
    Save.delete_key(player, "xp");
    Save.delete_key(player, "level");
    Save.delete_key(player, "total_kills");
    // etc.
    
    // Optionally set version to 0 to trigger migration on next load
    Save.set_int(player, "version", 0);
}
```

## Game-Level Save API

For data that should be shared across all players (not per-player), use the game-level save APIs. This is useful for global game state like world records, server settings, or shared progression.

### Game Save API Reference

```csl
Save :: struct {
    // Strings
    set_game_string      :: proc(key: string, value: string);
    get_game_string      :: proc(key: string, default: string) -> string;
    get_all_game_strings :: proc() -> []Save_Game_String;
    
    // Integers (with atomic increment)
    increment_game_int   :: proc(key: string, amount: s64, optimistic_update: bool = true);
    get_game_int         :: proc(key: string, default: s64) -> s64;
    get_all_game_ints    :: proc() -> []Save_Game_Int;
}

Save_Game_String :: struct {
    key: string;
    value: string;
}

Save_Game_Int :: struct {
    key: string;
    value: s64;
}
```

### Game-Level Usage

```csl
// Set a global high score
Save.set_game_string("world_record_holder", player->get_username());

// Get a global setting
difficulty := Save.get_game_string("server_difficulty", "normal");

// Atomically increment a global counter (safe for concurrent updates)
Save.increment_game_int("total_games_played", 1);

// Get a global counter
total_games := Save.get_game_int("total_games_played", 0);
```

### Atomic Integer Increments

Use `increment_game_int` for counters that multiple players might update simultaneously. The `optimistic_update` parameter (default `true`) immediately updates the local value while the server confirms the change.

```csl
// Track total kills across all players
on_enemy_killed :: proc() {
    Save.increment_game_int("global_kills", 1);
}

// Display on a leaderboard
total_kills := Save.get_game_int("global_kills", 0);
```

### Iterating All Game Data

```csl
// Get all stored game strings
all_strings := Save.get_all_game_strings();
for entry: all_strings {
    log_info("Key: %, Value: %", {entry.key, entry.value});
}

// Get all stored game integers
all_ints := Save.get_all_game_ints();
for entry: all_ints {
    log_info("Key: %, Value: %", {entry.key, entry.value});
}
```

### When to Use Game-Level vs Player-Level

| Use Case | API |
|----------|-----|
| Player XP, level, inventory | `Save.set_int(player, ...)` |
| Player preferences | `Save.set_string(player, ...)` |
| World records / high scores | `Save.set_game_string(...)` |
| Global kill counters | `Save.increment_game_int(...)` |
| Server configuration | `Save.set_game_string(...)` |
