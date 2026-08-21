# L Farmer

**Version:** 1.2.0  
Roblox AFK farming utility with ESP, Spectate, FullBright, Anti-AFK, Auto Run and Spotify dashboard.

Stable position lock, clean modular architecture, no teleport fighting or connection stacking.

---

## Features

- **L Farmer** – Teleport + stable platform lock (no snapping / jitter)
- **L Esp** – Ticket ESP
- **L Plr Esp** – Player name ESP
- **Spectate** – Floating button with live player dropdown and camera-only spectating
- **Turn Off Spectate** – Instantly restores normal camera control
- **Spotify** – Session-token dashboard (Now Playing, Recently Played, Playlists, Liked Songs)
- **Built-in Full Bright** – Automatic
- **Built-in Anti-AFK** – Automatic
- **Built-in Auto Run** – Lightweight activity detection

---

## Installation / Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/loader/Loader.lua"))()
```

Or load the main source directly:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Main.lua"))()
```

---

## Spotify Setup

Spotify does **not** use simple API keys. You need a temporary **OAuth access token** with the right scopes.

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) and create an app.
2. Use the Authorization Code flow (or a trusted token generator that supports user scopes) to obtain a short-lived access token with at least:
   - `user-read-currently-playing`
   - `user-read-recently-played`
   - `user-read-playback-state`
   - `playlist-read-private`
   - `user-library-read`
3. Open the **Spotify** button in the script UI.
4. Paste the access token into the field and press **Apply Key**.
5. The token is kept **only in memory for the current session**. It is never written to disk, never logged, and never committed.

Tokens expire (usually after 1 hour). When they expire, paste a fresh one.

---

## Repository Structure

```
/
├── README.md
├── LICENSE
├── src/
│   ├── Main.lua          # Main script + UI
│   └── SpotifyAPI.lua    # Modular Spotify client
└── loader/
    └── Loader.lua        # Tiny remote loader
```

---

## Configuration

Editable constants in `src/Main.lua`:

```lua
local TELEPORT_POSITION = Vector3.new(0, 15000, 0)
local PLATFORM_SIZE = Vector3.new(60, 2, 60)
local LOCK_THRESHOLD = 6
```

---

## Usage

Floating buttons (all draggable):

| Button | Action |
|--------|--------|
| L Farmer | Toggle AFK lock |
| L Esp | Toggle ticket ESP |
| L Plr Esp | Toggle player ESP |
| Spectate | Open player list / right-click toggle |
| Turn Off Spectate | Force-stop spectate + restore camera |
| Spotify | Open Spotify dashboard |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script does nothing | Executor must support `HttpGet` + `loadstring` |
| Spotify “No supported HTTP request method” | Your executor needs `syn.request` / `http.request` / equivalent for Authorization headers |
| Invalid or expired token | Generate a new access token |
| Missing permissions / scopes | Token must include the scopes listed above |
| Spectate camera stuck | Press **Turn Off Spectate** |

---

## Security Notes

- Access tokens live only in process memory for the current session.
- The token field is cleared after Apply.
- Tokens are never printed, never stored in the repo, and never sent anywhere except Spotify’s official API.
- On UI destroy the token is explicitly cleared.

---

## License

MIT License – see [LICENSE](LICENSE)
