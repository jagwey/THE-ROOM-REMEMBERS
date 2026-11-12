# Faz 0 — Kritik Hatalar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Spec Bölüm 5'teki 9 kritik hatayı kapatmak: softlock ve bozuk oda kalmasın, plaka kuralı tek tip olsun. Sürüm v1.14.0 olarak hazırlanır ama yayınlanmaz.

**Architecture:** Plaka "canlı koşul + geçişte kilit" modeline geçer: `PuzzleManager` canlı durumu tutar, `gate_blocker` canlı durumda açılır, oyuncu kapıdan geçince `mark_solved` çağrılır. Oda düzeltmeleri `.tscn` ve `built_room` verisiyle yapılır, kod mümkün olduğunca az değişir. Her kural yeni bir headless audit ile sabitlenir.

**Tech Stack:** Godot 4.7.2 GDScript, headless audit (`scripts/dev/*_audit.gd`), `e2e_runner.gd`, `docs/gelistirme/Run-Audit.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-12-room-overhaul-design.md` (Bölüm 2, 5; oda satırları 12, 13, 31, 33, 36)

## Global Constraints

- Godot: `C:/Users/Osman/OneDrive/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`, `--headless --path .`, env `TORIMON_TEST=1`.
- 40 oda korunur, hiçbir oda ID'si değişmez. Eski save'de çözülmüş bulmaca çözülmüş sayılır. Yeni puzzle ID'si `<oda>_<ad>` biçimindedir.
- Plaka: kapı koşul **canlı** sağlandıkça açık; `PuzzleManager.mark_solved` yalnız oyuncu o kapıdan **geçtiğinde**.
- `accept_player` bulmaca plakalarında `false`. Bilinçli istisnalar audit whitelist'inde gerekçeyle yazılır.
- Her `weight_stone.max_x` ≤ (aynı yöndeki en yakın çıkış/kapı x) − 48.
- Yetenek sırası: Ruh Kesimi `library_forbidden_wing`, Gölge Atılması `mirrors_shrine`. Önceki odalar bu yetenekleri istemez.
- Kayıt süresi (`echo_altar.record_seconds`) oyunun her yerinde tek sabit: **8.0** sn. Metinler "sekiz saniye" der.
- Kod ve identifier'lar İngilizce, oyun metni Türkçe (UTF-8). Yalnız "…" karakteri kullanılır. Satırlar ≤ 90 karakter, HUD satırları ≤ 70. Ana karakterin adı Noroi'dir.
- Push, release ya da main'e merge yok. Commitler yalnız `feat/phase0-critical-fixes` branch'ine atılır.

## Review Focus

1. **v1.13 save'i yükleme:** `awakening_weight` vb. çözülmüş eski save açıldığında kapı açık olmalı. Plaka boş olsa bile kapanmamalı.
2. **Geri dönüş:** Oyuncu kapıdan geçip plakadaki taşı geri çekerse kapı açık kalır, çünkü kapı geçişte kilitlenmiştir.
3. **Ceset limiti:** 3 cesetten fazlası olunca plakadaki ceset trim edilmemeli (anchored). Eski ceset traca dönüşünce canlı koşul düşer ve kapı kapanır, bu doğru davranış.
4. **Yeteneksiz oyuncu:** Sarnıç ve Katakomb Gölge Atılması ya da Ruh Kesimi olmadan bitirilebilmeli. Çekirdek Yükselişi yetenek eksikse ret repliğiyle durmalı, softlock olmamalı.
5. **Çiçeksiz ölüm (Katakomb):** Çiçek alınmadan ölünürse çiçek kaynağı yeniden kullanılabilir olmalı, oda tıkanmamalı.

Her madde, aşağıda kendisini barındıran görevin audit'inde bir test olarak yer alır.

---

### Task 1: Plaka canlı kuralı + geçiş kilidi

