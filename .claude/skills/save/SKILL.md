---
name: save
description: "Persist per-player and game-wide state across sessions via the Save API: restore/write patterns, JSON records, migration authority rules, concurrent-safe game counters"
---
# CSL Save System
Game-scoped KV store. Per-player data keyed by user id (survives rejoin, any server); game-level shared by all. Plain fields do NOT survive disconnect. Economy/inventory persist themselves — never mirror into Save.

## API
```csl
// Per-player:
Save.set_string(player: Player, key: string, value: string);
Save.get_string(player: Player, key: string, default: string) -> string;
Save.set_int(player: Player, key: string, value: s64);
Save.get_int(player: Player, key: string, default: s64) -> s64;
Save.set_f64(player: Player, key: string, value: f64);
Save.get_f64(player: Player, key: string, default: f64) -> f64;
Save.set_float(player: Player, key: string, value: float); // convenience alias stored through set_f64
Save.get_float(player: Player, key: string, default: float) -> float; // get_f64 narrowed to float
Save.set_item(player: Player, key: string, item: Item_Instance); // requires auto-saved default_inventory; null deletes
Save.get_item(player: Player, key: string) -> Item_Instance; // null if missing or no longer in that inventory
Save.set_json(player: Player, key: string, value: ref $T); // @ao_serialize fields
Save.try_get_json(player: Player, key: string, out_value: ref $T) -> bool;
Save.delete_key(player: Player, key: string); // missing is ok
Save.delete_all_keys(player: Player);
Save.get_all_keys(player: Player) -> []string;
// Game-level (no Player; shared by ALL):
Save.set_game_string(key, v: string);  Save.get_game_string(key, default) -> string;
Save.increment_game_int(key, amount: s64, optimistic_update: bool = true);
Save.get_game_int(key, default: s64) -> s64;
Save.delete_game_key(key); // deletes a game string or int; missing is ok; batched with game saves
Save.get_all_game_strings()|get_all_game_ints()|get_all_game_keys(); // []{key,value} / {key,kind:.INT/.STRING}
// Ordered docs: async f64 scores; copy cb results into synced fields; prefer Global_Leaderboard.
Save.ordered_set(doc,key:string,v:f64);
Save.ordered_get(doc,key,default:f64,ud:Object,cb:proc(Ordered_Save_Entry{key,value:f64,position:s64},Object));
Save.ordered_get_all(doc,offset,limit:s64,ud,cb:proc([]Ordered_Save_Entry,Object));
```
Per-player stored value kinds are string, int, f64, item reference, and JSON. `get_float` / `set_float` are f32 convenience aliases over f64 storage, not another stored kind. No: bool get/set (int 0/1); `set_game_int`/any game absolute setter; game-level f64/json (pack JSON into a game string); load/flush/has_key/is_loaded (reads always work, giving `default`); string->number parsing in CSL.

## Rules
- Persist only what's required — nothing transient/derivable.
- One get/set pair per key, same literal; wrong-type reads return garbage/0 silently.
- Per-player and game ints preserve the full signed 64-bit CSL range.
- Write at every change point (all paths), never per frame.
- Client writes are prediction-only; only the server run persists — an `is_local()`-only write is silently lost. Reads work both sides.
- `$AO.` keys are engine-reserved (write/delete raises); delete_all_keys/get_all_keys skip them — resets yours, not Economy/inventory.
- `ao_start` reads are safe (data loads before spawn); no wait-until-loaded code.
- Item references require automatic player inventory saving and are opaque links into `player.default_inventory`: slot rearrangement preserves them; removing, dropping, destroying, or transferring the item makes `get_item` return null. Use these for equipped selections instead of copying inventory ownership or item properties into Save.
- Accumulators: write at bounded moments + final Player `ao_end` write (persists; runs pre-unload).
- Restore in `ao_start` into Player fields, never globals. One-time grants: read 0, set 1, grant.

## JSON
- `try_get_json` false ONLY on missing key/malformed text (out untouched, maybe null): build full defaults. Wrong-shaped valid JSON panics.
- Success replaces the record wholesale: absent fields come back at class initializers (zero if none / structs) — version records, default new fields after load.
- Never retype a stored field: kind changes (string<->number, scalar<->object) panic on old saves; numeric retypes silently truncate. Add a new field + migrate.

## Migrations
Ascending `if v < N` steps before other reads; each idempotent, no-op on blank saves; write version key AFTER steps; delete stale keys. Overlapping keys: authority = schema history, NEVER magnitude — max/min/sum silently corrupts. Non-idempotent step: guard on the old key holding a meaningful value.

## Game-level
No per-player progress (shared key = mutual overwrite).
- `increment_game_int` sends server-applied deltas: concurrent increments accumulate across instances — never get-then-set a counter. Default optimistic_update shows the delta at once; false waits. No absolute setter; reset (increment by -current) is racy — absolute values go in a game string.
- `delete_game_key` is batched and deduplicated. A later game-string set cancels it; a later game-int increment runs after the delete and therefore restarts the counter from zero.
- Game strings: last-writer-wins; set NOT visible to get until round-trip — durable storage, not shared memory; keep live copy in synced fields.
