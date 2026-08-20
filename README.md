# L Farmer

**Version:** 1.0.0  
Roblox AFK farming utility with ESP, Spectate, FullBright, Anti-AFK and Auto Run.

Stable position lock, clean modular architecture, no teleport fighting or connection stacking.

---

## Features

- **L Farmer** – Teleport + stable platform lock (no snapping / jitter)
- **L Esp** – Ticket ESP
- **L Plr Esp** – Player name ESP
- **Spectate** – Fourth floating button with live player dropdown and camera-only spectating
- **Built-in Full Bright** – Automatic, no toggle
- **Built-in Anti-AFK** – Automatic, no toggle
- **Built-in Auto Run / Activity Detection** – Lightweight, skips while locked
- Proper connection cleanup, respawn handling, player join/leave handling
- Smooth UI animations and consistent styling

---

## Installation / Loadstring

Copy and paste this into your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/loader/Loader.lua"))()
```

Or load the main source directly:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ideBob/L-Farmer/main/src/Main.lua"))()
```

---

## Repository Structure

```
/
├── README.md
├── LICENSE
├── src/
│   └── Main.lua          # Full production script
└── loader/
    └── Loader.lua        # Tiny remote loader
```

- `src/Main.lua` – All functionality lives here. Update this file to push changes to every user.
- `loader/Loader.lua` – Extremely small. Fetches the latest `Main.lua` and executes it. Fails gracefully on network errors.

---

## Configuration

Editable constants at the top of `src/Main.lua`:

```lua
local TELEPORT_POSITION = Vector3.new(0, 15000, 0)
local PLATFORM_SIZE = Vector3.new(60, 2, 60)
local LOCK_THRESHOLD = 6  -- only correct position if drifted farther than this
```

---

## Usage

1. Execute the loadstring.
2. Four floating buttons appear (draggable):
   - **L Farmer** – Toggle AFK lock on/off
   - **L Esp** – Toggle ticket ESP
   - **L Plr Esp** – Toggle player ESP
   - **Spectate** – Left-click opens player dropdown; right-click toggles spectate on/off
3. FullBright, Anti-AFK and Auto Run start automatically.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Script does nothing | Ensure your executor supports `HttpGet` + `loadstring` |
| "Failed to load" warning | Check internet / GitHub availability |
| Character snaps / teleports randomly | Make sure you are on the latest version (1.0.0+). Old versions had continuous CFrame spam. |
| Spectate camera stuck | Right-click the Spectate button or rejoin |
| Buttons missing after death | UI uses `ResetOnSpawn = false`; re-execute if needed |

---

## Credits

- Original concept & UI style: L Farmer
- Refactor, stability fixes, modular systems, Spectate, built-ins: production release

---

## License

MIT License – see [LICENSE](LICENSE)
