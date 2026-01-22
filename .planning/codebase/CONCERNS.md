# Codebase Concerns

**Analysis Date:** 2026-01-22

## Tech Debt

**Inconsistent Player ID Handling:**
- Issue: Player IDs formatted as `peer_X` in Godot but stored as UUIDs in GameManager; web player receives `player_id` that don't match format expectations
- Files: `scripts/autoload/game_manager.gd`, `scripts/autoload/network_manager.gd`, `scripts/games/quick_draw.gd` (line 279-282), `scripts/games/charades.gd` (line 563)
- Impact: Peer ID conversion logic is fragile (lines 279-282 in quick_draw.gd uses hardcoded "peer_" prefix; line 563 in charades.gd uses `_peer_id` directly without conversion)
- Fix approach: Establish single authoritative ID format; create utility function for all conversions; synchronize between Godot server and web clients

**Monolithic Game Files:**
- Issue: Individual game implementations (quick_draw.gd, charades.gd) are 834 and 590 lines respectively; mixing UI logic, game logic, and network message handling
- Files: `scripts/games/quick_draw.gd`, `scripts/games/charades.gd`
- Impact: Difficult to test components independently; changes to one aspect (e.g., timer logic) require understanding entire file
- Fix approach: Extract game state machine, message handlers, and UI updates into separate classes; use composition over inheritance from BaseGame

**Character Sprite Generation Incomplete:**
- Issue: 3 of 8 characters still pending PixelLab generation (Yellow Bard, Orange Monk, Teal Robot); system uses color fallback
- Files: `scripts/autoload/game_manager.gd` (lines 27, 29, 31 marked as `sprite: null`)
- Impact: Incomplete visual polish; web player doesn't display character sprites at all
- Fix approach: Complete PixelLab generation; implement sprite loading system with error handling; add offline sprite cache

**Web Player Character Sprites Not Implemented:**
- Issue: Web player (`web-player/js/app.js`) stores character colors but doesn't load or display sprites; characters show only colored divs
- Files: `web-player/js/app.js` (lines 14-23), no sprite loading implementation
- Impact: Visual inconsistency between Godot host and web players; user experience degradation
- Fix approach: Add sprite URL property to character objects; load sprites in web player with fallback to colors

## Known Bugs

**WebSocket Reconnection Fragile:**
- Symptoms: After disconnection, reconnection attempts limited to 3 (hardcoded in web player); no exponential backoff
- Files: `web-player/js/websocket.js` (lines 8-9)
- Trigger: Disconnect host or interrupt network; player devices stop reconnecting after 3 attempts
- Workaround: Manual page refresh required to reconnect

**Quick Draw Guesser Canvas Rendering Bug:**
- Symptoms: Guesser canvas created dynamically in quickdraw.js (line 269); may fail if element doesn't exist
- Files: `web-player/js/games/quickdraw.js` (lines 264-280)
- Trigger: Rapid game transitions or missing DOM element `quickdraw-canvas-display`
- Workaround: Ensure HTML template always includes display element

**Player ID Type Mismatch in Charades:**
- Symptoms: Charades broadcast message uses wrong data type; `_peer_id` treated as player_id
- Files: `scripts/games/charades.gd` (line 563): `var player_id = "peer_%d" % _peer_id` should handle actual peer ID format
- Trigger: Non-host player makes guess in charades game
- Impact: Host-side validation may fail to attribute score correctly

**Base Game Peer ID Lookup Inefficient:**
- Symptoms: BaseGame._send_to_player loops through range 1-100 looking for peer_id match
- Files: `scripts/games/base_game.gd` (lines 70-74)
- Trigger: Every time game needs to send message to individual player
- Impact: Performance overhead in multiplayer with many round transitions

## Security Considerations

**No Input Validation on Guess/Answer Text:**
- Risk: Players can submit arbitrarily long strings; no length limits or sanitization
- Files: `scripts/games/quick_draw.gd` (line 654), `scripts/games/charades.gd` (line 267), `web-player/js/games/quickdraw.js` (line 316)
- Current mitigation: None
- Recommendations: Add max length constraints (e.g., 100 chars); sanitize before broadcast; validate string encoding

