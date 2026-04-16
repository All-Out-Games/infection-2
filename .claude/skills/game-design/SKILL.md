---
name: game-design
description: Must be used whenever the user requests a large game developed from scratch. It should not be used for discrete requests to build systems or small changes. 
---
# Game Design Workflow

Every game is built in two phases: **Scene** (the world) then **Scripts** (the logic). Plan both up front, build the scene first, verify it, then bring it to life with scripts.

This will be a production-grade, polished game. It will not be done in one shot. **Never use placeholder art. Never write throwaway scripts.** Every asset, every entity, every line of code ships.

## Core Rules
1. Inspect the request and the existing project before planning. Reuse what exists.
2. Every game is multiplayer. Design for many concurrent players from the start. Use ownership patterns (plot-based, instance-based, per-player state on the player class) so players don't collide on shared world state. (e.g. if you're asked to make a gardening game, plan for at least 6 duplicate garden plot with ownership assigned to players on join)
3. Search for assets using the All Out MCP tools and world-building skill. Prefer animated Spine assets if appropriate.
4. Use the All Out engine systems/skills like Inventory, Abilities, Economy Currencies, instead of creating your own custom systems. 
5. After any script change, compile with the All Out MCP compile tool.

---

### 1. Break Into Scene and Script Epics
**Scene epics**:
- Environment and terrain (ground, walls, decorations, lighting)
- Spawn area, player plots (if applicable)
- Interactable objects and NPCs (placed as entities with components)

**Script epics**:
- Plot assignment (if applicable)
- Match flow, game state, win/loss conditions
- Wave systems, spawners, timers
- Player abilities
- Enemy/NPC behavior and AI
- Economy, resources, progression
- Polish (tactile sfx for every action, animated particles, damage flashes, juicy effects when earning currency or harvesting plants)

### 3. Write `game_plan.json`
```json
{
  "game": "Game Title",
  "description": "One sentence",
  "scene_epics": [
    {
      "name": "Arena Layout",
      "status": "pending",
      "tasks": [
        { "name": "Search and download ground/wall/decoration assets", "done": false },
        { "name": "Place arena boundary walls", "done": false },
        { "name": "Place spawn points for players and enemies", "done": false },
        { "name": "Add decorative props to fill the space", "done": false }
      ],
      "verified": false
    }
  ],
  "script_epics": [
    {
      "name": "Enemy Wave System",
      "status": "pending",
      "tasks": [
        { "name": "Create wave manager script with timed spawns", "done": false },
        { "name": "Implement enemy pathfinding to target", "done": false },
        { "name": "Scale difficulty across waves", "done": false }
      ],
      "gate_test": "test_gate_enemy_waves",
      "gate_passed": false
    }
  ]
}
```

---

2a. Build the scene
2b. After completing a scene epic, **launch a verification subagent**. This subagent's job is to genuinely critique the work — not rubber-stamp it. **Don't write test.csl files for scene verification.**

Example verification subagent prompt:
```
Verify the "Arena Layout" scene epic for the Tower Defense game.

Use these MCP tools to critique this scene with a critical lens:
1. Call scene_hierarchy to get the full entity tree
2. Call editor_scene_screenshot to capture the current view
3. Call scene_camera to move to different positions, then screenshot again (get at least 3 angles)
4. Call scene_find_entities to confirm key entities exist: "Spawn_Point_1", "Spawn_Point_2", "Tower_Pad_1" through "Tower_Pad_6", "Base"

Evaluate against these criteria:
- NO GAPS: Is there ground/terrain covering the entire play area? Any holes or missing tiles?
- DENSITY: Does this look like a shipped game or an empty prototype? Are there enough decorative props?
- SCALE: Are towers, enemies, and the base appropriately sized relative to the lane?
- STRUCTURE: Are spawn points at lane entrances? Are tower pads along the lane? Is the base at the end?

Return a verdict: PASS or FAIL.
If FAIL, list every minor issue along with entity names and positions so they can be fixed.
```
Only set `verified: true` on the scene epic after the verification subagent passes. If it fails, fix the issues and re-verify.

---

## Phase 3 — Build the Scripts
After all scene epics are verified, build the `script_epics` in order.
Work through the `tasks` array in order:
1. Implement the task in CSL
2. Compile after every change
3. Fix errors before moving on
4. Mark the task done in `game_plan.json`

Use the appropriate engine skills as you go and constantly reference AGENTS.md. 

### Step 3: Gate Test
You must have a subagent write a gate_test for every task using the `testing` skill. 