**Files:**
- Modify: `scripts/autoload/puzzle_manager.gd` (live state, :103 metni)
- Modify: `scripts/world/pressure_plate.gd:86-123` (artık `mark_solved` çağırmaz)
- Modify: `scripts/world/gate_blocker.gd:22,38-39` (canlı açılma + geçiş kilidi)
- Modify: `scenes/rooms/awakening.tscn:212` (`accept_player` kaldır → false)
- Modify: `scenes/rooms/decay_greenhouse.tscn:43` (aşağıdaki karara göre)
- Modify: `scenes/rooms/decay_weight.tscn:184-191` (`max_x` 900 → 862)
- Create: `scripts/dev/plate_rule_audit.gd`
- Modify: `docs/gelistirme/Run-Audit.ps1:32-37` (audit listesine ekle)

**Interfaces:**
- Produces:
  - `PuzzleManager.set_live(puzzle_id: StringName, live: bool) -> void`
  - `PuzzleManager.is_live(puzzle_id: StringName) -> bool`
  - `signal live_changed(puzzle_id: StringName, live: bool)`
  - `gate_blocker` geçişte `PuzzleManager.mark_solved(id)` ve `SaveManager.save_game()` çağırır.
- Canlı durum kaydedilmez, yalnız bellektedir. Oda değişince plakalar `_recompute` ile yeniden yazar.

- [ ] **Step 1: Write the failing audit `plate_rule_audit.gd`** (extends SceneTree, PASS/FAIL satırları diğer `*_audit.gd` ile aynı formatta)
  - `plate_live_opens_gate`: awakening'e gir, taşı plakaya koy → gate açık, `is_solved(&"awakening_weight") == false`.
  - `plate_removed_closes_gate`: taşı çek → gate kapalı.
  - `pass_through_latches`: taş plakada, oyuncu gate x'inin ötesine ışınlanır → `is_solved == true`. Taşı çek → gate açık kalır.
  - `old_save_solved_stays_open`: `world_memory_state.puzzles["awakening_weight"]=true` ile yükle, plaka boş → gate açık.
  - `player_alone_no_press`: plakada yalnız oyuncu → `is_live == false` (awakening).
  - `accept_player_whitelist`: tüm `scenes/rooms/*.tscn` taranır. `accept_player = true` olan plaka yalnız whitelist'teyse geçer.
  - `stone_max_x_clearance`: her `weight_stone` için `max_x ≤ en yakın sağdaki RoomTransition/room_door/gate x − 48`, ve `min_x ≥ soldaki + 48`.
  - `anchored_corpse_survives_trim`: plakada ceset varken 3 ceset daha üretilir → plakadaki ceset kalır.
- [ ] **Step 2: Run, expect FAIL**
  Komut: `$env:TORIMON_TEST="1"; & $GODOT --headless --path . -s res://scripts/dev/plate_rule_audit.gd`. Beklenen: en az `plate_live_opens_gate`, `pass_through_latches`, `player_alone_no_press` ve `stone_max_x_clearance` FAIL.
- [ ] **Step 3: Implement**
  - `pressure_plate._set_pressed` `PuzzleManager.set_live(puzzle_id, _pressed)` çağırır. `mark_solved` ve `save_game` çağrıları kaldırılır.
  - `gate_blocker` açıktır eğer `is_solved(id) or is_live(id)`. `live_changed` ve `puzzle_solved` sinyallerini dinler. Gate açıkken oyuncunun x'i gate'in karşı tarafına geçtiği karede (giriş yönüne göre) `mark_solved` ve save çağrılır.
  - **Diğer tüketiciler:** pressure_plate puzzle ID'sini okuyan başka bir kod varsa (story_beat, room_transition `required_*`, objective) `grep -rn "is_solved\|puzzle_solved"` ile bulunur. Bunlar canlı durumu da kabul edecek şekilde ya da geçiş kilidine göre düzeltilir, çözümler raporda listelenir.
  - **awakening:** `accept_player` satırı silinir.
  - **decay_greenhouse SharedPlate:** odada plakaya ulaşabilen taş ya da ceset varsa `false` yapılır. Yoksa `true` kalır ve whitelist'e `"decay_greenhouse:SharedPlate — Faz 2'de saksı tasarımı"` gerekçesi yazılır.
  - **decay_weight:** `max_x = 862`. Audit başka bir taş bulursa o da düzeltilir.
  - **`puzzle_manager.gd:103` metni:** `"Ağır taşı plakada bırak. Kapı ağırlık durdukça açık; geçtiğinde hatırlar."`