**No Authentication Between Host and Players:**
- Risk: Any device on same network can connect and spoof player IDs; no session validation
- Files: `scripts/autoload/network_manager.gd` (lines 106-128 join request handling)
- Current mitigation: Session ID generated but not enforced in join requests
- Recommendations: Require session_id in all join_request messages; validate peer before accepting messages

**Game Prompts Exposed to Host Display:**
- Risk: In Quick Draw, word sent to drawer in clear text over WebSocket; could be intercepted
- Files: `scripts/games/quick_draw.gd` (lines 189-192, 274-276), `web-player/js/games/quickdraw.js`
- Current mitigation: None (sends plaintext JSON)
- Recommendations: Low priority for local network games; if deploying externally, use TLS/WSS

**No Rate Limiting on Message Send:**
- Risk: Players can spam messages (guesses, drawing strokes); no throttling
- Files: `web-player/js/websocket.js` (lines 109-123), `scripts/autoload/network_manager.gd`
- Current mitigation: None
- Recommendations: Implement per-player rate limits; batch stroke updates in Quick Draw

## Performance Bottlenecks

**Drawing Stroke Sync Inefficient:**
- Problem: Quick Draw sends every stroke update individually as separate message
- Files: `scripts/games/quick_draw.gd` (lines 545-561)
- Cause: No batching; drawing at 60fps creates 60 messages/second per player
- Improvement path: Batch multiple points per message; throttle by time/distance (already attempts distance throttle at line 531 with MIN_POINT_DISTANCE 3.0, but incremental)

**Prompt Loading Synchronous:**
- Problem: Prompts loaded from JSON files at scene load; blocks UI if files are large
- Files: `scripts/games/quick_draw.gd` (line 111), `scripts/games/charades.gd` (line 50)
- Cause: FileAccess.open() is blocking; no async file loading
- Improvement path: Pre-load all prompts at game initialization; cache in memory; consider data compression

**Player Display Regenerated Every Round:**
- Problem: Players status UI rebuilt entirely on each update
- Files: `scripts/games/quick_draw.gd` (lines 787-834), `scripts/games/charades.gd` (lines 452-483)
- Cause: queue_free() all children, recreate from scratch
- Improvement path: Update existing nodes instead; use data binding

**Web Player Global Instances:**
- Problem: Game instances stored in window scope; no garbage collection between games
- Files: `web-player/js/app.js` (line 326), `web-player/js/websocket.js` (line 187)
- Cause: Global singletons persist; handlers not unregistered
- Improvement path: Implement proper lifecycle management; unregister handlers on game end

## Fragile Areas

**BaseGame._send_to_player Peer ID Conversion:**
- Files: `scripts/games/base_game.gd` (lines 67-74)
- Why fragile: Hardcoded loop assumes sequential peer IDs; will break if peer IDs not sequential
- Safe modification: Extract to NetworkManager; use peer_id → player_id mapping dict
- Test coverage: No unit tests for this mapping

**Message Type Dispatch in Games:**
- Files: `scripts/games/quick_draw.gd` (lines 730-775), `scripts/games/charades.gd` (lines 547-577)
- Why fragile: Large match statements; easy to miss edge cases; no default error handling
- Safe modification: Create message handler registry pattern; centralize invalid type handling
- Test coverage: No tests for unhandled message types

**Character Grid Taken Characters Sync:**
- Files: `web-player/js/app.js` (lines 101-105, 190-199)
- Why fragile: takenCharacters array manually maintained; can get out of sync if player_left message loses race with player_joined
- Safe modification: Use Set-based approach; reconcile on every update
- Test coverage: No test for concurrent player join/leave

**Timer Synchronization Between Host and Players:**
- Files: `scripts/games/quick_draw.gd` (lines 334-342, 354), `scripts/games/charades.gd` (lines 228-235)
- Why fragile: Each player keeps local timer; no resync if drift occurs; network lag can cause desync
- Safe modification: Send periodic timer updates from host; players use host time as source
- Test coverage: No stress tests for network latency

