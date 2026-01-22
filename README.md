# Party Game Collection

A mobile party game collection built with Godot 4.5 where one player hosts a session and others join via QR code to play family-friendly games together.

## How It Works

1. **Host** opens the app and creates a session
2. **Players** scan the QR code to join (or enter the IP manually)
3. **Host** selects a game from the collection
4. Everyone plays on their own device

The host's device acts as the "game board" while player devices serve as personal controllers.

## Games

| Game | Description | Players |
|------|-------------|---------|
| **Quick Draw** | Pictionary-style drawing and guessing | 2+ |
| **Act It Out** | Classic charades - act without speaking | 3+ |
| **Fibbage** | Bluff with fake answers to fool others | 3+ |
| **Word Bomb** | Race to type words containing letter combos | 2+ |
| **Who Said It?** | Guess who wrote each anonymous answer | 3+ |
| **Trivia Showdown** | Fast-paced multiple choice trivia | 2+ |

## Current Status

| Game | Status | Notes |
|------|--------|-------|
| **Word Bomb** | Complete | Timer, lives, word validation |
| **Act It Out** | Complete | 799 prompts across 5 categories |
| **Quick Draw** | Complete | Drawing sync, guessing, 2+ players |
| **Who Said It?** | Complete | 62 prompts, anonymous answers, voting |
| **Trivia Showdown** | Complete | 120 questions, speed bonus scoring |
| **Fibbage** | Not Started | Last remaining game |

## Requirements

- Godot 4.5
- All players must be on the same local network

## Running the Game

1. Open the project in Godot 4.5
2. Run the project (F5)
3. Host: Tap "Host Game", enter your name, and create a session
4. Players: Scan the QR code or enter the host's IP address

## Project Structure

```
scenes/          - Game scenes (.tscn files)
scripts/         - GDScript files
  autoload/      - Global managers (GameManager, NetworkManager)
  games/         - Individual game logic
  lobby/         - Lobby and menu screens
data/prompts/    - JSON word banks for games
assets/          - Characters, UI, audio
```

See [PLAN.md](PLAN.md) for detailed development documentation.
