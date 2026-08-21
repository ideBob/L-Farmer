# L Farmer

**Version:** 1.3.0  
Roblox AFK farming utility with ESP, Spectate, FullBright, Anti-AFK, Auto Run, Spotify and **YouTube Player By L**.

---

## Features

- **L Farmer** – Stable platform lock (no snapping)
- **L Esp / L Plr Esp** – Ticket & player ESP
- **Spectate** + **Turn Off Spectate**
- **Spotify** – Session token dashboard
- **YouTube Player By L** – API-key search dashboard (thumbnails, open/copy link)
- Built-in Full Bright, Anti-AFK, Auto Run

---

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/loader/Loader.lua"))()
```

---

## YouTube Player By L

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/) and enable **YouTube Data API v3**.
2. Create an API key and restrict it to YouTube Data API v3 if desired.
3. Open the **YouTube** floating button → paste key → **Apply**.
4. Search box appears. Results show thumbnail, title, channel. **Open** copies the watch URL (clipboard when supported).

The key is stored **only in memory for the current session**. It is never logged or committed.

> Note: Roblox cannot embed a full interactive YouTube player. The UI provides search + metadata + one-click link access.

---

## Spotify

Requires a short-lived OAuth **access token** (not a simple API key). See previous docs for scopes.

---

## Repository

```
/
├── README.md
├── LICENSE
├── src/
│   ├── Main.lua
│   ├── SpotifyAPI.lua
│   └── YouTubeAPI.lua
└── loader/
    └── Loader.lua
```

---

## License

MIT
