---
name: game-design
description: You MUST reference this before implementing any new gameplay feature or system
---

# Game Design

This skill covers essential questions that should be answered when implementing game systems.

## When to Use
- Use this skill when the user is asking you to implement a new feature, especially when there is minimal guidance on how the feature should be implemented.
- This skill will help you make decisions on designing systems that work well within All Out

## Instructions
You must decide the scope of the feature. Below are some common scopes used in many games.
The list may be in-complete, so if the feature doesnt really match any of the scopes below consider how the state of the feature should be managed, what is its lifetime, where should it be stored. Keep in mind that this is a multiplayer game, each game will have players joining and leaving constantly, so keeping track of state is incredibly important.

### Scopes
 - Global: does it run independently of players and other scopes, generally lives the entire duration of the game
 - Player: does the feature directly link to a player, usually only exists while that player is logged in
 - Plot: do we require some sort of ownership of land in the world
 - Round: does the game require rounds and does the state reset between them
 - Instance: can instances of the state be spawned/despawned, and the state only exists while the instance does

#### Global
The simplest of all the scopes, state can be stored in data structures that exist for the duration of the game. 
Example: A game where you collect XP orbs, the system responsible for spawning and tracking those orbs.

#### Player
State here should be stored on the player object itself, or objects that the player explicitly owns. There is generally many instances of this state in a game at once, instances are often added/removed as players join and leave the game.
Example: a players health, or abilities

#### Plot
Plots are very similar to player state, except that they influence a particular spot in the world. Generally plots are assigned to players when they join the game (usually a fixed amount created at edit time). Their lifetime would be the same as a players resetting to some "empty state" when the owning player leaves. 
Example: players own and manage a farm. Their farm would persist between logins

#### Round
Rounds could be considered a global feature, but they are a common pattern so its worth calling them out. Often games are built around using rounds which means a lot of game state ends up being tied to the round, and gets reset/destroyed/respawned when a round is over.
Example: murder mystery, where players solve puzzles, open doors, kill eachother ..etc. Players would need to be respawned and the map would need to get reset 

#### Instance
Instances are for things that spawn in the game and have a limited life span. Generally their state does not persist when players exit the game, and instead of being tied to players joining/leaving it would be tied to actions that players take in-game.
Example: a dungeon, players enter it as a party and get a fresh version each time. Multiple parties could enter the same dungeon but get different instances of it. 