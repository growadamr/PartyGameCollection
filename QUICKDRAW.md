# Quick Draw Review

## Current Features

- **Core loop**: One player draws (60s timer), others guess via text input
- **Drawing tools**: 5 colors (black/red/blue/green/yellow), eraser, undo, clear
- **Scoring**: Speed-based tiered scoring with hints penalty
  - 3 pts: guess in first 20s
  - 2 pts: guess in 20-40s
  - 1 pt: guess after 40s
  - Each hint used reduces max points by 1 (minimum 0 pts)
  - 0 pts = "Congratulations, you have earned a participation trophy!"
  - Drawer gets points equal to highest guesser's score
- **Hints**: 3 automatic hints at time thresholds
  - 45s remaining: 2nd letter of the word
  - 30s remaining: Letter count
  - 15s remaining: First letter
- **Wrong guesses**: Displayed to all players (adds humor and helps eliminate options)
- **Round behavior**: Continues until timer ends or everyone guesses
- **Word difficulty**: Scales from easy -> medium -> hard as rounds progress
- **Rounds**: Each player draws once (total rounds = player count)
- **Real-time sync**: Strokes broadcast to all players
- **Web player support**: Full HTML5 canvas implementation

## Suggestions

### Low Effort / High Impact

1. ~~**Speed-based scoring**~~ DONE - 3/2/1 pts based on guess speed
2. ~~**Don't end on first guess**~~ DONE - Round continues until timer or everyone guesses
3. **Word choice for drawer** - Show 3 word options (easy/medium/hard) so the drawer picks based on confidence
4. ~~**Show wrong guesses**~~ DONE - Display failed guesses to all players (adds humor and helps everyone)

### Medium Effort

5. **Variable brush size** - Add a thickness slider or 3 preset sizes
6. ~~**Eraser tool**~~ DONE - Draw in white/background color
7. ~~**Hint system**~~ DONE - Auto-hints at 45s/30s/15s (2nd letter, letter count, first letter) with scoring penalty
8. **Multiple drawing rounds** - Let each player draw 2-3 times for longer games

### Polish

9. **Sound effects** - Timer tick, correct answer ding, round transitions (infrastructure exists per NEXTSTEPS.md)

10. **Better visual feedback** - Animate the canvas when someone guesses correctly, show confetti/celebration

## File Locations

| Purpose | Path |
|---------|------|
| Game Script | `scripts/games/quick_draw.gd` |
| Scene | `scenes/games/quick_draw/quick_draw.tscn` |
| Word List | `data/prompts/quick_draw_words.json` |
| Web Player | `web-player/js/games/quickdraw.js` |
