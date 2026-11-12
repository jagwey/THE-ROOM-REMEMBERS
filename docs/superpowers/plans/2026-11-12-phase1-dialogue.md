# Faz 1 — Diyalog Yeniden Yazımı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Oyundaki bütün Türkçe metni spec §6 üslup kurallarına ve §7 canon kararlarına uydurmak, bunu bir lint denetimiyle kilitlemek ve v1.15.0 adayını hazırlamak.

**Architecture:** Önce `scripts/dev/dialogue_lint_audit.gd` yazılır ve mekanik kural ihlalleri düzeltilerek yeşile çekilir (T1). Ardından canon düzeltmeleri `lore_canon_audit.gd` kontrolleriyle kilitlenir (T2). Sonra metin bölüm bölüm elle yeniden yazılır (T3–T6). Lint, canon audit ve e2e her görevde regresyon ağıdır. Kod mantığı, ID'ler, bulmaca çözümleri değişmez; yalnız oyuncuya görünen metin değişir.

**Tech Stack:** Godot 4.7.2 GDScript, headless SceneTree audit'leri, PowerShell `Run-Audit.ps1`.

**Spec:** `docs/superpowers/specs/2026-11-12-room-overhaul-design.md` (§6 Diyalog üslup kuralları, §7 Hikâye canon kararları, §8 Faz 1, §9 Diyalog lint).

**Branch:** `feat/phase1-dialogue` (Faz 0 dalı `feat/phase0-critical-fixes` üstünden açıldı; yayın/push yok).

## Global Constraints

