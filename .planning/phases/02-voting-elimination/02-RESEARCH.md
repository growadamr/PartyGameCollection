# Phase 2: Voting & Elimination - Research

**Researched:** 2026-01-22
**Domain:** Real-time voting system with consensus detection for Godot 4.5 + WebSocket web player
**Confidence:** HIGH

## Summary

This phase implements real-time voting where players vote for suspected imposters, with consensus detection triggering reveal countdowns. The implementation follows the established host-authoritative architecture where Godot controls all game state and web players send vote intents.

The existing codebase provides clear patterns: `NetworkManager.broadcast()` for state visible to all, `NetworkManager.send_to_client()` for personalized data, and message handlers using the `_on_message_received` pattern with match statements. The charades game demonstrates state machine patterns with timer management that directly apply here.

**Primary recommendation:** Implement voting as a state machine on the host (VOTING -> CONSENSUS_WARNING -> REVEALING -> RESULT_DISPLAY) with votes stored in a Dictionary, using a 100ms debounce on consensus checks to handle rapid vote changes, and broadcasting vote tallies after each change.

## Standard Stack

The implementation uses the existing technology stack with no new dependencies required.

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Godot 4.5 | 4.5 | Host-side game logic | Already in use, GDScript for all host logic |
| WebSocket | Built-in | Real-time communication | Already configured on port 8080 |
| JavaScript | ES6+ | Web player UI | Vanilla JS, no build step required |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| Timer node | Countdown management | Consensus warning countdown |
| Dictionary | Vote storage | Track `voter_id -> target_id` mappings |
| Signal | State change notifications | Internal component communication |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Timer node | `await get_tree().create_timer()` | Timer node can be stopped/reset; await cannot be cancelled |
| Dictionary for votes | Array of vote objects | Dictionary provides O(1) lookup by voter, easier to update |

## Architecture Patterns

### State Machine Design

The voting phase operates as a state machine with four states:

```
VOTING -> CONSENSUS_WARNING -> REVEALING -> RESULT_DISPLAY
   ^            |                               |
   |            v (consensus breaks)            |
   +------------+                               |
   ^                                            |
   +--------------------------------------------+
              (after result display)
```

**States:**
- `VOTING`: Players can cast/change votes, tallies update in real-time
- `CONSENSUS_WARNING`: 5-second countdown, votes can still change, resets if consensus breaks
- `REVEALING`: "Revealing..." dramatic pause (1-2 seconds), no vote changes
- `RESULT_DISPLAY`: Show result for 3-4 seconds, then transition

### Recommended Project Structure

The implementation extends existing files:

```
scripts/games/
  imposter.gd          # Add voting state machine, consensus detection
web-player/
  js/games/
    imposter.js        # Add vote UI handlers, state rendering
  index.html           # Add voting UI section to #screen-imposter
  css/
    style.css          # Add voting-specific styles
```

### Pattern 1: Host-Authoritative Voting

**What:** All vote validation and consensus detection happens on the host. Web players send vote intents, host broadcasts authoritative state.

**When to use:** Always - this is the established architecture.

**Example (existing pattern from charades.gd):**
```gdscript
# Web player sends intent
# {"type": "vote_cast", "target_id": "peer_3"}

# Host validates and broadcasts
func _on_message_received(peer_id: int, data: Dictionary) -> void:
    match data.get("type", ""):
        "vote_cast":
            var voter_id = "peer_%d" % peer_id
            var target_id = data.get("target_id", "")
            _process_vote(voter_id, target_id)

func _process_vote(voter_id: String, target_id: String) -> void:
    if not _can_vote(voter_id):
        return  # Eliminated players can't vote

    votes[voter_id] = target_id
    _broadcast_vote_state()
    _check_consensus()
```

### Pattern 2: Vote State Broadcasting

**What:** After any vote change, broadcast the complete vote state so all clients stay synchronized.

**When to use:** Every vote change.

**Example:**
```gdscript
func _broadcast_vote_state() -> void:
    # Calculate tallies
    var tallies: Dictionary = {}  # player_id -> vote_count
    for voter_id in votes:
        var target = votes[voter_id]
        tallies[target] = tallies.get(target, 0) + 1

    NetworkManager.broadcast({
        "type": "vote_update",
        "votes": votes,        # Full vote map for highlighting own vote
        "tallies": tallies,    # Aggregated counts for display
        "state": current_state # VOTING, CONSENSUS_WARNING, etc.
    })
```

