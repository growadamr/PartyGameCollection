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
    }

    init(app) {
        this.app = app;
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
    }

    handleRoleAssignment(data) {
        this.isImposter = data.is_imposter;
        this.secretWord = data.word || "";
        this.imposterCount = data.imposter_count || 1;
        this.totalPlayers = data.total_players || 0;

        this.showRoleScreen();
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
    }

    updateDiscussionUI() {
        // Could add additional UI updates when discussion starts
        // For now, role screen already shows discussion instructions
    }
}

// Global instance
window.imposterGame = new ImposterGame();
