/**
 * Imposter game handler for web player
 */
class ImposterGame {
    constructor() {
        this.app = null;
        this.isImposter = false;
        this.secretWord = "";
        this.imposterCount = 0;
        this.totalPlayers = 0;

        // Voting state
        this.currentState = '';
        this.votes = {};
        this.tallies = {};
        this.myVote = null;
        this.players = [];
        this.consensusTarget = null;
        this.countdown = 5;
        this.isEliminated = false;
        this.myPlayerId = null;
    }

    init(app) {
        this.app = app;
        this.myPlayerId = app.playerId;
        this.setupSocketHandlers();
    }

    setupSocketHandlers() {
        gameSocket.on('imposter_role', (data) => {
            this.handleRoleAssignment(data);
        });

        gameSocket.on('discussion_started', (data) => {
            // Discussion phase is free-form, just update UI if needed
            this.updateDiscussionUI();
        });

        // Voting phase handlers
        gameSocket.on('voting_started', (data) => {
            this.handleVotingStarted(data);
        });

        gameSocket.on('vote_update', (data) => {
            this.handleVoteUpdate(data);
        });

        gameSocket.on('consensus_warning', (data) => {
            this.handleConsensusWarning(data);
        });

        gameSocket.on('consensus_countdown', (data) => {
            this.handleConsensusCountdown(data);
        });

        gameSocket.on('consensus_cancelled', () => {
            this.handleConsensusCancelled();
        });

        gameSocket.on('reveal_start', (data) => {
            this.handleRevealStart(data);
        });

        gameSocket.on('reveal_result', (data) => {
            this.handleRevealResult(data);
        });

        gameSocket.on('voting_resumed', (data) => {
            this.handleVotingResumed(data);
        });

        gameSocket.on('word_revealed', (data) => {
            this.handleWordRevealed(data);
        });

        gameSocket.on('guess_result', (data) => {
            this.handleGuessResult(data);
        });

        gameSocket.on('round_end', (data) => {
            this.handleRoundEnd(data);
        });

        gameSocket.on('round_restart', (data) => {
            this.handleRoundRestart(data);
        });
    }

    handleRoleAssignment(data) {
        this.isImposter = data.is_imposter;
        this.secretWord = data.word || "";
        this.imposterCount = data.imposter_count || 1;
        this.totalPlayers = data.total_players || 0;

        // Reset voting state for new game
        this.currentState = '';
        this.votes = {};
        this.tallies = {};
        this.myVote = null;
        this.players = [];
        this.consensusTarget = null;
        this.countdown = 5;
        this.isEliminated = false;

        this.showRoleScreen();
    }

    showView(viewId) {
        const views = [
            'imposter-role-view',
            'imposter-voting-view',
            'imposter-spectator-view',
            'imposter-consensus-view',
            'imposter-reveal-view',
            'imposter-result-view',
            'imposter-round-end-view'
        ];

        views.forEach(id => {
            const el = document.getElementById(id);
            if (el) {
                if (id === viewId) {
                    el.classList.remove('hidden');
                } else {
                    el.classList.add('hidden');
                }
            }
        });
    }

    toggleGuessSection(show) {
        const section = document.getElementById('imposter-guess-section');
        if (section) {
            if (show) {
                section.classList.remove('hidden');
            } else {
                section.classList.add('hidden');
            }
        }
    }

