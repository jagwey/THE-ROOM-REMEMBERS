# THE ROOM REMEMBERS — Asset Inventory (corrected)

**Game repo (authoritative Godot project):**  
`C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\THE-ROOM-REMEMBERS`  
→ GitHub: `jagwey/THE-ROOM-REMEMBERS`  
**Engine:** Godot **4.7** (`config/features` includes `4.7`)

**Art / zip source (moodboard pack, not the game repo):**  
`C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\bekci`  
(ASCII alias people expect: `...\Desktop\Projects\bekci` — on this machine the parent folder is `Projects プロジェクト`.)

---

## Roles

| Location | Role |
|----------|------|
| `THE-ROOM-REMEMBERS/` | Playable Godot **4.7** game (scenes, scripts, imported `assets/`) |
| `bekci/` | Torimon asset pack v0.1 — zips, source sheets, preview demo, generation docs |
| `bekci/packages/*.zip` | Canonical zip archives of the pack |

Do **not** treat `bekci/project.godot` as the shipping game; it remains an asset preview. Game target is this repo.

---

## Wired into Godot (`res://` in THE-ROOM-REMEMBERS)

### Player — Noroi
- `res://assets/characters/noroi.tres`
- `res://assets/characters/noroi_sheet.png`
- `res://assets/characters/noroi/frame_00.png` … `frame_15.png`

### Keeper — Bekçi
- `res://assets/characters/keeper.tres`
- `res://assets/characters/keeper_sheet.png`
- `res://assets/characters/keeper/frame_00.png` … `frame_15.png`

### NPC helpers
- `res://assets/characters/npc.tres` + sheet + frames

### Awakening room (FAZ 1–2)
- `res://assets/backgrounds/awakening/far.png`
- `res://assets/backgrounds/awakening/mid.png`
- `res://assets/backgrounds/awakening/front.png`

### Other rooms (copied, not yet scenes)
- `res://assets/backgrounds/{decay,library,experiment,mirrors,core}/{far,mid,front}.png`

### Mobile HUD
- `res://assets/hud/joystick_base.png`, `joystick_thumb.png`
- `res://assets/hud/attack.png`, `dash.png`, `interact.png`
- `res://assets/hud/heart_full.png`, `heart_empty.png`
- (+ journal/pause/settings/speech/tabs/diamonds/health_bar)

### Props / panels / layers / tiles
- `res://assets/props/*`, `res://assets/panels/*`, `res://assets/layers/*`, `res://assets/tiles/*`

### Palette
- void `#221B27`, deep_stone `#322A39`, stone `#493F51`, pale_lilac `#AB98A9`, ivory `#E1D3D1`, crimson `#7E2D3A`, dark_red `#521D29`
- Files: `palette.json`, `palette.gpl`

---

## Still only in bekci pack (not in game repo)

- `bekci/packages/Torimon_Asset_Pack_v0.1.zip` (~28 MB)
- `bekci/packages/Torimon_Game_Assets_Only.zip` (~5 MB)
- `bekci/source/*_generated.png`, `concept_reference.png`
- `bekci/previews/*`, generation prompts, validation scripts
- Audio: **none** in either location

---

## Scene / script targets (this repo)

| Path | Purpose |
|------|---------|
| `res://scenes/main/main.tscn` | Main tree |
| `res://scenes/rooms/awakening.tscn` | Uyanış |
| `res://scenes/player/player.tscn` | Noroi |
| `res://scenes/keeper/keeper.tscn` | Observation-only Keeper |
| `res://scenes/ui/hud.tscn` | Hearts + mobile controls |
| `res://scripts/autoload/*.gd` | Managers |

---

## Counts (in this repo)

- ~138 PNG under `assets/`
- 3 SpriteFrames `.tres`
- 0 audio files
