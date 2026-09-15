---
name: game-design
description: Must be used whenever the user requests a game built from scratch, and whenever you are assigned a phase of a phased game build (world-building, scripting, review). Do not read for small changes or individual systems in an existing game.
---
# Building a Complete Game
You are building a full multiplayer game of the kind that tops the charts — a game strangers will play with nobody there to explain it, and come back to tomorrow. Not a demo, not a prototype, not a proof of concept.

**The failure mode to beat is shipping a demo.** A demo looks like: one mechanic, one zone, three shop items, a sparse flat map, "You win!" after two minutes, nothing left to want. If a player runs out of things to work toward inside an hour, the game is not done. Everything below exists to prevent that outcome.

## Find the Fun First
Before touching the scene or writing any code, design the game. The user's prompt is a fantasy — "be a wizard", "run a restaurant", "grow crops" — and your job is to find the proven, deeply engaging game inside it.

**1. Anchor on hits.** Name the 2–3 chart-topping Roblox games closest to the prompt and steal their proven structure and exact balance; differentiate on theme and feel, not on loop mechanics that already work. Genre anchors:
- Farm / collect / idle: Grow a Garden, Bee Swarm Simulator, Pet Simulator 99, Fisch
- Tycoon / builder: Theme Park Tycoon 2, Restaurant Tycoon 2, Car Dealership Tycoon
- Combat / RPG progression: Blox Fruits, Blade Ball, Arsenal, Rivals
- Social / roleplay / dress-up: Adopt Me!, Brookhaven RP, Dress to Impress
- Round-based / party / horror: Murder Mystery 2, Doors, Tower of Hell, BedWars, Natural Disaster Survival
- +1 Games: +1 Speed Keyboard Escape, +1 Dino Evolution, +1 Power Per Click
- Steal An [x]: Steal an Egg, Steal a Brainrot,  

Look up the closest comparable's wiki. Note its core loop, first-session onboarding, progression and economy numbers, and social hooks — design with real numbers, not guesses.

**2. Design the three loops.** Every hit game runs three loops at once:
- **Seconds** — the action repeated hundreds of times (harvest, shoot, serve, dodge). It must feel great: instant feedback, sound, motion, numbers going up.
- **Minutes** — the reason to keep doing it (fill the order, clear the wave, afford the next upgrade). A reward lands every few minutes; no dead air.
- **Hours/Days/Weeks** — the reason to come back (new zones, rarer drops, prestige/rebirth, leaderboard climb, cosmetics).

If you cannot say what the player is working toward at minute 1, minute 30, and day 2, the design is not done.

**3. Commit to real content scope.** Defaults for a real game — go bigger when the comparables do, smaller only if explicitly asked:
- 3+ interlocking systems (collect → sell → upgrade → unlock new area → collect faster)
- 15–30 purchasable upgrades/unlocks arranged in tiers
- 3+ distinct zones; later zones gated by progression and visibly aspirational from the start
- 8+ mechanically distinct variants of the core content (crops, towers, pets, weapons, enemies…) — different behavior, not stat reskins
- Rarity tiers (common → legendary -> divine) wherever collecting is involved; the rare version must be visibly cooler
- An endgame lever: prestige/rebirth, bosses, a leaderboard

**4. Do the economy math.** Write the actual price ladder: starting currency, income per seconds-loop, cost of every upgrade tier. Costs grow geometrically (~1.6–2×) alongside income so the next unlock is always 1–3 minutes-loops away. Paper-play the first ten minutes: first upgrade affordable inside 60–90 seconds, no early dead zones where nothing is within reach, no point where income can hit zero with no recovery path. For players that get hooked, there should be long late game progression that takes **days or weeks** to achieve.  

**5. Design multiplayer ownership.** Every game runs with 1–4+ concurrent players:
- Shared world state needs an ownership pattern: duplicated plots (at least 4) assigned on join, per-player instances, or per-player state on the player class. A gardening game with one shared garden is unplayable.
- Solo must be fully playable; a full server must feel better — shared boss moments, seeing others' progress, trading, leaderboards.