- Kod/identifier İngilizce, oyun metni Türkçe, dosyalar UTF-8 (BOM yok).
- **Noroi**: kısa, içe dönük; en fazla 1 cümle.
- **Shilda**: 2–8 kelime, "sen" der.
- **Gölge/Keeper**: adı öğrenilene kadar `GameState.keeper_speaker_name()` ("???"); sabit "Shilda" yazılmaz (JSON'da konuşmacı `@shilda`; sahne `lines` içinde `Shilda|` öneki çalışma anında çözülür, o kalabilir).
- **X**: "siz" der; Noroi X'e "sen" der.
- Diyalog satırı ≤ 90 karakter; HUD ipucu (kapı `msg`, `campaign_objectives.gd` hedefleri, `hud_controller.gd` ipuçları) ≤ 70. Uzunlar bölünür (yeni dizi elemanı / yeni `;;` parçası).
- Sade Türkçe; çeviri kalıbı yok ("…yapmak durumundasın", "bu bir … olarak" vb.).
- Somut imge: soyut felsefe yerine nesne/ses/koku.
- Üç nokta yalnız "…" karakteri ("..." yasak).
- Terimler: **Ruh Kesimi**, **Gölge Atılması**, **Çekirdek**, **Denek 14**, kurum = "deney". "hafıza" = sistem/kurum; "anı" = kişisel. "hatıra" ve "bellek" kullanılmaz (çekimleri dahil).
- İpucu satırı fiille biter ("…taşı plakaya it.").
- İngilizce kalıntı yok: `DOMAIN %02d` → "BÖLGE %02d", `END OF PART I` → "BÖLÜM I SONU", `İz: kind` → iz türünün Türkçe adı.
- Oda başlıkları: `experiment_quarantine` → "Karantina Mahzeni", `mirrors_1927` → "1927 Gecesi". Tek kaynak `RoomManager.ROOM_TITLES_TR`.
- Canon (§7): X'in adı yalnız `mirrors_1927` sonunda açılır; Shilda'nın insan oluşu `experiment_observation` yankısında açılır (Sarnıç/Okuma Hücresi yalnız ima); tesisi X kendi seçimiyle içeriden kilitledi, ironi Kasa'da (`core_memory_vault`) söylenir; Kabul'deki çiçeğin sahibi Shilda; "yüzlerce" ölüm yerine `{deaths}`; "1927 yazı" → "1927 gecesi"; Hall kaydındaki sıra = Tanık plakalarının sırası.
- Değişmeyenler: oda/puzzle/flag/relic ID'leri, `when` koşulları, JSON anahtarları, `Konuşmacı|metin` ve `;;` ayraçları, `%s`/`%d`/`%02d` ve `{deaths}` yer tutucularının sayısı ve sırası, bulmaca çözümleri.
- `{deaths}` yalnız `LorePoint.format_text` üstünden geçen metinde kullanılır (`lore_point.gd` `lines`, `memory_seal_point` vb. — kullanmadan önce yolun `format_text` çağırdığını doğrula). Geçmiyorsa sayı vermeden yaz ("sayısız", "her ölümde").
- Audit'ler eski metni birebir arıyorsa: aynı amacı koruyarak yeni metne göre güncellenir; hiçbir `check(` silinmez, gevşetilmez.
- Yayın/push/merge yok. Her görev kendi local commit'ini atar. Sır/anahtar yazılmaz.

## Komutlar

```powershell
$G="C:/Users/Osman/OneDrive/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
$env:TORIMON_TEST="1"; & $G --headless --path . -s res://scripts/dev/dialogue_lint_audit.gd     # exit 0, "LINT FAIL" yok
$env:TORIMON_TEST="1"; & $G --headless --path . -s res://scripts/dev/lore_canon_audit.gd        # exit 0
$env:TORIMON_TEST="1"; & $G --headless --path . -s res://scripts/dev/dialogue_data_audit.gd     # exit 0
$env:TORIMON_TEST="1"; $env:TORIMON_FRESH="1"; $env:TORIMON_NO_AUTO_DIALOGUE="1"; & $G --headless --path . -s res://scripts/dev/e2e_runner.gd   # 53/53 (veya daha fazla), 0 FAIL
powershell -ExecutionPolicy Bypass -File docs/gelistirme/Run-Audit.ps1 -ProjectPath (Get-Location).Path -GodotPath $G -OutputPath "$env:TEMP\trr-p1-audit"   # exit 0, 0 başarısız
```

Her rewrite görevi (T2–T6) sonunda lint + lore_canon + dialogue_data + e2e koşulur; T7'de tam Run-Audit.

## Review Focus

1. Ayraç bozulması: `Konuşmacı|metin` içindeki `|` veya `dialogue_sets` içindeki `;;` kaybolursa konuşmacı adı metne karışır → lint her `lines`/`dialogue_sets` parçasında tam bir `|` ve bilinen konuşmacı ister (T1).
2. Yer tutucu kayması: `"%s ile konuş" % x` gibi biçim dizgisinde `%` sayısı değişirse çalışma anında hata → lint, aynı dosyadaki değiştirilmiş biçim dizgilerini değil ama Godot parse'ı ve e2e/UI audit'leri yakalar; ek olarak lint `{deaths}` dışında `{...}` yer tutucusu görürse FAIL verir (T1).
3. İpucu–çözüm tutarlılığı: metin bir kodu/sırayı söylüyorsa (Çiçek Bahçesi "dört, bir, iki", Tanık sırası, Saatler) yeniden yazımda sayı/sıra korunur → T2 `lore_canon_audit` içine Hall kaydı ↔ Tanık plaka sırası ve Bahçe ipucu ↔ çözüm kontrolü ekler.
4. İsim öncesi sızıntı: Noroi'nin "Ben Noroi." anından (Nöbet Odası, `keeper_controller.gd:698`) önce oynayan metinde "Shilda" geçmez; X'in adı `mirrors_1927` öncesi hiçbir yerde geçmez → T2 lore_canon kontrolü.
5. JSON `when`/`variants` yapısı: metin değişirken koşul anahtarları kaybolursa satır her zaman/hiç görünmez → `dialogue_data_audit` zaten anahtarları doğrular; T3–T6 her JSON değişikliğinden sonra koşturur.

---

### Task 1: Diyalog lint audit + mekanik düzeltmeler + oda başlıkları

**Files:**
- Create: `scripts/dev/dialogue_lint_audit.gd`
- Modify: `docs/gelistirme/Run-Audit.ps1:32-36` (`$devAudits` listesine `'dialogue_lint'`)
- Modify: `scripts/autoload/room_manager.gd` (`ROOM_TITLES_TR`: `experiment_quarantine` → "Karantina Mahzeni", `mirrors_1927` → "1927 Gecesi")
- Modify: `scripts/world/cracked_mirror.gd` (yerel oda adı haritası varsa `RoomManager.ROOM_TITLES_TR`'den okusun; çift kaynak kalkar)
- Modify: `scripts/story/final_sequence.gd` (`"DOMAIN %02d"` → `"BÖLGE %02d"`, `"END OF PART I"` → `"BÖLÜM I SONU"`)
- Modify: `scripts/ui/journal_ui.gd:235` (`"İz: %s" % kind` → iz türünün Türkçe adı; tür → ad haritası `journal_ui.gd` içinde `const TRACE_KIND_TR := {...}`, bilinmeyen tür "İz")
- Modify: lint'in bulduğu mekanik ihlaller ("...", hatıra/bellek, JSON `"s": "Shilda"`) olan dosyalar
- Modify: `scripts/dev/final_sequence_audit.gd` ("END OF PART I label" kontrolü yeni metne)

**Interfaces:**
- Produces: `dialogue_lint_audit.gd` — `extends SceneTree`, çıktı satırları `LINT PASS <label>` / `LINT FAIL <label> <dosya>:<satır> <metin>`; çıkış kodu = 0 yalnız FAIL yoksa. Sonraki görevler bunu regresyon ağı olarak koşar.
- Produces: `const KNOWN_SPEAKERS` (lint içinde) — `Noroi`, `Shilda`, `@shilda`, `???`, `Ses`, `X` + kaynaklarda bulunan diğer gerçek konuşmacılar. Yeni konuşmacı eklemek listeye eklemeyi gerektirir.

Lint kapsamı ve kuralları:
- Taranan kaynaklar: `res://data/dialogue/*.json` (`t` ve `variants` metinleri); `res://scenes/**/*.tscn` metin özellikleri (`lines`, `locked_lines`, `repeat_line`, `intro_text`, `solved_text`, `evidence_title`, `evidence_body`, `refusal_line`, `locked_line`, `*_refusal_line`, `locked_message`, `dialogue_sets`, `doors` içindeki `msg`); `res://scripts/**/*.gd` içindeki Türkçe harf içeren string literal'leri, `res://scripts/dev/` hariç, `##`/`#` yorum satırları hariç.
- Kurallar (her biri ayrı FAIL etiketi):
  - `three_dots`: metinde `...` var.
  - `banned_word`: `hatıra`, `bellek` (büyük/küçük harf duyarsız, çekim ekleri dahil: kök eşleşmesi).
  - `english_residue`: `DOMAIN`, `END OF PART`, `İz: ` öneki, `PART I`.
  - `json_shilda_speaker`: JSON `s` alanı tam `"Shilda"`.
  - `line_length`: diyalog satırı (`Konuşmacı|` öneki ve `;;` ile bölünmüş parça başına, öneksiz metin) > 90. Diyalog kaynağı = JSON `t`/`variants`, tscn `lines`/`locked_lines`/`repeat_line`/`dialogue_sets`/`intro_text`/`solved_text`/`*refusal_line`/`locked_line`/`locked_message`, gd içinde `DialogueManager.say(`/`whisper(`/`say_with(` çağrısının metin argümanı literal'i. `evidence_body` uzunluk kuralından muaf.
  - `hint_length`: HUD ipucu > 70. İpucu kaynağı = tscn `doors` `msg`, `scripts/story/campaign_objectives.gd` literal'leri.
  - `speaker_format`: tscn `lines`/`locked_lines`/`repeat_line` elemanı ve `dialogue_sets` `;;` parçası tam bir `Konuşmacı|metin` biçiminde değil ya da konuşmacı `KNOWN_SPEAKERS` dışında.
  - `unknown_placeholder`: metinde `{deaths}` dışında `{...}` var.
- Bir kural için yanlış pozitif kaçınılmazsa lint içine `const ALLOW := {"<dosya>:<kural>": "<gerekçe>"}` eklenir; gerekçesiz muafiyet yok.

- [ ] **Step 1: Lint'i yaz, mevcut içerikte koştur; FAIL listesini rapora kaydet**

Run: lint komutu. Expected: exit ≠ 0, `three_dots`/`banned_word`/`english_residue`/`line_length` FAIL'leri listelenir (en az `final_sequence.gd` `DOMAIN` ve `END OF PART` FAIL'i görünmeli — görünmüyorsa tarayıcı hatalı).

- [ ] **Step 2: Mekanik ihlalleri düzelt**

`...` → `…`; hatıra/bellek → "anı" (kişisel) veya "hafıza" (kurum); İngilizce kalıntılar; JSON `"s": "Shilda"` → `"@shilda"`; oda başlıkları; `İz:` haritası. Uzun satırlar ikiye bölünür (anlam aynı). `final_sequence_audit.gd` etiket kontrolü yeni metne güncellenir.

- [ ] **Step 3: Lint + final_sequence + dialogue_data + room_header_fit + e2e koştur**

Expected: hepsi exit 0, lint "LINT FAIL" yok, e2e 0 FAIL.

- [ ] **Step 4: Run-Audit listesine ekle, commit**

```bash
git add scripts/dev/dialogue_lint_audit.gd docs/gelistirme/Run-Audit.ps1 <düzeltilen dosyalar>
git commit -m "test(text): dialogue lint audit, mechanical text fixes, room titles"
```

---

### Task 2: Canon düzeltmeleri + canon kontrolleri

**Files:**
- Modify: `scripts/dev/lore_canon_audit.gd` (yeni kontroller, aşağıda)
- Modify: canon ihlali olan sahne/script/JSON dosyaları (bilinen örnekler: `scenes/rooms/library_reading_cell.tscn:26` ve `data/dialogue/library_reading_cell.json` "1927 yazı"; `scenes/rooms/awakening_crypt.tscn:33`, `scenes/rooms/core_memory_vault.tscn:32`, `scenes/rooms/decay_shilda_wall.tscn:44`, `scripts/story/story_beat.gd:113` "yüzlerce"; `experiment_cells` sızıntısı; `core_memory_vault` ironi satırı; `experiment_intake` çiçek sahibi; `library_hall` kaydı ↔ `library_witness` plaka sırası)

**Interfaces:**
- Consumes: Task 1 lint (yeşil kalmalı).
- Produces: `lore_canon_audit.gd` içinde şu `check(` etiketleri (sonraki görevler bunları kırmamalı):
  - `CANON x_name_late`: X'in özel adı (adı `final_sequence.gd` / `mirrors_1927` kaynaklarından bul) `ROOM_ORDER`'da `mirrors_1927`'den önceki odaların sahne/JSON/story_beat metinlerinde ve sistem metinlerinde (keeper_controller, corpse, campaign_objectives) geçmez.
  - `CANON shilda_human_late`: Shilda'nın insan olduğunu açıkça söyleyen ifade (`insandı`, `insan olarak`, `bir zamanlar insan` vb. — tam liste audit'te `const`) `experiment_observation` öncesi odalarda geçmez.
  - `CANON no_hundreds`: "yüzlerce" hiçbir oyun metninde geçmez.
  - `CANON night_1927`: "1927 yazı" geçmez.
  - `CANON vault_irony`: `core_memory_vault` metinlerinde X'in tesisi kendi seçimiyle içeriden kilitlediği söylenir (anahtar kelime: "kilit" + "kendi" aynı satır kümesinde).
  - `CANON intake_flower_owner`: `experiment_intake` çiçek metni sahibini Shilda olarak verir.
  - `CANON witness_order`: `library_hall` kaydında sayılan tanık sırası, `library_witness` plakalarının çözüm sırasıyla aynı (sıra `library_witness_room.gd`/sahneden okunur, metinden çıkarılan sırayla kıyaslanır).
  - `CANON garden_hint`: `core_bloom_garden` ipucundaki sayılar ("dört, bir, iki") bahçe bulmacasının çözümüyle aynı.
  - `CANON pre_name_shilda`: Nöbet Odası tanışmasından önce oynayan odalarda (`awakening` … `awakening_seal`) metin gövdesinde "Shilda" geçmez.

