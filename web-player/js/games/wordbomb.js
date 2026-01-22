/**
 * Word Bomb game handler for web player
 */
class WordBombGame {
    constructor() {
        this.app = null;
        this.lives = 3;
        this.currentLetters = '';
        this.timeRemaining = 10;
        this.timerInterval = null;
        this.isMyTurn = false;
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
    }

    setupEventListeners() {
        document.getElementById('btn-submit-word')?.addEventListener('click', () => {
            this.submitWord();
        });

        document.getElementById('wordbomb-input')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.submitWord();
            }
        });
    }

    setupSocketHandlers() {
        gameSocket.on('word_bomb_init', (data) => {
            this.handleInit(data);
        });

        gameSocket.on('word_bomb_turn', (data) => {
            this.handleTurn(data);
        });

        gameSocket.on('word_bomb_result', (data) => {
            this.handleResult(data);
        });

        gameSocket.on('word_bomb_timeout', (data) => {
            this.handleTimeout(data);
        });

        gameSocket.on('word_bomb_eliminated', (data) => {
            this.handleEliminated(data);
        });

        gameSocket.on('word_bomb_end', (data) => {
            this.handleGameEnd(data);
        });
    }

    handleInit(data) {
        this.lives = data.lives || 3;
        this.updateLivesDisplay();
    }

    handleTurn(data) {
        this.currentLetters = data.letters;
        this.timeRemaining = data.time || 10;
        this.isMyTurn = (data.player_id === this.app.playerId);

        document.getElementById('wordbomb-letters').textContent = this.currentLetters;

        const input = document.getElementById('wordbomb-input');
        const btn = document.getElementById('btn-submit-word');

        if (this.isMyTurn) {
            input.disabled = false;
            input.value = '';
            input.focus();
            btn.disabled = false;
            this.setFeedback('Your turn! Type a word containing: ' + this.currentLetters, '');
            this.startTimer();
        } else {
            input.disabled = true;
            btn.disabled = true;
            this.stopTimer();
            const playerName = this.app.getPlayerName(data.player_id);
            this.setFeedback(`${playerName}'s turn...`, '');
        }

        this.updateTimerDisplay();
    }

    handleResult(data) {
        if (data.valid) {
            this.setFeedback(`"${data.word}" is valid!`, 'success');
        } else {
            this.setFeedback(`"${data.word}" doesn't work!`, 'error');
        }
    }

    handleTimeout(data) {
        this.stopTimer();

        if (data.player_id === this.app.playerId) {
            this.lives = data.lives_remaining;
            this.updateLivesDisplay();
            this.setFeedback('Time\'s up! You lost a life.', 'error');
        } else {
            const playerName = this.app.getPlayerName(data.player_id);
            this.setFeedback(`${playerName} ran out of time!`, '');
        }
    }

    handleEliminated(data) {
        const playerName = this.app.getPlayerName(data.player_id);

        if (data.player_id === this.app.playerId) {
            this.setFeedback('You\'ve been eliminated!', 'error');
            document.getElementById('wordbomb-input').disabled = true;
            document.getElementById('btn-submit-word').disabled = true;
        } else {
            this.setFeedback(`${playerName} has been eliminated!`, '');
        }
    }

    handleGameEnd(data) {
        this.stopTimer();
        this.app.showScreen('game-over');

        const winnerDisplay = document.getElementById('winner-display');
        winnerDisplay.innerHTML = `
            <h2>Winner</h2>
            <div class="name">${data.winner_name}</div>
        `;

        const scoresDisplay = document.getElementById('final-scores');
        scoresDisplay.innerHTML = '';

        if (data.final_scores) {
            const sortedScores = Object.entries(data.final_scores)
                .sort((a, b) => b[1] - a[1]);

            sortedScores.forEach(([playerId, score]) => {
                const row = document.createElement('div');
                row.className = 'score-row';
                row.innerHTML = `
                    <span>${this.app.getPlayerName(playerId)}</span>
                    <span>${score}</span>
                `;
                scoresDisplay.appendChild(row);
            });
        }

        setTimeout(() => {
            this.app.returnToLobby();
        }, 5000);
    }

    submitWord() {
        if (!this.isMyTurn) return;

        const input = document.getElementById('wordbomb-input');
        const word = input.value.trim().toLowerCase();

        if (word) {
            gameSocket.send({
                type: 'word_bomb_submit',
                word: word
            });
            input.value = '';
        }
    }

    updateLivesDisplay() {
        const livesContainer = document.getElementById('wordbomb-lives');
        if (!livesContainer) return;

        livesContainer.innerHTML = '';
        for (let i = 0; i < 3; i++) {
            const life = document.createElement('span');
            life.className = 'life';
            life.textContent = '❤️';
            if (i >= this.lives) {
                life.classList.add('lost');
            }
            livesContainer.appendChild(life);
        }
    }

    setFeedback(message, type) {
        const feedback = document.getElementById('wordbomb-feedback');
        if (feedback) {
            feedback.textContent = message;
            feedback.className = 'feedback';
            if (type) {
                feedback.classList.add(type);
            }
        }
    }

    startTimer() {
        this.stopTimer();
        this.timerInterval = setInterval(() => {
            this.timeRemaining--;
            this.updateTimerDisplay();

            if (this.timeRemaining <= 0) {
                this.stopTimer();
            }
        }, 1000);
    }

    stopTimer() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    updateTimerDisplay() {
        const timer = document.getElementById('wordbomb-timer');
        if (timer) {
            timer.textContent = this.timeRemaining;
            timer.classList.toggle('warning', this.timeRemaining <= 3);
        }
    }
}

// Global instance
window.wordBombGame = new WordBombGame();
