# THE ROOM REMEMBERS v1.3.0 — Test Infrastructure & Test Plan (TEST_INFRA.md)

## 1. Test Philosophy & Principles

### 1.1 Opaque-Box & Requirement-Driven Testing
All tests in this suite operate strictly as **opaque-box tests**. Rather than inspecting or asserting on transient private variables or coupling to internal implementation quirks, tests interface with the system through:
1. Public methods and lifecycle functions (`on_interact()`, `receive_sword_hit()`, `apply_push()`, `enter_room()`).
2. Engine-level collision layers, physics masks, and scene tree nodes (`CollisionObject2D.collision_layer`, `Area2D.collision_mask`, `z_index`).
3. Autoload contracts (`GameState`, `RoomManager`, `CurseManager`, `SaveManager`, `EndingManager`, `MobileInputManager`).
4. Configuration and export artifacts (`project.godot`, `export_presets.cfg`, save file JSON serialization).

Every single test assertion is authoritatively derived from:
- `ORIGINAL_REQUEST.md` (R1 P0/P1/P2 fixes, R2 combat/feel mechanics, R3 audits, R4 release).
- `PROJECT.md § Feature Inventory` (Features 1 through 33).
- `PROJECT.md § Interface Contracts` (Player ↔ WeightStone, Player/SoulSlash ↔ Memory Shades, Corpse ↔ Platforming, EchoAltar ↔ EchoTwin, MobileInputManager ↔ Haptics, RoomManager ↔ Region Title Cards & Cracked Mirrors).

### 1.2 Progressive Testability & Fault Isolation
Tests are architected with progressive testability:
- Each tier and milestone feature can be independently exercised.
- State is strictly sandboxed. The test harness isolates user data by enforcing `TORIMON_TEST="1"` (`user://qa/torimon_save.json`), ensuring zero contamination of player save data.
- State resets between checks (`TORIMON_FRESH="1"`, `GameState.reset()`, `RoomManager` cleanup) guarantee test independence and prevent order-dependent flakiness.

---

## 2. Test Execution Architecture

### 2.1 Invocation Syntax
Tests are executed headlessly using Godot 4.7.2:
```powershell
$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & godot --headless --path . -s res://scripts/dev/e2e_runner.gd
```

To run individual dev audit suites:
```powershell
# Gothic door layering & transition audit:
$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & godot --headless --path . -s res://scripts/dev/door_audit.gd

# Room graph & collision isolation audit:
$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & godot --headless --path . -s res://scripts/dev/release_audit.gd

# Player controls & mechanics audit:
$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & godot --headless --path . -s res://scripts/dev/controls_audit.gd

# Windows save robustness audit:
$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & godot --headless --path . -s res://scripts/dev/save_robust_audit.gd
```

### 2.2 Environment Variables Matrix
| Variable | Value | Purpose |
| :--- | :--- | :--- |
| `TORIMON_TEST` | `"1"` | Redirects save paths to `user://qa/` to protect player saves |
| `TORIMON_FRESH` | `"1"` | Wipes stale runtime and puzzle memory for a clean test baseline |
| `TORIMON_NO_AUTO_DIALOGUE` | `"1"` | Suppresses opening story dialogs that freeze physics or input |
| `TORIMON_TIER` | `"all"`, `"1"`, `"2"`, `"3"`, `"4"` | Selects execution tier in `e2e_runner.gd` (default: `"all"`) |
| `TORIMON_SMOKE` | `"1"` | Triggers headless end-to-end smoke test in `main.gd` |

### 2.3 Output Reporting
Results are printed to stdout in human-readable format and serialized to `res://build/qa/e2e-report.json`:
```json
{
  "total": 33,
  "passed": 33,
  "failed": 0,
  "skipped": 0,
  "tiers": {
    "tier1_features": { "total": 33, "passed": 33, "failed": 0 },
    "tier2_boundaries": { "total": 8, "passed": 8, "failed": 0 },
    "tier3_combinations": { "total": 5, "passed": 5, "failed": 0 },
    "tier4_scenarios": { "total": 4, "passed": 4, "failed": 0 }
  },
  "checks": [...]
}
```

