# Project: THE ROOM REMEMBERS v1.3.0 Release

## Architecture
- **Engine**: Godot 4.7 Engine (GDScript, Headless CLI, Android Export Template).
- **Core Systems**:
  - `scripts/autoload/`: `GameState`, `RoomManager`, `CurseManager`, `AudioManager`, `SaveManager`, `EndingManager`, `MobileInputManager`.
  - `scripts/player/`: `player_controller.gd`, `soul_slash_wave.gd`.
  - `scripts/world/`: `room_transition.gd`, `weight_stone.gd`, `corpse.gd`, `echo_altar.gd`, `echo_twin.gd`, `keeper_controller.gd`, `memory_shade_walking.gd`, `memory_shade_shielded.gd`, `cracked_mirror.gd`.
  - `scripts/ui/`: `session_menu.gd`, `journal_map.gd`, `ui_gate.gd`, `credits_scroll.gd`, `code_seal_base.gd`, `region_title_card.gd`.
  - `scripts/dev/`: `door_audit.gd`, `release_audit.gd`, `controls_audit.gd`, `save_robust_audit.gd`, `death_loop_audit.gd`, `e2e_runner.gd`.
  - `scenes/rooms/`: 30 room scenes (`core.tscn`, `core_seal_chamber.tscn`, `decay_weight.tscn`, `awakening_room.tscn`, etc.).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | `decay_weight` softlock & hybrid push | Configure `weight_stone.gd` collision layers (1 \| 8) and add slide push in `player_controller.gd` | M1 | R1 P0-1 |
