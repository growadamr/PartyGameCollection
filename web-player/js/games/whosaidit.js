/**
 * Who Said It game handler for web player
 */
const MAX_ANSWER_LENGTH = 250;

class WhoSaidItGame {
    constructor() {
        this.app = null;
        this.timeRemaining = 60;
        this.timerInterval = null;
        this.currentPhase = 'waiting';
        this.hasSubmittedAnswer = false;
        this.hasVoted = false;
        this.isReady = false;
        this.currentAuthorId = null;
        this.mySubmittedAnswer = '';
        this.playersReady = {};
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
    }

    setupEventListeners() {
        document.getElementById('btn-submit-answer')?.addEventListener('click', () => {
            this.submitAnswer();
        });

        document.getElementById('whosaid-answer')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.submitAnswer();
            }
        });

        document.getElementById('whosaid-answer')?.addEventListener('input', (e) => {
            if (e.target.value.length > MAX_ANSWER_LENGTH) {
                e.target.value = e.target.value.substring(0, MAX_ANSWER_LENGTH);
            }
            this.updateCharCounter();
        });

        document.getElementById('btn-ready')?.addEventListener('click', () => {
            this.submitReady();
        });
    }

    setupSocketHandlers() {
        gameSocket.on('whosaid_init', (data) => {
            // Initialize ready state for all players
            this.playersReady = {};
            (data.player_order || []).forEach(pid => {
                this.playersReady[pid] = false;
            });
        });

        gameSocket.on('whosaid_pre_round', (data) => {
            this.handlePreRound(data);
        });

        gameSocket.on('whosaid_ready_status', (data) => {
            this.handleReadyStatus(data);
        });

        gameSocket.on('whosaid_prompt', (data) => {
            this.handlePrompt(data);
        });

        gameSocket.on('whosaid_answer_received', (data) => {
            this.handleAnswerReceived(data);
        });

        gameSocket.on('whosaid_vote_start', (data) => {
            this.handleVoteStart(data);
        });

        gameSocket.on('whosaid_vote_received', (data) => {
            this.handleVoteReceived(data);
        });

        gameSocket.on('whosaid_reveal', (data) => {
            this.handleReveal(data);
        });

        gameSocket.on('whosaid_continue', (data) => {
            this.handleContinue(data);
        });

        gameSocket.on('whosaid_round_end', (data) => {
            this.handleRoundEnd(data);
        });

        gameSocket.on('whosaid_end', (data) => {
            this.handleGameEnd(data);
        });
    }

    handlePreRound(data) {
        this.currentPhase = 'pre_round';
        this.isReady = false;

        // Update ready states
        const readyList = data.ready_players || [];
        Object.keys(this.playersReady).forEach(pid => {
            this.playersReady[pid] = readyList.includes(pid);
        });

        this.hideAllViews();
        document.getElementById('whosaid-ready-view').classList.remove('hidden');

        const nextRound = data.round || 1;
        const title = nextRound === 1 ? 'Ready to Start?' : `Round ${nextRound}`;
        document.getElementById('whosaid-ready-title').textContent = title;
        document.getElementById('btn-ready').textContent = 'Ready!';
        document.getElementById('btn-ready').disabled = false;
        document.getElementById('whosaid-ready-status').textContent = `${readyList.length}/${Object.keys(this.playersReady).length} ready`;

        this.updatePlayerReadyIndicators();
    }

    handleReadyStatus(data) {
        const readyList = data.ready_players || [];
        const readyCount = data.ready_count || 0;
        const needed = data.players_needed || Object.keys(this.playersReady).length;

        Object.keys(this.playersReady).forEach(pid => {
            this.playersReady[pid] = readyList.includes(pid);
        });

        document.getElementById('whosaid-ready-status').textContent = `${readyCount}/${needed} ready`;
        this.updatePlayerReadyIndicators();
    }

    handlePrompt(data) {
        this.currentPhase = 'writing';
        this.hasSubmittedAnswer = false;
        this.mySubmittedAnswer = '';
        this.timeRemaining = data.time_limit || 60;

        this.hideAllViews();
        document.getElementById('whosaid-writing-view').classList.remove('hidden');

        document.getElementById('whosaid-prompt').textContent = data.prompt;
        document.getElementById('whosaid-answer').value = '';
        document.getElementById('whosaid-answer').disabled = false;
        document.getElementById('btn-submit-answer').disabled = false;
        document.getElementById('whosaid-answers-status').textContent = '0 answers received';
        this.updateCharCounter();

        this.startTimer();
    }

    handleAnswerReceived(data) {
        document.getElementById('whosaid-answers-status').textContent =
            `${data.answers_received}/${data.answers_needed} answers received`;
    }

    handleVoteStart(data) {
        this.currentPhase = 'voting';
        this.hasVoted = false;
        this.timeRemaining = data.time_limit || 30;

        this.hideAllViews();

        const isAuthor = (data.answer_text === this.mySubmittedAnswer);

        if (isAuthor) {
            document.getElementById('whosaid-author-view').classList.remove('hidden');
            document.getElementById('whosaid-your-answer').textContent = `"${data.answer_text}"`;
        } else {
            document.getElementById('whosaid-voting-view').classList.remove('hidden');
            document.getElementById('whosaid-answer-display').textContent = `"${data.answer_text}"`;
            this.populateVoteButtons();
        }

        document.getElementById('whosaid-votes-status').textContent = '0 votes';
        this.startTimer();
    }

    populateVoteButtons() {
        const container = document.getElementById('whosaid-vote-buttons');
        container.innerHTML = '';

        // Show all players except yourself (you can't vote for yourself)
        // Players CAN vote for the author - that's the correct answer!
        Object.entries(this.app.players).forEach(([playerId, player]) => {
            if (playerId === this.app.playerId) return;

            const btn = document.createElement('button');
            btn.className = 'btn-vote';
            btn.textContent = player.name;
            btn.addEventListener('click', () => this.submitVote(playerId));
            container.appendChild(btn);
        });
    }

    handleVoteReceived(data) {
        document.getElementById('whosaid-votes-status').textContent =
            `${data.votes_received}/${data.votes_needed} votes`;
    }

    handleReveal(data) {
        this.currentPhase = 'reveal';
        this.stopTimer();

        this.hideAllViews();
        document.getElementById('whosaid-reveal-view').classList.remove('hidden');

        document.getElementById('whosaid-reveal-answer').textContent = `"${data.answer_text}"`;
        document.getElementById('whosaid-reveal-author').textContent = `Written by: ${data.author_name}`;

        const resultsContainer = document.getElementById('whosaid-reveal-results');
        resultsContainer.innerHTML = '';

        // Show correct guessers
        data.correct_guessers.forEach(playerId => {
            const playerName = this.app.getPlayerName(playerId);
            const div = document.createElement('div');
            div.className = 'result-correct';
            div.textContent = `${playerName} guessed correctly (+50 pts)`;
            resultsContainer.appendChild(div);
        });

        // Show fooled message
        if (data.fooled_players.length > 0) {
            const div = document.createElement('div');
            div.className = 'result-fooled';
            div.textContent = `${data.author_name} fooled ${data.fooled_players.length} player(s) (+${data.fooled_players.length * 50} pts)`;
            resultsContainer.appendChild(div);
        }
    }

    handleContinue(data) {
        this.currentPhase = 'continue';
        this.isReady = false;

        const readyList = data.ready_players || [];
        Object.keys(this.playersReady).forEach(pid => {
            this.playersReady[pid] = readyList.includes(pid);
        });

        this.hideAllViews();
        document.getElementById('whosaid-ready-view').classList.remove('hidden');

        const isLast = data.is_last_answer || false;
        const title = isLast ? 'That was the last answer!' : 'Ready for next answer?';
        const buttonText = isLast ? 'See Results' : 'Next Answer';

        document.getElementById('whosaid-ready-title').textContent = title;
        document.getElementById('btn-ready').textContent = buttonText;
        document.getElementById('btn-ready').disabled = false;
        document.getElementById('whosaid-ready-status').textContent = `${readyList.length}/${Object.keys(this.playersReady).length} ready`;

        this.updatePlayerReadyIndicators();
    }

    handleRoundEnd(data) {
        this.currentPhase = 'round_end';
        this.stopTimer();

        this.hideAllViews();
        document.getElementById('whosaid-round-end-view').classList.remove('hidden');
        document.getElementById('whosaid-round-complete').textContent = `Round ${data.round} Complete!`;
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

    updateCharCounter() {
        const input = document.getElementById('whosaid-answer');
        const counter = document.getElementById('whosaid-char-counter');
        if (!input || !counter) return;
        const len = input.value.length;
        const remaining = MAX_ANSWER_LENGTH - len;
        counter.textContent = `${len} / ${MAX_ANSWER_LENGTH}`;
        if (remaining <= 25) {
            counter.style.color = '#ff4d4d';
        } else if (remaining <= 50) {
            counter.style.color = '#ff9933';
        } else {
            counter.style.color = '#999';
        }
    }

    submitAnswer() {
        if (this.hasSubmittedAnswer) return;

        const input = document.getElementById('whosaid-answer');
        let answer = input.value.trim();

        if (!answer) return;
        if (answer.length > MAX_ANSWER_LENGTH) {
            answer = answer.substring(0, MAX_ANSWER_LENGTH);
        }

        this.hasSubmittedAnswer = true;
        this.mySubmittedAnswer = answer;
        input.disabled = true;
        document.getElementById('btn-submit-answer').disabled = true;

        gameSocket.send({
            type: 'whosaid_answer',
            player_id: this.app.playerId,
            answer: answer
        });
    }

    submitVote(votedForId) {
        if (this.hasVoted) return;

        this.hasVoted = true;

        // Disable all vote buttons
        document.querySelectorAll('.btn-vote').forEach(btn => {
            btn.disabled = true;
        });

        gameSocket.send({
            type: 'whosaid_vote',
            player_id: this.app.playerId,
            voted_for: votedForId
        });
    }

    submitReady() {
        if (this.isReady) return;

        this.isReady = true;
        document.getElementById('btn-ready').disabled = true;

        gameSocket.send({
            type: 'whosaid_ready',
            player_id: this.app.playerId
        });
    }

    updatePlayerReadyIndicators() {
        // Update player indicators in the ready view
        const container = document.getElementById('whosaid-players-ready');
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
        document.getElementById('whosaid-writing-view')?.classList.add('hidden');
        document.getElementById('whosaid-voting-view')?.classList.add('hidden');
        document.getElementById('whosaid-author-view')?.classList.add('hidden');
        document.getElementById('whosaid-reveal-view')?.classList.add('hidden');
        document.getElementById('whosaid-ready-view')?.classList.add('hidden');
        document.getElementById('whosaid-round-end-view')?.classList.add('hidden');
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
        const timer = document.getElementById('whosaid-timer');
        if (timer) {
            timer.textContent = this.timeRemaining;
            timer.classList.toggle('warning', this.timeRemaining <= 10);
        }
    }
}

// Global instance
window.whoSaidItGame = new WhoSaidItGame();