### Write design.md
Capture the above in `design.md` at the project root — about a page of markdown, never JSON, no task-tracking bureaucracy. It is the design contract every later phase builds against:
- Fantasy and comparables (one line each)
- The three loops (one line each)
- Content list: every zone, upgrade, and item/enemy/unit by name — this is the scope commitment
- Economy table: starting currency, income rates, full price ladder
- Multiplayer ownership model
- First 60 seconds: what a brand-new player sees, does, and earns

Keep updated because later phases trust it over guesses.

## The Three Build Phases

The build runs **world-building → scripting → review**. In phased builds each phase gets a fresh conversation and you are told which phase you are executing: do only that phase, and read `design.md` first. In a single conversation, run the phases in order yourself.

Rules for every phase:
- Use engine systems — Inventory, Abilities, Economy, save, interactables, effects — instead of custom versions. Check the skills list before building anything generic.
- Never use placeholder art. Search real assets with the MCP asset tools; prefer animated Spine assets (spine skill).
- Compile after every script change; fix errors before moving on.
- Verify by playing, not by reading code. Live loop: `start_game` once, then edit → `compile` (hot-reloads in seconds) → `in_game_screenshot` → `client_ui_tree`/`client_input`.

### Phase 1 — World Building
Find the fun first (above), write `design.md`, then build the ENTIRE world. No scripts in this phase.
- Follow the world-building skill for asset discovery, placement, tiling, and scale verification.
- Build every zone in the content list at full quality: spawn area, all player plots, gameplay entities, NPCs, decoration, collision/navmesh. The starter zone must read instantly; later zones visible and enticing but clearly gated.
- The bar is a beautiful, dense, complete game world — the kind a player screenshots — not a starter area with props scattered to look busy.
- Before calling it done, critique it like an outsider: screenshot from several camera positions (includePlayerForScale) hunting for terrain gaps, empty dead space, wrong relative scales, floating/overlapping props, and zones that don't match `design.md`. For a large map, spawn a fresh-eyes subagent to run this critique with scene_hierarchy plus screenshots from 3+ angles and return concrete failures with entity names and positions; fix and re-verify until it passes.

### Phase 2 — Scripting
Read the design.md or write it if it doesn't exist. Bring the world to life with ALL of the game logic. Do not rearrange the world unless something is genuinely broken.
- Core loop first: make the seconds→minutes loop playable end-to-end before anything else. Then build out the full `design.md` content list — every upgrade, zone gate, and variant — plus win/loss and match flow.
- Multiplayer from the first line: ownership assignment on join, shared predicted simulation with authoritative reconciliation, per-player progress, plot reset when a player leaves.
- Onboarding is a feature: a brand-new player must know their first action within seconds (pointer/arrow to it) and earn their first reward inside a minute.
- Make every action tactile: sound on every interaction, particles, number pop-ups, damage flashes, celebrations on unlocks (effects skill). Silent actions feel broken.
- UI through the uidoc skill (screen-space) and world-space-ui skill (in-world). Keep the HUD to what a new player needs.
- Play continuously through the live loop; nothing is "done" until you have watched it work in-game.

### Phase 3 — Review
The game works; now make it engaging, then make it shippable. You are the last check before real players see this, and your improvements must be implemented, not noted.

The design audit comes first:
- Re-check the comparables' wikis with real questions now that the game is playable, and port over what they do better.
- Audit against `design.md`: did scripting quietly cut scope? Restore it.
- Play the game start to finish and fix against this list:
  1. Is the core loop focused, satisfying, and instantly clear to a new player?
  2. Is there enough depth and scaling to hold interest for hours or days, not minutes?
  3. Is there always "just one more thing" 1–3 loops away?
  4. Soft locks: can income hit zero with no recovery? Can colliders block anywhere the game points the player? Verify by playing.
  5. Is the UI exactly what a new player needs — nothing missing, nothing extra?
  6. Is it fun solo and duo, and better with 4?