Gate subagent prompt: 
```
Write the gate test for the "{epic name}" script epic.

Read these skills first:
- <absolute path to testing/SKILL.md>
- <absolute path to syntax/SKILL.md>

Read these files to understand what was built:
- <list every script file the epic created or modified>

The test procedure must be named `{gate_test name}`.
It should:
- <specific assertions for this epic's deliverable>
- Take screenshots at key moments

Write the test to tests/{test_file}.csl.
After writing, compile using the All Out MCP compile tool and fix any errors.
```

### Step 4: Run the Gate Test
Use MCP `run_tests` with the gate test name.

- **Pass** → set `gate_passed: true`, set `status: "done"`, continue
- **Fail** → inspect, fix, recompile, re-run

### Step 5: Checkpoint
Update `game_plan.json` after each epic.
---

## Phase 4 — Final Verification
After all epics are done:

1. Run the full test suite
2. Take screenshots of the complete game
3. Report what was built and any remaining risks

---
## Example: 2D Tower Defense
```json
{
  "game": "Lane Defense",
  "description": "Place elemental themed towers to stop waves of enemies from reaching the base matching the level of polish of Bloons TD6. 8 unique towers each have special effects and enemies are varied and scale in difficulty.",
  "scene_epics": [
    {
      "name": "Arena Environment",
      "status": "pending",
      "tasks": [
        { "name": "Place a backdrop and scenery to match the theme", "done": false },
        { "name": "Lay out the lane path with ground tiles from spawn to base", "done": false },
        { "name": "If using a pre-baked map, figure out the EXACT points the enemies will path between to get to the base using red markers pixel-pushed to perfection.", "done": false },
        { "name": "Add decorative environment props (trees, rocks, grass) to fill empty space", "done": false },
      ],
      "verified": false
    },
    {
      "name": "Gameplay Entities",
      "status": "pending",
      "tasks": [
        { "name": "Find unique and beautiful animated tower, enemy, and base assets", "done": false },
        { "name": "Place the base entity at the lane endpoint", "done": false },
        { "name": "Place 6 tower pads in strategic places off of the lane", "done": false },
      ],
      "verified": false
    }
  ],
  "script_epics": [
    {
      "name": "Enemy Wave Loop",
      "status": "pending",
      "tasks": [
        { "name": "Implement wave manager with timed spawns from spawn points", "done": false },
        { "name": "Move enemies along the lane using pathfinding", "done": false },
        { "name": "Damage the base when an enemy reaches it and destroy the enemy", "done": false }
      ],
      "gate_test": "test_gate_enemy_wave_loop",
      "gate_passed": false
    },
    {
      "name": "Tower Placement",
      "status": "pending",
      "tasks": [
        { "name": "Implement tap-to-build on tower pads using plot ownership (per-player pad locking)", "done": false },
        { "name": "Spend currency to place a tower, block if pad is occupied or owned by another player", "done": false },
        { "name": "Visual feedback on valid/invalid/owned pads, build sfx when placement succeeds", "done": false }
      ],
      "gate_test": "test_gate_tower_placement",
      "gate_passed": false
    },
    {
      "name": "Tower Combat",
      "status": "pending",
      "tasks": [
        { "name": "Give towers targeting rules and fire cadence", "done": false },
        { "name": "Spawn projectiles that travel to and damage enemies", "done": false },
        { "name": "Add tactile impact animations and subtle sfx", "done": false },
        { "name": "Award currency to the tower's owner on kill", "done": false }
      ],
      "gate_test": "test_gate_tower_combat",
      "gate_passed": false
    },
    {
      "name": "Economy and Wave Scaling",
      "status": "pending",
      "tasks": [
        { "name": "Register currency with Economy system for persistence", "done": false },
        { "name": "Reset currency on logging in (call economy_delete_save_data) for round based games", "done": false },
        { "name": "Scale enemy count and stats between waves", "done": false }
      ],
      "gate_test": "test_gate_economy_scaling",
      "gate_passed": false
    },
    {
      "name": "HUD and Match Flow",
      "status": "pending",
      "tasks": [
        { "name": "Display per-player currency, shared base health, wave number", "done": false },
        { "name": "Show build menu with tower options and costs", "done": false },
        { "name": "Implement win state (all waves cleared) and loss state (base destroyed)", "done": false },
        { "name": "End-of-match screen with player stats and play again screen", "done": false }
      ],
      "gate_test": "test_gate_hud_match_flow",
      "gate_passed": false
    }
  ]
}
```