### Pattern 3: Consensus Detection with Debounce

**What:** Check for consensus after votes change, with debounce to handle rapid changes.

**When to use:** After every vote change during VOTING or CONSENSUS_WARNING states.

**Example:**
```gdscript
var _consensus_check_timer: Timer
var CONSENSUS_CHECK_DELAY: float = 0.1  # 100ms debounce

func _check_consensus() -> void:
    # Debounce rapid vote changes
    if _consensus_check_timer.is_stopped():
        _consensus_check_timer.start(CONSENSUS_CHECK_DELAY)

func _on_consensus_check_timer_timeout() -> void:
    var eligible_voters = _get_eligible_voters()  # Non-eliminated players
    var vote_counts: Dictionary = {}

    for voter_id in votes:
        if voter_id in eligible_voters:
            var target = votes[voter_id]
            vote_counts[target] = vote_counts.get(target, 0) + 1

    # Consensus: all eligible voters (except target) vote for same person
    for target_id in vote_counts:
        var voters_excluding_target = eligible_voters.filter(func(v): return v != target_id)
        if vote_counts[target_id] == voters_excluding_target.size() and voters_excluding_target.size() > 0:
            _start_consensus_warning(target_id)
            return

    # No consensus - reset warning if active
    if current_state == State.CONSENSUS_WARNING:
        _cancel_consensus_warning()
```

### Pattern 4: Interruptible Countdown

**What:** Timer-based countdown that can be cancelled and reset.

**When to use:** Consensus warning countdown.

**Example:**
```gdscript
var _countdown_timer: Timer
var _countdown_remaining: int = 5

func _start_consensus_warning(target_id: String) -> void:
    consensus_target = target_id
    current_state = State.CONSENSUS_WARNING
    _countdown_remaining = 5
    _countdown_timer.start(1.0)

    NetworkManager.broadcast({
        "type": "consensus_warning",
        "target_id": target_id,
        "countdown": _countdown_remaining
    })

func _on_countdown_timer_timeout() -> void:
    _countdown_remaining -= 1

    if _countdown_remaining <= 0:
        _countdown_timer.stop()
        _start_reveal()
    else:
        NetworkManager.broadcast({
            "type": "consensus_countdown",
            "countdown": _countdown_remaining
        })
        _countdown_timer.start(1.0)

func _cancel_consensus_warning() -> void:
    _countdown_timer.stop()
    consensus_target = ""
    current_state = State.VOTING

    NetworkManager.broadcast({
        "type": "consensus_cancelled"
    })
```

### Anti-Patterns to Avoid

- **Client-side vote validation:** Never trust web player to determine valid votes. Host validates everything.
- **Polling for state:** Don't have clients poll for vote counts. Push updates on every change.
- **Storing state in multiple places:** Votes Dictionary is single source of truth. Tallies are computed, not stored.
- **Blocking timers:** Don't use `await` for cancellable countdowns. Use Timer nodes that can be stopped.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Countdown timer | Manual delta tracking | Timer node | Can be stopped/reset, emits signals |
| JSON serialization | String concatenation | `JSON.stringify()` / `JSON.parse_string()` | Already used throughout codebase |
| Peer ID lookup | Manual mapping | `"peer_%d" % peer_id` pattern | Established convention in codebase |
| Player list iteration | Custom loops | `GameManager.players.keys()` | Consistent with existing code |

**Key insight:** The codebase has established patterns for all networking, timing, and player management. Follow existing patterns rather than inventing new ones.

## Common Pitfalls

### Pitfall 1: Race Conditions in Vote Updates

**What goes wrong:** Multiple rapid votes arrive, consensus check triggers multiple times, state becomes inconsistent.

**Why it happens:** WebSocket messages can arrive faster than processing completes.

**How to avoid:**
- Debounce consensus checks with a short timer (100ms)
- Always check current state before processing votes
- State transitions are atomic (change state, then broadcast)

**Warning signs:** Multiple "consensus_warning" messages in quick succession, UI flickering.