- [ ] **Step 1: Kontrolleri yaz, koştur**

Expected: mevcut içerikte en az `no_hundreds` ve `night_1927` FAIL; diğerleri mevcut duruma göre FAIL/PASS (rapora yaz).

- [ ] **Step 2: Metni canon'a göre düzelt**

"yüzlerce" → `{deaths}` yalnız `format_text` yolundaysa, değilse sayısız/her ölüm ifadesi. Kasa'ya ironi satırı: X unutmayı yasakladı, sonra kendini hafızaya kilitledi (Global Constraints üslubuyla, ≤ 90). Diğerleri §7'ye göre.

- [ ] **Step 3: Lint + lore_canon + dialogue_data + e2e koştur**

Expected: hepsi exit 0.

- [ ] **Step 4: Commit**

```bash
git commit -am "fix(text): canon decisions locked by lore audit"
```

---

### Task 3: Bölüm I–II metinleri (odalar 01–13)

Odalar: `awakening`, `awakening_balcony`, `awakening_crypt`, `awakening_passage`, `awakening_seal`, `awakening_vigil`, `decay_vines`, `decay_weight`, `decay_greenhouse`, `decay_shilda_wall`, `decay_garden`, `decay_catacombs`, `decay_cistern`.

**Files:**
- Modify: `scenes/rooms/<oda>.tscn` (yukarıdaki odalar; `scenes/main/main.tscn` içinde kurulan oda varsa orası da)
- Modify: `data/dialogue/awakening_vigil.json`, `data/dialogue/decay_cistern.json`, `data/dialogue/decay_greenhouse.json`
- Modify: bu odalara ait story script metinleri (`scripts/story/story_beat.gd` içinde bu oda ID'leriyle kaydedilen satırlar, `scripts/world/awakening_seal_echo_recall.gd`, `scripts/story/shilda_garden_trust.gd`, oda adıyla anılan diğer `scripts/world/*_room.gd`)
- Modify: metni birebir arayan audit'ler (yalnız gerekiyorsa)

**Interfaces:**
- Consumes: T1 lint, T2 canon kontrolleri (yeşil kalmalı).
- Produces: yok (metin).

Yazım yöntemi: her satırı sesli oku; çeviri kokan, anlamsız, soyut ya da uzun satırı Global Constraints'e göre yeniden yaz. Anlamı/olayı koru; bilgi veren satır bilgiyi kaybetmez. Tekrarlanan bilgi tek satıra iner. İpucu satırları fiille biter.

- [ ] **Step 1: Odaların metnini çıkar ve yeniden yaz**
- [ ] **Step 2: Lint + lore_canon + dialogue_data + e2e koştur** — Expected: hepsi exit 0.
- [ ] **Step 3: Rapor dosyasına her oda için 2–3 önce/sonra örneği yaz; commit**

```bash
git commit -am "text: rewrite part I-II dialogue in natural Turkish"
```

---

### Task 4: Bölüm III–IV metinleri (odalar 14–27)

Odalar: `library_hall`, `library_witness`, `library_clockroom`, `library_page`, `library_upper_stacks`, `library_forbidden_wing`, `library_reading_cell`, `experiment_cells`, `experiment_intake`, `experiment_circuit`, `experiment_authority`, `experiment_quarantine`, `experiment_core_conduit`, `experiment_observation`.

**Files:**
- Modify: bu odaların `.tscn` dosyaları; `data/dialogue/library_clockroom.json`, `library_reading_cell.json`, `experiment_intake.json`, `experiment_observation.json`
- Modify: `scripts/story/story_beat.gd` (bu odaların satırları), `scripts/story/library_witness_room.gd`, `scripts/story/page_order_puzzle.gd`, `scripts/story/pocket_watch_inspect.gd`, `scripts/world/archive_door.gd`, oda adıyla anılan diğer scriptler

**Interfaces:** T3 ile aynı. `CANON witness_order`, `CANON shilda_human_late`, `CANON intake_flower_owner` yeşil kalmalı; `experiment_observation` yankısı Shilda'nın insan oluşunu açıkça söyler.

- [ ] **Step 1: Odaların metnini yeniden yaz** (T3 yöntemi)
- [ ] **Step 2: Lint + lore_canon + dialogue_data + e2e koştur** — Expected: hepsi exit 0.
- [ ] **Step 3: Önce/sonra örnekleri rapora; commit**

```bash
git commit -am "text: rewrite part III-IV dialogue in natural Turkish"
```

---

### Task 5: Bölüm V–VI metinleri + final (odalar 28–40)

Odalar: `mirrors_reverse`, `mirrors_dual`, `mirrors_gallery`, `mirrors_unbroken`, `mirrors_labyrinth`, `mirrors_shrine`, `mirrors_1927`, `core_threshold`, `core_ascent`, `core_seal_chamber`, `core_memory_vault`, `core_bloom_garden`, `core`.

**Files:**
- Modify: bu odaların `.tscn` dosyaları; `data/dialogue/mirrors_1927.json`, `mirrors_gallery.json`, `core_ascent.json`
- Modify: `scripts/story/final_sequence.gd`, `scripts/world/cracked_mirror.gd`, `scripts/world/core_crystal.gd`, `scripts/world/echo_altar.gd` varsayılan metinleri, `story_beat.gd` bu odaların satırları
- Modify: `scripts/dev/final_sequence_audit.gd` (yalnız metin eşleşmesi gerekiyorsa)

**Interfaces:** T3 ile aynı. X "siz" der, Noroi X'e "sen" der. `CANON x_name_late`, `CANON vault_irony`, `CANON garden_hint` yeşil. `core_ascent` metinleri Faz 0 mekaniğiyle uyumlu kalır (sunak→plaka→bekle→kapıdan geç).

- [ ] **Step 1: Odaların + finalin metnini yeniden yaz** (T3 yöntemi)
- [ ] **Step 2: Lint + lore_canon + dialogue_data + final_sequence + ascent + e2e koştur** — Expected: hepsi exit 0.
- [ ] **Step 3: Önce/sonra örnekleri rapora; commit**

```bash
git commit -am "text: rewrite part V-VI and finale dialogue in natural Turkish"
```

---

### Task 6: Sistem ve arayüz metinleri

**Files:**
- Modify: `scripts/keeper/keeper_controller.gd`, `scripts/world/corpse.gd`, `scripts/autoload/puzzle_manager.gd`, `scripts/story/campaign_objectives.gd`, `scripts/autoload/echo_manager.gd`, `scripts/autoload/room_manager.gd` (başlık dışı metinler), `scripts/autoload/save_manager.gd`, `scripts/world/interact_glow.gd`, `scripts/world/room_transition.gd`, `scripts/world/code_seal_base.gd`, `scripts/world/encounter_zone.gd`, `scripts/world/memory_seal_point.gd`, `scripts/main.gd`
- Modify: `scripts/ui/title_screen.gd`, `session_menu.gd`, `hud_controller.gd`, `journal_ui.gd`, `journal_map.gd`, `region_title_card.gd`; `scenes/ui/journal.tscn`, `scenes/ui/hud.tscn`
- Modify: metni birebir arayan UI audit'leri (yalnız gerekiyorsa)

**Interfaces:** T3 ile aynı. Shilda satırları 2–8 kelime, "sen". HUD ipuçları ≤ 70 ve fiille biter. Buton/menü etiketleri kısa ad olarak kalır (fiil kuralı ipucu satırları içindir).

- [ ] **Step 1: Metinleri yeniden yaz**
- [ ] **Step 2: Lint + lore_canon + dialogue_data + ui_header_portrait + room_header_fit + start_flow + e2e koştur** — Expected: hepsi exit 0.
- [ ] **Step 3: Önce/sonra örnekleri rapora; commit**

```bash
git commit -am "text: rewrite keeper, system and UI text in natural Turkish"
```

---

### Task 7: Sürüm adayı v1.15.0 + dokümantasyon + tam doğrulama

**Files:**
- Modify: `project.godot` (`config/version="1.15.0"`)
- Modify: `export_presets.cfg` (`version/code=45`, `version/name="1.15.0"`, `export_path` → `TheRoomRemembers-1.15.0-android-arm64.apk`)
- Modify: `README.md` (yeni bölüm "### v1.15.0 (hazır, yayınlanmadı) — Faz 1 diyalog yeniden yazımı": lint kuralları, canon kararları, oda başlıkları, İngilizce kalıntılar; rozet yayınlanmadığı için değişmez)
- Modify: `PROGRESS.md` (Faz 1 satırı; satır satır düzenle, baştan yazma)

- [ ] **Step 1: Sürüm alanlarını güncelle**
- [ ] **Step 2: Tam Run-Audit koştur** — Expected: exit 0, "0 başarısız"; `summary.json` `dev_records` içinde `dialogue_lint` passed.
- [ ] **Step 3: README + PROGRESS güncelle; commit**

```bash
git commit -am "chore: prepare v1.15.0 (unreleased), docs"
```
