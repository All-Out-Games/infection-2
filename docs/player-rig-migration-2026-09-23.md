# Infection player rig migration

Status: original multiplayer, candidate compilation, native rig comparison,
compact source preparation, both inactive hosted candidates and cold A/B passed.
Separate primary/staging multiplayer and OPFS restart checks passed. Ready for
guarded activation after master integration. Neither candidate is active in
production yet.

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

Commit the validation, integrate the game master and request guarded staging
then primary activation of the existing candidates. Do not repeat the uploads or
the completed canonical same-session cold Chrome comparison.
Keep fresh production verification separate from local timing and population
loading/retention claims. Do not start another Poki Player Fit test.

Detailed evidence and action state are under
`C:/allout-rig-startup-local/.codex-tmp/rig-startup/infection-*`.

## Original gameplay and reviewed compact archive

Three isolated Chrome clients loaded the exact original hosted primary package
in full local development, started a round and displayed survivor/zombie roles.
Trusted inputs exercised movement, survivor shooting and ammunition change,
dodge-roll motion, sprint input and zombie slash motion/cooldown. The round
timed out with the existing zombie win screen and all clients entered the next
round. None had a JavaScript exception; each logged one expected runtime merge.
Direct infection/death and the complete multi-stage escape objective were not
verified in this observation. Native import was concurrent, so these captures
are functional evidence only. All three clients were closed successfully.

Candidate compilation passed with the same existing `icons/fuel.png` warning.
Normal native preparation produced a 2,065,413-byte compact source archive,
SHA-256 `d5bfffea89a04f59afc9524b67df8efd9c7532e25ce2356fb8ac6137e6785033`.
All seven source scripts are unchanged from both published originals. All 356
entity identities, AOIDs and values match after 29 native `tint` to `color`
normalizations; native save also renames entity files. The sole scene config
change selects `player_composed/player.spine`. No entity was edited manually.

The runtime manifest has eight external ordinary rigs, zero bundled rigs and
zero merge recipes, 196 manifest entries and 11 bundled entries. The required
custom texture page is preserved. Archive size is not total join bandwidth.
Evidence: `migration-candidates/infection-baked.json`,
`infection-rig-native-comparison-summary.json`, `infection-source-preflight.json`
and `infection-original-multiplayer` in the engine evidence folder.

## Hosted candidates and cold comparison

Both candidates compiled under protocol 48 and remain inactive during validation.
Primary `6ab3b0a62e1d629109ef6641` has build hash `a740bf75af344f98`, DAT
2,079,840 bytes, SHA-256
`cf1965106218a5362a3a1393ff729c8b85ac40f507aaf02917a5ea705afa856e`.
Staging `6ab3b0a12e1d629109ef6640` has build hash `6497ad16b7678e5c`, DAT
2,080,664 bytes, SHA-256
`f68aeaa07b1d114ac5894a10b9ab525f23020a31aafb326cced9c2e50e32cfeb`.
Independent hosted downloads verify the reviewed source bytes, runtime manifest,
scene config and bundled asset entries for each target.

Canonical same-session Chrome used the isolated full dev environment, CPU6,
slow4g (655,360 bytes/s, 80 ms), server warmup and fresh profiles with all storage
cleared. Two runs per version passed without retries or a tiebreaker. No editor,
heavy build or second gameplay client ran concurrently. Debug Wasm SHA-256 was
unchanged before/after:
`a8ccde20a30e7cea03e30133c4dfdb3ef9698c680860f27ff599d3b50a980ac6`.

| Median through spawn | Original | Authored rig |
|---|---:|---:|
| Navigation to spawn | 72.336 s | 70.607 s |
| Encoded whole-page transfer | 36,353,550 bytes | 39,312,182 bytes |
| Game-data transfer | 5,974,591 bytes | 1,660,779 bytes |
| Separate game-asset transfer | 10,377,997 bytes | 17,650,224 bytes |
| Wasm heap capacity | 765,362,176 bytes | 556,793,856 bytes |
| Native allocated-byte snapshot | 264,133,684 bytes | 262,030,408 bytes |

