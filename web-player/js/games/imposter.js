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
            'imposter-role-screen',
            'imposter-vote-screen',
            'imposter-spectator-screen',
            'imposter-consensus-screen',
            'imposter-reveal-screen',
            'imposter-result-screen'
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

        this.showView('imposter-role-screen');
    }

    updateDiscussionUI() {
        // Could add additional UI updates when discussion starts
        // For now, role screen already shows discussion instructions
    }
}

// Global instance
window.imposterGame = new ImposterGame();
