/**
 * Main application controller for Party Games web player
 */
class PartyGameApp {
    constructor() {
        this.currentScreen = 'connect';
        this.playerId = null;
        this.playerName = '';
        this.characterId = 0;
        this.players = {};
        this.currentGame = null;

        // Character data (must match Godot's GameManager.CHARACTERS)
        this.characters = [
            { id: 0, name: 'Red Knight', color: '#ff0000' },
            { id: 1, name: 'Blue Wizard', color: '#0000ff' },
            { id: 2, name: 'Green Ranger', color: '#00ff00' },
            { id: 3, name: 'Yellow Bard', color: '#ffff00' },
            { id: 4, name: 'Purple Rogue', color: '#800080' },
            { id: 5, name: 'Orange Monk', color: '#ffa500' },
            { id: 6, name: 'Pink Princess', color: '#ffc0cb' },
            { id: 7, name: 'Teal Robot', color: '#008080' }
        ];

        this.takenCharacters = [];
        this.selectedCharacter = null;

        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupSocketHandlers();
        this.tryAutoConnect();
    }

    /**
     * Set up DOM event listeners
     */
    setupEventListeners() {
        // Connect screen
        document.getElementById('btn-connect')?.addEventListener('click', () => {
            const ip = document.getElementById('host-ip').value.trim();
            const port = parseInt(document.getElementById('host-port').value) || 8080;
            if (ip) {
                gameSocket.connect(ip, port);
            }
        });

        // Join screen
        document.getElementById('player-name')?.addEventListener('input', (e) => {
            this.playerName = e.target.value.trim();
            this.updateJoinButton();
        });

        document.getElementById('btn-join')?.addEventListener('click', () => {
            if (this.playerName && this.selectedCharacter !== null) {
                gameSocket.requestJoin(this.playerName, this.selectedCharacter);
            }
        });

        // Reconnect button
        document.getElementById('btn-reconnect')?.addEventListener('click', () => {
            gameSocket.reconnectAttempts = 0;
            gameSocket.connect();
        });
    }

    /**
     * Set up WebSocket message handlers
     */
    setupSocketHandlers() {
        gameSocket.on('connected', () => {
            document.getElementById('connection-status').textContent = 'Connected! Enter your name to join.';
            this.showScreen('join');
            this.populateCharacterGrid();
        });

        gameSocket.on('disconnected', () => {
            this.showScreen('disconnected');
        });

        gameSocket.on('error', (data) => {
            document.getElementById('connection-status').textContent = data.message || 'Connection failed';
            document.getElementById('manual-connect').classList.remove('hidden');
        });

        gameSocket.on('join_accepted', (data) => {
            this.playerId = data.player_id;
            this.players = data.players || {};
            this.showScreen('waiting');
            this.updateWaitingScreen();
        });

        gameSocket.on('player_joined', (data) => {
            this.players[data.player_id] = {
                name: data.name,
                character: data.character
            };
            this.updatePlayersList();
            // Mark character as taken
            if (!this.takenCharacters.includes(data.character)) {
                this.takenCharacters.push(data.character);
                this.updateCharacterGrid();
            }
        });

        gameSocket.on('player_left', (data) => {
            if (this.players[data.player_id]) {
                const char = this.players[data.player_id].character;
                delete this.players[data.player_id];
                // Unmark character
                const idx = this.takenCharacters.indexOf(char);
                if (idx !== -1) this.takenCharacters.splice(idx, 1);
                this.updatePlayersList();
                this.updateCharacterGrid();
            }
        });

        gameSocket.on('game_starting', (data) => {
            this.currentGame = data.game;
            this.startGame(data.game);
        });

        gameSocket.on('host_left', () => {
            this.showScreen('disconnected');
        });
    }

    /**
     * Try to auto-connect using URL parameters
     */
    tryAutoConnect() {
        if (gameSocket.parseURLParams()) {
            document.getElementById('connection-status').textContent = 'Connecting to host...';
            gameSocket.connect();
        } else {
            document.getElementById('connection-status').textContent = 'Enter host details to connect';
            document.getElementById('manual-connect').classList.remove('hidden');
        }
    }

