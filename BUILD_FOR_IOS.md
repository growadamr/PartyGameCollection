# Building Party Game Collection for iOS

This guide explains how to build and deploy the Godot host app to your iPhone.

## Architecture

```
┌─────────────────────────────┐
│  iPhone (HOST)              │
│  - Runs Godot app           │
│  - WebSocket server :8080   │
│  - QR code with IP/port     │
│  - Game display             │
└──────────────┬──────────────┘
               │ WiFi Network
        ┌──────┴──────┬──────────┐
        │             │          │
    ┌───▼───┐    ┌───▼───┐   ┌──▼────┐
    │iPhone │    │iPhone │   │iPhone │
    │Player1│    │Player2│   │Player3│
    │(Web)  │    │(Web)  │   │(Web)  │
    └───────┘    └───────┘   └───────┘
```

## Prerequisites

1. **Xcode** (already installed ✓)
2. **Godot 4.5** with iOS export templates
3. **Apple Developer Account** (free or paid)
4. **iPhone** connected via USB
5. All devices on **same WiFi network**

## Step 1: Install Godot iOS Export Templates

1. Open Godot Editor
2. Go to **Editor → Manage Export Templates**
3. Click **Download and Install**
4. Wait for download to complete (iOS templates included)

## Step 2: Configure iOS Export Settings

1. In Godot Editor, go to **Project → Export**
2. Select the **iOS** preset (should already exist)
3. Configure the following:

### Required Settings:

**Application Bundle Identifier:**
- Click on "application/bundle_identifier"
- Enter: `com.yourname.partygames` (use lowercase, no spaces)
- Example: `com.adamgrow.partygames`

**Export Method (Debug):**
- Set to: **iOS Development** (for testing on your device)

**Targeted Device Family:**
- Already set to: **iPhone & iPad** (2)

### Optional but Recommended:

**Version Info:**
- application/short_version: `1.0`
- application/version: `1`

**Export Path:**
- Set to: `builds/ios/PartyGames`

## Step 3: Export Xcode Project

1. In the Export window, click **Export Project**
2. Choose location: `builds/ios/PartyGames`
3. Make sure **Export as Xcode Project** is checked
4. Click **Save**

Godot will create an Xcode project with:
- `PartyGames.xcodeproj` - Xcode project file
- Game resources and compiled code

## Step 4: Open in Xcode

```bash
cd builds/ios/PartyGames
open PartyGames.xcodeproj
```

Or double-click `PartyGames.xcodeproj` in Finder.

## Step 5: Configure Code Signing

This is the most important step!

1. In Xcode, select the project in the left sidebar
2. Select the **PartyGames** target
3. Go to **Signing & Capabilities** tab

### For Free Apple Account (Personal Team):

1. Click **Team** dropdown
2. Click **Add Account...**
3. Sign in with your Apple ID
4. Select your Personal Team (Your Name)
5. Bundle Identifier should auto-populate
6. Check: **Automatically manage signing** ✓

**Note:** Free accounts can only deploy to your own devices for 7 days at a time.

### Trust Your Developer Certificate on iPhone:

First time only:
1. Settings → General → VPN & Device Management
2. Find your Apple ID under "Developer App"
3. Tap it and choose **Trust**

## Step 6: Connect iPhone and Deploy

1. **Connect iPhone** via USB cable
2. **Unlock your iPhone**
3. In Xcode, select your iPhone from the device dropdown (top toolbar)
4. Click the **Play button** (▶️) or press **Cmd+R**
5. Xcode will build and deploy to your iPhone

First build takes 2-5 minutes. Subsequent builds are faster.

## Step 7: Run the Game on Host iPhone

Once installed:

1. **Launch the app** on your iPhone (it should open automatically)
2. Tap **Host Game**
3. Enter your name and select character
4. Tap **Create Lobby**
5. The app will:
   - Start a WebSocket server on port 8080
   - Show a QR code with the connection URL
   - Display the connection info (IP address)

## Step 8: Connect Player iPhones

On other player iPhones:

### Option A: Scan QR Code
1. Open **Camera** app
2. Point at the host's QR code
3. Tap the notification to open Safari
4. The web player loads automatically

### Option B: Manual Entry
1. Open **Safari**
2. Navigate to the IP shown on host screen, e.g.: `http://192.168.1.100:8080`
3. The web player loads

### Join the Game:
1. Enter your player name
2. Select a character
3. Tap **Join Game**
4. Wait in lobby until host starts a game

## Troubleshooting

### "App Verification Required"
- Go to: Settings → General → VPN & Device Management
- Trust your developer certificate

### "Code Signing Error"
- Make sure you selected your Team in Xcode
- Try changing the Bundle Identifier slightly
- Enable "Automatically manage signing"

### Can't Find Device in Xcode
- Make sure iPhone is unlocked
- Reconnect USB cable
- In Xcode: Window → Devices and Simulators

### Players Can't Connect
- All devices must be on the **same WiFi network**
- Check iPhone WiFi settings (not cellular)
- Try disabling VPN on all devices
- Make sure host app is running and showing the QR code

### WebSocket Connection Fails
- The host iPhone may have firewall blocking port 8080
- Restart the host app
- Check that the IP address shown matches iPhone's actual IP

### App Crashes on Launch
- Check Xcode console for error messages
- Rebuild and redeploy
- Make sure iOS version is 14.0 or higher

## Network Setup

### Important: Local Network Permission

The first time you run the app, iOS will ask:
**"PartyGames would like to find and connect to devices on your local network"**

✅ **Tap "Allow"** - Required for other players to connect!

Without this permission, the WebSocket server won't be accessible to other devices.

### Finding Your iPhone's IP

To manually check your iPhone's IP:
1. Settings → WiFi
2. Tap the (i) icon next to your connected network
3. Look for **IP Address** (e.g., 192.168.1.100)

## Testing the Imposter Game

Once you have host + 2-3 players connected:

1. Host selects **Imposter** from game menu
2. All players see their role (Imposter/Innocent)
3. Innocents see the secret word
4. After 10 seconds, voting begins
5. Players should see a list of all player names
6. Tap a name to vote
7. When consensus is reached (all vote same person), 5-second countdown
8. Reveal if eliminated player was imposter
9. Round continues or ends

## Quick Reference

```bash
# Export from Godot
Project → Export → iOS → Export Project

# Open in Xcode
cd builds/ios/PartyGames
open PartyGames.xcodeproj

# Build and run
Select iPhone device → Press ▶️ (Cmd+R)
```

## Next Steps After Testing

- Add app icons (different sizes required)
- Test with more players (up to 8)
- Test all 7 games on mobile
- Optimize UI for smaller screens
- Add touch-friendly controls

## Notes

- Free Apple Developer accounts: Apps expire after 7 days (just rebuild)
- Paid Developer accounts: Apps work for 1 year
- For App Store release, you need a paid account ($99/year)
- This is for testing/development only
