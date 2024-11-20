<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/mark-dark.svg">
  <img alt="Dojo logo" align="right" width="120" src=".github/mark-light.svg">
</picture>

<a href="https://x.com/0xDislands">
<img src="https://img.shields.io/twitter/follow/0xDIslands?style=social"/>
</a>
<a href="https://github.com/0xDislands/">
<img src="https://img.shields.io/github/stars/dojoengine/dojo?style=social"/>
</a>

[![discord](https://img.shields.io/badge/join-dislands-green?logo=discord&logoColor=white)](https://discord.gg/AZ7HEYy5nX)


# DISLAND CARD KNIGHT

Card Knight is a 2D, turn-based RPG game that takes place on a 3x3 battlefield. Players navigate a grid of cards to engage in strategic battles, leveling up their heroes and using skills to defeat monsters. The game features various heroes, each with unique skills, and challenges players to make tactical moves on a small board, where every cell interaction counts.

This app is developed with Dojo.
Read the full tutorial [here](hhttps://book.dojoengine.org/).

## Running Locally

#### Terminal one (Make sure this is running)
```bash
# Run Katana
katana --disable-fee --allowed-origins "*"
```

#### Terminal two
```bash
# Build the example
sozo build

# Migrate the example
sozo migrate apply

# Start Torii
torii --world 0xb4079627ebab1cd3cf9fd075dda1ad2454a7a448bf659591f259efa2519b18 --allowed-origins "*"
```

---

# Gameplay Overview

Game Mode: Solo turn-based 

Objective: Defeat monsters, avoid harmful items, and gain experience to increase your rank and high score.

Win Condition: Survive as long as possible and maximize experience.

Lose Condition: Lose all HP.

# Interactions

- Monsters: Combat monsters to defeat them, reducing your HP or shield based on the monster's strength.
- Healing Potion: Restores HP by a random value (1-5), up to your hero's max HP.

- Poison: Decreases HP at the end of each turn. Reapplying resets the poison duration.

- Random Chest: Converts to either a healing potion or poison upon opening.

# Character Classes and Skills

Each hero type has unique active skills, which can be used strategically in battle:

## Knight
Slash: Deals 25% of HP as damage to an adjacent monster.

Teleport: Swap positions with an adjacent cell.

Regeneration: Fully heals HP.

## Shaman

Hex: Transforms a monster into a chicken (non-lethal).

Shuffle: Rearranges all cards on the board.

Meteor: Attacks all monsters, dealing 25% of the hero's HP in damage.

## Vampire
Life Steal: Steals 20% of a monster's HP.

Teleport: Swap positions with an adjacent cell.

Curse: Reduces a monster’s HP by 50%.



# Scoring and Ranking
- Experience Points (XP): Earned by defeating monsters, with higher XP contributing to the player's ranking.
- High Score Tracking: Tracks weekly high scores and player rankings.
- Weekly Winner: Based on accumulated high scores, players are ranked weekly, with the top performer designated as the Weekly Winner.


# Game Objects and Their Effects
- Healing Potion: Restores HP immediately.
- Poison: Reduces HP per turn (does not stack).
- Shield: Adds armor.
- Random Chest: Opens to reveal a healing potion or poison.
- Fire: Attacks the 2 nearest monsters (if available).
- Pike: Deals damage based on max HP.


# Game Instructions

1. Starting the Game:

Use the start_game function to begin. You’ll be placed on a 3x3 game board with monsters and items. Monsters are enemies you can fight, and items provide benefits (like healing).

2. Movement: 

Move using the move function, specifying directions (Up, Down, Left, Right). Each move might lead to a battle or item collection, depending on the cell’s contents.

3. Using Skills:

Special skills can be used to gain an advantage. For example:

- Use Skill: Deploy a skill in a chosen direction to influence the outcome of battles.
- Swap Skill: Swap positions with another card to avoid enemies or reach items faster.
- Curse Skill: Target and weaken a monster on the board.

4. Leveling Up: 

After collecting enough experience, use the level_up function to strengthen your player by choosing specific upgrades.

5. Winning and Scoring: 

The game tracks your high scores and ranks you among other players weekly. You can earn rewards based on your performance.


# Key Functions

1. `start_game(game_id: u32, hero: Hero)`

This initializes a new game by setting up a game board and player properties. The board is a 3x3 grid where each cell may contain either a monster or an item. The player starts with basic stats and is placed on a specific position on the board.

| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| game_id | u32            | Specify the game id. |
| hero | Hero            | Specify the hero type.|               


2. `set_contract(ref self: ContractState, index: u128, new_address: ContractAddress)`

Allows admins to set or update essential contract addresses used within the system.

| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| index | u128            | Specify the contract index. |
| new_address | ContractAddress            | Updates the specified contract address in the Core Wheel’s world state. |

3. `move(game_id: u32, direction: Direction)`

Moves the player in a specified direction (Up, Down, Left, or Right) and handles interactions with cards (monsters, items, etc.) in the destination cell. If the player moves to a cell with a monster, they may fight, and if they move to an item cell, they can collect it. The function also checks the player's health and updates their position accordingly.

| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| game_id | u32            | Specify the game id. |
| direction | Direction            | Specify the direction.|               


4. `use_skill(game_id: u32, direction: Direction)`

The player can use a skill in a specified direction, assuming they meet level requirements and other conditions (e.g., not silenced). The skill effects vary based on the skill type and direction, allowing the player to interact with monsters or items more effectively.

| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| game_id | u32            | Specify the game id. |
| direction | Direction            | Specify the direction.|  


5. `use_swap_skill(game_id: u32, direction: Direction)`

This skill allows the player to swap positions with another card in a specified direction. This function checks that the move is valid within the board and that the skill cooldown has elapsed.

| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| game_id | u32            | Specify the game id. |
| direction | Direction            | Specify the direction.|  

6. `use_curse_skill(game_id: u32, x: u32, y:u32)`

This skill is used to curse a monster at a specific (x, y) position, assuming the player meets level and cooldown requirements. The skill weakens the targeted monster, making it easier to defeat.


| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| game_id | u32            | Specify the game id. |
| x | u32            | Specify the x coordinate.|  
| u | u32            | Specify the y coordinate.|  

7. `level_up(game_id: u32, upgrade: u32)`

 The player can level up, choosing an upgrade to enhance certain stats or skills. This function applies the level increase and stores the player’s updated state.

| Name            | Type            | Description                                                                            |
|-----------------|-----------------|----------------------------------------------------------------------------------------|
| game_id | u32            | Specify the game id. |
| upgrade | u32            | Specify the upgrade.|  


Happy coding!
# dislands-card-knight
