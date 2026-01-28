# Who Said It? - Implementation Plan

> **Game Type:** Quote Attribution / Social Deduction
> **Min Players:** 3 | **Max Players:** 8
> **Round Time:** 60 seconds (writing) + 30 seconds (voting per answer)

---

## Table of Contents

1. [Game Overview](#game-overview)
2. [Game Flow](#game-flow)
3. [Scoring System](#scoring-system)
4. [Message Protocol](#message-protocol)
5. [Files to Create](#files-to-create)
6. [Code Structure](#code-structure)
7. [UI/Scene Layout](#uiscene-layout)
8. [Assets Needed](#assets-needed)
9. [Data File Structure](#data-file-structure)
10. [Implementation Steps](#implementation-steps)
11. [Integration Checklist](#integration-checklist)

---

## Game Overview

**Who Said It?** is a social deduction party game where players anonymously answer personal or hypothetical questions, then try to guess who wrote each answer.

### Core Mechanics
- All players receive the same prompt (e.g., "What would you do with a million dollars?")
- Each player writes their answer anonymously
- Once all answers are submitted, they're displayed one at a time
- For each answer, all OTHER players vote on who they think wrote it (you can vote for any player except yourself)
- Points awarded for correct guesses AND for fooling other players

### Why It's Fun
- Reveals personality and humor
- Creates memorable moments when friends guess wrong
- Rewards both clever answers and knowing your friends

---

## Game Flow

### Phase 0: Ready Check (before each round)

All players must click "Ready!" before the round begins. Player avatars show a checkmark when ready.

```
┌─────────────────────────────────────────┐
│  HOST DISPLAY                           │
│                                         │
│         Ready to Start?                 │
│         Round 1                         │
│                                         │
│  [✓ Alice]  [✓ Bob]  [○ Carol]  [○ Dave]│
│                                         │
│           2/4 ready                     │
│                                         │
│  Players click "Ready!" to continue     │
└─────────────────────────────────────────┘
```

### Phase 1: Prompt Display & Answer Writing (60 seconds)

```
┌─────────────────────────────────────────┐
│  HOST DISPLAY                           │
│  ┌─────────────────────────────────────┐│
│  │ "What would you bring to a          ││
│  │  deserted island?"                  ││
│  └─────────────────────────────────────┘│
│                                         │
│  ⏱️ Time Remaining: 45s                 │
│                                         │
│  Waiting for answers...                 │
│  ✓ Alice    ✓ Bob    ○ Carol    ○ Dave │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  PLAYER DISPLAY (all players)           │
│  ┌─────────────────────────────────────┐│
│  │ "What would you bring to a          ││
│  │  deserted island?"                  ││
│  └─────────────────────────────────────┘│
│                                         │
│  Your answer (keep it secret!):         │
│  ┌─────────────────────────────────────┐│
│  │ A solar-powered phone charger       ││
│  └─────────────────────────────────────┘│
│                                         │
│  [Submit Answer]                        │
└─────────────────────────────────────────┘
```

### Phase 2: Voting Phase (30 seconds per answer)

```
┌─────────────────────────────────────────┐
│  HOST DISPLAY                           │
│  Answer 1 of 4                          │
│  ┌─────────────────────────────────────┐│
│  │ "A solar-powered phone charger"     ││
│  └─────────────────────────────────────┘│
│                                         │
│  ⏱️ Vote now: 25s                       │
│                                         │
│  Who wrote this?                        │
│  Votes cast: 2/3                        │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  PLAYER DISPLAY (if NOT the author)     │
│  ┌─────────────────────────────────────┐│
│  │ "A solar-powered phone charger"     ││
│  └─────────────────────────────────────┘│
│                                         │
│  Who wrote this?                        │
│  ┌───────┐ ┌───────┐ ┌───────┐         │
│  │ Alice │ │  Bob  │ │ Carol │         │
│  └───────┘ └───────┘ └───────┘         │
│  ┌───────┐                              │
│  │ Dave  │                              │
│  └───────┘                              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│  PLAYER DISPLAY (if IS the author)      │
│  ┌─────────────────────────────────────┐│
│  │ "A solar-powered phone charger"     ││
│  │         (Your answer!)              ││
│  └─────────────────────────────────────┘│
│                                         │
│  😏 Wait and see who guesses correctly! │
│                                         │
│  Votes so far: 2/3                      │
└─────────────────────────────────────────┘
```

### Phase 3: Reveal Results (per answer)

```
┌─────────────────────────────────────────┐
│  HOST DISPLAY                           │
│  ┌─────────────────────────────────────┐│
│  │ "A solar-powered phone charger"     ││
│  │         Written by: CAROL           ││
│  └─────────────────────────────────────┘│
│                                         │
│  ✓ Alice guessed Carol (+50 pts)       │
│  ✗ Bob guessed Dave                    │
│  😏 Carol fooled 1 player (+50 pts)    │
│  (Dave is the author - didn't vote)    │
│                                         │
└─────────────────────────────────────────┘
```

### Phase 3b: Continue (after each reveal)

After viewing the reveal, all players must click "Next Answer" (or "See Results" for the last answer) to continue. This ensures everyone has time to see the results.

```
┌─────────────────────────────────────────┐
│  HOST DISPLAY                           │
│                                         │
│      Ready for next answer?             │
│                                         │
│  [✓ Alice]  [✓ Bob]  [○ Carol]  [○ Dave]│
│                                         │
│           2/4 ready                     │
│                                         │
│        [ Next Answer ]                  │
└─────────────────────────────────────────┘
```

### Phase 4: Round End / Game End

```
┌─────────────────────────────────────────┐
│  ROUND COMPLETE!                        │
│                                         │
│  Scores this round:                     │
│  1. Carol   +150 pts (300 total)       │
│  2. Alice   +100 pts (250 total)       │
│  3. Bob     +50 pts  (150 total)       │
│  4. Dave    +50 pts  (100 total)       │
│                                         │
│  [Next Round] or [Final Results]        │
└─────────────────────────────────────────┘
```

---

## Scoring System

| Action | Points | Description |
|--------|--------|-------------|
| Correct Guess | +50 | You correctly identified who wrote an answer |
| Fooled Player | +50 | Each player who guessed wrong on YOUR answer |
| Speed Bonus | +10 | First to submit answer (optional) |

### Scoring Example
- 4 players: Alice, Bob, Carol, Dave
- Carol writes an answer
- Alice guesses Carol (correct) → Alice +50
- Bob guesses Dave (wrong) → Carol +50 (fooled Bob)
- Dave guesses Alice (wrong) → Carol +50 (fooled Dave)
- Carol didn't vote (it's her answer) → no action

**Result:** Alice +50, Carol +100

---

## Message Protocol

All messages use the prefix `whosaid_`:

### Host → Players

```gdscript
# Game initialization
{
    "type": "whosaid_init",
    "player_order": ["uuid1", "uuid2", ...],
    "total_rounds": 3,
    "scores": {"uuid1": 0, "uuid2": 0, ...}
}

# Pre-round ready check
{
    "type": "whosaid_pre_round",
    "round": 1,
    "total_rounds": 3,
    "ready_players": []
}

# Ready status update
{
    "type": "whosaid_ready_status",
    "ready_players": ["uuid1", "uuid2"],
    "ready_count": 2,
    "players_needed": 4
}

# Writing phase started
{
    "type": "whosaid_prompt",
    "prompt": "What would you do with a million dollars?",
    "round": 1,
    "time_limit": 60
}

# Player submitted answer (status update)
{
    "type": "whosaid_answer_received",
    "player_id": "uuid",
    "answers_received": 3,
    "answers_needed": 4
}

# All answers received, voting begins
{
    "type": "whosaid_vote_start",
    "answer_index": 0,
    "answer_text": "Buy a yacht",
    "author_id": "uuid",  # Only sent to author for UI
    "voters": ["uuid1", "uuid2", "uuid3"],  # Everyone except author
    "time_limit": 30
}

# Vote received (status update)
{
    "type": "whosaid_vote_received",
    "votes_received": 2,
    "votes_needed": 3
}

# Answer reveal
{
    "type": "whosaid_reveal",
    "answer_index": 0,
    "answer_text": "Buy a yacht",
    "author_id": "uuid",
    "author_name": "Carol",
    "votes": {
        "uuid1": "uuid2",  # player1 voted for player2
        "uuid2": "uuid",   # player2 voted correctly
    },
    "correct_guessers": ["uuid2"],
    "fooled_players": ["uuid1"],
    "points_awarded": {
        "uuid": 50,    # Author fooled 1
        "uuid2": 50    # Correct guess
    },
    "scores": {"uuid1": 100, "uuid2": 150, ...}
}

# Continue screen (after reveal, before next answer)
{
    "type": "whosaid_continue",
    "answer_index": 0,
    "is_last_answer": false,
    "ready_players": []
}

# Round complete
{
    "type": "whosaid_round_end",
    "round": 1,
    "round_scores": {...},
    "total_scores": {...}
}

# Game over
{
    "type": "whosaid_end",
    "final_scores": {...},
    "winner_id": "uuid",
    "winner_name": "Carol"
}
```

### Players → Host

```gdscript
# Player ready
{
    "type": "whosaid_ready",
    "player_id": "uuid"
}

# Submit answer
{
    "type": "whosaid_answer",
    "player_id": "uuid",
    "answer": "Buy a yacht and sail around the world"
}

# Submit vote
{
    "type": "whosaid_vote",
    "player_id": "uuid",
    "voted_for": "uuid2"  # Who they think wrote it
}
```

---

## Files to Create

### GDScript Files

| File | Purpose |
|------|---------|
| `scripts/games/who_said_it.gd` | Main game logic (host + player) |

### Scene Files

| File | Purpose |
|------|---------|
| `scenes/games/who_said_it/who_said_it.tscn` | Game scene |

### Web Player Files

| File | Purpose |
|------|---------|
| `web-player/js/games/whosaidit.js` | Browser game interface |

### Data Files

| File | Purpose |
|------|---------|
| `data/prompts/who_said_prompts.json` | Prompt categories and questions |

---

## Code Structure

### who_said_it.gd - Main Script

```gdscript
extends Control

# Constants
const WRITING_TIME: int = 60
const VOTING_TIME: int = 30
const REVEAL_TIME: int = 5
const MIN_PLAYERS: int = 3

# Game State
enum GamePhase { WAITING, PRE_ROUND, WRITING, VOTING, REVEAL, CONTINUE, ROUND_END, GAME_END }
var current_phase: GamePhase = GamePhase.WAITING
var current_round: int = 0
var total_rounds: int = 3

# Player Management
var player_order: Array = []
var player_scores: Dictionary = {}

# Round Data
var current_prompt: String = ""
var player_answers: Dictionary = {}  # {player_id: "answer text"}
var shuffled_answers: Array = []     # [{author_id, answer_text}, ...]
var current_answer_index: int = 0
var player_votes: Dictionary = {}    # {voter_id: voted_for_id}

# Prompt Data
var prompts: Dictionary = {}
var used_prompts: Array = []

# UI References
@onready var prompt_label: Label = $VBox/PromptSection/PromptLabel
@onready var timer_label: Label = $VBox/Header/TimerLabel
@onready var round_label: Label = $VBox/Header/RoundLabel
@onready var phase_label: Label = $VBox/Header/PhaseLabel

# Writing Phase UI
@onready var writing_section: VBoxContainer = $VBox/WritingSection
@onready var answer_input: TextEdit = $VBox/WritingSection/AnswerInput
@onready var submit_button: Button = $VBox/WritingSection/SubmitButton
@onready var answers_status: Label = $VBox/WritingSection/AnswersStatus

# Voting Phase UI
@onready var voting_section: VBoxContainer = $VBox/VotingSection
@onready var answer_display: Label = $VBox/VotingSection/AnswerDisplay
@onready var your_answer_label: Label = $VBox/VotingSection/YourAnswerLabel
@onready var vote_buttons: GridContainer = $VBox/VotingSection/VoteButtons
@onready var votes_status: Label = $VBox/VotingSection/VotesStatus

# Reveal Phase UI
@onready var reveal_section: VBoxContainer = $VBox/RevealSection
@onready var reveal_answer: Label = $VBox/RevealSection/RevealAnswer
@onready var reveal_author: Label = $VBox/RevealSection/RevealAuthor
@onready var reveal_results: VBoxContainer = $VBox/RevealSection/RevealResults

# Players Display
@onready var players_status: HBoxContainer = $VBox/PlayersStatus

# Timers
@onready var phase_timer: Timer = $PhaseTimer
@onready var tick_timer: Timer = $TickTimer

var time_remaining: int = 0


func _ready() -> void:
    _load_prompts()
    _connect_signals()
    _setup_timers()

    if GameManager.is_host:
        _initialize_game()


func _load_prompts() -> void:
    var file = FileAccess.open("res://data/prompts/who_said_prompts.json", FileAccess.READ)
    if file:
        var json = JSON.parse_string(file.get_as_text())
        if json:
            prompts = json
        file.close()
    else:
        # Fallback prompts
        prompts = {
            "hypothetical": [
                "What would you do with a million dollars?",
                "If you could have dinner with anyone, who would it be?"
            ],
            "personal": [
				"What's your most embarrassing moment?",
				"What's your secret talent?"
            ]
        }


func _connect_signals() -> void:
    NetworkManager.message_received.connect(_on_message_received)
    submit_button.pressed.connect(_on_submit_pressed)


func _setup_timers() -> void:
    phase_timer.one_shot = true
    phase_timer.timeout.connect(_on_phase_timeout)
    tick_timer.timeout.connect(_on_tick)


func _initialize_game() -> void:
    if not GameManager.is_host:
        return

    player_order = GameManager.players.keys()
    player_order.shuffle()

    for player_id in player_order:
        player_scores[player_id] = 0

    NetworkManager.broadcast({
        "type": "whosaid_init",
        "player_order": player_order,
        "total_rounds": total_rounds,
        "scores": player_scores
    })

    _start_round()


func _start_round() -> void:
    current_round += 1
    player_answers.clear()
    shuffled_answers.clear()
    current_answer_index = 0
    player_votes.clear()

    # Pick random prompt
    var categories = prompts.keys()
    var category = categories[randi() % categories.size()]
    var category_prompts = prompts[category]

    # Avoid repeats
    var available = category_prompts.filter(func(p): return p not in used_prompts)
    if available.is_empty():
        used_prompts.clear()
        available = category_prompts

    current_prompt = available[randi() % available.size()]
    used_prompts.append(current_prompt)

    _start_writing_phase()


func _start_writing_phase() -> void:
    current_phase = GamePhase.WRITING

    NetworkManager.broadcast({
        "type": "whosaid_prompt",
        "prompt": current_prompt,
        "round": current_round,
        "time_limit": WRITING_TIME
    })

    _show_writing_ui()
    _start_timer(WRITING_TIME)


func _start_voting_phase() -> void:
    current_phase = GamePhase.VOTING

    # Shuffle answers
    shuffled_answers.clear()
    for player_id in player_answers:
        shuffled_answers.append({
            "author_id": player_id,
            "answer_text": player_answers[player_id]
        })
    shuffled_answers.shuffle()

    current_answer_index = 0
    _show_next_answer_for_voting()


func _show_next_answer_for_voting() -> void:
    if current_answer_index >= shuffled_answers.size():
        _end_round()
        return

    player_votes.clear()
    var answer_data = shuffled_answers[current_answer_index]
    var author_id = answer_data.author_id

    # Build voter list (everyone except author)
    var voters = player_order.filter(func(pid): return pid != author_id)

    NetworkManager.broadcast({
        "type": "whosaid_vote_start",
        "answer_index": current_answer_index,
        "answer_text": answer_data.answer_text,
        "author_id": author_id,
        "voters": voters,
        "time_limit": VOTING_TIME
    })

    _show_voting_ui(answer_data, author_id)
    _start_timer(VOTING_TIME)


func _reveal_answer() -> void:
    current_phase = GamePhase.REVEAL

    var answer_data = shuffled_answers[current_answer_index]
    var author_id = answer_data.author_id
    var author_name = GameManager.players[author_id].name

    # Calculate points
    var correct_guessers: Array = []
    var fooled_players: Array = []
    var points_awarded: Dictionary = {}

    for voter_id in player_votes:
        var voted_for = player_votes[voter_id]
        if voted_for == author_id:
            # Correct guess
            correct_guessers.append(voter_id)
            points_awarded[voter_id] = points_awarded.get(voter_id, 0) + 50
            player_scores[voter_id] = player_scores.get(voter_id, 0) + 50
        else:
            # Wrong guess - author gets points
            fooled_players.append(voter_id)
            points_awarded[author_id] = points_awarded.get(author_id, 0) + 50
            player_scores[author_id] = player_scores.get(author_id, 0) + 50

    NetworkManager.broadcast({
        "type": "whosaid_reveal",
        "answer_index": current_answer_index,
        "answer_text": answer_data.answer_text,
        "author_id": author_id,
        "author_name": author_name,
        "votes": player_votes,
        "correct_guessers": correct_guessers,
        "fooled_players": fooled_players,
        "points_awarded": points_awarded,
        "scores": player_scores
    })

    _show_reveal_ui(answer_data, author_id, correct_guessers, fooled_players, points_awarded)

    # Auto-advance after delay
    await get_tree().create_timer(REVEAL_TIME).timeout

    current_answer_index += 1
    if current_answer_index < shuffled_answers.size():
        _show_next_answer_for_voting()
    else:
        _end_round()


func _end_round() -> void:
    current_phase = GamePhase.ROUND_END

    NetworkManager.broadcast({
        "type": "whosaid_round_end",
        "round": current_round,
        "total_scores": player_scores
    })

    if current_round >= total_rounds:
        _end_game()
    else:
        # Show round summary, then start next round
        await get_tree().create_timer(5.0).timeout
        _start_round()


func _end_game() -> void:
    current_phase = GamePhase.GAME_END

    # Find winner
    var winner_id = ""
    var highest_score = -1
    for player_id in player_scores:
        if player_scores[player_id] > highest_score:
            highest_score = player_scores[player_id]
            winner_id = player_id

    var winner_name = GameManager.players[winner_id].name if winner_id else "Nobody"

    # Update GameManager scores
    for player_id in player_scores:
        GameManager.update_score(player_id, player_scores[player_id])

    NetworkManager.broadcast({
        "type": "whosaid_end",
        "final_scores": player_scores,
        "winner_id": winner_id,
        "winner_name": winner_name
    })

    # Return to game select after delay
    await get_tree().create_timer(5.0).timeout

    if GameManager.is_host:
        get_tree().change_scene_to_file("res://scenes/lobby/game_select.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/lobby/player_waiting.tscn")


# ============ UI METHODS ============

func _show_writing_ui() -> void:
    writing_section.visible = true
    voting_section.visible = false
    reveal_section.visible = false

    prompt_label.text = current_prompt
    answer_input.text = ""
    answer_input.editable = true
    submit_button.disabled = false
    answers_status.text = "0/%d answers received" % player_order.size()
    phase_label.text = "WRITE"


func _show_voting_ui(answer_data: Dictionary, author_id: String) -> void:
    writing_section.visible = false
    voting_section.visible = true
    reveal_section.visible = false

	answer_display.text = '"%s"' % answer_data.answer_text
    phase_label.text = "VOTE"

    var is_author = (author_id == GameManager.local_player_id)

    if is_author:
        your_answer_label.visible = true
        your_answer_label.text = "This is YOUR answer! Wait for votes..."
        vote_buttons.visible = false
    else:
        your_answer_label.visible = false
        vote_buttons.visible = true
        _populate_vote_buttons(author_id)

    votes_status.text = "0/%d votes" % (player_order.size() - 1)


func _populate_vote_buttons(exclude_author: String) -> void:
    # Clear existing buttons
    for child in vote_buttons.get_children():
        child.queue_free()

    # Create button for each player (except author)
    for player_id in player_order:
        if player_id == exclude_author:
            continue
        if player_id == GameManager.local_player_id:
			continue  # Can't vote for yourself

		var player = GameManager.players[player_id]
		var btn = Button.new()
		btn.text = player.name
		btn.custom_minimum_size = Vector2(120, 50)
		btn.pressed.connect(_on_vote_button_pressed.bind(player_id))
		vote_buttons.add_child(btn)


func _show_reveal_ui(answer_data: Dictionary, author_id: String,
					 correct: Array, fooled: Array, points: Dictionary) -> void:
	writing_section.visible = false
	voting_section.visible = false
	reveal_section.visible = true

	var author_name = GameManager.players[author_id].name
	reveal_answer.text = '"%s"' % answer_data.answer_text
	reveal_author.text = "Written by: %s" % author_name
	phase_label.text = "REVEAL"

	# Show results
	for child in reveal_results.get_children():
		child.queue_free()

	for player_id in correct:
		var player_name = GameManager.players[player_id].name
		var lbl = Label.new()
		lbl.text = "✓ %s guessed correctly (+50 pts)" % player_name
		lbl.add_theme_color_override("font_color", Color.GREEN)
		reveal_results.add_child(lbl)

	if fooled.size() > 0:
		var author_name_display = GameManager.players[author_id].name
		var lbl = Label.new()
		lbl.text = "😏 %s fooled %d player(s) (+%d pts)" % [
			author_name_display, fooled.size(), fooled.size() * 50
		]
		lbl.add_theme_color_override("font_color", Color.YELLOW)
		reveal_results.add_child(lbl)


func _update_players_display() -> void:
	for child in players_status.get_children():
		child.queue_free()

	for player_id in player_order:
		var player = GameManager.players[player_id]
		var score = player_scores.get(player_id, 0)

		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(80, 60)

		var color_rect = ColorRect.new()
		color_rect.custom_minimum_size = Vector2(40, 40)
		color_rect.color = GameManager.get_character_data(player.character).color
		container.add_child(color_rect)

		var name_label = Label.new()
		name_label.text = player.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(name_label)

		var score_label = Label.new()
		score_label.text = str(score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(score_label)

		players_status.add_child(container)


# ============ TIMER METHODS ============

func _start_timer(duration: int) -> void:
	time_remaining = duration
	_update_timer_display()
	phase_timer.wait_time = duration
	phase_timer.start()
	tick_timer.start()


func _on_tick() -> void:
	time_remaining -= 1
	_update_timer_display()

	if time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color.RED)
	elif time_remaining <= 20:
		timer_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)


func _update_timer_display() -> void:
	timer_label.text = "%ds" % time_remaining
	round_label.text = "Round %d/%d" % [current_round, total_rounds]


func _on_phase_timeout() -> void:
	tick_timer.stop()

	match current_phase:
		GamePhase.WRITING:
			if GameManager.is_host:
				_start_voting_phase()
		GamePhase.VOTING:
			if GameManager.is_host:
				_reveal_answer()


# ============ INPUT HANDLERS ============

func _on_submit_pressed() -> void:
	var answer = answer_input.text.strip_edges()
	if answer.is_empty():
		return

	submit_button.disabled = true
	answer_input.editable = false

	var data = {
		"type": "whosaid_answer",
		"player_id": GameManager.local_player_id,
		"answer": answer
	}

	if GameManager.is_host:
		_handle_answer(data)
	else:
		NetworkManager.send_to_server(data)


func _on_vote_button_pressed(voted_for_id: String) -> void:
	# Disable all vote buttons
	for child in vote_buttons.get_children():
		if child is Button:
			child.disabled = true

	var data = {
		"type": "whosaid_vote",
		"player_id": GameManager.local_player_id,
		"voted_for": voted_for_id
	}

	if GameManager.is_host:
		_handle_vote(data)
	else:
		NetworkManager.send_to_server(data)


# ============ MESSAGE HANDLING ============

func _on_message_received(_peer_id: int, data: Dictionary) -> void:
	var msg_type = data.get("type", "")

	match msg_type:
		"whosaid_init":
			_apply_init(data)
		"whosaid_prompt":
			_apply_prompt(data)
		"whosaid_answer":
			if GameManager.is_host:
				_handle_answer(data)
		"whosaid_answer_received":
			_apply_answer_status(data)
		"whosaid_vote_start":
			_apply_vote_start(data)
		"whosaid_vote":
			if GameManager.is_host:
				_handle_vote(data)
		"whosaid_vote_received":
			_apply_vote_status(data)
		"whosaid_reveal":
			_apply_reveal(data)
		"whosaid_round_end":
			_apply_round_end(data)
		"whosaid_end":
			_apply_game_end(data)


func _apply_init(data: Dictionary) -> void:
	player_order = data.player_order
	total_rounds = data.total_rounds
	player_scores = data.scores
	_update_players_display()


func _apply_prompt(data: Dictionary) -> void:
	current_prompt = data.prompt
	current_round = data.round
	_show_writing_ui()
	_start_timer(data.time_limit)


func _handle_answer(data: Dictionary) -> void:
	var player_id = data.player_id
	var answer = data.answer

	player_answers[player_id] = answer

	NetworkManager.broadcast({
		"type": "whosaid_answer_received",
		"player_id": player_id,
		"answers_received": player_answers.size(),
		"answers_needed": player_order.size()
	})

	# Check if all answers received
	if player_answers.size() >= player_order.size():
		phase_timer.stop()
		tick_timer.stop()
		_start_voting_phase()


func _apply_answer_status(data: Dictionary) -> void:
	answers_status.text = "%d/%d answers received" % [
		data.answers_received, data.answers_needed
	]


func _apply_vote_start(data: Dictionary) -> void:
	current_answer_index = data.answer_index
	var author_id = data.author_id
	var answer_data = {"answer_text": data.answer_text, "author_id": author_id}
	_show_voting_ui(answer_data, author_id)
	_start_timer(data.time_limit)


func _handle_vote(data: Dictionary) -> void:
	var voter_id = data.player_id
	var voted_for = data.voted_for

	player_votes[voter_id] = voted_for

	var voters_needed = player_order.size() - 1  # Exclude author

	NetworkManager.broadcast({
		"type": "whosaid_vote_received",
		"votes_received": player_votes.size(),
		"votes_needed": voters_needed
	})

	# Check if all votes received
	if player_votes.size() >= voters_needed:
		phase_timer.stop()
		tick_timer.stop()
		_reveal_answer()


func _apply_vote_status(data: Dictionary) -> void:
	votes_status.text = "%d/%d votes" % [data.votes_received, data.votes_needed]


func _apply_reveal(data: Dictionary) -> void:
	var answer_data = {"answer_text": data.answer_text}
	_show_reveal_ui(
		answer_data,
		data.author_id,
		data.correct_guessers,
		data.fooled_players,
		data.points_awarded
	)
	player_scores = data.scores
	_update_players_display()


func _apply_round_end(data: Dictionary) -> void:
	player_scores = data.total_scores
	_update_players_display()


func _apply_game_end(data: Dictionary) -> void:
	player_scores = data.final_scores
	_update_players_display()
	# Scene transition handled by host broadcast timing
```

---

## UI/Scene Layout

### Scene Tree Structure

```
who_said_it (Control)
├── Background (ColorRect)
│   └── color: #1a1a2e
└── VBox (VBoxContainer)
	├── Header (HBoxContainer)
	│   ├── GameTitle (Label) - "Who Said It?"
	│   ├── Spacer (Control) - size_flags_horizontal: EXPAND
	│   ├── PhaseLabel (Label) - "WRITE" / "VOTE" / "REVEAL"
	│   ├── RoundLabel (Label) - "Round 1/3"
	│   └── TimerLabel (Label) - "45s"
	│
	├── PromptSection (PanelContainer)
	│   └── PromptLabel (Label) - The question/prompt
	│
	├── WritingSection (VBoxContainer) - visible during writing phase
	│   ├── InstructionLabel (Label) - "Type your answer (keep it secret!)"
	│   ├── AnswerInput (TextEdit) - multiline text input
	│   ├── SubmitButton (Button) - "Submit Answer"
	│   └── AnswersStatus (Label) - "2/4 answers received"
	│
	├── VotingSection (VBoxContainer) - visible during voting phase
	│   ├── AnswerDisplay (Label) - Shows the anonymous answer
	│   ├── YourAnswerLabel (Label) - "This is YOUR answer!" (only for author)
	│   ├── VotePrompt (Label) - "Who wrote this?"
	│   ├── VoteButtons (GridContainer) - Player name buttons
	│   └── VotesStatus (Label) - "2/3 votes"
	│
	├── RevealSection (VBoxContainer) - visible during reveal
	│   ├── RevealAnswer (Label) - The answer text
	│   ├── RevealAuthor (Label) - "Written by: Carol"
	│   └── RevealResults (VBoxContainer) - Dynamic result labels
	│
	├── PlayersStatus (HBoxContainer) - Always visible scoreboard
	│
	├── PhaseTimer (Timer) - one_shot: true
	└── TickTimer (Timer) - wait_time: 1.0
```

### Visual Layout Mockup

```
┌────────────────────────────────────────────────────────┐
│  WHO SAID IT?            WRITE    Round 1/3    ⏱️ 45s  │
├────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐  │
│  │  "What would you bring to a deserted island?"   │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│  Type your answer (keep it secret!):                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │                                                  │  │
│  │                                                  │  │
│  └──────────────────────────────────────────────────┘  │
│                                                        │
│              [ Submit Answer ]                         │
│                                                        │
│           2/4 answers received                         │
│                                                        │
├────────────────────────────────────────────────────────┤
│  [Alice]    [Bob]     [Carol]    [Dave]               │
│    100       75        150        50                   │
└────────────────────────────────────────────────────────┘
```

---

## Assets Needed

### UI Icons (from PixelLab or custom)

| Asset | Size | Description | Priority |
|-------|------|-------------|----------|
| `icon_whosaid.png` | 64x64 | Game selection icon (speech bubble with "?") | High |
| `icon_pencil.png` | 32x32 | Writing phase indicator | Medium |
| `icon_vote.png` | 32x32 | Voting phase indicator (ballot box) | Medium |
| `icon_reveal.png` | 32x32 | Reveal phase indicator (eye) | Medium |

### Audio (if implementing sound)

| Asset | Description | Priority |
|-------|-------------|----------|
| `sfx_submit.wav` | Answer submitted sound | Low |
| `sfx_vote.wav` | Vote cast sound | Low |
| `sfx_reveal.wav` | Dramatic reveal sound | Low |
| `sfx_correct.wav` | Correct guess | Low |
| `sfx_fooled.wav` | Fooled someone | Low |

### Existing Assets to Reuse

- Character avatars (already in `assets/characters/`)
- Character colors (from `GameManager.get_character_data()`)
- Timer styling (from existing games)
- Background colors (from existing games)

---

## Data File Structure

### `data/prompts/who_said_prompts.json`

```json
{
	"hypothetical": [
		"What would you do with a million dollars?",
		"If you could have any superpower, what would it be?",
		"What would you do if you were invisible for a day?",
		"If you could live anywhere in the world, where would it be?",
		"What would you do if you found a time machine?",
		"If you could only eat one food for the rest of your life, what would it be?",
		"What would you do if you won the lottery tomorrow?",
		"If you could meet any historical figure, who would it be?",
		"What would you do if you could fly?",
        "If you had to survive a zombie apocalypse, what's your strategy?"
	],
	"personal": [
		"What's your most embarrassing moment?",
		"What's your secret talent that nobody knows about?",
		"What's the weirdest thing you've ever eaten?",
		"What's your guilty pleasure?",
		"What's something you're afraid of that most people aren't?",
		"What's the most adventurous thing you've ever done?",
		"What's a habit you wish you could break?",
		"What's your unpopular opinion?",
		"What's the best compliment you've ever received?",
        "What's something on your bucket list?"
	],
	"opinions": [
		"What's the best movie of all time?",
		"Pineapple on pizza: yes or no, and why?",
		"What's the most overrated thing?",
		"What's an underrated life skill everyone should learn?",
		"What's the best way to spend a rainy day?",
		"What's the worst fashion trend ever?",
		"What's the best decade for music?",
		"What makes someone a good friend?",
		"What's the most important quality in a partner?",
        "What's the best age to be?"
	],
	"creative": [
		"Describe your perfect day in 3 sentences.",
		"Write a haiku about your morning routine.",
		"What would be the title of your autobiography?",
		"Describe your personality using only food items.",
		"What would your superhero name be?",
		"Create a new holiday and explain how it's celebrated.",
		"What would be your campaign slogan if you ran for president?",
		"Describe your ideal vacation using only emojis and one sentence.",
		"What would you name your pet dragon?",
        "Write a fortune cookie message for your future self."
	],
	"wouldyourather": [
		"Would you rather be able to talk to animals or speak every human language?",
		"Would you rather have unlimited money or unlimited time?",
		"Would you rather be famous or powerful?",
		"Would you rather live in the past or the future?",
        "Would you rather be the funniest or smartest person in the room?"
	]
}
```

---

## Implementation Steps

### Step 1: Create Data File (15 min)

1. Create `data/prompts/who_said_prompts.json`
2. Populate with 50+ prompts across categories
3. Test JSON validity

### Step 2: Create Game Script (2-3 hours)

1. Create `scripts/games/who_said_it.gd`
2. Implement core structure:
   - Constants and enums
   - State variables
   - UI references
3. Implement game flow:
   - `_initialize_game()`
   - `_start_round()`
   - `_start_writing_phase()`
   - `_start_voting_phase()`
   - `_reveal_answer()`
   - `_end_round()`
   - `_end_game()`
4. Implement UI methods:
   - `_show_writing_ui()`
   - `_show_voting_ui()`
   - `_show_reveal_ui()`
   - `_update_players_display()`
5. Implement message handlers:
   - All `_apply_*()` methods
   - All `_handle_*()` methods for host
6. Implement input handlers:
   - `_on_submit_pressed()`
   - `_on_vote_button_pressed()`
7. Implement timers

### Step 3: Create Scene (1 hour)

1. Create `scenes/games/who_said_it/who_said_it.tscn`
2. Build scene tree per layout above
3. Configure:
   - Background color
   - Font sizes
   - Button styles
   - Panel containers
4. Attach script
5. Set up @onready references

### Step 4: Create Web Player Interface (1-2 hours)

1. Create `web-player/js/games/whosaidit.js`
2. Implement:
   - `WhoSaidItGame` class
   - Socket handlers for all message types
   - UI rendering for each phase
   - Answer submission
   - Vote button generation and handling
3. Register in `web-player/js/app.js`

### Step 5: Integration (30 min)

1. Add game to `game_select.tscn`:
   - Add "Who Said It?" card
   - Connect button to launch scene
2. Update `GameManager` if needed
3. Test host → game transition

### Step 6: Testing (1 hour)

1. Test with 3+ players (mix of Godot and web)
2. Test edge cases:
   - Player disconnection during writing
   - Timer expiration with missing answers
   - All correct guesses
   - All wrong guesses
3. Test scoring accuracy

### Step 7: Polish (30 min)

1. Add animations for reveals
2. Tune timing values
3. Add visual feedback for submissions
4. Test and adjust UI for different screen sizes

---

## Integration Checklist

### Files to Create
- [x] `data/prompts/who_said_prompts.json`
- [x] `scripts/games/who_said_it.gd`
- [x] `scenes/games/who_said_it/who_said_it.tscn`
- [x] `web-player/js/games/whosaidit.js`

### Files to Modify
- [x] `scripts/lobby/game_select.gd` - Game already listed
- [x] `web-player/js/app.js` - Register whosaidit.js
- [x] `web-player/index.html` - Add game screens
- [x] `web-player/css/style.css` - Add game styles

### Testing Checklist
- [x] Game initializes correctly with 3+ players
- [x] All players receive prompts
- [x] Answer submission works
- [x] Host sees answer count update
- [x] Voting phase shows correct options (can vote for any player except self)
- [x] Author sees "your answer" indicator
- [x] Votes are recorded correctly
- [x] Reveal shows correct author
- [x] Points calculated correctly
- [x] Scores update and sync
- [x] Round transitions work
- [x] Game end returns to lobby
- [x] Web player works identically
- [x] Ready-up system before rounds and after reveals
- [x] Player avatars show checkmark when ready

### Update PLAN.md
- [x] Mark "Who Said It?" as complete in Phase 3
- [x] Add to Completed Items list
- [x] Update last modified date

---

## Notes & Considerations

### Edge Cases to Handle

1. **Player disconnects during writing** - Use their last submitted answer or skip
2. **No answer submitted** - Auto-submit empty or placeholder
3. **Tie scores** - Both players win (multiple winners)
4. **2 players only** - Game requires minimum 3 (enforce in game_select)

### Future Enhancements

- Like/favorite answers feature
- "Best answer" bonus voting
- Custom prompt submission by players
- Themed prompt packs (holiday, movies, etc.)
- Answer character limit
- Anonymous mode where even author doesn't know it's theirs

---

*Last Updated: 2026-01-22 (Implemented with ready-up system)*