**Word Validation Fuzzy Matching:**
- Files: `scripts/games/charades.gd` (line 271): `(prompt_lower in guess_lower) or (guess_lower in prompt_lower)`
- Why fragile: Substring matching too permissive; "star" matches "start"; "war" matches "award"
- Safe modification: Use word boundary detection; Levenshtein distance for typos; disable substring matching
- Test coverage: Manual testing only; no validation test suite

## Scaling Limits

**Maximum Simultaneous Players:**
- Current capacity: Tested with up to 8 players (per PLAN.md settings); no load tests
- Limit: Each stroke in Quick Draw creates message per player; 8 players × 60 strokes/sec = 480 messages/sec
- Scaling path: Message batching; reduce update frequency; compress stroke data; consider server-side relay optimization

**WebSocket Server Connection Limit:**
- Current capacity: Godot TCPServer default limit (usually OS socket limit ~1024)
- Limit: Unclear; no explicit limits in code
- Scaling path: Add explicit max_players check; implement connection pooling for future

**Game Prompt Database Size:**
- Current capacity: Charades has 799 prompts; loaded entirely into memory
- Limit: If expanding to 1000s of prompts, memory pressure increases
- Scaling path: Paginate prompts; lazy-load by category; implement prompt streaming

## Dependencies at Risk

**Godot WebSocket Implementation:**
- Risk: Relies on Godot 4.5's built-in WebSocketPeer; if bugs found, limited options
- Impact: Connection issues would require Godot update or workaround
- Migration plan: Switch to godotengine/godot-websocket plugin if needed; document alternatives

**JSON Parsing Across Platforms:**
- Risk: JSON.parse_string() behavior may differ across Godot versions or platforms
- Impact: Message deserialization could fail silently on some platforms
- Migration plan: Add try-catch around all JSON parsing; implement fallback parser

## Missing Critical Features

**Session Timeout:**
- Problem: No timeout for idle sessions; host can leave game running indefinitely
- Blocks: Memory cleanup; preventing stale sessions
- Recommended: Add 30-minute timeout; warn players before disconnect

**Graceful Host Disconnect:**
- Problem: When host leaves, all players get disconnected but no UI prompt to rejoin
- Blocks: Resuming games if host has temporary network issue
- Recommended: Implement host rejoin with session recovery

**Message Acknowledgment System:**
- Problem: No confirmation that critical messages (start_round, end_game) were received
- Blocks: Reliable game state sync; detecting silent failures
- Recommended: Add ACK mechanism for game-critical messages; timeout + retry

**Player Reconnection During Game:**
- Problem: If player reconnects mid-game, they start from scratch; no state recovery
- Blocks: Robust multiplayer experience
- Recommended: Store per-player game state; send on reconnect

## Test Coverage Gaps

**Web Player WebSocket Reconnection:**
- What's not tested: 3+ reconnection attempts; exponential backoff; connection timeout
- Files: `web-player/js/websocket.js`
- Risk: Silent failure modes; users unaware reconnection failed
- Priority: High

**Cross-Device Message Sync:**
- What's not tested: Multiple players sending simultaneous messages; message ordering; race conditions
- Files: `scripts/autoload/network_manager.gd`, `web-player/js/websocket.js`
- Risk: Game state inconsistency; wrong winner calculation
- Priority: High

**Guess Validation Edge Cases:**
- What's not tested: Empty string; very long string; special characters; unicode; case sensitivity
- Files: `scripts/games/charades.gd` (line 266-271), `scripts/games/quick_draw.gd` (line 664-670)
- Risk: Crashes; unfair game outcomes
- Priority: Medium

**Drawing Undo/Clear Sync:**
- What's not tested: Undo when multiple strokes in flight; clear during active drawing
- Files: `scripts/games/quick_draw.gd` (lines 606-623)
- Risk: Visual desync between players
- Priority: Medium

**Character Selection Conflict Resolution:**
- What's not tested: Two players selecting same character; race condition during join
- Files: `scripts/autoload/game_manager.gd` (lines 69-76), `web-player/js/app.js` (lines 177-181)
- Risk: Duplicate character assignment
- Priority: Medium

---

*Concerns audit: 2026-01-22*
