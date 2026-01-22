/**
 * Charades game handler for web player
 */
class CharadesGame {
    constructor() {
        this.app = null;
        this.isActor = false;
        this.actorId = null;
        this.timeRemaining = 60;
        this.timerInterval = null;
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
    }

    setupEventListeners() {
        document.getElementById('btn-start-turn')?.addEventListener('click', () => {
            gameSocket.send({ type: 'charades_start_turn' });
        });

        document.getElementById('btn-skip')?.addEventListener('click', () => {
            gameSocket.send({ type: 'charades_skip' });
        });

        document.getElementById('btn-guess')?.addEventListener('click', () => {
            this.submitGuess();
        });

        document.getElementById('charades-guess')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.submitGuess();
            }
        });
    }

    setupSocketHandlers() {
        gameSocket.on('charades_init', (data) => {
            // Game initialized, wait for first turn
        });

        gameSocket.on('charades_prepare', (data) => {
            this.handlePrepare(data);
        });

        gameSocket.on('charades_turn', (data) => {
            this.handleTurn(data);
        });

        gameSocket.on('charades_wrong', (data) => {
            this.handleWrongGuess(data);
        });

        gameSocket.on('charades_result', (data) => {
            this.handleResult(data);
        });

        gameSocket.on('charades_skipped', (data) => {
            this.handleSkipped(data);
        });

        gameSocket.on('charades_timeout', (data) => {
            this.handleTimeout(data);
        });

        gameSocket.on('charades_end', (data) => {
            this.handleGameEnd(data);
        });
    }

    handlePrepare(data) {
        this.actorId = data.actor_id;
        this.isActor = (data.actor_id === this.app.playerId);
        this.timeRemaining = 60;

        this.updateTimerDisplay();
        this.stopTimer();

        // Hide all views first
        this.hideAllViews();

        if (this.isActor) {
            // Show actor prepare view
            document.getElementById('charades-actor-view').classList.remove('hidden');
            document.getElementById('charades-prompt').textContent = 'Get Ready!';
            document.getElementById('btn-start-turn').classList.remove('hidden');
            document.getElementById('btn-skip').classList.add('hidden');
        } else {
            // Show waiting message
            document.getElementById('charades-guesser-view').classList.remove('hidden');
            document.getElementById('charades-actor-name').textContent = this.app.getPlayerName(data.actor_id);
            document.getElementById('charades-guess').disabled = true;
            document.getElementById('btn-guess').disabled = true;
        }
    }

    handleTurn(data) {
        this.actorId = data.actor_id;
        this.isActor = (data.actor_id === this.app.playerId);
        this.timeRemaining = data.time || 60;

        this.hideAllViews();

        if (this.isActor) {
            // Show prompt to actor
            document.getElementById('charades-actor-view').classList.remove('hidden');
            document.getElementById('charades-prompt').textContent = data.prompt;
            document.getElementById('btn-start-turn').classList.add('hidden');
            document.getElementById('btn-skip').classList.remove('hidden');
        } else {
            // Show guess interface
            document.getElementById('charades-guesser-view').classList.remove('hidden');
            document.getElementById('charades-actor-name').textContent = this.app.getPlayerName(data.actor_id);
            document.getElementById('charades-guess').disabled = false;
            document.getElementById('charades-guess').value = '';
            document.getElementById('charades-guess').focus();
            document.getElementById('btn-guess').disabled = false;
        }

        this.startTimer();
    }

    handleWrongGuess(data) {
        // Could show a brief feedback that someone guessed wrong
        console.log(`${data.player_name} guessed: ${data.guess}`);
    }

    handleResult(data) {
        this.stopTimer();
        this.hideAllViews();

        const resultView = document.getElementById('charades-result-view');
        const resultCard = document.getElementById('charades-result');
        resultView.classList.remove('hidden');

        if (data.correct) {
            const guesserName = this.app.getPlayerName(data.guesser_id);
            const actorName = this.app.getPlayerName(data.actor_id);
            resultCard.innerHTML = `
                <h2>Correct!</h2>
                <div class="answer">${data.prompt}</div>
                <p>${guesserName} guessed it! (+100 pts)</p>
                <p>${actorName} acted it! (+50 pts)</p>
            `;
        }
    }

    handleSkipped(data) {
        this.stopTimer();
        this.hideAllViews();

        const resultView = document.getElementById('charades-result-view');
        const resultCard = document.getElementById('charades-result');
        resultView.classList.remove('hidden');

        resultCard.innerHTML = `
            <h2>Skipped!</h2>
            <div class="answer">${data.prompt}</div>
            <p>No points awarded.</p>
        `;
    }

    handleTimeout(data) {
        this.stopTimer();
        this.hideAllViews();

        const resultView = document.getElementById('charades-result-view');
        const resultCard = document.getElementById('charades-result');
        resultView.classList.remove('hidden');

        resultCard.innerHTML = `
            <h2>Time's Up!</h2>
            <div class="answer">${data.prompt}</div>
            <p>Nobody guessed it in time.</p>
        `;
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

        // Sort by score
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

        // Return to lobby after delay
        setTimeout(() => {
            this.app.returnToLobby();
        }, 5000);
    }

    submitGuess() {
        const input = document.getElementById('charades-guess');
        const guess = input.value.trim();

        if (guess) {
            gameSocket.send({
                type: 'charades_guess',
                guess: guess
            });
            input.value = '';
        }
    }

    hideAllViews() {
        document.getElementById('charades-actor-view')?.classList.add('hidden');
        document.getElementById('charades-guesser-view')?.classList.add('hidden');
        document.getElementById('charades-result-view')?.classList.add('hidden');
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
        const timer = document.getElementById('charades-timer');
        if (timer) {
            timer.textContent = this.timeRemaining;
            timer.classList.toggle('warning', this.timeRemaining <= 10);
        }
    }
}

// Global instance
window.charadesGame = new CharadesGame();
