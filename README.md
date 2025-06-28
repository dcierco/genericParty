# Generic Party

A 2D party game inspired by Mario Party, developed in Godot 4.4.1. The game features a minigame system with multiple minigames where players compete against each other.

## Game Overview

Generic Party is a multiplayer party game where:
- Players compete in various minigames in **Party Mode**
- The minigame selection screen shows cumulative scores across all games
- Each completed minigame is removed from the list
- When all minigames are completed, final party results are displayed
- Each minigame has its own scoring system with first place bonuses and completion rewards

## Code Structure

The project is built with a modular design, using a base minigame class that handles common functionality:

### Minigame System

All minigames inherit from the `MinigameBase` class which provides:
- Common UI elements (countdown timer, results screen)
- Game state management (intro, playing, finished states)
- Score tracking and player ranking
- Time limits and countdown functionality

This approach allows each individual minigame to focus on its specific gameplay while reusing common mechanics.

### Game Structure

```
/genericParty
├── assets/            # Game assets (sprites, sounds, etc.)
├── scenes/
│   ├── main_menu.tscn           # Main menu
│   ├── minigame_select.tscn     # Minigame selection screen with party mode
│   ├── party_results.tscn       # Final results screen
│   └── minigames/
│       ├── minigame_base.tscn   # Base minigame template
│       ├── race_game.tscn       # Reflex-based race game
│       ├── shrinking_platform.tscn # Shrinking platform survival
│       ├── avoid_the_obstacles.tscn # Obstacle dodging game
│       └── jumping_platforms.tscn # Vertical platforming challenge
├── scripts/
│   ├── globals/
│   │   ├── game_manager.gd      # Game state management
│   │   ├── minigame_manager.gd  # Minigame loading/selection
│   │   └── global_score_manager.gd # Party mode score tracking
│   ├── party_results.gd         # Final party results screen
│   └── minigames/
│       ├── minigame_base.gd     # Base minigame class
│       ├── race_game.gd         # Reflex-based race implementation
│       ├── shrinking_platform.gd # Platform survival minigame
│       ├── avoid_the_obstacles.gd # Obstacle dodging implementation
│       └── jumping_platforms.gd # Vertical platforming implementation
```

## Current Minigames

### Race Game
A reflex-based race where players must press the correct button shown on screen to advance their character. Random button prompts appear that players must respond to quickly and accurately.

- **Controls**: 
  - Player 1: A/D/W/S/Space
  - Player 2: Arrow Keys/Enter
- **Time Limit**: 25 seconds
- **Scoring**: +100 points per distance traveled, +50 first place bonus, +200 completion bonus

### Shrinking Platform
A survival minigame where players try to stay on a platform as it gets consumed by lava in a spiral pattern. Players can push each other to knock opponents into the lava.

- **Controls**: 
  - Player 1: WASD (movement) + Space (push)
  - Player 2: Arrow Keys (movement) + Enter (push)
- **Time Limit**: 60 seconds
- **Scoring**: Last player standing gets the most points

### Avoid the Obstacles
Players control characters that must dodge incoming obstacles from multiple directions. The last player remaining or the player who survives the longest wins. Push opponents into danger to gain an advantage!

- **Controls**: 
  - Player 1: A/D (move) + W (jump) + Space (push)
  - Player 2: Left/Right Arrows (move) + Up Arrow (jump) + Enter (push)
- **Time Limit**: 60 seconds or until one player remains
- **Scoring**: Points awarded based on survival time, or last player standing wins

### Jumping Platforms
A vertical platforming challenge where players must jump on procedurally generated platforms to reach the highest point. Push opponents off platforms and avoid falling behind as the camera moves upward!

- **Controls**: 
  - Player 1: A/D (move) + W (jump) + Space (push)
  - Player 2: Left/Right Arrows (move) + Up Arrow (jump) + Enter (push)
- **Time Limit**: 60 seconds
- **Features**: One-way collision platforms, dynamic camera movement, procedural generation
- **Scoring**: +10 points per meter climbed, +50 first place bonus, +100 survival bonus

## Party Mode Features

- **Global Score Tracking**: Cumulative scores across all minigames
- **Game Progression**: Completed minigames are removed from the selection list
- **Final Results**: Comprehensive results screen with winner announcement, full rankings, and detailed score breakdowns
- **Action Options**: Start new party, return to main menu, or exit game

## Getting Started

1. Install Godot 4.4.1
2. Clone this repository
3. Open the project in Godot
4. Press F5 to run

## License

See the [LICENSE](LICENSE) file for details.
