# Imposter Game Fixes

## Issues Identified and Fixed

### 1. Host Not Treated as a Player ✅ FIXED

**Problem**: The host device was not receiving role assignment (imposter vs innocent).

**Root Cause**: In `scripts/games/imposter.gd` lines 77-90, the code only sent role data to remote players via WebSocket (`NetworkManager.send_to_client()`), but the host player (`GameManager.local_player_id`) never received their role assignment.

**Fix**: Modified the initialization loop to check if the player is the host (local player) and directly call `_apply_role_data()` instead of sending via WebSocket.

**Changed in**: `scripts/games/imposter.gd:77-97`

```gdscript
# BEFORE: Only sent to remote clients
NetworkManager.send_to_client(peer_id, role_data)

# AFTER: Check if local player and handle appropriately
if player_id.begins_with("peer_"):
    var peer_id = _get_peer_id_for_player(player_id)
    NetworkManager.send_to_client(peer_id, role_data)
elif player_id == GameManager.local_player_id:
    _apply_role_data(role_data)
```

---

### 2. Voting System Not Working ✅ FIXED

**Problem**: When players cast votes, the server crashed or votes were not processed.

**Root Cause**: In `scripts/games/imposter.gd` line 127-129, the code referenced `_peer_id` (with underscore prefix) which doesn't exist in scope.

```gdscript
# BUG:
"vote_cast":
    if GameManager.is_host:
        var voter_id = "peer_%d" % _peer_id  // _peer_id doesn't exist!
```

The function signature was `func _on_message_received(_peer_id: int, data: Dictionary)` where the underscore prefix indicates an intentionally unused parameter. However, the code tried to use it.

**Fix**: Removed the underscore prefix from the parameter name.

**Changed in**: `scripts/games/imposter.gd:118`

```gdscript
# BEFORE:
func _on_message_received(_peer_id: int, data: Dictionary) -> void:

# AFTER:
func _on_message_received(peer_id: int, data: Dictionary) -> void:
```

Now `peer_id` is properly accessible at lines 128 and 133.

---

### 3. Word Guess System Not Working ✅ FIXED

**Problem**: Imposters could not submit word guesses.

**Root Cause #1**: Same `_peer_id` variable issue as voting (line 133).

**Root Cause #2**: The web player JavaScript was calling `gameSocket.send()` incorrectly in two places:

In `web-player/js/games/imposter.js`:

```javascript
// WRONG (line 171):
gameSocket.send('word_guess', { guess: guess });

// WRONG (line 369):
gameSocket.send('vote_cast', { target_id: targetId });
```

The `gameSocket.send()` function expects a single object parameter with a `type` field, but the code was passing the type as a separate first parameter.

**Fix**:

1. Fixed the `peer_id` variable (same as issue #2)
2. Fixed the JavaScript calls:

**Changed in**: `web-player/js/games/imposter.js:171`
```javascript
// BEFORE:
gameSocket.send('word_guess', { guess: guess });

// AFTER:
gameSocket.send({ type: 'word_guess', guess: guess });
```

**Changed in**: `web-player/js/games/imposter.js:369`
```javascript
// BEFORE:
gameSocket.send('vote_cast', { target_id: targetId });

// AFTER:
gameSocket.send({ type: 'vote_cast', target_id: targetId });
```

---

## Files Modified

1. **scripts/games/imposter.gd**
   - Line 77-97: Added host player role assignment
   - Line 118: Fixed parameter name from `_peer_id` to `peer_id`

2. **web-player/js/games/imposter.js**
   - Line 171: Fixed word guess message format
   - Line 369: Fixed vote cast message format

3. **scripts/autoload/web_files_embedded.gd** (regenerated)
   - Updated with new JavaScript content

---

## How to Test

1. **Build and deploy** to iOS device with updated code
2. **Host creates game** with name and character
3. **Host opens web player** on same device (Safari → http://localhost:8000)
4. **Other players join** via QR code on their devices
5. **Start Imposter game** from game selection

### Expected Behavior:

- ✅ Host receives role (imposter or innocent) and sees secret word if innocent
- ✅ All players can cast votes for who they think is the imposter
- ✅ Imposters can guess the word to win instantly
- ✅ Consensus system works (5-second countdown when everyone votes for same person)
- ✅ Eliminated players enter spectator mode
- ✅ Round ends correctly with winner announcement

---

## Architecture Note

The Party Game Collection uses a **dual-interface architecture**:

- **Godot App (iPhone)**: Acts as the game board/display server
- **Web Player (Browser)**: Acts as player controllers

This means:
- The host runs the Godot app on their iPhone to display the game
- The host ALSO loads the web player in Safari to participate as a player
- All players (including host) interact through the web player interface
- The Godot app handles game logic and broadcasts state to all web players

---

## Additional Files

- **generate_web_files.py**: Python script to regenerate embedded web files
  - Run with: `python3 generate_web_files.py`
  - Regenerates `scripts/autoload/web_files_embedded.gd`
  - Should be run whenever web player files (HTML/CSS/JS) are modified

---

*Fixes completed: 2026-01-28*