### Pitfall 2: Eliminated Player Votes

**What goes wrong:** Eliminated players' old votes still count, or they can still vote.

**Why it happens:** Forgetting to clear votes when player is eliminated, not checking elimination status.

**How to avoid:**
- Check `_can_vote(voter_id)` before processing any vote
- Clear eliminated player's vote from Dictionary immediately on elimination
- Filter out eliminated players when counting eligible voters

**Warning signs:** Vote counts exceed active player count.

### Pitfall 3: Consensus Target Voting for Themselves

**What goes wrong:** If 5 players vote for Alex, and Alex doesn't vote, that's consensus. But what if Alex votes for themselves?

**Why it happens:** Unclear consensus rules.

**How to avoid:** Consensus formula: "All eligible voters EXCEPT the target have voted for the target"
- Eligible = not eliminated
- Exclude target from the voter count

**Warning signs:** Consensus triggers when target hasn't voted.

### Pitfall 4: State Desync After Reconnection

**What goes wrong:** If a web player disconnects and reconnects mid-vote, they have no state.

**Why it happens:** No state recovery mechanism.

**How to avoid:**
- Send full state on reconnection (current votes, tallies, game state)
- Consider adding a `request_state` message type for recovery

**Warning signs:** Reconnected players see blank/stale UI.

### Pitfall 5: Countdown Visual Desync

**What goes wrong:** Host says "3" but web player shows "4" due to network latency.

**Why it happens:** Client-side timer drifts from server.

