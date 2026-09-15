---
name: json
description: "For serializing and deserializing data to/from JSON strings: JSON.serialize / JSON.try_deserialize semantics, @ao_serialize fields, Save.set_json persistence, and evolving/versioning stored schemas."
---
# JSON Serialization (CSL)

## API

```csl
JSON :: struct {
    serialize       :: proc(obj: ref $T) -> string;
    try_deserialize :: proc(json: string, out_value: ref $T) -> bool;
}
```

Both take the value by `ref`. Deserialization returns its result through the out param, never as a return value.

This reflection-driven API is the only supported path: never build JSON by string concatenation or parse it by hand — define an annotated class/struct and round-trip it.

For per-player persistence, do not hand-roll `JSON.serialize` + `Save.set_string`; the Save layer has built-in JSON helpers (same serializer, one call):

```csl
Save.set_json(player, "key", ref value);
ok := Save.try_get_json(player, "key", ref out); // false: key never written OR stored text failed to parse
```

## `@ao_serialize` gates everything

Only fields annotated `@ao_serialize` are written or read. This applies to classes and structs alike, including fields inherited from a parent class (annotate them where they are declared). It is the only annotation the JSON system recognizes from CSL — there is no annotation for renaming fields or accepting `null`.

Field initializers are **class-only**. With one, the note comes after the value, and the value must be a compile-time constant:

```csl
Payload :: class {
    speed_mult: float = 1.5 @ao_serialize; // OK: class field initializer
}
Bad :: struct {
    speed_mult: float = 1.5 @ao_serialize; // COMPILE ERROR: "Variable assignments are not allowed inside struct or enum definitions."
}
```

Use `class` for any payload type that needs non-zero defaults; struct fields always default to zero.

## Error model

- `try_deserialize` returns `false` only for malformed JSON text. On `false` the destination is untouched — a fresh class destination is still null, so do not read fields off it.
- Syntactically valid JSON with the wrong shape does NOT return `false`: a kind mismatch panics the engine (hard crash). String where a number is expected, number where a string is expected, non-bool into `bool`, non-object into a class/struct, non-array into an array, and explicit JSON `null` into a class-typed field are all panics.
- Numeric mismatches are the opposite failure: any JSON number loads into any numeric field through a silent cast — int into float, float into int, narrowing width, sign changes all truncate/wrap with no panic and no `false`.
- The boolean therefore protects against corrupted/truncated text only, not schema mismatch. Only deserialize JSON that was produced by `JSON.serialize` of the same type or a schema-compatible revision (rules below). Never feed externally sourced or unknown-shape JSON into a typed deserialize.
- Always check the boolean; on `false`, log and fall back to a well-defined default state (`log` is the standard logging proc — an alias of `log_info`; `log_warning` / `log_error` also exist):

```csl
loaded: Config_Data;
if JSON.try_deserialize(text, ref loaded) {
    apply(loaded);
} else {
    log_warning("Config JSON failed to parse, using defaults");
    apply(new(Config_Data));
}
```

Silent tolerances (fine to rely on for evolution, never as validation): unknown keys in input are ignored; missing keys become field defaults; `null` into a `string` field yields `""`; enums read from either their numeric value or a member-name string; extra elements beyond a fixed array's length are dropped.

## Hand-authored JSON string literals

Two CSL literal traps break hand-written JSON constants (test payloads, tool commands):

- **Backtick strings treat `{` and `}` as interpolation delimiters.** A bare `{` in a backtick literal is a compile error ("Expected '}' after template string expression"). Write every literal JSON brace doubled — and note backticks have NO backslash escapes, but raw newlines and unescaped quotes are fine:

```csl
payload := `{{
    "version": 1,
    "coins": 5
}}`;
```

- **Ordinary `"..."` strings require `\"` for every quote** (common escapes like `\n`, `\t`, `\\`, `\"`, `\0` are supported). Simplest for short payloads:

```csl
payload := "{\"version\": 1, \"coins\": 5}";
```

## Destination semantics

- **Object load = fresh rebuild, then overwrite.** A class-typed destination or field gets a freshly allocated object on every load: fields start at their declared initializer values (zero where there is no initializer), then only keys present in the JSON overwrite them. You never need `new()` on the destination, and prior object contents cannot leak through. So: **missing field = declared initializer value for class fields, zero for everything else.**
- **Struct destinations are fully zero-filled before filling** — even a reused struct variable has ALL its annotated state reset (a field you set beforehand comes back 0 if its key is absent). Structs can never have initializers, so struct fields missing from input are always zero.
- **Bare array destinations are the one stale-data hazard.** Deserializing `[]` into an already-populated `[..]T` / `[]T` leaves the old elements in place, and a fixed `[N]T` only overwrites the first `min(N, input_count)` slots. Non-empty input fully replaces dynamic/managed arrays with fresh backing (no append). Rule: use a fresh zero-value destination for every deserialize call; never reuse a scratch object between loads.

## Output format facts