- [ ] **Step 4: Run audit → PASS; run e2e tier 1-2 → yeni FAIL yok**
  e2e komutu: `$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & $GODOT --headless --path . -s res://scripts/dev/e2e_runner.gd`. Önce baseline FAIL listesi alınır, sonra karşılaştırılır.
- [ ] **Step 5: Commit** `fix(puzzle): live plate rule with latch-on-pass, accept_player audit`

### Task 2: Çekirdek Yükselişi yeniden yapımı (`core_ascent`)

**Files:**
- Modify: `scenes/rooms/core_ascent.tscn` (`built_room.gd` exportları: `platforms`, `floor_gaps`, etkileşimler)
- Modify: `scripts/world/built_room.gd` yalnız eksik bir export gerekiyorsa
- Test: `scripts/dev/plate_rule_audit.gd` değil; yeni `scripts/dev/ascent_audit.gd`

**Interfaces:**
- Consumes: Task 1 plaka modeli (yankı plakası canlı kural, `accept_player=false`).
- Puzzle ID'leri: `LastStep.solve_puzzle` mevcut ID'yi korur (eski save). Yeni testler `core_ascent_seal`, `core_ascent_gap` ve `core_ascent_echo` ID'lerini alır.

- [ ] **Step 1: Failing `ascent_audit.gd`**
  - `ascent_has_platforms`: oda kurulduktan sonra en az 3 platform ya da gap var.
  - `ascent_three_tests`: sahnede bir `soul_seal`/`curse_barrier` (Ruh Kesimi), en az 96 px'lik bir floor gap (Atılma) ve bir `pressure_plate` + `echo_altar` (yankı) var.
  - `ascent_refusal_names_room`: Atılma yokken gap öncesi ret repliği `"Ayna Tapınağı"` içerir. Ruh Kesimi yoksa `"Yasak Kanat"` içerir.
  - `ascent_no_softlock`: yeteneksiz oyuncu girişe geri dönebilir, yani geri kapı erişilebilir.
- [ ] **Step 2: Run → FAIL**
- [ ] **Step 3: Implement.** Soldan sağa: mühür (Ruh Kesimi ile kırılır), gap (Atılma ile geçilir), yankı plakası (8 sn kayıt + plaka) ve LastStep. Platform yükseklikleri mevcut zıplama yüksekliğiyle (`jump_audit` değerleri) erişilebilir. Ret replikleri Türkçe ve ≤ 90 karakterdir.
- [ ] **Step 4: Run ascent_audit + e2e → PASS / yeni FAIL yok**
- [ ] **Step 5: Commit** `feat(core_ascent): three-test ascent with platforms`

### Task 3: Ayna Tapınağı kapısı (`mirrors_unbroken` → `mirrors_shrine`)

**Files:**
- Modify: `scenes/rooms/mirrors_shrine.tscn` (`from_mirrors_unbroken` spawn noktası ekle)
- Modify: `scripts/main.gd:55-115` (SIDE_DOORS girişine görünür işaret: `door_title` ve glow)
- Modify: `mirrors_unbroken` Shilda yönlendirme satırı ("Tapınağa uğra.") — story_beat ya da dialogue verisinde, odanın mevcut diyalog kaynağında
- Test: `scripts/dev/door_audit.gd`'ye yeni kontrol

**Interfaces:** yok (yalnız veri).

- [ ] **Step 1: door_audit'e failing kontroller**
  - `shrine_spawn_exists`: `mirrors_shrine` içinde `from_mirrors_unbroken` spawn noktası var.
  - `shrine_door_marked`: `Side_mirrors_shrine` görünür bir işaret taşır (label + glow node).
  - `all_side_doors_have_spawn`: SIDE_DOORS'taki her hedefte `from_<kaynak>` spawn noktası var. Bu kontrol aynı türden diğer hataları da yakalar.