| 2 | Gothic door visuals layering | Set door z-index (`DoorBack`, `DoorInnerLight`, `DoorFrame`, `DoorSeal`) to 1 to render above parallax and below terrain | M1 | R1 P0-2 |
| 3 | Save system Windows overwrite | Safe `.bak` rotation before overwriting `torimon_save.json` to prevent `ERR_ALREADY_EXISTS` | M1 | R1 P0-4 |
| 4 | `ShadowDash` collision mask leaks | Restore `collision_mask = 1 \| LAYER_CURSE_BARRIER` on dash interruption, death, or curse stagger | M1 | R1 P1-1 |
| 5 | Player sword `AttackArea` vertical offset | Correct sword `AttackArea` offset from y=0 to body center (y=-20) | M1 | R1 P1-2 |
| 6 | Corpse push raycasts & safe floor | Add raycast collision checks to corpse push and record hazard death corpses at safe floor | M1 | R1 P1-5 |
| 7 | EchoAltar transition cleanup & passive doors | Disconnect altar signals on room transition and fix passive door layer persistence | M1 | R1 P1-3, P1-4 |
| 8 | Audio worker thread & ambient triggers | Ensure `_sem.post()` on task enqueue, eliminate main thread synthesis hitches, trigger ambient audio on save continuation and title screen | M2 | R1 P0-3 |
| 9 | Core room exit & final guidance | Add exit door on left of `core.tscn` to `core_seal_chamber` (`Vector2(880, 288)`); v3: choice pads removed, single final (`FinalSequence`, END OF PART I), Shilda warning | M2 | R1 P0-5 |
| 10 | Shilda spawn timing & corpse mourning | Prevent Shilda in wrong rooms / after defeat, defer mystery beat until title closes, mourn by active room ID | M2 | R1 P0-6, P0-7 |
| 11 | Android renderer & audio effects | Set `renderer/rendering_method.mobile="gl_compatibility"`, optimize particles, consolidate reverb | M2 | R1 P0-8 |
| 12 | UiGate layer flags | Separate `UiGate` layer flags (`TITLE`, `PAUSE_MENU`, `JOURNAL`) to eliminate input bleed | M2 | R1 P1-6 |
| 13 | Final skip input (was EndingUI double touch skip) | v3: `ending_ui.gd` deleted; final skip is event-based `SkipListener` in `final_sequence.gd` (ui_cancel only after `final_seen`) | M2 | R1 P1-7 |
| 14 | Save creation & state persistence | Prevent premature save on defocus, persist curse level, reset `time_scale = 1.0`, delete stale `.prev` | M2 | R1 P1-8, P1-9, P1-10 |
| 15 | Puzzle hints & room inheritance | Reconcile library witness hints, conduit timing (3.8s), inherit `awakening_room.gd` from `room_atmosphere.gd` | M2 | R1 P1-11, P1-12 |
| 16 | Door transition labels | Center door labels horizontally and clamp within room bounds | M2 | R1 P2-1 |
| 17 | Pause button SafeArea & orientation | Move pause button into `SafeArea`, hide during modals, set `orientation=6` (`sensor_landscape`) | M2 | R1 P2-2 |
| 18 | Journal typography & tabs | Fix right page title wrapping (`anchor_right = 1.0`), tab padding | M2 | R1 P2-3 |
| 19 | SealCode fullscreen dim & 3x4 keypad | Cover entire viewport including notch with dim, standard 3x4 keypad layout, direct close on cancel | M2 | R1 P2-4 |
| 20 | Android system back navigation | Intercept back key / gesture across all overlay modals | M2 | R1 P2-5 |
| 21 | Mobile interaction hints & skill icon | Use `"El · ..."` hint, replace skill icon with `slash.png`, eliminate touch button circle overlap | M2 | R1 P2-6 |
| 22 | Walking Memory Shade | Advance towards player, take knockback, drop clarity motes (+10% clarity) on 3-hit combo finisher | M3 | R2 Combat |
| 23 | Shielded Memory Shade | Reflect basic attacks, shield broken by `SoulSlash`, bypassed by `ShadowDash` flank | M3 | R2 Combat |
| 24 | Corpse one-way top platforming | Set `one_way_collision = true`, `margin = 8.0` on `corpse.tscn` to enable jumping on corpses as platforms | M3 | R2 Emergent |
| 25 | EchoAltar attack & skill recording | Record and replay attack and skill actions on `EchoTwin` alongside movement | M3 | R2 Emergent |
| 26 | Mobile haptic feedback & toggle | Micro-haptics (`Input.vibrate_handheld`) on hits (18ms), seals (35ms), death (45ms) with Settings toggle | M3 | R2 Feel |
| 27 | Gothic Region Title Cards | Title card HUD stinger (`&"discovery"`) on first entry to each of the 6 regions | M3 | R2 Feel |
| 28 | Cracked Mirror fast travel | Discovered cracked mirrors act as fast-travel anchors between regional hubs | M3 | R2 Feel |
| 29 | Dev audit updates | Update `door_audit.gd` (z-index >= 1), `release_audit.gd` (layer 8, core exit, save overwrite), `controls_audit.gd` | M4 | R3 Audits |
| 30 | Headless test suite & smoke test | Fix `_headless_faz67_smoke` shard requirements, ensure 0 errors in all dev audits and main smoke test | M4 | R3 Tests |
| 31 | POCO X6 Pro 5G Android APK build & test | Build APK with Godot export, install via ADB to `QC59AM55BMCIEUHQ`, verify launch and execution | M4 | R3 Android |
| 32 | Versioning & export configuration | Update `project.godot` to version 1.3.0, `export_presets.cfg` to versionCode 17 and name "1.3.0" | M5 | R4 Version |
| 33 | Git commit, tag, and GitHub Release | Git commit all changes, tag `v1.3.0`, publish release with APK binary to `https://github.com/jagwey/THE-ROOM-REMEMBERS` | M5 | R4 Release |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Physics & Core Systems Bugfixes | Features 1–7 (Weight stone, Door z-index, Windows save overwrite, ShadowDash mask, Sword attack offset, Corpse raycasts, EchoAltar cleanup) | none | DONE |
| M2 | Audio, Scene Flow & UI/Mobile Bugfixes | Features 8–21 (Audio worker & ambience, Core exit & final guidance, Shilda timing/mourning, Mobile renderer & orientation, UiGate, FinalSequence, Journal, SealCode, Mobile UI hints) | M1 | IN_PROGRESS |
| M3 | Combat & Emergent Mechanics | Features 22–28 (Walking & Shielded Shades, Corpse one-way platforming, Echo attack/skill replay, Mobile haptics & settings toggle, Region title cards, Cracked mirror fast travel) | M1 | DONE |
| M4 | Audits, Tests & POCO X6 Pro Deployment | Features 29–31 (Update door_audit, release_audit, controls_audit, fix main.gd smoke test, build Android APK, install & verify via ADB on POCO X6 Pro 5G) | M1, M2, M3 | PLANNED |
| M5 | Versioning & GitHub v1.3.0 Release | Features 32–33 (project.godot & export_presets versioning, git commit, tag v1.3.0, GitHub release creation with APK artifact) | M4 | PLANNED |

