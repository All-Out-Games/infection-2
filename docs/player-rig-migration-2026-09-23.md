# Infection player rig migration

Status: original import/compile and native rig comparison passed. Hosted
multiplayer validation is running; no candidate publication or activation yet.

Repository: All-Out-Games/infection-2. Baseline master:
`7b1b94ad37f8c75ced98be09e5bf4f6fddb5c7a4`. Isolated branch:
`codex/infection-rig-migration`.

| Target | Game | Original active version |
|---|---|---|
| Primary | `698a72b5bec3a37de86775c7` | `6ab20436236e3076fa1ad9cc` |
| Staging | `6935dcc718506c430b35c652` | `6ab1f7434c1aefa488cabe16` |

Fresh production readbacks and hosted archives were inspected on 23 September
2026. Both have the same seven source scripts, 356 entities, scene config,
asset manifest, cooked asset records, serialized source/entity sections and
terrain. Their packed compiled scene sections differ by 312 bytes; the archives
are not byte-identical. Source equality supports separately rebuilding both
identities; do not treat the old compiled packages as interchangeable.

Git's two tracked generated core-library files were stale relative to both
published sources. Normal native import regenerated them to match the published
source exactly. The gameplay file `scripts/main.csl` is unchanged. Generated
API references are aligned separately before the rig change. Original native
compilation passed; it reports the existing unresolved `icons/fuel.png` asset
warning. This warning is not introduced by the migration.

## Behavior to preserve

The scene's player rig combines the custom Fat Simulator base with the shared
engine player rig. The custom input is byte-identical to both published cooked
inputs: 2,862,966 JSON bytes, SHA-256
`199df10d1181b98b086441815508c24118979a0efb12c447180a5a4173fec81f`.
The replacement uses the same native composition, authored as an ordinary rig.
It retains all clips, skins, bones, constraints and attachment layering. Shared
rig additions now require reauthoring this snapshot rather than applying
automatically through a runtime merge.

Infection starts rounds with three players, assigning survivor and zombie teams.
Its player state machine uses `Run_Fast`, attack, dodge-roll, death and RESET;
survivors shoot, sprint and carry task objects, while zombie slashes infect them.
Round start, role-specific abilities, death/respawn and carrying must continue to
work. Preserve the gameplay, separate boat, dust, hit and victory rigs, scene
entities and textures. No gameplay or entity file is edited by hand.

## Native comparison

The bake is 21,203,406 JSON bytes and 306,181 atlas bytes across 793 pages.
Native comparison passed seven inventories, every skin attachment list (1,024),
all 268 animation details and 882 sampled complete layouts without mismatches or
truncation. Samples cover clip start/midpoint/end for the base skin, with four
additional retained body skins for FAT_001 clips. These checks are structural
and sampled-pose evidence, not exhaustive layered/pixel or gameplay equivalence.

An 800-entry source/archive/decoded-bundle reference audit found no references
outside the `ao_player` authoring bundle itself. It was already absent from the
published cooked bundle; archiving it is not a claimed network saving. The
custom `fat_rig2` base and PNG remain because the composed atlas uses its page.

## Remaining release checks

Preserve and audit native source preparation, then publish inactive candidates.
Verify each hosted source/DAT and manifest, run the canonical same-session cold
Chrome comparison without concurrent heavy work, exercise multiplayer behavior,
and restart with HTTP cache cleared/OPFS retained before guarded activation.
Keep fresh production verification separate from local timing and population
loading/retention claims. Do not start another Poki Player Fit test.

Detailed evidence and action state are under
`C:/allout-rig-startup-local/.codex-tmp/rig-startup/infection-*`.