- [ ] **Step 2: Run → FAIL**
- [ ] **Step 3: Implement.** Spawn noktası dönüş kapısının iç tarafına konur. `all_side_doors_have_spawn` başka eksik spawn bulursa onlar da eklenir. Shilda satırı oyuncu odaya ilk girdiğinde bir kez çıkar.
- [ ] **Step 4: Run → PASS**
- [ ] **Step 5: Commit** `fix(mirrors): visible shrine door, missing side-door spawns`

### Task 4: Katakomb çiçek kaynağı + Sarnıç Atılma şartı

**Files:**
- Modify: `scenes/rooms/decay_catacombs.tscn` (girişe yakın, x≈150, `FlowerSource` etkileşimi + işaret)
- Modify: `scripts/autoload/corpse_manager.gd:18-54` (`record_corpse_at`: çiçek eldeyse `has_flower=true`)
- Modify: `scripts/autoload/puzzle_manager.gd` HINTS (`decay_catacombs` ipucu girişi)
- Modify: `scripts/main.gd:58` (cistern yan kapısından `"ability"` kaldırılır)
- Test: yeni `scripts/dev/softlock_phase0_audit.gd`

**Interfaces:**
- Produces: `GameState.character_current_life_knowledge["flower_in_hand"]: bool`. Hayat başına tutulur, ölümde cesede aktarılır ve sıfırlanır.

- [ ] **Step 1: Failing `softlock_phase0_audit.gd`**
  - `catacomb_flower_source_exists`: odada `FlowerSource` var ve x < 380'dir (ilk gap'ten önce).
  - `flower_transfers_to_corpse`: çiçek al, öl → yeni ceset `has_flower == true`, `flower_in_hand == false`.
  - `flower_source_reusable`: çiçeksiz ölümden sonra `FlowerSource` hâlâ etkileşilebilir.
  - `catacomb_hint_exists`: `PuzzleManager.HINTS` içinde katakomb anahtarı var.
  - `cistern_no_ability`: SIDE_DOORS cistern girişinde `ability` yok, ayrıca `decay_cistern.tscn` hiçbir yerde `need_dash`/`need_soul` içermez.
- [ ] **Step 2: Run → FAIL**
- [ ] **Step 3: Implement.** Çiçeğin nasıl yandığı mevcut `lantern` koşulunu (`corpse.gd` `has_flower`) kullanır, yeni ışık kodu yazılmaz. HINTS metni (≤ 70): `"Çiçeği al, sonra dikende öl. Çiçekli beden ışık olur."`
- [ ] **Step 4: Run → PASS; e2e yeni FAIL yok**
- [ ] **Step 5: Commit** `fix(decay): catacomb flower source, cistern needs no dash`

### Task 5: Metin ve veri düzeltmeleri (toplu)

**Files:**
- `scripts/autoload/puzzle_manager.gd:152` (Çiçeklenme ipucu)
- `scripts/world/echo_altar.gd:2,11,13` (8.0 sn, "sekiz saniye")
- `scenes/rooms/experiment_circuit.tscn:115` (intro_text "Sekiz saniye…")
- `scripts/story/story_beat.gd:254` ("altı saniye" → "sekiz saniye")
- `scenes/rooms/experiment_cells.tscn:103-111` (node `ForwardCircuit` → `ForwardIntake`, tüm referanslar)
- `scripts/story/page_order_puzzle.gd:25,75-84,157-165`
- `scripts/world/core_portal.gd` (sil) + `scripts/dev/m3_transition_audit.gd:393-400` (o kontrolü kaldır)
- Test: `scripts/dev/dialogue_data_audit.gd`'ye kontroller

- [ ] **Step 1: Failing kontroller (dialogue_data_audit)**
  - `bloom_hint_matches_order`: ipucu `"en çok"` ve `"en az"` içerir, `"Çoktan aza"` içermez.
  - `record_seconds_single`: `echo_altar.record_seconds == 8.0`. Hiçbir `.tscn` farklı bir override vermez. Kodda ve metinde "altı saniye" ya da "Altı saniye" geçmez.
  - `no_forward_circuit`: `ForwardCircuit` stringi projede yok.
  - `page_hint_matches_order`: hint metni sırasıyla "deney", "kapı", "mühür" içerir. "Mühül" yazımı yoktur.
  - `core_portal_gone`: `res://scripts/world/core_portal.gd` mevcut değil.
