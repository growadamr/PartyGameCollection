# Party Games - Web Player

This is the web-based player interface for Party Games. Players scan a QR code and join the game through their mobile browser - no app installation required.

## How It Works

1. Host runs the native Godot app on their phone
2. QR code is generated with URL: `https://[your-domain]/play?host=[ip]&port=8080`
3. Players scan QR code, web app loads in browser
4. Web app connects via WebSocket to host's local IP
5. Players interact through the web interface

## Hosting Options

### Option 1: GitHub Pages (Recommended)

1. Push this `web-player` folder to a GitHub repository
2. Enable GitHub Pages in repository settings
3. Update the QR code URL in the Godot app to point to your GitHub Pages URL

```
https://[username].github.io/[repo]/web-player/?host={IP}&port=8080
```

### Option 2: Netlify / Vercel

1. Connect your repository to Netlify or Vercel
2. Set the publish directory to `web-player`
3. Deploy and use the provided URL

### Option 3: Local Testing

For local development, use any static file server:

```bash
# Python
cd web-player
python -m http.server 8000

# Node.js (with http-server)
npx http-server web-player

# PHP
cd web-player
php -S localhost:8000
```

Then open `http://localhost:8000?host=192.168.1.X&port=8080`

## File Structure

```
web-player/
├── index.html          # Main HTML file
├── css/
│   └── style.css       # Mobile-first styling
└── js/
    ├── websocket.js    # WebSocket connection handler
    ├── app.js          # Main application logic
    └── games/
        ├── charades.js  # Charades game UI
        ├── wordbomb.js  # Word Bomb game UI
        ├── quickdraw.js # Quick Draw game UI
        ├── whosaidit.js # Who Said It game UI
        ├── fibbage.js   # Fibbage game UI
        └── trivia.js    # Trivia Showdown game UI
```

## URL Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `host` | Host device IP address | `192.168.1.5` |
| `port` | WebSocket port (default: 8080) | `8080` |

## Supported Games

- **Charades**: Actor sees prompt, guessers submit guesses
- **Word Bomb**: Type words containing letter combinations
- **Quick Draw**: Draw/guess with touch canvas support
- **Who Said It?**: Write anonymous answers, guess who wrote each one
- **Fibbage**: Submit lies, vote for the truth, fool other players
- **Trivia Showdown**: Answer multiple choice questions with speed bonus

## Browser Support

- iOS Safari 12+
- Chrome for Android 70+
- Any modern mobile browser with WebSocket support

## Development

The web player communicates with the Godot host using the same WebSocket message protocol. Message types include:

### Connection
- `join_request` - Player requests to join
- `join_accepted` - Host confirms join with player_id

### Game Messages
- `game_starting` - Host starts a game
- `charades_*` - Charades game messages
- `word_bomb_*` - Word Bomb game messages
- `quickdraw_*` - Quick Draw game messages
- `whosaid_*` - Who Said It game messages
- `fibbage_*` - Fibbage game messages
- `trivia_*` - Trivia Showdown game messages

See the Godot `network_manager.gd` for the complete protocol.