    setupGuessInput() {
        const btn = document.getElementById('imposter-guess-btn');
        const input = document.getElementById('imposter-guess-input');
        if (!btn || !input) return;

        // Remove existing listeners by cloning button
        const newBtn = btn.cloneNode(true);
        btn.parentNode.replaceChild(newBtn, btn);

        newBtn.addEventListener('click', () => {
            this.submitGuess();
        });

        // Submit on Enter key
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                this.submitGuess();
            }
        });
    }

    submitGuess() {
        const input = document.getElementById('imposter-guess-input');
        if (!input) return;

        const guess = input.value.trim();
        if (guess === '') return;

        gameSocket.send('word_guess', { guess: guess });
        input.value = '';
    }

    handleGuessResult(data) {
        if (!data.correct) {
            const feedback = document.getElementById('guess-feedback');
            if (feedback) {
                feedback.textContent = 'Incorrect!';
                feedback.classList.remove('hidden');
                setTimeout(() => {
                    feedback.classList.add('hidden');
                }, 2000);
            }
        }
    }

    handleRoundEnd(data) {
        this.currentState = 'round_end';
        this.toggleGuessSection(false);
        this.showView('imposter-round-end-view');

        const winnerEl = document.getElementById('round-end-winner');
        const wordEl = document.getElementById('round-end-word');
        const namesEl = document.getElementById('round-end-imposter-names');
        const card = document.getElementById('round-end-card');
        const imposterScoreEl = document.getElementById('round-end-imposter-score');
        const innocentScoreEl = document.getElementById('round-end-innocent-score');

        if (winnerEl) {
            winnerEl.textContent = data.winner === 'imposters' ? 'IMPOSTERS WIN!' : 'INNOCENTS WIN!';
        }
        if (wordEl) {
            wordEl.textContent = 'The word was: ' + (data.word || '???');
        }
        if (namesEl && data.imposter_names) {
            namesEl.textContent = data.imposter_names.join(', ');
        }
        if (card) {
            card.className = data.winner === 'imposters'
                ? 'round-end-card imposters-win'
                : 'round-end-card innocents-win';
        }
        if (imposterScoreEl && data.scores) {
            imposterScoreEl.textContent = 'Imposters: ' + (data.scores.imposters || 0);
        }
        if (innocentScoreEl && data.scores) {
            innocentScoreEl.textContent = 'Innocents: ' + (data.scores.innocents || 0);
        }
    }

    handleRoundRestart(data) {
        this.currentState = '';
        this.votes = {};
        this.tallies = {};
        this.myVote = null;
        this.consensusTarget = null;
        this.countdown = 5;
        this.isEliminated = false;
        this.toggleGuessSection(false);

        const input = document.getElementById('imposter-guess-input');
        if (input) input.value = '';
        const feedback = document.getElementById('guess-feedback');
        if (feedback) feedback.classList.add('hidden');
    }

    showRoleScreen() {
        const roleLabel = document.getElementById('imposter-role-label');
        const wordDisplay = document.getElementById('imposter-word');
        const imposterInfo = document.getElementById('imposter-info');
        const instructionLabel = document.getElementById('imposter-instruction');

        // Update imposter count info
        if (imposterInfo) {
            const plural = this.imposterCount > 1 ? 'imposters' : 'imposter';
            imposterInfo.textContent = `There ${this.imposterCount > 1 ? 'are' : 'is'} ${this.imposterCount} ${plural} among you`;
        }

        if (this.isImposter) {
            // Player IS the imposter
            if (roleLabel) {
                roleLabel.textContent = "You are an IMPOSTER!";
                roleLabel.className = 'role-label imposter';
            }
            if (wordDisplay) {
                wordDisplay.textContent = "IMPOSTER";
                wordDisplay.className = 'word-display imposter';
            }
            if (instructionLabel) {
                instructionLabel.textContent = "Blend in! Figure out the secret word without revealing yourself.";
            }
        } else {
            // Player is NOT the imposter
            if (roleLabel) {
                roleLabel.textContent = "You are NOT the imposter!";
                roleLabel.className = 'role-label innocent';
            }
            if (wordDisplay) {
                wordDisplay.textContent = this.secretWord;
                wordDisplay.className = 'word-display innocent';
            }
            if (instructionLabel) {
                instructionLabel.textContent = "Discuss clues about the word to find the imposter!";
            }
        }

        this.showView('imposter-role-view');
        this.toggleGuessSection(this.isImposter);
        this.setupGuessInput();
    }

    updateDiscussionUI() {
        // Could add additional UI updates when discussion starts
        // For now, role screen already shows discussion instructions
    }

    // Voting handlers
    handleVotingStarted(data) {
        this.currentState = 'voting';
        this.votes = data.votes || {};
        this.tallies = data.tallies || {};
        this.players = data.players || [];

        if (this.isEliminated) {
            this.showSpectatorView();
        } else {
            this.showVotingView();
        }
    }

    showVotingView() {
        this.showView('imposter-voting-view');
        this.renderVoteList('vote-player-list', true);
        this.updateVoteHighlight();
        this.updateVoteCounts();
        this.toggleGuessSection(this.isImposter);
    }

    showSpectatorView() {
        this.showView('imposter-spectator-view');
        this.renderVoteList('spectator-vote-list', false);
        this.updateVoteCounts();
        this.toggleGuessSection(false);
    }

    renderVoteList(containerId, interactive) {
        const container = document.getElementById(containerId);
        if (!container) return;

        container.innerHTML = '';

        this.players.forEach(player => {
            // Skip eliminated players in vote list
            if (player.eliminated) return;

            const div = document.createElement('div');
            div.className = 'vote-option';
            div.dataset.playerId = player.id;

            const nameSpan = document.createElement('span');
            nameSpan.className = 'player-name';
            nameSpan.textContent = player.name;

            const countSpan = document.createElement('span');
            countSpan.className = 'vote-count';
            countSpan.textContent = this.tallies[player.id] || 0;

            div.appendChild(nameSpan);
            div.appendChild(countSpan);

            if (interactive) {
                div.addEventListener('click', () => {
                    this.castVote(player.id);
                });
            }

            container.appendChild(div);
        });
    }

    castVote(targetId) {
        this.myVote = targetId;
        gameSocket.send('vote_cast', { target_id: targetId });
        this.updateVoteHighlight();
    }

    updateVoteHighlight() {
        const container = document.getElementById('vote-player-list');
        if (!container) return;

        const options = container.querySelectorAll('.vote-option');
        options.forEach(opt => {
            if (opt.dataset.playerId === this.myVote) {
                opt.classList.add('my-vote');
            } else {
                opt.classList.remove('my-vote');
            }
        });
    }

    updateVoteCounts() {
        // Update counts in both voting and spectator views
        ['vote-player-list', 'spectator-vote-list'].forEach(containerId => {
            const container = document.getElementById(containerId);
            if (!container) return;

            const options = container.querySelectorAll('.vote-option');
            options.forEach(opt => {
                const playerId = opt.dataset.playerId;
                const countSpan = opt.querySelector('.vote-count');
                if (countSpan) {
                    countSpan.textContent = this.tallies[playerId] || 0;
                }
            });
        });
    }

    handleVoteUpdate(data) {
        this.votes = data.votes || {};
        this.tallies = data.tallies || {};
        this.updateVoteCounts();
    }

    // Consensus handlers
    handleConsensusWarning(data) {
        this.consensusTarget = data.target_id;
        this.countdown = data.countdown || 5;

        this.showView('imposter-consensus-view');

        const targetName = this.players.find(p => p.id === this.consensusTarget)?.name || 'Unknown';
        const targetLabel = document.getElementById('consensus-target-name');
        if (targetLabel) {
            targetLabel.textContent = targetName;
        }

        const countdownEl = document.getElementById('consensus-countdown');
        if (countdownEl) {
            countdownEl.textContent = this.countdown;
        }

        this.toggleGuessSection(this.isImposter && !this.isEliminated);
    }

    handleConsensusCountdown(data) {
        this.countdown = data.countdown;

        const countdownEl = document.getElementById('consensus-countdown');
        if (countdownEl) {
            countdownEl.textContent = this.countdown;
        }
    }

    handleConsensusCancelled() {
        this.consensusTarget = null;
        this.countdown = 5;

        // Return to appropriate view
        if (this.isEliminated) {
            this.showSpectatorView();
        } else {
            this.showVotingView();
        }
    }

    // Reveal handlers
    handleRevealStart(data) {
        this.showView('imposter-reveal-view');
        this.toggleGuessSection(false);
    }

    handleRevealResult(data) {
        const eliminatedId = data.target_id;
        const wasImposter = data.is_imposter;
        const eliminatedName = this.players.find(p => p.id === eliminatedId)?.name || 'Unknown';

        this.showView('imposter-result-view');

        const nameEl = document.getElementById('result-player-name');
        const outcomeEl = document.getElementById('result-role-text');
        const resultCard = document.getElementById('result-card');

        if (nameEl) {
            nameEl.textContent = eliminatedName;
        }

        if (outcomeEl && resultCard) {
            if (wasImposter) {
                outcomeEl.textContent = 'was the IMPOSTER!';
                outcomeEl.className = 'result-outcome imposter';
                resultCard.className = 'result-card imposter';
            } else {
                outcomeEl.textContent = 'was INNOCENT';
                outcomeEl.className = 'result-outcome innocent';
                resultCard.className = 'result-card innocent';
            }
        }

        // Mark player as eliminated if it was me
        if (eliminatedId === this.myPlayerId) {
            this.isEliminated = true;
        }

        // Update player list
        const player = this.players.find(p => p.id === eliminatedId);
        if (player) {
            player.eliminated = true;
        }
    }

    handleVotingResumed(data) {
        this.currentState = 'voting';
        this.votes = data.votes || {};
        this.tallies = data.tallies || {};
        this.myVote = null;

        if (this.isEliminated) {
            this.showSpectatorView();
        } else {
            this.showVotingView();
        }
    }

    handleWordRevealed(data) {
        this.secretWord = data.word;

        // Update spectator view to show word
        const wordEl = document.getElementById('spectator-word-display');
        if (wordEl) {
            wordEl.textContent = `The word was: ${this.secretWord}`;
        }
    }
}

// Global instance
window.imposterGame = new ImposterGame();