## Interface Contracts
### Player ↔ WeightStone
- `WeightStone` collision layer: `1 | 8` (`LAYER_WORLD | LAYER_INTERACT`).
- `Player.InteractArea`: collision mask: `8` (`LAYER_INTERACT`).
- Interaction: calls `target.apply_push(_facing)` and `target.on_interact(self)`.
- Physical Slide: `player_controller.gd` detects `get_slide_collision(i)` on bodies with `apply_push()`, moving stone smoothly.

### Player / SoulSlash ↔ Memory Shades
- Shade collision layer: `4` (`LAYER_HITBOX`), collision mask: `1` (`LAYER_WORLD`).
- `receive_sword_hit(attacker: Node, facing: float, combo: int) -> void`:
  - Walking Shade: takes knockback; if `combo == 2`, dies and spawns `res://assets/props/memory_mote.png` (+10% clarity via `CurseManager.clear_curse(10.0)`).
  - Shielded Shade: if attacked from front (`(attacker.pos.x - pos.x) * _facing < 0`) and not broken, reflects hit with spark and hitstop; if attacked from behind (via `ShadowDash`) or broken, takes normal damage.
- `receive_soul_slash(slash_wave: Node) -> void`:
  - Breaks Shielded Shade's shield immediately with shatter sound.

### Corpse ↔ Platforming
- `scenes/world/corpse.tscn`: `AnimatableBody2D`, `collision_layer = 1`, `collision_mask = 0`.
- Collision shape: `one_way_collision = true`, `one_way_collision_margin = 8.0`.
- Player standing on corpse reaches jump height of `76.0 px` above ground floor, enabling 75–80px ledges.

### EchoAltar ↔ EchoTwin
- `_events` array captures `[timestamp, action_name]`:
  - `"interact"`: calls interact on overlapping interactables.
  - `"attack"`: executes sword strike hitting layer 4 / breakables.
  - `"skill"`: spawns `soul_slash_wave.gd`.

### MobileInputManager ↔ Haptics
- `vibrate(duration_ms: int) -> void`:
  - Checks `haptics_enabled` setting (from `user://settings.cfg`).
  - Calls `Input.vibrate_handheld(duration_ms)`.

### RoomManager ↔ Region Title Cards & Cracked Mirrors
- Region mapping: `awakening`, `decay`, `library`, `experiment`, `mirrors`, `core`.
- On room enter: if region not in `world_memory_state["regions_visited"]`, triggers `HudController.show_region_title(region_name)` and plays stinger `&"discovery"`.
- Cracked Mirror interaction: checks discovered mirrors in `world_memory_state["unlocked_mirrors"]`, displays travel modal, and calls `RoomManager.enter_room(target_room_id, spawn_point)`.

## Code Layout
- `scripts/autoload/`: Engine autoload singletons.
- `scripts/player/`: Player mechanics, controller, skills.
- `scripts/world/`: Interactables, doors, shades, corpses, altars.
- `scripts/ui/`: HUD, modals, settings, keypad, dialogue.
- `scripts/dev/`: Headless audit and validation scripts.
- `scenes/`: Room scenes, player, props, UI scenes.
- `export_presets.cfg`: Android APK export configuration.
- `project.godot`: Project settings, versioning, renderer settings.