- [ ] **Step 2: Run → FAIL**
- [ ] **Step 3: Implement**
  - Çiçeklenme ipucu: `"Taşlardaki noktaları say: önce en çok, sonra en az, sonra kalan."`
  - library_page hint: `"Tanıkları hatırla: önce deney, sonra kapı, en son mühür."`
  - Kart etiketi `"Mühür devreye girdi"`.
  - Kamera pulse hedefi: `ROOM_ORDER`'da library_page'den sonra gelen odaya giden kapıdır. Bulunamazsa pulse yapılmaz, sabit (900,248) fallback'i kaldırılır.
- [ ] **Step 4: Run → PASS; m3_transition_audit PASS**
- [ ] **Step 5: Commit** `fix(text): bloom/page hints, 8s record, ForwardIntake, drop core_portal`

### Task 6: Portre kesilmesi (ODA 15 Üç Tanık)

**Files:**
- Investigate: `scripts/keeper/keeper_controller.gd:101`, keeper_observe spawn'ları (y288 / zemin 280), `scripts/ui/portrait_medallion.gd`, `scripts/ui/hud_controller.gd:43-44,238-309,889-912`, `scenes/ui/hud.tscn` Dialogue paneli
- Test: `scripts/dev/ui_header_portrait_audit.gd`'ye kontroller

Kod geometrisi 640×360'ta sığıyor (scout: madalyon panel y 52–120, panel 165). Kesilme büyük ihtimalle dünya içindeki Shilda sprite'ında (offset −51, spawn y288 > zemin 280 → ayaklar zeminin altında) ya da geniş oranda SafeArea'dadır.

- [ ] **Step 1: Failing kontroller**
  - `keeper_spawns_on_floor`: tüm odalardaki `keeper_*` spawn y'si ≤ odanın zemin y'si. Sprite alt kenarı zemine ±2 px oturur.
  - `medallion_inside_panel`: 640×360, 1280×720 ve 2400×1080 (20:9) viewportlarında madalyon rect'i, panel rect'i ve viewport rect'i içinde kalır.
- [ ] **Step 2: Run → FAIL olanı kaydet** (ikisi de geçerse `systematic-debugging` ile ODA 15'te dialogue açıkken `room_visual_capture.gd` görüntüsü alınır, kök neden bulunur ve test o nedene göre yazılır)
- [ ] **Step 3: Implement** kök nedene göre minimum düzeltme yapılır, örneğin spawn y'leri ya da sprite offset'i.
- [ ] **Step 4: Run → PASS**
- [ ] **Step 5: Commit** `fix(ui): keeper portrait/sprite clipping`

### Task 7: Sürüm hazırlığı + tam doğrulama + dokümantasyon

**Files:** `project.godot:9`, `export_presets.cfg` (version/code 44, version/name "1.14.0", export_path), `README.md`, `PROGRESS.md`

- [ ] **Step 1:** Sürüm `config/version="1.14.0"`, `version/code=44`, `version/name="1.14.0"`. APK derlenmez, release çıkılmaz.
- [ ] **Step 2:** `powershell -File docs/gelistirme/Run-Audit.ps1`. Beklenen çıktı exit 0, summary.json'da FAIL=0. Baseline'da zaten FAIL olanlar ayrıca raporlanır.
- [ ] **Step 3:** README'ye "v1.14.0 (hazır, yayınlanmadı)" bölümü eklenir: plaka kuralı, Yükseliş, Tapınak kapısı, Katakomb çiçeği, Sarnıç ve metin düzeltmeleri. PROGRESS.md'de yalnız ilgili satırlar düzenlenir.
- [ ] **Step 4: Commit** `chore: prepare v1.14.0 (unreleased), docs`