**How to avoid:**
- Host broadcasts the current countdown value each tick
- Web player displays exactly what host sends (don't run parallel timer)
- Minor visual jitter is acceptable; correctness matters more

**Warning signs:** Reveal happens when player's UI shows 1-2 seconds remaining.

## Code Examples

Verified patterns from existing codebase:

### Message Handling Pattern (from charades.gd)
```gdscript
func _on_message_received(_peer_id: int, data: Dictionary) -> void:
    var msg_type = data.get("type", "")

    match msg_type:
        "vote_cast":
            if GameManager.is_host:
                var voter_id = "peer_%d" % _peer_id
                _process_vote(voter_id, data.get("target_id", ""))
        "vote_update":
            _apply_vote_state(data)
        "consensus_warning":
            _apply_consensus_warning(data)
        "consensus_countdown":
            _apply_countdown(data)
        "consensus_cancelled":
            _apply_consensus_cancelled()
        "reveal_start":
            _apply_reveal_start(data)
        "reveal_result":
            _apply_reveal_result(data)
```

### Broadcast Pattern (from charades.gd)
```gdscript
func _broadcast_result(is_imposter: bool, target_id: String) -> void:
    var target_data = GameManager.players.get(target_id, {})
    var target_name = target_data.get("name", "Unknown")

    var data = {
        "type": "reveal_result",
        "target_id": target_id,
        "target_name": target_name,
        "is_imposter": is_imposter,
        "remaining_imposters": _count_remaining_imposters()
    }

    if GameManager.is_host:
        NetworkManager.broadcast(data)
        _apply_reveal_result(data)
```

### Web Player Socket Handler Pattern (from charades.js)
```javascript
setupSocketHandlers() {
    gameSocket.on('vote_update', (data) => {
        this.handleVoteUpdate(data);
    });

    gameSocket.on('consensus_warning', (data) => {
        this.handleConsensusWarning(data);
    });

    gameSocket.on('consensus_countdown', (data) => {
        this.updateCountdown(data.countdown);
    });

    gameSocket.on('consensus_cancelled', () => {
        this.handleConsensusCancelled();
    });

    gameSocket.on('reveal_result', (data) => {
        this.handleRevealResult(data);
    });
}
```

### Web Player Vote Sending Pattern
```javascript
castVote(targetId) {
    gameSocket.send({
        type: 'vote_cast',
        target_id: targetId
    });
}
```

### Timer Node Usage (from charades.gd)
```gdscript
@onready var countdown_timer: Timer = $CountdownTimer

func _ready() -> void:
    countdown_timer.timeout.connect(_on_countdown_timer_timeout)

func _start_countdown() -> void:
    countdown_remaining = 5
    countdown_timer.start(1.0)  # 1 second intervals

func _on_countdown_timer_timeout() -> void:
    countdown_remaining -= 1
    if countdown_remaining <= 0:
        countdown_timer.stop()
        _proceed_to_reveal()
    else:
        _broadcast_countdown()
        countdown_timer.start(1.0)

func _cancel_countdown() -> void:
    countdown_timer.stop()
```

## Message Protocol Design

### Client -> Host Messages

| Message Type | Data | When Sent |
|--------------|------|-----------|
| `vote_cast` | `{target_id: string}` | Player taps a name to vote |

### Host -> All Clients Messages

| Message Type | Data | When Sent |
|--------------|------|-----------|
| `voting_started` | `{players: [...], eliminated: [...]}` | Voting phase begins |
| `vote_update` | `{votes: {voter->target}, tallies: {player->count}, state: string}` | After any vote change |
| `consensus_warning` | `{target_id: string, target_name: string, countdown: int}` | Consensus detected |
| `consensus_countdown` | `{countdown: int}` | Each second of countdown |
| `consensus_cancelled` | `{}` | Consensus broken |
| `reveal_start` | `{target_id: string, target_name: string}` | Countdown finished, reveal starting |
| `reveal_result` | `{target_id, target_name, is_imposter, remaining_imposters}` | After dramatic pause |
| `elimination` | `{eliminated_id: string, eliminated_name: string}` | Imposter caught |
| `voting_resumed` | `{votes: {...}, tallies: {...}}` | After result, if game continues |

### Host -> Specific Client Messages

| Message Type | Data | When Sent |
|--------------|------|-----------|
| `word_revealed` | `{word: string}` | Eliminated imposter can see the word |

## State Management Approach

### Host State Variables

```gdscript
enum State { VOTING, CONSENSUS_WARNING, REVEALING, RESULT_DISPLAY }

var current_state: State = State.VOTING
var votes: Dictionary = {}           # voter_id -> target_id
var eliminated_players: Array = []   # List of eliminated player IDs
var consensus_target: String = ""    # Current consensus target (if any)
var countdown_remaining: int = 5     # Consensus countdown
var remaining_imposters: int = 0     # Count of living imposters
```

### Web Player State Variables

```javascript
class ImposterGame {
    constructor() {
        // ... existing
        this.currentState = 'voting';  // voting, consensus_warning, revealing, result
        this.votes = {};               // Synced from host
        this.tallies = {};             // Synced from host
        this.myVote = null;            // Current player's vote target
        this.consensusTarget = null;   // Who is being accused
        this.countdown = 5;            // Countdown remaining
        this.isEliminated = false;     // Is current player eliminated
    }
}
```

### State Transitions

```
VOTING:
  - on vote_cast: update votes, broadcast vote_update, check consensus
  - on consensus detected: -> CONSENSUS_WARNING

CONSENSUS_WARNING:
  - on vote_cast: update votes, broadcast vote_update, check if consensus still holds
  - on consensus broken: -> VOTING, broadcast consensus_cancelled
  - on countdown complete: -> REVEALING

REVEALING:
  - 1-2 second dramatic pause
  - No votes accepted
  - -> RESULT_DISPLAY

RESULT_DISPLAY:
  - Show result for 3-4 seconds
  - If imposter caught: update eliminated_players
  - If innocents remain and imposters remain: -> VOTING
  - If all imposters caught: -> GAME_END (Phase 3)
  - If not enough players: -> GAME_END (Phase 3)
```

## UI Implementation Notes

### Vote Display HTML Structure
```html
<!-- Inside #screen-imposter -->
<div id="imposter-voting-view" class="game-content hidden">
    <p class="vote-instruction">Tap a player to vote</p>
    <div id="vote-player-list" class="vote-list">
        <!-- Dynamically populated -->
    </div>
</div>

<div id="imposter-consensus-view" class="game-content hidden">
    <div class="consensus-warning">
        <p class="consensus-text">Consensus on <span id="consensus-name">???</span></p>
        <div class="countdown-number" id="consensus-countdown">5</div>
    </div>
</div>

<div id="imposter-reveal-view" class="game-content hidden">
    <div class="reveal-card">
        <p class="reveal-text">Revealing...</p>
    </div>
</div>

<div id="imposter-result-view" class="game-content hidden">
    <div class="result-card imposter">  <!-- or .innocent -->
        <h2 id="result-name">Alex</h2>
        <p id="result-role">was an IMPOSTER!</p>
        <p id="remaining-count">1 imposter remaining</p>
    </div>
</div>
```

### CSS Additions
```css
/* Voting list */
.vote-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
    width: 100%;
}

.vote-option {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    background: var(--bg-card);
    border-radius: var(--border-radius);
    border: 3px solid transparent;
    cursor: pointer;
}

.vote-option.my-vote {
    border-color: var(--accent-primary);
}

.vote-option.eliminated {
    opacity: 0.4;
    text-decoration: line-through;
    cursor: not-allowed;
}

.vote-count {
    background: var(--accent-secondary);
    padding: 4px 12px;
    border-radius: 12px;
    font-weight: bold;
}

/* Consensus warning */
.consensus-warning {
    display: flex;
    flex-direction: column;
    align-items: center;
    animation: pulse-red 0.5s infinite;
}

@keyframes pulse-red {
    0%, 100% { background-color: rgba(255, 0, 0, 0.1); }
    50% { background-color: rgba(255, 0, 0, 0.3); }
}

.countdown-number {
    font-size: 6rem;
    font-weight: bold;
    color: var(--accent-secondary);
}

/* Result cards */
.result-card.imposter {
    background: linear-gradient(135deg, #ff4444 0%, #cc0000 100%);
}

.result-card.innocent {
    background: linear-gradient(135deg, #44ff44 0%, #00cc00 100%);
}
```

## Edge Cases to Handle

1. **Last two players:** If only 2 players remain and one is imposter, game should likely end (handle in Phase 3).

2. **All vote at once:** Rapid simultaneous votes - debounce prevents multiple consensus triggers.

3. **Player disconnects during countdown:**
   - If disconnected player was the consensus target: cancel countdown, remove from game
   - If disconnected player was a voter: recount votes, may break/maintain consensus

4. **Everyone votes except target:** This IS consensus. Target doesn't need to vote.

5. **Imposter votes for fellow imposter:** Allowed. Imposters can try to frame each other strategically.

6. **Vote change during countdown:** Allowed per requirements. Must recheck consensus after every change.

## Open Questions

1. **Minimum voters for consensus:**
   - What happens with 3 players remaining? 2 vote for 1 = consensus?
   - Recommendation: Yes, this is valid consensus. Handle "too few players" in Phase 3.

2. **Self-votes:**
   - Can players vote for themselves?
   - Recommendation: Allow it (strategic misdirection), but it counts in consensus (voting for yourself when you're the target doesn't block consensus).

3. **Vote timeout:**
   - Should there be a maximum voting time before forcing a skip?
   - Recommendation: No timeout in Phase 2. Add optional time pressure in Phase 3 if desired.

## Sources

### Primary (HIGH confidence)
- `/Users/adamgrow/PartyGameCollection/scripts/games/charades.gd` - State machine patterns, timer usage, message handling
- `/Users/adamgrow/PartyGameCollection/scripts/autoload/network_manager.gd` - Networking API (`broadcast`, `send_to_client`)
- `/Users/adamgrow/PartyGameCollection/scripts/games/imposter.gd` - Existing Phase 1 implementation to extend
- `/Users/adamgrow/PartyGameCollection/web-player/js/games/charades.js` - Web player socket handler patterns
- `/Users/adamgrow/PartyGameCollection/web-player/js/websocket.js` - GameSocket API (`send`, `on`)

### Secondary (MEDIUM confidence)
- `/Users/adamgrow/PartyGameCollection/.planning/phases/02-voting-elimination/02-CONTEXT.md` - User design decisions

## Metadata

**Confidence breakdown:**
- Message protocol: HIGH - Follows exact patterns from charades implementation
- State machine: HIGH - Direct adaptation of proven charades pattern
- Consensus detection: HIGH - Straightforward algorithm, no external dependencies
- UI patterns: HIGH - Follows existing CSS variables and class patterns
- Edge cases: MEDIUM - Some decisions need confirmation (self-votes, minimum players)

**Research date:** 2026-01-22
**Valid until:** Indefinite (internal codebase patterns, no external dependencies)
