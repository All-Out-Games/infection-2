# Infection

A survivors-versus-zombies multiplayer game for [All Out](https://allout.game/). Survivors work through an escape sequence while zombies try to stop them: gather fuel, charge and deliver a battery, push the trolley, and reach takeoff. Weapons, sprinting, dodge rolls, carried items, and a round timer create pressure around those shared objectives.

The repository is named `infection-2`; the project itself is named **Infection**.

## Script architecture

Almost all game-specific code lives in [scripts/main.csl](scripts/main.csl). It is organized around these types and functions:

| Area | Responsibility |
| --- | --- |
| `Game_State`, `g_game`, and the global lifecycle callbacks | Map reset, waiting for players, active gameplay, task progression, the timer, and results. |
| `Player` | Team membership, player state, abilities, HUD, and objective guidance. |
| `Game_Manager`, `Zombie_Spawn_Point`, `Survivor_Spawn_Point` | Connections between the game rules and authored scene entities. |
| `Shoot_Ability`, `Slash_Ability`, `Sprint_Ability`, `Dodge_Roll` | Player actions and their associated effects. |
| `Health_Component`, `Death_Effect`, `Food_Projectile` | Damage, death behavior, and projectile combat. |
| `Carried_Item`, `Fuel_Canister`, `Boat_Battery`, `Battery_Charger`, `Trolley`, `Takeoff_Station` | The physical objects and interactions used by the escape sequence. |

Read the top-level state definitions first, then the global `ao_update` and `Player` callbacks. The later interactable classes implement the task sequence **fuel → battery → trolley → takeoff**. [scene/](scene/) wires those components to the map; [res/](res/) holds the visual, audio, and prefab assets.

## How CSL works here

CSL is All Out's statically typed scripting language. [ao.project](ao.project) enables it with `"csl": true`, and the editor compiles the game's `.csl` source.

- `import "core:ao"` supplies players, entities, rendering, input, UI, and gameplay APIs. The checked-in `scripts/.ao_core/` and `api_references/` folders help with API lookup.
- `Player :: class : Player_Base` adds game-specific behavior to each connected player. `Component`, `Interactable`, `Ability_Base`, and `Effect_Base` subclasses express world behavior, usable objects, actions, and temporary effects.
- `ao_before_scene_load` loads shared assets and registers input bindings; `ao_start` gathers scene spawn points. Update callbacks drive rounds and interactions, while player late-update code presents the UI.
- All Out runs shared gameplay with client prediction and authoritative server reconciliation. Keep each player's state on that player, and use shared state such as `g_game` for match-wide objectives. When extending the game, follow the current networking guidance rather than assuming every older call site is a recommended pattern.

This compact organization makes Infection useful for following a complete game flow within one source file.

## Open and remix

1. Set up the [Windows All Out editor](https://docs.allout.game/getting-started/first-game).
2. Clone the repository; its default branch is `master`:

   ```sh
   git clone https://github.com/All-Out-Games/infection-2.git
   ```

3. Use **Open project** on the cloned folder containing `ao.project`. Wait for script compilation and assets, then press **Play**. Use multiple local clients to exercise survivor and zombie interactions and the shared objectives.
4. To publish a remix, create a game in your own Creator Portal and associate your working copy with that game's identity. The existing live/staging IDs belong to the original project; review project-specific purchases and progression before publishing your version.

Requires the All Out editor/runtime and referenced platform assets. Saving source triggers compilation; restart play mode for scene or startup changes. See [CSL syntax](https://docs.allout.game/scripting/syntax), [networking](https://docs.allout.game/scripting/networking-fundamentals), and [local multiplayer testing](https://docs.allout.game/getting-started/playtesting-your-game).

## License

The code, documentation, and original assets contributed by All Out Games are available under the [MIT License](LICENSE). You may copy, modify, remix, distribute, and use them in commercial games, including games published on All Out. Keep the copyright and license notice with copies or substantial portions.

Separately licensed third-party material retains its own terms. References to platform-provided assets, such as `$AO/...`, do not transfer ownership of those assets or license the All Out engine and services.
