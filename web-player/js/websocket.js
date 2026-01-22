/**
 * WebSocket connection manager for Party Games web player
 */
class GameSocket {
    constructor() {
        this.socket = null;
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 3;
        this.messageHandlers = new Map();

        // Connection info from URL params or manual entry
        this.hostIP = null;
        this.hostPort = 8080;
    }

    /**
     * Parse connection info from URL parameters
     * Expected format: ?host=192.168.1.5&port=8080
     */
    parseURLParams() {
        const params = new URLSearchParams(window.location.search);
        this.hostIP = params.get('host');
        this.hostPort = parseInt(params.get('port')) || 8080;
        return this.hostIP !== null;
    }

    /**
     * Connect to the game host
     */
    connect(host = null, port = null) {
        if (host) this.hostIP = host;
        if (port) this.hostPort = port;

        if (!this.hostIP) {
            console.error('No host IP specified');
            this.emit('error', { message: 'No host IP specified' });
            return;
        }

        const url = `ws://${this.hostIP}:${this.hostPort}`;
        console.log('Connecting to:', url);

        try {
            this.socket = new WebSocket(url);
            this.setupSocketHandlers();
        } catch (e) {
            console.error('WebSocket creation failed:', e);
            this.emit('error', { message: 'Failed to create connection' });
        }
    }

    /**
     * Set up WebSocket event handlers
     */
    setupSocketHandlers() {
        this.socket.onopen = () => {
            console.log('WebSocket connected');
            this.isConnected = true;
            this.reconnectAttempts = 0;
            this.emit('connected');
        };

        this.socket.onclose = (event) => {
            console.log('WebSocket closed:', event.code, event.reason);
            this.isConnected = false;

            if (this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                console.log(`Reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}`);
                setTimeout(() => this.connect(), 2000);
            } else {
                this.emit('disconnected');
            }
        };

        this.socket.onerror = (error) => {
            console.error('WebSocket error:', error);
            this.emit('error', { message: 'Connection error' });
        };

        this.socket.onmessage = (event) => {
            try {
                const data = JSON.parse(event.data);
                this.handleMessage(data);
            } catch (e) {
                console.error('Failed to parse message:', e);
            }
        };
    }

    /**
     * Handle incoming messages and route to appropriate handlers
     */
    handleMessage(data) {
        const type = data.type;
        console.log('Received:', type, data);

        // Emit to specific type handlers
        this.emit(type, data);

        // Also emit to generic 'message' handlers
        this.emit('message', data);
    }

    /**
     * Send a message to the host
     */
    send(data) {
        if (!this.isConnected || !this.socket) {
            console.error('Cannot send: not connected');
            return false;
        }

        try {
            this.socket.send(JSON.stringify(data));
            console.log('Sent:', data.type, data);
            return true;
        } catch (e) {
            console.error('Send failed:', e);
            return false;
        }
    }

    /**
     * Send a join request to the host
     */
    requestJoin(playerName, characterId) {
        return this.send({
            type: 'join_request',
            name: playerName,
            character: characterId
        });
    }

    /**
     * Register a message handler
     */
    on(type, handler) {
        if (!this.messageHandlers.has(type)) {
            this.messageHandlers.set(type, []);
        }
        this.messageHandlers.get(type).push(handler);
    }

    /**
     * Remove a message handler
     */
    off(type, handler) {
        if (this.messageHandlers.has(type)) {
            const handlers = this.messageHandlers.get(type);
            const index = handlers.indexOf(handler);
            if (index !== -1) {
                handlers.splice(index, 1);
            }
        }
    }

    /**
     * Emit an event to all registered handlers
     */
    emit(type, data = {}) {
        if (this.messageHandlers.has(type)) {
            this.messageHandlers.get(type).forEach(handler => {
                try {
                    handler(data);
                } catch (e) {
                    console.error(`Handler error for ${type}:`, e);
                }
            });
        }
    }

    /**
     * Close the connection
     */
    disconnect() {
        if (this.socket) {
            this.socket.close();
            this.socket = null;
        }
        this.isConnected = false;
    }
}

// Global instance
const gameSocket = new GameSocket();
