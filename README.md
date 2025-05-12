# Generic Party

A 2D party game inspired by Mario Party, developed in Godot 4.4.1. The game features a minigame system with multiple minigames where players compete against each other.

## Game Overview

Generic Party is a multiplayer party game where:
- Players compete in various minigames
- The minigame selection screen allows choosing specific minigames
- Each minigame has its own scoring system
- Results are shown after each minigame

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
│   ├── minigame_select.tscn     # Minigame selection screen
│   └── minigames/
│       ├── minigame_base.tscn   # Base minigame template
│       ├── race_game.tscn       # Button mashing race
│       └── shrinking_platform.tscn # Shrinking platform survival
├── scripts/
│   ├── globals/
│   │   ├── game_manager.gd      # Game state management
│   │   └── minigame_manager.gd  # Minigame loading/selection
│   └── minigames/
│       ├── minigame_base.gd     # Base minigame class
│       ├── race_game.gd         # Race minigame implementation
│       └── shrinking_platform.gd # Platform survival minigame
```

## Current Minigames

### Race Game
A button-mashing race where players must rapidly press their action button to move their character toward the finish line. The first player to reach the finish line wins.

- **Controls**: Player 1: Space, Player 2: Enter
- **Time Limit**: 30 seconds
- **Scoring**: First to finish gets the highest score

### Shrinking Platform
A survival minigame where players try to stay on a platform as it gets consumed by lava in a spiral pattern. Players can push each other to knock opponents into the lava.

- **Controls**: 
  - Player 1: WASD (movement) + Space (push)
  - Player 2: Arrow Keys (movement) + Enter (push)
- **Time Limit**: 60 seconds
- **Scoring**: Last player standing gets the most points

## Getting Started

1. Install Godot 4.4.1
2. Clone this repository
3. Open the project in Godot
4. Press F5 to run

## License

See the [LICENSE](LICENSE) file for details.