---

## 3. 4-Tier Test Methodology

### 3.1 Tier 1: Feature Coverage (Sanity & Interface Contracts)
Covers all 33 features from `PROJECT.md § Feature Inventory` individually with contract verification.

### 3.2 Tier 2: Boundary & Corner Conditions
Stresses edge behaviors, input rates, extremes, and hardware variances:
- Rapid button/interact spam (debounce filtering on doors, altars, and weight stone).
- Extreme rapid consecutive saves (10+ calls in <100ms on Windows filesystem).
- Zero health / max curse (curse >= 100%, 0 hearts during room transition or mid-dash).
- Screen aspect ratio bounds (20:9 POCO X6 Pro 2712×1220 ultrawide vs standard 16:9).
- Viewport notch padding & Safe Area compliance for overlay UI.
- Mouse emulation event rejection (`DEVICE_ID_EMULATION` suppression).

### 3.3 Tier 3: Component Combinations & Emergent Interactions
Verifies cross-system synergy:
- **Corpse Platforming + Shade Combat**: Standing on a previous death corpse to strike elevated or shielded shades.
- **Echo Twin + Weight Stone & Levers**: Echo twin holding a pressure plate while player pushes a weight stone through a opened barrier.
- **ShadowDash + Shielded Shade Flank**: Bypassing a shield reflection from the rear using ShadowDash invulnerability.
- **Save/Load State Fidelity**: Saving while cursed with dead shades and corpses, reloading, and verifying exact room state reconstruction.
- **Cracked Mirror Hub + Region Title Cards**: Fast-traveling across regional hubs and verifying HUD title cards trigger only once per region.

### 3.4 Tier 4: Real-World Scenarios & Full Game Progression
End-to-end scenario validation:
- **Awakening to Core Progression**: Traversal through Awakening, Decay, Library, Experiment, Mirrors, to Core.
- **Good Ending Shard Sequence**: Obtaining both `seal_shard_1` and `seal_shard_2`, entering Core, receiving Shilda guidance, and completing Good Trust Seal.
- **Death Loop & Corpse Accumulation**: Player dying on hazards, safely placing corpse platform, and using it to overcome obstacle.
- **Complete Mobile Session Simulation**: Simulating POCO X6 Pro 5G environment (Sensor Landscape, Safe Area, Touch controls, Haptics toggle, System Back navigation).

---

## 4. Feature Inventory Mapping (Features 1–33)