This is a 1.729-second startup improvement (2.4%) with 2.959 MB more cold transfer.
The 208.568-MB capacity decrease is not a peak or resident-memory measurement;
worker heap allocation stayed 113,770,496 bytes. These Debug measurements do
not establish production timing, minimum payload or player retention.

Infection and Fat Simulator have identical authored player-rig JSON (SHA-256
`165a7bcb4069894e33c72813dff4d2fe00f271c3fd4723bc92ae19fe78d40cff`), but their
freshly cooked runtime content IDs differ. No cross-game reuse of that rig is
claimed. The earlier asset serialization determinism investigation remains open;
this observation alone does not establish the cause. No serializer, asset-format
or cache implementation was changed here.

## Primary candidate multiplayer

Three isolated Chrome profiles loaded the exact hosted primary candidate through
the full local development stack without bundle or game-data overrides. All
three spawned and rendered with zero runtime merges, engine error-state
transitions or JavaScript exceptions. Trusted input and screenshots verified
survivor shooting with an ammunition change, dodge-roll motion, sprint motion,
and zombie slash motion/cooldown. One zombie's slash killed the second survivor:
the victim displayed the named killer and respawn countdown, then reappeared as
a zombie with the matching objective and Slash ability. The next round also
started; movement and slash motion were observed there. All clients closed with
exit 0. Evidence: `infection-primary-multiplayer`, especially captures 06, 09,
11, 24, 27 and 30. The complete task-carrying/escape sequence was not exercised;
its unchanged source positions carried objects using the player entity rather
than a rig bone. These are scoped functional checks, not exhaustive gameplay or
production performance measurements.

Primary's fresh Chrome process then retained OPFS while clearing HTTP cache.
It reused all 310 previously stored asset files without requesting any again,
including all eight external rigs. Five previously absent assets downloaded
29,615 encoded bytes. The exact hosted candidate spawned, rendered and accepted
movement with zero runtime merges or page exceptions; the helper exited 0.
Evidence: `infection-primary-multiplayer-cache-restart/opfs-only.json`. No cache
implementation change was needed. The primary local game job was then stopped
before starting the separate staging fixture.

## Staging candidate multiplayer

Three new isolated Chrome profiles separately loaded the exact staging candidate
through full local development. All spawned with zero runtime rig merges,
engine error-state transitions or page exceptions. Screenshots and trusted input
verified survivor shooting/ammunition use, roll and sprint motion, zombie slash,
movement, the round-timeout result and entry into the following round.

The second round additionally verified fuel pickup, moving with the following
fuel sprite/shadow and the Drop action returning to the pickup prompt (captures
56, 58 and 59 in `infection-staging-multiplayer`). The first short E tap was
below the authored 500 ms hold threshold, and a second attempt was outside the
one-unit radius; neither is counted as a successful pickup. A 900 ms hold in
range succeeded. The complete multi-stage escape objective remains unplayed.
The unchanged carrying logic does not attach to rig bones.

The anonymous staging session also logs HTTP 401 responses from its existing
`translated.allout.game/.../unseen-strings` endpoint. These are preserved in the
capture and did not prevent play; zero page exceptions is not a claim of zero
unsuccessful network responses. The pre-existing missing `icons/fuel.png` icon
does not prevent the text-labelled Drop ability working.

All three staging profiles closed with exit 0. A separate Chrome restart with
HTTP cache cleared and OPFS retained reused all 305 previously stored assets
without refetching any, including all eight rigs. Six new cache misses downloaded
224,310 encoded bytes. The expected staging version spawned, rendered and moved
with zero runtime merges or page exceptions; that helper also exited 0. Evidence:
`infection-staging-multiplayer-cache-restart/opfs-only.json`. The owned staging
local game job was then stopped; both editors and all browser sessions are closed.

Fresh production readbacks after validation still select the original primary
and staging versions, with both reviewed candidates compiled successfully under
protocol 48. Gameplay source and the fuel-canister prefab have zero Git diff
against the original master. Activation must use these existing candidates,
preserve visibility/channel settings and retain both previous versions.