- Output is pretty-printed multi-line text (a top-level scalar prints as a single line). Never string-compare serialized JSON or assert exact output.
- **Default-byte omission:** a field is omitted from output when its raw bytes equal the field's declared initializer bytes — or all-zero bytes when it has no initializer. Consequences: `{}`/`{\n\n}` is a legitimate payload for an all-default object; a field explicitly set to `0` IS written when its declared initializer is non-zero (0 differs from the default); and because the test is over raw bytes, a runtime-assigned "empty" value (string set to `""`, array populated then cleared) may still appear in output. Never require a particular key to be present or absent. Round-trips work regardless, because missing = default on read.
- Floats with integral values print without a decimal point (`3` not `3.0`); otherwise fixed 16 digits after the decimal point, trailing zeros included (`1.5` → `1.5000000000000000`). Round-trips are exact; never string-compare output.
- Enums are written as their **numeric value**, never as a name. Reordering/renumbering an enum silently reinterprets stored data — give persisted enums explicit stable values.
- `null`: inside an object, a null class field is simply omitted (zero bytes), not written as `null`. Explicit `null` reaches output only for a top-level null class or a null element in an array of class references — and `null` cannot be deserialized back into a class (panic). Never serialize arrays of class references containing nulls; compact them first.

## Supported types

`string` • `int`/`s8`..`s64` (`int` == `s64`) • `u8`..`u64` • `float`/`f64` • `bool` • enum (numeric on the wire) • bit fields • `v2`/`v3`/`v4` (objects keyed `"x"`,`"y"`[,`"z"`,`"w"`], not arrays) • fixed `[N]T`, managed `[]T`, dynamic `[..]T` (JSON arrays) • annotated classes/structs (JSON objects keyed by exact field names).

Entity / Component / Player-class fields technically serialize (as a bare scene-local id number; null writes `"0:0"`) but resolve only inside the same running scene — deserializing one via `JSON.try_deserialize`/`Save.try_get_json` is a probable CRASH (the script-facing path has no id-remapping table), not a clean null. Never persist them; use stable identifiers instead: `player.get_user_id()` strings, item/definition names. Asset fields (`Texture_Asset` etc.) round-trip as asset-id strings and are safe to persist.

## Schema evolution — what is free, what breaks

Free (old payloads keep loading, no version bump needed):

- **Adding** an annotated field — old payloads load it as zero, or as its declared initializer if you give it one (class fields only). `energy_regen: float = 1.0 @ao_serialize;` is a complete migration by itself.
- **Removing** a field — the stale key in old payloads is ignored.

Breaks:

- **Changing an existing key's kind** (`int` <-> `string`, scalar <-> array/object) panics when an old payload is loaded. Changing between numeric types (`int` <-> `float`, narrowing, signedness) does NOT fail — old values load through a silent cast and truncate/wrap, corrupting data with no error. Either way: never reuse a field name at a different type or meaning — add a new name.
- **Renaming** silently loses data (old key ignored, new field defaults). Migrate explicitly.
- **Enum renumbering** silently corrupts stored values.

### Versioned payload pattern

```csl
SAVE_VERSION :: 2;

Save_Data :: class {
    version: int @ao_serialize; // NO initializer: missing/0 must mean "oldest payload"
    coins: s64 @ao_serialize;
    owned_item_names: [..]string @ao_serialize;   // stable names, never live refs
    best_lap_ms: s64 @ao_serialize;               // legacy (pre-v2); kept ONLY so old payloads still load it
    best_lap_seconds: float @ao_serialize;        // added in v2 — old payloads default it, no step needed for the add itself
}

load_save_data :: proc(player: My_Player) -> Save_Data {
    data: Save_Data;
    if !Save.try_get_json(player, "save", ref data) {
        // First join, or stored text unparseable: well-defined fresh state.
        data = new(Save_Data);
        data.version = SAVE_VERSION;
        return data;
    }
    if data.version < 2 {
        // To migrate a renamed/retyped value you must keep the OLD field in the class;
        // a removed field's key is ignored on load and its data is unreachable.
        if data.best_lap_ms != 0 {
            data.best_lap_seconds = data.best_lap_ms.(float) / 1000.0;
            data.best_lap_ms = 0; // zeroed legacy field is omitted from future saves
        }
    }
    // Chain further `if data.version < 3 { ... }` blocks in order as the schema grows.
    data.version = SAVE_VERSION; // an upgraded payload is never re-migrated
    return data;
}

save_data :: proc(player: My_Player, data: Save_Data) {
    data.version = SAVE_VERSION;
    Save.set_json(player, "save", ref data);
}
```

Two subtleties this pattern depends on:

- `version` must NOT have an initializer. Missing class fields load as their declared initializer, so `version: int = 2 @ao_serialize;` would make every pre-versioning payload masquerade as already-current.
- Start real versions at 1 and always assign `version = SAVE_VERSION` before saving: a stored `version` equal to 0 (initializer-less default) is omitted from output and indistinguishable from "field absent".

Keep serialized classes as plain data containers, separate from live gameplay components: snapshot component state into the data class to save, copy out of it on load.
