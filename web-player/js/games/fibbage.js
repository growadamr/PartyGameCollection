/**
 * Fibbage game handler for web player
 */
class FibbageGame {
    constructor() {
        this.app = null;
        this.timeRemaining = 60;
        this.timerInterval = null;
        this.currentPhase = 'waiting';
        this.hasSubmittedAnswer = false;
        this.hasVoted = false;
        this.isReady = false;
        this.playersReady = {};
        this.answers = [];
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
    }

    setupEventListeners() {
        document.getElementById('btn-submit-lie')?.addEventListener('click', () => {
            this.submitAnswer();
        });

        document.getElementById('fibbage-answer')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.submitAnswer();
            }
        });

        document.getElementById('btn-fibbage-ready')?.addEventListener('click', () => {
            this.submitReady();
        });
    }

    setupSocketHandlers() {
        gameSocket.on('fibbage_init', (data) => {
            this.playersReady = {};
            (data.player_order || []).forEach(pid => {
                this.playersReady[pid] = false;
            });
        });

        gameSocket.on('fibbage_pre_round', (data) => {
            this.handlePreRound(data);
        });

        gameSocket.on('fibbage_ready_status', (data) => {
            this.handleReadyStatus(data);
        });

        gameSocket.on('fibbage_question', (data) => {
            this.handleQuestion(data);
        });

        gameSocket.on('fibbage_answer_received', (data) => {
            this.handleAnswerReceived(data);
        });

        gameSocket.on('fibbage_vote_start', (data) => {
            this.handleVoteStart(data);
        });

        gameSocket.on('fibbage_vote_received', (data) => {
            this.handleVoteReceived(data);
        });

        gameSocket.on('fibbage_reveal', (data) => {
            this.handleReveal(data);
        });

        gameSocket.on('fibbage_round_end', (data) => {
            this.handleRoundEnd(data);
        });

        gameSocket.on('fibbage_end', (data) => {
            this.handleGameEnd(data);
        });
    }

    handlePreRound(data) {
        this.currentPhase = 'pre_round';
        this.isReady = false;

        const readyList = data.ready_players || [];
        Object.keys(this.playersReady).forEach(pid => {
            this.playersReady[pid] = readyList.includes(pid);
        });

        this.hideAllViews();
        document.getElementById('fibbage-ready-view').classList.remove('hidden');

        const nextRound = data.round || 1;
        const title = nextRound === 1 ? 'Ready to Lie?' : `Round ${nextRound}`;
        document.getElementById('fibbage-ready-title').textContent = title;
        document.getElementById('btn-fibbage-ready').textContent = 'Ready!';
        document.getElementById('btn-fibbage-ready').disabled = false;
        document.getElementById('fibbage-ready-status').textContent = `${readyList.length}/${Object.keys(this.playersReady).length} ready`;

        this.updatePlayerReadyIndicators();
    }

    handleReadyStatus(data) {
        const readyList = data.ready_players || [];
        const readyCount = data.ready_count || 0;
        const needed = data.players_needed || Object.keys(this.playersReady).length;

        Object.keys(this.playersReady).forEach(pid => {
            this.playersReady[pid] = readyList.includes(pid);
        });

        document.getElementById('fibbage-ready-status').textContent = `${readyCount}/${needed} ready`;
        this.updatePlayerReadyIndicators();
    }

    handleQuestion(data) {
        this.currentPhase = 'writing';
        this.hasSubmittedAnswer = false;
        this.timeRemaining = data.time_limit || 60;

        this.hideAllViews();
        document.getElementById('fibbage-writing-view').classList.remove('hidden');

        document.getElementById('fibbage-question').textContent = data.question;
        document.getElementById('fibbage-answer').value = '';
        document.getElementById('fibbage-answer').disabled = false;
        document.getElementById('btn-submit-lie').disabled = false;
        document.getElementById('fibbage-answers-status').textContent = '0 lies submitted';

        this.startTimer();
    }

    handleAnswerReceived(data) {
        document.getElementById('fibbage-answers-status').textContent =
            `${data.answers_received}/${data.answers_needed} lies submitted`;
    }

    handleVoteStart(data) {
        this.currentPhase = 'voting';
        this.hasVoted = false;
        this.answers = data.answers || [];
        this.timeRemaining = data.time_limit || 30;

        this.hideAllViews();
        document.getElementById('fibbage-voting-view').classList.remove('hidden');

        document.getElementById('fibbage-vote-question').textContent = data.question;
        this.populateVoteButtons();

        document.getElementById('fibbage-votes-status').textContent = '0 votes';
        this.startTimer();
    }

    populateVoteButtons() {
        const container = document.getElementById('fibbage-vote-buttons');
        container.innerHTML = '';

        this.answers.forEach((answer) => {
            const btn = document.createElement('button');
            btn.className = 'btn-vote-answer';
            btn.textContent = answer.text;
            btn.addEventListener('click', () => this.submitVote(answer.id));
            container.appendChild(btn);
        });
    }

    handleVoteReceived(data) {
        document.getElementById('fibbage-votes-status').textContent =
            `${data.votes_received}/${data.votes_needed} votes`;
    }

    handleReveal(data) {
        this.currentPhase = 'reveal';
        this.stopTimer();

        this.hideAllViews();
        document.getElementById('fibbage-reveal-view').classList.remove('hidden');

        document.getElementById('fibbage-reveal-answer').textContent = `The truth: "${data.real_answer}"`;

        const resultsContainer = document.getElementById('fibbage-reveal-results');
        resultsContainer.innerHTML = '';

        // Show correct guessers
        if (data.correct_guessers && data.correct_guessers.length > 0) {
            data.correct_guessers.forEach(playerId => {
                const playerName = this.app.getPlayerName(playerId);
                const div = document.createElement('div');
                div.className = 'result-correct';
                div.textContent = `${playerName} found the truth! (+200 pts)`;
                resultsContainer.appendChild(div);
            });
        } else {
            const div = document.createElement('div');
            div.className = 'result-wrong';
            div.textContent = 'Nobody found the truth!';
            resultsContainer.appendChild(div);
        }

        // Show who fooled whom
        if (data.fooled_by) {
            Object.entries(data.fooled_by).forEach(([authorId, fooledList]) => {
                const authorName = this.app.getPlayerName(authorId);
                const count = fooledList.length;
                const div = document.createElement('div');
                div.className = 'result-fooled';
                div.textContent = `${authorName} fooled ${count} player(s)! (+${count * 100} pts)`;
                resultsContainer.appendChild(div);
            });
        }
    }

    handleRoundEnd(data) {
        this.currentPhase = 'round_end';
        this.stopTimer();

        this.hideAllViews();
        document.getElementById('fibbage-round-end-view').classList.remove('hidden');
        document.getElementById('fibbage-round-complete').textContent = `Round ${data.round} Complete!`;
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

        setTimeout(() => {
            this.app.returnToLobby();
        }, 5000);
    }

    submitAnswer() {
        if (this.hasSubmittedAnswer) return;

        const input = document.getElementById('fibbage-answer');
        const answer = input.value.trim();

        if (!answer) return;

        this.hasSubmittedAnswer = true;
        input.disabled = true;
        document.getElementById('btn-submit-lie').disabled = true;

        gameSocket.send({
            type: 'fibbage_answer',
            player_id: this.app.playerId,
            answer: answer
        });
    }

    submitVote(answerId) {
        if (this.hasVoted) return;

        this.hasVoted = true;

        // Disable all vote buttons
        document.querySelectorAll('.btn-vote-answer').forEach(btn => {
            btn.disabled = true;
        });

        gameSocket.send({
            type: 'fibbage_vote',
            player_id: this.app.playerId,
            answer_id: answerId
        });
    }

    submitReady() {
        if (this.isReady) return;

        this.isReady = true;
        document.getElementById('btn-fibbage-ready').disabled = true;

        gameSocket.send({
            type: 'fibbage_ready',
            player_id: this.app.playerId
        });
    }

    updatePlayerReadyIndicators() {
        const container = document.getElementById('fibbage-players-ready');
        if (!container) return;

        container.innerHTML = '';

        Object.entries(this.app.players).forEach(([playerId, player]) => {
            const isPlayerReady = this.playersReady[playerId] || false;
            const div = document.createElement('div');
            div.className = `player-ready-indicator ${isPlayerReady ? 'ready' : ''}`;

            const color = this.app.getCharacterColor(player.character);
            div.innerHTML = `
                <div class="player-avatar" style="background-color: ${color}">
                    ${isPlayerReady ? '<span class="checkmark">✓</span>' : ''}
                </div>
                <span class="player-name">${player.name}</span>
            `;
            container.appendChild(div);
        });
    }

    hideAllViews() {
        document.getElementById('fibbage-writing-view')?.classList.add('hidden');
        document.getElementById('fibbage-voting-view')?.classList.add('hidden');
        document.getElementById('fibbage-reveal-view')?.classList.add('hidden');
        document.getElementById('fibbage-ready-view')?.classList.add('hidden');
        document.getElementById('fibbage-round-end-view')?.classList.add('hidden');
    }

    startTimer() {
        this.stopTimer();
        this.updateTimerDisplay();

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
        const timer = document.getElementById('fibbage-timer');
        if (timer) {
            timer.textContent = this.timeRemaining;
            timer.classList.toggle('warning', this.timeRemaining <= 10);
        }
    }
}

// Global instance
window.fibbageGame = new FibbageGame();
