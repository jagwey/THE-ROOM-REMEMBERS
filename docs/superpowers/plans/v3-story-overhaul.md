# TORIMON v3.0 Story Overhaul — Implementation Plan

**Spec:** `docs/superpowers/specs/torimon-v3-spec.md` (Sürüm 3.0). The spec is the binding authority; section numbers (§) below refer to it. Read only the sections your task names.

## Global Constraints (apply to every task)

- Godot 4.7.2, GDScript. Code/identifiers in English, all player-facing text in natural Turkish, UTF-8.
- Godot console binary (on PATH in Git Bash): `Godot_v4.7.2-stable_win64_console.exe`. Never download anything.
- **Every** test/audit command runs with env `TORIMON_TEST=1` (redirects SAVE_PATH to a `qa/` path so the user's real save is never touched). Example: `TORIMON_TEST=1 Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://scripts/dev/release_audit.gd`. Windowed render: same without `--headless`, add `--resolution 1920x1080`, save PNGs from a scratchpad SceneTree script via `root.get_texture().get_image().save_png(...)`, then open the PNGs with your image-reading tool and actually look at them.
- Temporary test scripts / screenshots go **outside the repo** (use the scratchpad dir you are given). Permanent audits in `scripts/dev/` are fine. `git status` must be clean after your commit; do not leave files under `build/qa/` uncommitted (it is generated output — if an audit writes there and it is tracked, restore it with `git checkout -- build/qa` unless the task says to update it).
- After every code change: run the task's own audit plus the **core set** headless: `release_audit.gd`, `e2e_runner.gd`, `death_loop_audit.gd`, `save_quit_audit.gd`, `start_flow_audit.gd`, `interact_audit.gd` (all under `res://scripts/dev/`). If you run `docs/gelistirme/Run-Audit.ps1`, always pass `-OutputPath <scratchpad dir>` so no results folder lands in the repo. Report exact pass/fail counts. A baseline of the core set on the starting commit is in the SDD ledger; a failure that was already failing at baseline is not yours unless your task touches it.
- Never write secrets/keys/passwords to files. Never push, never create releases, never touch the public release repo.
- Commit locally on the current branch with a clear message ending with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Canon (§2–§7, §37): protagonist is **Noroi** (never "Shiren" in any player text or docs). Shilda = X's former research assistant ("Araştırma Yardımcısı S."), changed by X's experiments, uncursed humanoid Keeper. **X** built the dimension in 1927; the disaster was 1927; Noroi arrives in **1995**, 68 years later, a newcomer with no memory. Noroi never ran, signed, authorized, or ordered any experiment. Before the final, X is never named directly — use redacted forms ("Baş Araştırmacı", "Yetkili: ███", "imza kazınmış") (§34: "X hakkında kesin bilgiler finalden önce verilmemelidir").
- Dialogue rules §18: short, natural Turkish; no needless abstraction; Shilda calm/tired; X cold and clinical.
- Do not report anything as done that is not implemented and tested.

---

### Task 1: Lore & canon text rewrite + lore_canon_audit

**Spec:** §2–§7, §16 (opening clues), §18, §37 "Hikâye güncellemesi".

Remove every text that makes Noroi the experiment's authority/initiator, and plant the 1927/1995 timeline.

Files to rewrite (known hits; grep for more with `Noroi.*(onay|yetkili|başlat|emir|imza)`, `Protokol Yetkilisi`, `ben başlattım`, `benimdi`, `ben istedim`):
- `scenes/rooms/library_forbidden_wing.tscn` (~l.60, 62: "Protokol Yetkilisi: Noroi…", "Ben başlattım…")
- `scenes/rooms/core_memory_vault.tscn` (~l.44)
- `scenes/rooms/decay_catacombs.tscn` (~l.115)
- `scenes/rooms/experiment_quarantine.tscn` (~l.43 "Yetkili Noroi onayladı")
- `scenes/rooms/awakening_balcony.tscn` (l.36–38: Telescope Shilda line "Bütün tesisi bu balkondan izlerdin." and evidence_body "…Duruşu bana benziyor. Bu balkon bir zamanlar benimdi.") → the figure in the facility is an unknown white-coated authority; Shilda line becomes something like "O balkon onundu. Ben aşağıda, kayıtların başındaydım." — Noroi has no tie to it.
- `scenes/rooms/awakening_crypt.tscn` (~l.43 "Bana kendisi emretti. Hatırlamaması için.")
- `scenes/rooms/library_upper_stacks.tscn` (~l.32 "…Protokol Yetkilisi.")
- `scripts/story/story_beat.gd` (~l.97, 197, 199, 281)
- `scripts/autoload/echo_manager.gd` (~l.53 "Hafızamın silinmesini ben istedim…")
- `scripts/story/campaign_objectives.gd`: `experiment_authority` → "Deneyi kimin başlattığını öğren; imzayı incele." ; `core` → "Çekirdeğe in; mührü Shilda ile birlikte kır." ; `core_bloom_garden` → "Shilda'yı dinle; birlikte ilerleyin." (no "barış/güveni onar" blame implication).
- `scripts/autoload/ending_manager.gd` l.23 epilogue line "Duvarda kendi el yazın…" (text only; the ending system itself is replaced in Task 9 — just make the text canon-safe).
- `README.md` and `PROGRESS.md`: replace "Shiren" with "Noroi" in prose (edit lines, do not rewrite files).

Plant (new or edited lore lines, keep them short):
- Awakening-area dossier: year **1927** visible, unexplained (e.g. evidence "Tarihli Dosya": "Kapağında 1927 yazıyor. Gerisi yanmış.").
- At least one record mentioning **"Araştırma Yardımcısı S."** (§16; e.g. in library_witness or awakening_crypt: "Gözlem notu — Araştırma Yardımcısı S.: Denek 14 hâlâ konuşuyor.").
- At least one 1995 reference that Noroi is new (e.g. a ticket/stub "1995" in Noroi's pocket, or Shilda later: "Altmış sekiz yıl oldu.").
- Authority signatures become redacted: "Yetkili imza: ███ (kazınmış)".

New audit `scripts/dev/lore_canon_audit.gd` (extends SceneTree, headless): scans all `res://scenes/**/*.tscn` and `res://scripts/**/*.gd` text for forbidden patterns and fails (exit code = failure count) on any hit:
- `Shiren` (any case) in player-facing strings (allow only in comments that say "old name" — simpler: forbid everywhere in scenes/scripts; technical keys containing `shiren` must be listed in an explicit allowlist array inside the audit if any exist).
- `Protokol Yetkilisi: Noroi`, `Yetkili Noroi`, `Ben başlattım`, `bir zamanlar benimdi`, `ben istedim`, `Bana kendisi emretti`.
- Also asserts presence: at least one `1927`, at least one `1995`, at least one `Araştırma Yardımcısı S.` across scenes/scripts.
Print `LORE PASS/FAIL <label>` lines and `LORE failures=N`.

**Tests:** `TORIMON_TEST=1 godot --headless --path . -s res://scripts/dev/lore_canon_audit.gd` → failures=0; release_audit still passes. No windowed render needed beyond one screenshot of the balcony telescope dialogue (taken by a scratchpad script).

---

### Task 2: Story flags API + save v6

**Spec:** §34 "Hikâye durumları", "Kayıt dosyası doğrulama"; §15 "Kaydedilecek bilgiler".

- In `scripts/autoload/game_state.gd` add `var story_flags: Dictionary = {}` with `set_story_flag(id: StringName, value := true)`, `has_story_flag(id: StringName) -> bool`, `clear_story_flags()`, signal `story_flag_changed(id, value)`. Define `const STORY_FLAGS := [&"intro_completed", &"first_shadow_seen", &"first_warning_heard", &"first_death_completed", &"first_corpse_discovered", &"shilda_name_known", &"first_archive_record_read", &"dimension_origin_discovered", &"shilda_past_discovered", &"core_access_granted", &"final_seal_broken", &"x_revealed", &"game_completed"]`; `set_story_flag` with an unknown id pushes a warning but still stores it.
- `scripts/autoload/save_manager.gd`: bump `SAVE_VERSION` to 6; persist `story_flags`; on loading v≤5 data, migrate: fill missing fields with safe defaults and derive flags from existing state where possible (e.g. `shilda_name_known` from `GameState.is_shilda_named()` data; `first_death_completed` if any corpse/death count > 0; `core_access_granted` if core rooms visited; `intro_completed` if awakening puzzle solved). New game clears flags.
- Hook the flags whose triggers already exist: `first_death_completed` (DeathManager after first respawn), `first_corpse_discovered` (first time a corpse of the player is seen/interacted — use the existing corpse manager hook), `first_archive_record_read` (first lore_point in a library room), `core_access_granted` (enter core_threshold), `dimension_origin_discovered` / `shilda_past_discovered` (the lore points that reveal 1927 origin / Shilda's assistant past from Task 1). Flags for intro/shadow/warning/name/final are hooked in later tasks (7, 9) — leave TODO-free stubs: just make sure the API exists.
- New audit `scripts/dev/story_flags_audit.gd`: sets flags, save→load roundtrip keeps them, v5-shaped dict migrates without error and gets defaults, new game clears them. Exit = failures.

**Tests:** story_flags_audit failures=0; save_robust_audit / stress_save_system / save_quit_audit still pass (update their version expectations to 6 if they assert the number).

---

### Task 3: Committed save vs resume point

**Spec:** §15 "Kayıt noktası güvenliği", §13/§14 (curse reload loads the last *committed* save), §27 "Kaydet ve Çık", §34 "Lanet ele geçirme yönetimi".

Problem: today every room entry autosaves the full game, so "load last save" ≈ now. Split:
- **Committed save** (`SAVE_PATH`, with existing atomic tmp→.bak/.prev backup): written ONLY by `SaveManager.commit_save(reason)` — called from a Memory Seal (Task 4), from "Kaydet ve Çık" (Task 8), from new-game start, and from the final completion (Task 9). Stores the safe position (seal/checkpoint position, not the raw player position).
- **Resume point** (separate file, e.g. `SAVE_PATH.get_basename() + "_resume.json"`): written by the existing autosave callers (room_manager enter_room, story_beat, PuzzleManager, app pause/quit `NOTIFICATION_WM_CLOSE_REQUEST` / `NOTIFICATION_APPLICATION_PAUSED`) so quitting never loses progress (§15 "Oyuncu oyundan çıktığında veri kaybı yaşanmamalıdır").
- `Devam Et` loads the newer of resume/committed (by a monotonically increasing `save_serial` stored in both). `SaveManager.load_committed()` loads only the committed file (used by curse reload in Task 5) and then deletes/invalidates the resume file so a later "Devam Et" does not resurrect the rolled-back state.
- Keep the old public function names working (rename internals, keep `save_game()` as the resume-writer so existing callers keep compiling), and update `save_resume_point/take_resume_point` semantics consistently.
- Audit `scripts/dev/save_split_audit.gd`: commit at state A, change state to B (+autosave), `load_committed()` → state A and resume invalidated; resume-only path → state B; corrupt committed file → falls back to .prev/.bak; missing fields → defaults.

**Tests:** save_split_audit + all existing save audits pass.

---

### Task 4: Memory Seal save points (Hafıza Mührü)

**Spec:** §15 (visual, interaction text, placement), §9 "Tekrar eden yolculuğun önlenmesi".

- New `scripts/world/memory_seal_point.gd` (Area2D, interactable via the project's existing interaction system — mirror how `lore_point.gd` registers interaction). Visual: small gothic pedestal + broken-ring symbol + red-white crystal. Draw it procedurally (`_draw`) or compose from existing props in `assets/props/`; do not add binary assets you cannot verify visually. Idle: soft crystal pulse. On interact: glow + short sfx (reuse an existing AudioManager sfx id), call `SaveManager.commit_save(&"memory_seal")` with the seal's safe position, show the banner **"HAFIZA MÜHÜRLENDİ"** with subtitle **"Kayıt noktası etkinleştirildi."** (reuse an existing banner/toast UI; add one in `scripts/ui/` if none fits), mark the seal as discovered (`GameState` list `discovered_seals`, saved).
- Seal must not be usable while dying/possessed/in dialogue or while an enemy is within ~120 px (§15 "Kayıt alınırken karakter tehlikede olmamalıdır" — show "Tehlike varken mühür tepki vermiyor." instead).
- Fast travel (§9): interacting with a seal that the player has activated before also offers "Mühürler arası geçiş" listing other discovered seals (simple modal using `scripts/ui/gothic_modal_panel.gd`); choosing one enters that room at the seal's spawn. The Awakening Room seal is always discovered, so after a normal death (bed respawn, Task 6) the player can jump back.
- Placement: at least one seal in every **main** room (not short connectors). Main rooms: awakening, decay_garden, library_hall, experiment_cells, mirrors_reverse, core_threshold, plus awakening_crypt, decay_catacombs, library_forbidden_wing, experiment_core_conduit, mirrors_shrine, core_seal_chamber. Place on safe floor away from hazards/doors; add a spawn marker per seal (`seal_<room_id>`).
- Audit `scripts/dev/memory_seal_audit.gd`: every listed room instantiates a seal; seal position not overlapping hazards/doors (reuse release_audit's hazard rects if available); interacting commits a save (committed file serial increases) and records the room; fast-travel to another discovered seal lands the player in that room on the floor.

**Tests:** memory_seal_audit + release_audit (30 rooms still) + windowed 1920x1080 screenshot of a seal idle and of the banner, inspected.

---

### Task 5: Curse bands + possession reload

**Spec:** §12 (bands), §13 (animation flow + "Önemli kurallar"), §14, §34 "Lanet ele geçirme yönetimi".

- `scripts/autoload/curse_manager.gd`: replace stages 25/50/75 with bands **0–49** control, **50–69** first signs (red eye tint + whispers; meter visible from 50), **70–89** danger (occasional stumble/input hiccup, screen-edge veins), **90–99** critical (strong pulse, heartbeat, still escapable). Add `set_curse(v)` and `get_band()`; emit `band_changed`.
- At **100**: remove the keeper mercy_kill path and the corpse-creating `DeathManager.request_death(&"curse")` path. Instead run the possession sequence (≈4.5 s total per §13 flow: control lost, red vein spread, distortion, dark fade) and the text **"LANET SENİ ELE GEÇİRDİ"** / **"Bilincin karanlığın içinde kayboldu."** / **"Son kayıt noktasından yeniden başlayacaksın."**. Repeats: a counter in GameState (persisted) — after the first time the sequence is shortened (~2 s) and any input skips it.
- Then `SaveManager.load_committed()` (Task 3), spawn at the committed safe position, set curse to a safe level (≤ 30, never ≥ 90), NO corpse, NO soul animation, NO bed. Story flags and world state after the commit are lost (that is what loading the committed save does). Not an ending (`EndingManager` must not be called).
- Audit `scripts/dev/curse_reload_audit.gd`: commit at A; then change room/puzzle/flag (B) and push curse to 100; after the sequence: state == A, corpse count unchanged, curse ≤ 30, player not on a hazard, `EndingManager.current == NONE`; second possession is shorter; band thresholds 49/50/69/70/89/90/99 map correctly.
- Update `death_loop_audit.gd` and any audit that expected a curse death to create a corpse.

**Tests:** curse_reload_audit + death_loop_audit + release_audit; windowed screenshots of band 50, band 90 and the possession text, inspected.

---

### Task 6: Normal death → Awakening bed respawn

**Spec:** §9, §10, §14, §34 "Normal ölüm yönetimi".

- `scripts/autoload/death_manager.gd` `_respawn`: normal (non-curse) deaths always respawn in room `awakening` at the rebirth bed position (find the bed node/marker in `scenes/rooms/awakening.tscn`; add a `rebirth_bed` spawn marker if missing). Keep: corpse left where Noroi died, world state persisted, soul-rise visual (white + pale purple light, camera briefly follows) then eyes-open at the bed.
- The room checkpoint auto-set in `room_manager.gd` enter_room (l.~215) must no longer decide the death respawn; keep it only if other systems need it (e.g. hazard pit reset within a room — check usages before removing).
- Normal death never loads a save. Set `first_death_completed` after the first respawn (Task 2 API).
- Make sure the Awakening Room seal (Task 4) fast travel is reachable right after respawn.
- Update `death_loop_audit.gd`: die in a far room → respawn in awakening at bed; corpse exists in the far room; opened doors/puzzles persist; committed save untouched (serial unchanged).

**Tests:** death_loop_audit + release_audit + windowed screenshot of the bed respawn, inspected.

---

### Task 7: Slow opening, silhouette beats, Shilda naming scene

**Spec:** §16, §17 (exact lines), §19 stage 1, §26 "Kimliği bilinmeyen karakterler", §34.

- Remove forced naming: `main.gd` (~l.110) and `keeper_controller.gd` `_ready` (l.~82–103) must not call `set_shilda_named(true)`.
- Speaker card shows **"???"** until `shilda_name_known`; remove the 5 places that rewrite "???"→"Shilda" unconditionally (`dialogue_manager.gd` resolve_whisper_speaker ~l.79–82, `lore_point.gd` ~l.132–139, `interact_glow.gd` ~l.113, `dialogue_portraits.gd` ~l.21, `audio_manager.gd` ~l.482) — they must use `GameState.keeper_speaker_name()` which returns "???" or "Shilda" based on the flag. Line authors keep writing `Shilda|...`; the resolver displays "???" until named. `shilda_name_known` and `GameState.is_shilda_named()` must be the same truth (one delegates to the other).
- Opening (§16 0–14 min) in the Awakening room: eye-open, Noroi: "Burası neresi?"; pocket watch lore: "Saat durmuş. Ama içeriden hâlâ ses geliyor."; 1927 dossier (Task 1) unexplained. Shilda is NOT standing in the awakening room at start (remove awakening from `ROOM_PRESENCE` until named or move her to an observing silhouette). Set `intro_completed` after the eye-open beat.
- Silhouette beat (first time in awakening_passage or similar): brief dark figure at the edge, then dialogue "???|Dur." / "Noroi|Kim var orada?" / "???|Oraya yaklaşma." → flags `first_shadow_seen`, `first_warning_heard`.
- First corpse beat: when Noroi first meets his own corpse: "Noroi|Bu... benim kıyafetim." / "Noroi|Bunu kim bıraktı?" (red flower beside it) → `first_corpse_discovered`.
- Naming scene (§17) — use these lines **verbatim**, triggered at the first real conversation with the Keeper after `first_death_completed` (or when she first appears in person, whichever the current story beat structure supports; document the choice): "Noroi|Beni ne zamandır izliyorsun?", "???|Buraya geldiğinden beri.", "Noroi|Peki neden?", "???|Daha önce de birilerinin geldiğini gördüm.", "Noroi|Onlara ne oldu?", "???|Hiçbiri çıkamadı.", "Noroi|Bir adın var mı?", "???|Shilda.", then set `shilda_name_known` so the following lines show the name: "Noroi|Ben Noroi.", "Shilda|Biliyorum.", "Noroi|Nereden?", "Shilda|Bunu sonra konuşalım."
- Update awakening objective in `campaign_objectives.gd` (`Gölgeyle konuş` step) to match the new flow so the player is never blocked (awakening gate/softlock protections from v0.10.1 must still pass).
- Update `ui_header_portrait_audit.gd`, `start_flow_audit.gd`, `interact_audit.gd`, `e2e_runner.gd` for the "???" behaviour. Add checks: before naming every Keeper line displays "???"; after the scene "Shilda".

**Tests:** those audits + release_audit; windowed screenshots: opening eye-open line, silhouette "???" dialogue card, naming scene before/after name, inspected.

---

### Task 8: Menus (title Jenerik, pause, confirmations)

**Spec:** §27 (all), §34 "Oyuncu yeni oyun açtığında eski kayıt istemeden üzerine yazılmamalıdır".

- `scripts/ui/title_screen.gd` main page buttons in order: **Yeni Oyun / Devam Et / Ayarlar / Jenerik / Oyundan Çık** (keep the update button logic). Devam Et disabled/hidden when no save. Yeni Oyun with an existing save asks confirmation ("Kayıtlı ilerlemen silinecek. Yeni oyuna başlamak istiyor musun?" — Evet / Vazgeç). Jenerik opens a credits page (scrolling, gothic panel) — the same credits content Task 9 shows after the final; put the credits text in one shared place (e.g. `scripts/ui/credits_data.gd`). Credits content: game title, "Bir Jagwey Studio oyunu", design/code/art/music credits as currently known from README (no invented people; use "Jagwey" and "Claude (yapay zekâ yardımı)" if README says so — check README).
- `scripts/ui/session_menu.gd` pause: **Devam Et / Ayarlar / Kaydet ve Çık / Ana Menüye Dön**; remove the "Yeni oyun" button from pause.
- Kaydet ve Çık confirm text exactly: **"İlerlemen kaydedilecek ve ana menüye döneceksin. Emin misin?"** with buttons **Kaydet ve Çık** / **Vazgeç**; on confirm: `SaveManager.commit_save(&"save_and_quit")` then return to the title screen (do NOT quit the app).
- Ana Menüye Dön: warn **"Kaydedilmemiş ilerleme kaybolacak. Ana menüye dönmek istiyor musun?"** (Ana Menüye Dön / Vazgeç); on confirm return to title without committing (resume file is still written so app-quit safety holds — but Devam Et must then load the committed save, so invalidate the resume file here; document this).
- Update `save_quit_audit.gd` / `start_flow_audit.gd`; add checks for button order and texts.

**Tests:** those audits; windowed screenshots of title (5 buttons), Jenerik page, pause menu, both confirms, inspected. Touch UI (TORIMON_TOUCH_UI=1) buttons must remain tappable.

---

### Task 9: Single final — seal break, Shilda human form, X, END OF PART I, credits

**Spec:** §8, §31, §32 (all lines verbatim), §33.

- Remove endings: `EndingManager` enum becomes `{NONE, PART_ONE}`; delete BAD_KILL_KEEPER and SEVER_BOND and GOOD_TRUST_SEAL branches, their epilogues, `can_attempt_sever`, `has_both_shards` gating that only served choices (keep shard collection as progression if the core seal still needs both shards — §31 says so? check §31 and keep what it requires). Remove `keeper_controller.receive_player_strike` killing Shilda (she cannot be killed; a strike makes her flinch/block). Remove `scripts/world/core_choice_pad.gd` usage and the two pads from `scenes/rooms/core.tscn`; update release_audit/e2e PUZZLE_SOURCE so the softlock graph matches (no `core_choice`).
- Final sequence in `core` (scripted, input locked, skippable lines only after first view): Soul Slash on the seal bonds → main seal breaks (`final_seal_broken`) → Shilda returns to human form (swap sprite/tint; if no human sprite exists, use a pale desaturated tint + glow transition and note it as a placeholder) → lines from §32 verbatim ("Shilda|Ellerim...", "Noroi|Shilda?", "Shilda|Sanırım... sonunda bitti.", "Shilda|Gidelim." etc.) → X appears (tall silhouette, cold white light; speaker "X") with the §32 lines verbatim (including "Demek sonunda başardınız.", "Bu bir deneydi.", "Şimdiye kadarki en başarılı deneklerim sizsiniz.") → `x_revealed` → screens flash **EXPERIMENTAL DOMAIN — 01**, **DOMAIN — 02**, **03**, **04** → X pulls the core shard from Noroi's chest ("İhtiyacım olan şeyi aldım.", "Çünkü henüz işiniz bitmemişti.", "İkiniz de beklentilerimi aştınız.") → X leaves through a portal → Shilda: "Noroi... beni duyuyor musun?" → fade → **THE ROOM REMEMBERS** / **END OF PART I** → credits (Task 8's shared credits) → `game_completed`, `commit_save(&"final")` → title screen.
- Read §32 fully and use every line in its order; do not invent extra X lore.
- `main.gd` `_headless_faz67_smoke` and any core smoke: update to the single final.
- New audit `scripts/dev/final_sequence_audit.gd`: drives the sequence headless (with a fast-forward flag), asserts flag order final_seal_broken → x_revealed → game_completed, END OF PART I label shown, credits shown, no other ending reachable (EndingManager enum has only NONE/PART_ONE), Shilda not killable.

**Tests:** final_sequence_audit + release_audit + e2e; windowed screenshots: Shilda human form, X reveal, DOMAIN screen, END OF PART I, credits, inspected.

---

### Task 10: Dialogue polish (Shilda stages, §18 rules)

**Spec:** §18, §19 (5 stages with sample lines), §26.

- Pass over Keeper/Shilda lines in `keeper_controller.gd`, `story_beat.gd`, room `.tscn` lore lines and `echo_manager.gd`: shorten, make natural; map each region to a Shilda stage (1 Mesafeli: awakening/decay, 2 Merak: library, 3 Güven: experiment, 4 Acı: mirrors, 5 Ortak amaç: core) and use/adapt the §19 sample lines there.
- No line > ~90 characters in a dialogue box; no abstract philosophy lines that §18 lists as wrong examples.
- Keep all `Shilda|`-prefixed speaker tags (the ??? resolver from Task 7 handles naming).
- Run lore_canon_audit again (no regressions).

**Tests:** lore_canon_audit, interact_audit, e2e; a line-length check added to lore_canon_audit (warn list, fail if > 120 chars).

---

### Task 11: Audit sweep + full test run + docs

- Update `docs/gelistirme/Run-Audit.ps1` to include the new audits (lore_canon, story_flags, save_split, memory_seal, curse_reload, final_sequence).
- Run the full set with `TORIMON_TEST=1`; fix any regression caused by Tasks 1–10.
- §36 test plan: write `docs/gelistirme/v3-test-plan.md` mapping each §36 item to the audit/screenshot that covers it, and listing items NOT automatically covered (honestly).
- PROGRESS.md: add a v3 section (line edits only).

**Tests:** full Run-Audit green; windowed 1920x1080 tour screenshots (title, opening, seal, curse, death respawn, naming, final) inspected.
