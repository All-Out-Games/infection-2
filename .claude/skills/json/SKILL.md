---
name: json
description: "For serializing and deserializing data to/from JSON strings."
---
# JSON Serialization

The JSON system provides serialization and deserialization of CSL data structures to JSON strings. Only fields marked with `@ao_serialize` are included.

## Core Concepts

1. **Opt-in serialization** - Only fields with `@ao_serialize` are serialized
2. **Type preservation** - Supports strings, numbers, bools, and nested classes
3. **Safe deserialization** - Use `try_deserialize` which returns success/failure

## JSON API Reference

```csl
JSON :: struct {
    serialize       :: proc(value: ref $T) -> string;
    try_deserialize :: proc(json: string, out: ref $T) -> bool;
}

// Direct Save integration (preferred for persistence)
Save :: struct {
    set_json     :: proc(player: Player, key: string, value: ref $T);
    try_get_json :: proc(player: Player, key: string, out: ref $T) -> bool;
}
```

Use `Save.set_json` / `Save.try_get_json` when persisting JSON to player saves. This avoids intermediate string allocation compared to `JSON.serialize` + `Save.set_string`.

## Basic Usage

### Defining Serializable Data

Mark fields with `@ao_serialize` to include them in serialization:

```csl
Player_Stats :: class {
    name: string @ao_serialize;
    level: int @ao_serialize;
    health: float @ao_serialize;
    internal_id: int;  // Not serialized (no @ao_serialize)
}
```

### Serializing to JSON

```csl
stats := new(Player_Stats);
stats.name = "Hero";
stats.level = 42;
stats.health = 87.5;

json := JSON.serialize(ref stats);
// Result: {"name": "Hero", "level": 42, "health": 87.5}
```

### Deserializing from JSON

Always use `try_deserialize` and check the return value:

```csl
loaded: Player_Stats;
if JSON.try_deserialize(json, ref loaded) {
    log("Loaded: % at level %", {loaded.name, loaded.level});
} else {
    log("Failed to parse JSON");
}
```

## Complete Example

### Save/Load Game State

```csl
Game_Settings :: class {
    music_volume: float @ao_serialize;
    sfx_volume: float @ao_serialize;
    difficulty: string @ao_serialize;
}

save_settings :: proc(player: Player, settings: Game_Settings) {
    Save.set_json(player, "settings", ref settings);
}

load_settings :: proc(player: Player) -> Game_Settings {
    settings: Game_Settings;
    if Save.try_get_json(player, "settings", ref settings) {
        return settings;
    }
    
    // Return defaults
    settings.music_volume = 1.0;
    settings.sfx_volume = 1.0;
    settings.difficulty = "normal";
    return settings;
}
```

### Nested Classes

```csl
Weapon :: class {
    name: string @ao_serialize;
    damage: int @ao_serialize;
}

Loadout :: class {
    primary: Weapon @ao_serialize;
    secondary: Weapon @ao_serialize;
}

// Serialize nested structure
loadout := new(Loadout);
loadout.primary = new(Weapon);
loadout.primary.name = "Sword";
loadout.primary.damage = 25;

json := JSON.serialize(ref loadout);
// Result: {"primary": {"name": "Sword", "damage": 25}, "secondary": null}
```

### Primitive Types

JSON works with primitive types directly:

```csl
// Vectors
pos := v2{10.5, 20.0};
json := JSON.serialize(ref pos);
// Result: {"x": 10.5, "y": 20.0}

// Restore
loaded_pos: v2;
JSON.try_deserialize(json, ref loaded_pos);
```

## Supported Types

| Type | JSON Representation |
|------|---------------------|
| `string` | `"value"` |
| `int`, `s64` | `42` |
| `float`, `f64` | `3.14` |
| `bool` | `true` / `false` |
| `v2` | `{"x": 1.0, "y": 2.0}` |
| `[..]T` (dynamic array) | `[...]` |
| `[]T` (managed array) | `[...]` |
| `[N]T` (fixed array) | `[...]` |
| Class with `@ao_serialize` | `{"field": value, ...}` |
| `null` | `null` |

## Schema Versioning

When your data structure changes over time, include a version field to handle migrations:

```csl
Player_Progress :: class {
    version: int @ao_serialize;
    max_health: int @ao_serialize;
    max_stamina: int @ao_serialize;
    unlocked_abilities: [..]string @ao_serialize;
}

CURRENT_PROGRESS_VERSION :: 3;

load_progress :: proc(player: Player) -> Player_Progress {
    progress: Player_Progress;
    if !Save.try_get_json(player, "progress", ref progress) {
        progress.version = CURRENT_PROGRESS_VERSION;
        progress.max_health = 100;
        progress.max_stamina = 50;
        return progress;
    }
    
    // v1 -> v2: health was stored as float, now int (just reset it)
    if progress.version < 2 {
        progress.version = 2;
        progress.max_health = 100;
    }
    
    // v2 -> v3: added stamina system
    if progress.version < 3 {
        progress.version = 3;
        progress.max_stamina = 50;
    }
    
    // Save migrated data
    if progress.version != CURRENT_PROGRESS_VERSION {
        progress.version = CURRENT_PROGRESS_VERSION;
        save_progress(player, ref progress);
    }
    
    return progress;
}

save_progress :: proc(player: Player, progress: ref Player_Progress) {
    progress.version = CURRENT_PROGRESS_VERSION;
    Save.set_json(player, "progress", ref progress);
}
```

### Migration Tips

- Always bump `CURRENT_VERSION` when changing the schema
- Run migrations in order (v1→v2, then v2→v3)
- Set sensible defaults for new fields
- Save immediately after migration to persist the updated format

## Best Practices

1. **Use `Save.set_json` / `Save.try_get_json` for persistence** - More efficient than separate serialize + set_string
2. **Handle missing data** - Provide defaults when deserialization fails
3. **Use `@ao_serialize` selectively** - Only serialize what you need to persist
4. **Keep structures simple** - Avoid deeply nested or circular references
5. **Include a version field** - Makes future schema changes manageable
