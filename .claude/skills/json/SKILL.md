---
name: json
description: "For serializing and deserializing data to/from JSON strings."
---
# JSON Serialization

Only fields marked with `@ao_serialize` are serialized/deserialized. This is a huge footgun you have to pay close attention to mark your fields with this. 

## API Reference

```csl
JSON :: struct {
    serialize       :: proc(value: ref $T) -> string;
    try_deserialize :: proc(json: string, out: ref $T) -> bool;
}
```

For persistence, prefer `Save.set_json` / `Save.try_get_json` (see the save skill)

## Basic Usage

```csl
Player_Stats :: class {
    name: string @ao_serialize;
    level: int @ao_serialize;
    health: float @ao_serialize;
    internal_id: int; // Not serialized (no @ao_serialize)
}

stats := new(Player_Stats);
stats.name = "Hero";
stats.level = 42;
stats.health = 87.5;

json := JSON.serialize(ref stats);
// {"name": "Hero", "level": 42, "health": 87.5}

loaded: Player_Stats;
if JSON.try_deserialize(json, ref loaded) {
    log("Loaded: % at level %", {loaded.name, loaded.level});
}
```

## Nested Classes

Uninitialized class fields are **omitted** from the output (not serialized as `null`):

```csl
Weapon :: class {
    name: string @ao_serialize;
    damage: int @ao_serialize;
}

Loadout :: class {
    primary: Weapon @ao_serialize;
    secondary: Weapon @ao_serialize;
}

loadout := new(Loadout);
loadout.primary = new(Weapon);
loadout.primary.name = "Sword";
loadout.primary.damage = 25;

json := JSON.serialize(ref loadout);
// {"primary": {"name": "Sword", "damage": 25}}
// secondary is omitted because it is uninitialized (all-zero)
```

## Primitives

JSON works with primitive types directly:

```csl
pos := v2{10.5, 20.0};
json := JSON.serialize(ref pos); // {"x": 10.5, "y": 20.0}

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

Include a `version: int @ao_serialize` field. On load, run migrations in order (`v < 2`, then `v < 3`, etc.) and save after migrating. See the save skill's versioning section for the full pattern.
