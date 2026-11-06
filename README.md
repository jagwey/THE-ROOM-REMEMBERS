# THE ROOM REMEMBERS

**Slogan:** You forget. It remembers.  
**Studio:** TORIMON  
**Engine:** Godot **4.7** · GDScript · Android-first · Turkish UI  
**Repo:** [jagwey/THE-ROOM-REMEMBERS](https://github.com/jagwey/THE-ROOM-REMEMBERS)

## Run

1. Open this folder in **Godot 4.7**.
2. Main scene: `scenes/main/main.tscn` (set in `project.godot`).
3. Press **F5**.

Controls: arrows/WASD move · **Z/J** attack · **X/K** dash · **E/F** interact · on-screen mobile HUD.

## Asset source

Moodboard / zip art originally lives in the local pack folder:

`C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\bekci`

Playable PNGs + SpriteFrames used by the game are copied into `assets/` in this repo. Source sheets / full zips stay in the bekci pack (not duplicated here).

## Status (FAZ 1–2)

- Side-view player: walk / attack / dash / interact
- Mobile joystick + buttons, hearts UI (TR strings)
- Awakening room backgrounds wired
- Keeper observation-only stub (no early kill)
- Autoload stubs: GameState (3 knowledge layers), Curse/Death/Corpse/Echo/Puzzle/Dialogue/Save/Ending, MobileInput

Next: **FAZ 3** — scripted Keeper (warn / intervene).
