/**
 * Quick Draw game handler for web player
 */
class QuickDrawGame {
    constructor() {
        this.app = null;
        this.isDrawer = false;
        this.drawerId = null;
        this.timeRemaining = 60;
        this.timerInterval = null;

        // Drawing state
        this.canvas = null;
        this.ctx = null;
        this.isDrawing = false;
        this.lastX = 0;
        this.lastY = 0;
        this.brushColor = '#ffffff';
        this.brushSize = 5;
        this.strokes = [];
        this.currentStroke = null;
    }

    init(app) {
        this.app = app;
        this.setupEventListeners();
        this.setupSocketHandlers();
        this.setupCanvas();
    }

    setupEventListeners() {
        // Drawing tools
        document.getElementById('btn-clear')?.addEventListener('click', () => {
            this.clearCanvas();
            gameSocket.send({ type: 'quick_draw_clear' });
        });

        document.getElementById('brush-color')?.addEventListener('input', (e) => {
            this.brushColor = e.target.value;
        });

        document.getElementById('brush-size')?.addEventListener('input', (e) => {
            this.brushSize = parseInt(e.target.value);
        });

        // Guess input
        document.getElementById('btn-quickdraw-guess')?.addEventListener('click', () => {
            this.submitGuess();
        });

        document.getElementById('quickdraw-guess')?.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                this.submitGuess();
            }
        });
    }

    setupCanvas() {
        this.canvas = document.getElementById('drawing-canvas');
        if (!this.canvas) return;

        this.ctx = this.canvas.getContext('2d');
        this.ctx.lineCap = 'round';
        this.ctx.lineJoin = 'round';

        // Clear canvas
        this.ctx.fillStyle = '#1a1a1a';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        // Mouse events
        this.canvas.addEventListener('mousedown', (e) => this.startDrawing(e));
        this.canvas.addEventListener('mousemove', (e) => this.draw(e));
        this.canvas.addEventListener('mouseup', () => this.stopDrawing());
        this.canvas.addEventListener('mouseout', () => this.stopDrawing());

        // Touch events
        this.canvas.addEventListener('touchstart', (e) => {
            e.preventDefault();
            this.startDrawing(e.touches[0]);
        });
        this.canvas.addEventListener('touchmove', (e) => {
            e.preventDefault();
            this.draw(e.touches[0]);
        });
        this.canvas.addEventListener('touchend', () => this.stopDrawing());
    }

    setupSocketHandlers() {
        gameSocket.on('quick_draw_init', (data) => {
            // Game initialized
        });

        gameSocket.on('quick_draw_turn', (data) => {
            this.handleTurn(data);
        });

        gameSocket.on('quick_draw_stroke', (data) => {
            if (!this.isDrawer) {
                this.drawRemoteStroke(data.stroke);
            }
        });

        gameSocket.on('quick_draw_clear', () => {
            if (!this.isDrawer) {
                this.clearCanvas();
            }
        });

        gameSocket.on('quick_draw_wrong', (data) => {
            console.log(`${data.player_name} guessed: ${data.guess}`);
        });

        gameSocket.on('quick_draw_result', (data) => {
            this.handleResult(data);
        });

        gameSocket.on('quick_draw_timeout', (data) => {
            this.handleTimeout(data);
        });

        gameSocket.on('quick_draw_end', (data) => {
            this.handleGameEnd(data);
        });
    }

    handleTurn(data) {
        this.drawerId = data.drawer_id;
        this.isDrawer = (data.drawer_id === this.app.playerId);
        this.timeRemaining = data.time || 60;

        this.clearCanvas();
        this.hideAllViews();

        if (this.isDrawer) {
            document.getElementById('quickdraw-drawer-view').classList.remove('hidden');
            document.getElementById('quickdraw-prompt').textContent = data.prompt;
            this.setupCanvas();
        } else {
            document.getElementById('quickdraw-guesser-view').classList.remove('hidden');
            document.getElementById('quickdraw-drawer-name').textContent =
                this.app.getPlayerName(data.drawer_id);
            document.getElementById('quickdraw-guess').value = '';
            document.getElementById('quickdraw-guess').disabled = false;
            document.getElementById('btn-quickdraw-guess').disabled = false;
        }

        this.startTimer();
    }

    handleResult(data) {
        this.stopTimer();

        const guesserName = this.app.getPlayerName(data.guesser_id);
        const drawerName = this.app.getPlayerName(data.drawer_id);

        // Show result overlay or message
        alert(`${guesserName} guessed "${data.prompt}" correctly!\n\n${guesserName}: +100 pts\n${drawerName}: +50 pts`);
    }

    handleTimeout(data) {
        this.stopTimer();
        alert(`Time's up! The word was: ${data.prompt}`);
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

    // Drawing methods
    getCanvasCoords(e) {
        const rect = this.canvas.getBoundingClientRect();
        const scaleX = this.canvas.width / rect.width;
        const scaleY = this.canvas.height / rect.height;

        return {
            x: (e.clientX - rect.left) * scaleX,
            y: (e.clientY - rect.top) * scaleY
        };
    }

    startDrawing(e) {
        if (!this.isDrawer) return;

        this.isDrawing = true;
        const coords = this.getCanvasCoords(e);
        this.lastX = coords.x;
        this.lastY = coords.y;

        this.currentStroke = {
            color: this.brushColor,
            size: this.brushSize,
            points: [{ x: coords.x, y: coords.y }]
        };
    }

    draw(e) {
        if (!this.isDrawing || !this.isDrawer) return;

        const coords = this.getCanvasCoords(e);

        // Draw locally
        this.ctx.strokeStyle = this.brushColor;
        this.ctx.lineWidth = this.brushSize;
        this.ctx.beginPath();
        this.ctx.moveTo(this.lastX, this.lastY);
        this.ctx.lineTo(coords.x, coords.y);
        this.ctx.stroke();

        this.lastX = coords.x;
        this.lastY = coords.y;

        // Add to current stroke
        if (this.currentStroke) {
            this.currentStroke.points.push({ x: coords.x, y: coords.y });
        }
    }

    stopDrawing() {
        if (!this.isDrawing) return;

        this.isDrawing = false;

        // Send stroke to server
        if (this.currentStroke && this.currentStroke.points.length > 1) {
            gameSocket.send({
                type: 'quick_draw_stroke',
                stroke: this.currentStroke
            });
            this.strokes.push(this.currentStroke);
        }

        this.currentStroke = null;
    }

    drawRemoteStroke(stroke) {
        if (!this.ctx) {
            // Create a canvas for guesser view if needed
            const display = document.getElementById('quickdraw-canvas-display');
            if (display && !display.querySelector('canvas')) {
                const canvas = document.createElement('canvas');
                canvas.width = 300;
                canvas.height = 300;
                canvas.style.maxWidth = '100%';
                display.innerHTML = '';
                display.appendChild(canvas);
                this.guesserCtx = canvas.getContext('2d');
                this.guesserCtx.fillStyle = '#1a1a1a';
                this.guesserCtx.fillRect(0, 0, 300, 300);
                this.guesserCtx.lineCap = 'round';
                this.guesserCtx.lineJoin = 'round';
            }
        }

        const ctx = this.guesserCtx || this.ctx;
        if (!ctx || !stroke.points || stroke.points.length < 2) return;

        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.size;
        ctx.beginPath();
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);

        for (let i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }

        ctx.stroke();
    }

    clearCanvas() {
        if (this.ctx) {
            this.ctx.fillStyle = '#1a1a1a';
            this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
        }

        if (this.guesserCtx) {
            this.guesserCtx.fillStyle = '#1a1a1a';
            this.guesserCtx.fillRect(0, 0, 300, 300);
        }

        this.strokes = [];
    }

    submitGuess() {
        if (this.isDrawer) return;

        const input = document.getElementById('quickdraw-guess');
        const guess = input.value.trim();

        if (guess) {
            gameSocket.send({
                type: 'quick_draw_guess',
                guess: guess
            });
            input.value = '';
        }
    }

    hideAllViews() {
        document.getElementById('quickdraw-drawer-view')?.classList.add('hidden');
        document.getElementById('quickdraw-guesser-view')?.classList.add('hidden');
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
        const timer = document.getElementById('quickdraw-timer');
        if (timer) {
            timer.textContent = this.timeRemaining;
            timer.classList.toggle('warning', this.timeRemaining <= 10);
        }
    }
}

// Global instance
window.quickDrawGame = new QuickDrawGame();
