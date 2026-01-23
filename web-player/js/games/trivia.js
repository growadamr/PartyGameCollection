/**
 * Trivia Showdown game handler for web player
 */
class TriviaGame {
    constructor() {
        this.app = null;
        this.timeRemaining = 15;
        this.timerInterval = null;
        this.currentPhase = 'waiting';
        this.hasAnswered = false;
        this.isReady = false;
        this.playersReady = {};
        this.questionStartTime = 0;
        this.currentQuestion = null;
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
    }

    setupEventListeners() {
        document.getElementById('btn-trivia-ready')?.addEventListener('click', () => {
            this.submitReady();
        });
    }

    setupSocketHandlers() {
        gameSocket.on('trivia_init', (data) => {
            this.playersReady = {};
            (data.player_order || []).forEach(pid => {
                this.playersReady[pid] = false;
            });
        });

        gameSocket.on('trivia_pre_round', (data) => {
            this.handlePreRound(data);
        });

        gameSocket.on('trivia_ready_status', (data) => {
            this.handleReadyStatus(data);
        });

        gameSocket.on('trivia_question', (data) => {
            this.handleQuestion(data);
        });

        gameSocket.on('trivia_answer_count', (data) => {
            this.handleAnswerCount(data);
        });

        gameSocket.on('trivia_reveal', (data) => {
            this.handleReveal(data);
        });

        gameSocket.on('trivia_leaderboard', (data) => {
            this.handleLeaderboard(data);
        });

        gameSocket.on('trivia_round_end', (data) => {
            this.handleRoundEnd(data);
        });

        gameSocket.on('trivia_end', (data) => {
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
        document.getElementById('trivia-ready-view').classList.remove('hidden');

        const nextRound = data.round || 1;
        const title = nextRound === 1 ? 'Ready to Start?' : `Round ${nextRound}`;
        document.getElementById('trivia-ready-title').textContent = title;
        document.getElementById('btn-trivia-ready').textContent = 'Ready!';
        document.getElementById('btn-trivia-ready').disabled = false;
        document.getElementById('trivia-ready-status').textContent = `${readyList.length}/${Object.keys(this.playersReady).length} ready`;

        this.updatePlayerReadyIndicators();
    }

    handleReadyStatus(data) {
        const readyList = data.ready_players || [];
        const readyCount = data.ready_count || 0;
        const needed = data.players_needed || Object.keys(this.playersReady).length;

        Object.keys(this.playersReady).forEach(pid => {
            this.playersReady[pid] = readyList.includes(pid);
        });

        document.getElementById('trivia-ready-status').textContent = `${readyCount}/${needed} ready`;
        this.updatePlayerReadyIndicators();
    }

    handleQuestion(data) {
        this.currentPhase = 'question';
        this.hasAnswered = false;
        this.timeRemaining = data.time_limit || 15;
        this.questionStartTime = Date.now();
        this.currentQuestion = data;

        this.hideAllViews();
        document.getElementById('trivia-question-view').classList.remove('hidden');

        document.getElementById('trivia-category').textContent = data.category || 'General';
        document.getElementById('trivia-question-num').textContent = `Question ${data.question_num}/${data.total_questions}`;
        document.getElementById('trivia-question-text').textContent = data.question;

        this.populateAnswerButtons(data.answers || []);
        document.getElementById('trivia-answer-status').textContent = '0 answered';

        this.startTimer();
    }

    populateAnswerButtons(answers) {
        const container = document.getElementById('trivia-answer-buttons');
        container.innerHTML = '';

        const labels = ['A', 'B', 'C', 'D'];

        answers.forEach((answer, index) => {
            const btn = document.createElement('button');
            btn.className = 'btn-trivia-answer';
            btn.innerHTML = `<span class="answer-label">${labels[index]}</span><span class="answer-text">${answer}</span>`;
            btn.addEventListener('click', () => this.submitAnswer(index));
            container.appendChild(btn);
        });
    }

    handleAnswerCount(data) {
        document.getElementById('trivia-answer-status').textContent =
            `${data.answered}/${data.total} answered`;
    }

    handleReveal(data) {
        this.currentPhase = 'reveal';
        this.stopTimer();

        this.hideAllViews();
        document.getElementById('trivia-result-view').classList.remove('hidden');

        const myResult = data.player_results[this.app.playerId] || { answered: -1, correct: false, points: 0 };

        const resultLabel = document.getElementById('trivia-result-label');
        const pointsLabel = document.getElementById('trivia-points-label');

        if (myResult.answered === -1) {
            resultLabel.textContent = "Time's Up!";
            resultLabel.className = 'result-timeout';
            pointsLabel.textContent = '0 points';
        } else if (myResult.correct) {
            resultLabel.textContent = 'Correct!';
            resultLabel.className = 'result-correct';
            pointsLabel.textContent = `+${myResult.points} points`;
        } else {
            resultLabel.textContent = 'Wrong!';
            resultLabel.className = 'result-wrong';
            pointsLabel.textContent = '0 points';
        }

        document.getElementById('trivia-correct-answer').textContent = `Answer: ${data.correct_answer}`;
    }

    handleLeaderboard(data) {
        this.currentPhase = 'leaderboard';

        this.hideAllViews();
        document.getElementById('trivia-leaderboard-view').classList.remove('hidden');

        document.getElementById('trivia-leaderboard-title').textContent =
            `Question ${data.question_num}/${data.total_questions} Complete`;

        const container = document.getElementById('trivia-leaderboard-list');
        container.innerHTML = '';

        (data.standings || []).forEach(entry => {
            const row = document.createElement('div');
            row.className = 'leaderboard-row';

            let rankClass = '';
            if (entry.rank === 1) rankClass = 'rank-gold';
            else if (entry.rank === 2) rankClass = 'rank-silver';
            else if (entry.rank === 3) rankClass = 'rank-bronze';

            row.innerHTML = `
                <span class="rank ${rankClass}">#${entry.rank}</span>
                <span class="name">${entry.name}</span>
                <span class="score">${entry.score}</span>
            `;
            container.appendChild(row);
        });
    }

    handleRoundEnd(data) {
        this.currentPhase = 'round_end';
        this.stopTimer();

        this.hideAllViews();
        document.getElementById('trivia-round-end-view').classList.remove('hidden');
        document.getElementById('trivia-round-complete').textContent = `Round ${data.round} Complete!`;
        document.getElementById('trivia-round-winner').textContent = `Winner: ${data.round_winner_name}`;
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

    submitAnswer(answerIndex) {
        if (this.hasAnswered) return;

        this.hasAnswered = true;
        const timeTaken = (Date.now() - this.questionStartTime) / 1000;

        // Disable all answer buttons and highlight selected
        const buttons = document.querySelectorAll('.btn-trivia-answer');
        buttons.forEach((btn, idx) => {
            btn.disabled = true;
            if (idx === answerIndex) {
                btn.classList.add('selected');
            }
        });

        gameSocket.send({
            type: 'trivia_answer',
            player_id: this.app.playerId,
            answer_index: answerIndex,
            time_taken: timeTaken
        });
    }

    submitReady() {
        if (this.isReady) return;

        this.isReady = true;
        document.getElementById('btn-trivia-ready').disabled = true;

        gameSocket.send({
            type: 'trivia_ready',
            player_id: this.app.playerId
        });
    }

    updatePlayerReadyIndicators() {
        const container = document.getElementById('trivia-players-ready');
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
        document.getElementById('trivia-ready-view')?.classList.add('hidden');
        document.getElementById('trivia-question-view')?.classList.add('hidden');
        document.getElementById('trivia-result-view')?.classList.add('hidden');
        document.getElementById('trivia-leaderboard-view')?.classList.add('hidden');
        document.getElementById('trivia-round-end-view')?.classList.add('hidden');
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
        const timer = document.getElementById('trivia-timer');
        if (timer) {
            timer.textContent = this.timeRemaining;
            timer.classList.toggle('warning', this.timeRemaining <= 5);
        }
    }
}

// Global instance
window.triviaGame = new TriviaGame();