    /**
     * Show a specific screen
     */
    showScreen(screenId) {
        document.querySelectorAll('.screen').forEach(screen => {
            screen.classList.remove('active');
        });
        const screen = document.getElementById(`screen-${screenId}`);
        if (screen) {
            screen.classList.add('active');
            this.currentScreen = screenId;
        }
    }

    /**
     * Populate the character selection grid
     */
    populateCharacterGrid() {
        const grid = document.getElementById('character-grid');
        if (!grid) return;

        grid.innerHTML = '';

        this.characters.forEach(char => {
            const div = document.createElement('div');
            div.className = 'character-option';
            div.style.backgroundColor = char.color;
            div.dataset.id = char.id;
            div.title = char.name;

            if (this.takenCharacters.includes(char.id)) {
                div.classList.add('taken');
            }

            div.addEventListener('click', () => {
                if (!this.takenCharacters.includes(char.id)) {
                    this.selectCharacter(char.id);
                }
            });

            grid.appendChild(div);
        });
    }

    /**
     * Update character grid to show taken characters
     */
    updateCharacterGrid() {
        document.querySelectorAll('.character-option').forEach(div => {
            const id = parseInt(div.dataset.id);
            if (this.takenCharacters.includes(id)) {
                div.classList.add('taken');
            } else {
                div.classList.remove('taken');
            }
        });
    }

    /**
     * Select a character
     */
    selectCharacter(id) {
        this.selectedCharacter = id;
        this.characterId = id;

        document.querySelectorAll('.character-option').forEach(div => {
            div.classList.remove('selected');
            if (parseInt(div.dataset.id) === id) {
                div.classList.add('selected');
            }
        });

        this.updateJoinButton();
    }

    /**
     * Update join button state
     */
    updateJoinButton() {
        const btn = document.getElementById('btn-join');
        if (btn) {
            btn.disabled = !(this.playerName && this.selectedCharacter !== null);
        }
    }

    /**
     * Update the waiting screen with player info
     */
    updateWaitingScreen() {
        document.getElementById('display-name').textContent = this.playerName;

        const preview = document.getElementById('display-character');
        if (preview && this.characters[this.characterId]) {
            preview.style.backgroundColor = this.characters[this.characterId].color;
        }

        this.updatePlayersList();
    }

    /**
     * Update the players list display
     */
    updatePlayersList() {
        const list = document.getElementById('players-list');
        if (!list) return;

        list.innerHTML = '';

        Object.entries(this.players).forEach(([id, player]) => {
            const chip = document.createElement('div');
            chip.className = 'player-chip';

            const dot = document.createElement('span');
            dot.className = 'dot';
            dot.style.backgroundColor = this.characters[player.character]?.color || '#888';

            const name = document.createElement('span');
            name.textContent = player.name;

            chip.appendChild(dot);
            chip.appendChild(name);
            list.appendChild(chip);
        });
    }

    /**
     * Start a specific game
     */
    startGame(gameId) {
        console.log('Starting game:', gameId);

        switch (gameId) {
            case 'charades':
                this.showScreen('charades');
                if (window.charadesGame) {
                    charadesGame.init(this);
                }
                break;

            case 'word_bomb':
                this.showScreen('word-bomb');
                if (window.wordBombGame) {
                    wordBombGame.init(this);
                }
                break;

            case 'quick_draw':
                this.showScreen('quick-draw');
                if (window.quickDrawGame) {
                    quickDrawGame.init(this);
                }
                break;

            case 'who_said_it':
                this.showScreen('who-said-it');
                if (window.whoSaidItGame) {
                    whoSaidItGame.init(this);
                }
                break;

            case 'fibbage':
                this.showScreen('fibbage');
                if (window.fibbageGame) {
                    fibbageGame.init(this);
                }
                break;

            default:
                console.warn('Unknown game:', gameId);
        }
    }

    /**
     * Return to waiting screen (called when game ends)
     */
    returnToLobby() {
        this.currentGame = null;
        this.showScreen('waiting');
    }

    /**
     * Get player name by ID
     */
    getPlayerName(playerId) {
        return this.players[playerId]?.name || 'Unknown';
    }

    /**
     * Get character color by ID
     */
    getCharacterColor(characterId) {
        return this.characters[characterId]?.color || '#888888';
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.app = new PartyGameApp();
});