| # | Feature | Milestone | Source | Tier | Target Script / Method | Authoritative Expected Contract |
|---|---------|-----------|--------|------|------------------------|---------------------------------|
| 1 | `decay_weight` softlock & hybrid push | M1 | R1 P0-1 | T1, T2, T3 | `weight_stone.gd`, `player_controller.gd` | Stone `collision_layer` has bits 1 & 8 (`1 \| 8`). `Player/InteractArea.collision_mask` has bit 8. Walk push calls `apply_push()`; pressing interact calls `apply_push()`. |
| 2 | Gothic door visuals layering | M1 | R1 P0-2 | T1, T2 | `room_transition.gd`, `door_audit.gd` | Across all 30 rooms: `DoorBack`, `DoorInnerLight`, `DoorFrame`, `DoorSeal` have `z_index >= 1` (above parallax background at `z=0`) and `< player.z_index` (`z=5`). |
| 3 | Save system Windows overwrite | M1 | R1 P0-4 | T1, T2 | `save_manager.gd`, `save_robust_audit.gd` | Two or more consecutive `save_game()` calls succeed without `ERR_ALREADY_EXISTS` (code 32) using safe `.bak` rotation. |
| 4 | `ShadowDash` collision mask leaks | M1 | R1 P1-1 | T1, T2 | `player_controller.gd` | On dash interruption, death, or curse stagger, `collision_mask` is restored to `1 \| LAYER_CURSE_BARRIER` (bit 1 \| 16 = 17). |
| 5 | Player sword `AttackArea` vertical offset | M1 | R1 P1-2 | T1 | `player_controller.gd` | `AttackArea` vertical offset is centered at `y = -20.0` (±2px), matching character chest/body center. |
| 6 | Corpse push raycasts & safe floor | M1 | R1 P1-5 | T1, T2, T4 | `corpse.gd`, `corpse_manager.gd` | Pushing corpse checks wall/hazard raycasts; hazard deaths place corpse at last safe floor position (`player._safe_floor_pos`). |
| 7 | EchoAltar transition cleanup & passive doors | M1 | R1 P1-3, P1-4 | T1, T3 | `echo_altar.gd`, `built_room.gd` | Room exit cleans up altar recording/playback signals. Re-entering passive room does not re-enable door collision. |
| 8 | Audio worker thread & ambient triggers | M2 | R1 P0-3 | T1 | `audio_manager.gd` | `_sem.post()` called on enqueue. Save continuation and room entry trigger region ambient track. Title screen plays title ambience. |
| 9 | Core room exit & good ending guidance | M2 | R1 P0-5 | T1, T4 | `scenes/rooms/core.tscn`, `ending_manager.gd` | `core.tscn` contains exit door leading to `core_seal_chamber` (`Vector2(880, 288)`). Choice pads have visual runes. Missing shards trigger Shilda warning. |
| 10 | Shilda spawn timing & corpse mourning | M2 | R1 P0-6, P0-7 | T1 | `keeper_controller.gd`, `room_manager.gd` | Shilda never spawns in wrong rooms or after defeat. Intro mystery deferred until title closes. Mourning filters corpses by active room ID. |
| 11 | Android renderer & audio effects | M2 | R1 P0-8 | T1 | `project.godot`, `audio_manager.gd` | `project.godot` specifies `renderer/rendering_method.mobile="gl_compatibility"`. Audio buses consolidate reverb. |
| 12 | UiGate layer flags | M2 | R1 P1-6 | T1, T2 | `ui_gate.gd` | Distinct flags for `TITLE`, `PAUSE_MENU`, `JOURNAL`. Setting one does not bleed input or clear another layer inappropriately. |
| 13 | EndingUI double touch skip | M2 | R1 P1-7 | T1, T2 | `ending_ui.gd` | Rejects `event.device == InputEvent.DEVICE_ID_EMULATION` mouse events following touch; prevents double-skipping text lines. |
| 14 | Save creation & state persistence | M2 | R1 P1-8, P1-9, P1-10 | T1, T3 | `save_manager.gd`, `game_state.gd` | No save created on title defocus. Curse level persisted across save/load. `Engine.time_scale` reset to 1.0. Stale `.prev` files deleted on new game. |
| 15 | Puzzle hints & room inheritance | M2 | R1 P1-11, P1-12 | T1 | `awakening_room.gd`, `experiment_core_conduit.gd` | `awakening_room.gd` inherits from `room_atmosphere.gd`. Conduit puzzle timer is `3.8s`. Library witness hints reconciled with page puzzle. |
| 16 | Door transition labels | M2 | R1 P2-1 | T1, T2 | `room_transition.gd` | Transition labels horizontally centered and clamped within room bounds (`[32.0, room_width - 32.0]`). |
| 17 | Pause button SafeArea & orientation | M2 | R1 P2-2 | T1, T2 | `hud_controller.gd`, `project.godot` | Pause button placed inside `SafeArea`, hidden during open modals. `project.godot` sets `window/handheld/orientation=6` (`sensor_landscape`). |
| 18 | Journal typography & tabs | M2 | R1 P2-3 | T1 | `journal_map.gd` | Right page title wrapping sets `anchor_right = 1.0` with autowrap enabled; tabs have minimum 12px touch padding. |
| 19 | SealCode fullscreen dim & 3x4 keypad | M2 | R1 P2-4 | T1, T2 | `code_seal_base.gd` | Dim overlay covers full viewport (`anchor_right=1.0`, `anchor_bottom=1.0`). Keypad laid out in 3x4 grid with direct close on cancel. |
| 20 | Android system back navigation | M2 | R1 P2-5 | T1, T2 | `gothic_modal_panel.gd`, `ui_gate.gd` | Android back button / `ui_cancel` dismisses uppermost active modal without exiting the game. |
| 21 | Mobile interaction hints & skill icon | M2 | R1 P2-6 | T1 | `hud_controller.gd` | Interaction hint displays `"El · ..."`. Skill button icon texture is `slash.png`. Touch button hitboxes do not overlap. |
| 22 | Walking Memory Shade | M3 | R2 Combat | T1, T3 | `memory_shade_walking.gd` | Advances toward player, takes knockback, dies on 3-hit combo finisher and drops clarity mote (`+10%` clarity via `CurseManager.clear_curse(10.0)`). |
| 23 | Shielded Memory Shade | M3 | R2 Combat | T1, T3 | `memory_shade_shielded.gd` | Reflects frontal basic attacks with spark/hitstop. Shield broken by `SoulSlash` wave or bypassed by flanking via `ShadowDash`. |
| 24 | Corpse one-way top platforming | M3 | R2 Emergent | T1, T2, T3 | `corpse.tscn`, `corpse.gd` | Corpse collision has `one_way_collision = true`, `margin = 8.0`. Player jump height from corpse reaches `76.0 px` above ground, enabling 75–80px ledges. |
| 25 | EchoAltar attack & skill recording | M3 | R2 Emergent | T1, T3 | `echo_altar.gd`, `echo_twin.gd` | Records `[timestamp, "attack"]` and `[timestamp, "skill"]`. `EchoTwin` replays sword strikes and spawns `soul_slash_wave.gd`. |
| 26 | Mobile haptic feedback & toggle | M3 | R2 Feel | T1, T2 | `mobile_input_manager.gd`, `session_menu.gd` | Micro-haptics (`Input.vibrate_handheld`) on sword hit (18ms), seal break (35ms), and death (45ms). Controlled by `haptics_enabled` toggle in Settings. |
| 27 | Gothic Region Title Cards | M3 | R2 Feel | T1, T3 | `room_manager.gd`, `hud_controller.gd` | First entry to each of the 6 regions triggers `HudController.show_region_title(region)` and plays audio stinger `&"discovery"`. |
| 28 | Cracked Mirror fast travel | M3 | R2 Feel | T1, T3 | `cracked_mirror.gd`, `room_manager.gd` | Discovered mirrors recorded in `world_memory_state["unlocked_mirrors"]`. Interaction opens travel menu and navigates between hubs. |
| 29 | Dev audit updates | M4 | R3 Audits | T1 | `scripts/dev/*_audit.gd` | `door_audit.gd` verifies `z_index >= 1`. `release_audit.gd` verifies layer 8, core exit, save overwrite. `controls_audit.gd` verifies push, corpses, echo twin. |
| 30 | Headless test suite & smoke test | M4 | R3 Tests | T1, T4 | `main.gd`, `scripts/dev/` | `_headless_faz67_smoke` sets `seal_shard_1` and `seal_shard_2`, executing all ending paths with 0 errors. |
| 31 | POCO X6 Pro 5G Android APK build & test | M4 | R3 Android | T1, T4 | `export_presets.cfg`, ADB | Android build configuration validated. APK installs to `QC59AM55BMCIEUHQ` with `permissions/vibrate=true`. |
| 32 | Versioning & export configuration | M5 | R4 Version | T1 | `project.godot`, `export_presets.cfg` | `config/version="1.3.0"`, `preset.0.options.version/code=17`, `version/name="1.3.0"`. |
| 33 | Git commit, tag, and GitHub Release | M5 | R4 Release | T1, T4 | Git / GitHub CLI | Clean working tree, tag `v1.3.0`, GitHub Release draft with APK binary attachment. |

---

## 5. Test Maintenance & Verification Protocol

1. **Local Verification**:
   Before handoff, run the master runner:
   ```powershell
   $env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & godot --headless --path . -s res://scripts/dev/e2e_runner.gd
   ```
2. **Defect Escalation**:
   Any assertion failure pointing to implementation code must be documented as an escalated issue in `handoff.md` and communicated to the orchestrator. Test writers do not modify production scripts.
3. **Publication**:
   Once all test cases are implemented and verified against current milestones, publish `TEST_READY.md` summarizing test inventory, execution results, and outstanding implementation dependencies.
