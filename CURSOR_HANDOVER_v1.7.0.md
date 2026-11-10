# CURSOR HANDOVER GUIDE — THE ROOM REMEMBERS v1.7.0 REVİZYONU

Bu belge, Antigravity oturumundan Cursor ortamına devredilen **v1.6.0 -> v1.7.0** revizyonunun tam durumunu, tamamlanan adımları ve Cursor'da sırasıyla yapılması gerekenleri içerir.

---

## 🛠️ ÇALIŞMA ORTAMI VE ARAÇLAR
- **Proje Ana Dizini:** `C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\THE-ROOM-REMEMBERS`
- **Godot Konsol Yürütücüsü:** `C:\Users\Osman\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- **Test Çalıştırma Komutu Örneği:**
  ```powershell
  $godot = "C:\Users\Osman\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
  & $godot --headless --path . -s res://scripts/dev/m3_transition_audit.gd
  ```
- **Hedef Sürüm:** `v1.7.0` (versionCode `31`)
- **Uzak Depolar (Release Hedefleri):**
  1. Halka açık release deposu (UpdateChecker hedefi): `jagwey/THE-ROOM-REMEMBERS-release`
  2. Kaynak depo: `jagwey/THE-ROOM-REMEMBERS`

---

## ✅ ANTIGRAVITY TARAFINDA TAMAMLANANLAR (FAZ 1, FAZ 2, FAZ 3)

### 1. Faz 1: Ölüm, Kalıcı Dünya ve Yeniden Doğuş (M1) — TAMAMLANDI & DOĞRULANDI
- **Değiştirilen Dosyalar:**
  - `scripts/autoload/death_manager.gd`: Oda 01 (`awakening`) dışındaki 29 odada oyuncu öldüğünde `RoomManager.get_active_room_id()` odasında kalır ve o odanın güvenli checkpoint/kapı noktasında dirilir. `awakening` odasındaki `rebirth_bed` zorlaması yalnızca Oda 01 içindeki ölümler için geçerlidir.
  - `scripts/autoload/curse_manager.gd`: Ölümde `reload_current_scene` veya `load_committed` çağrısı engellendi. Açılan kapılar, çözülen bulmacalar (`PuzzleManager`), kırılan duvarlar ve cesetler (`CorpseManager`) dünyada kalıcı kalır.
  - Ölüm sonrasında oyuncuya otomatik olarak +%25 lanet eklenir (`CurseManager.add_curse(25.0, &"death")`) ve lanet seviyesi en az %50 (Bant 1) seviyesine çekilir.
  - %100 Lanet (`Possession`) durumunda `world_memory_state` veya `PuzzleManager` silinmez; oyuncu son mühür odasına taşınır ve lanet seviyesi %50.0 güvenli seviyeye çekilir.
  - `scripts/autoload/game_state.gd`: Oda içi yeniden doğuş koordinatları ve checkpoint yönetimi uyarlandı.
- **Test Dosyaları:**
  - `scripts/dev/m1_rebirth_audit.gd` (29 kontrol, 0 FAIL)
  - `scripts/dev/m1_challenger1_audit.gd`, `m1_stress_challenger2.gd`, `m1_forensic_auditor_suite.gd` (toplam 250+ kontrol, 0 FAIL)

### 2. Faz 2: Lanet Mühürleme Noktaları (M2) — TAMAMLANDI & DOĞRULANDI
- **Değiştirilen Dosyalar:**
  - `scripts/world/memory_seal_point.gd`: Artık sıradan bir kayıt noktası değildir. Yalnızca oyuncuda aktif lanet varken (`CurseManager.curse > 0.0`) çalışır.
  - `get_interact_label()`: Lanet yoksa `"Sessiz Mühür"`, lanetliyken `"Laneti Mühürle (%d%%)"` döner.
  - `on_interact()`: Lanetsiz oyuncuya diyalogla ("Kanımda aktif bir lanet yok. Bu mühür sadece lanet altındayken uyanır.") ret verir, kayıt yapmaz. Lanetliyken laneti emer (`clear_curse`), `commit_save` ile durumu mühre kazır, ses çalar ve `SealBanner.show_banner("LANET MÜHÜRLENDİ")` gösterir.
  - Mühürler arası ışınlanma menüsü (`_open_travel`, vb.) kaldırıldı. Hızlı seyahat tek merkez olarak `cracked_mirror.gd` (Çatlak Bellek Aynası) üzerinden yürütülür.
- **Test Dosyaları:**
  - `scripts/dev/m2_seal_audit.gd`, `m2_challenger1_stress.gd`, `m2_adversarial_forensic_suite.gd` (143+ kontrol, 0 FAIL)

### 3. Faz 3: Kapı/Geçiş Deadlock'ı, Oda 1 Softlock'u ve Yan Kapılar (M3) — TAMAMLANDI & DOĞRULANDI
- **Değiştirilen Dosyalar:**
  - `scenes/rooms/awakening.tscn`: Plakanın soluna `WeightStone` eklendi (`(840, 288)`). Eski/işlevsiz `core_portal` düğümü silindi.
  - `scripts/world/memory_hazard.gd`: `awakening_rift` tehlikesi plaka bulmacasından koparıldı; cep saati görüldüğünde (`awakening_mystery_seen`) aktif olur.
  - `scripts/world/room_transition.gd`: `reset_transition_lock()` eklendi. `_ready()`, `_exit_tree()`, `room_changed` sinyalleri ve tüm çıkış yollarında `_transitioning = false` ve `UiGate.set_cutscene(false)` sıfırlaması garantiye alındı.
  - `scripts/player/player_controller.gd`: `<= 44.0 px` mesafedeki kapılara etkileşimde -200 öncelik bonusu verildi.
  - `scripts/main.gd`: `SIDE_DOORS` yan oda kapıları 224px bay katlarına hizalandı, en az 120px nesne mesafesi ve dönüşte 48px içeride doğuş sağlandı.
- **Test Dosyaları:**
  - `scripts/dev/m3_transition_audit.gd` (115 kontrol, 0 FAIL)

---

## 📋 CURSOR'DA YAPILACAKLAR (FAZ 4, FAZ 5 VE RELEASE)

### 📍 ADIM 1: FAZ 4 — 30 ODANIN BÖLGE BÖLGE REVİZYONU
Aşağıdaki oda bazlı düzenlemeleri `scenes/rooms/*.tscn` ve `scripts/world/*.gd` dosyalarında uygulayın:

#### Bölge I — Uyanış Mahmuzu (`awakening`)
- **Oda 01 (`awakening`):** Cep saati -> Shilda -> Taş/Plaka -> Sağ Kapı akışının sorunsuz olduğunu test edin.
- **Oda 02 (`awakening_balcony`):** Teleskop / dış gözlem etkileşiminde tesisin dış dünyadan kopuk, karanlık bir boşlukta asılı olduğunu vurgulayan kanon metnini netleştirin. `soul_seal.gd` `back_side = 1` korumasını doğrulayın.
- **Oda 03 (`awakening_crypt`):** `hidden_symbol.gd` (`586` kodu) için `lantern_corpse` (çiçekli ceset) algılama yarıçapını `reveal_radius = 220.0` yapın ve fener ceset yaklaştığında sembollerin parlamasını belirginleştirin.
- **Oda 04 (`awakening_passage`):** Koridordaki `memory_hazard` yarıklarının bekleme süresini (`_grace = 4.0`) koruyun, `awakening_rift_echo` (`314` kodu) yankı noktasının parlamasını (`InteractGlow`) belirgin yapın.
- **Oda 05 (`awakening_seal`):** `blood_thorn.gd` ile bilerek ölüp plakaya (`awakening_seal_weight`) ceset bırakıldığında, oyuncunun Faz 1 gereği bu odada doğduğunu ve kapının açık kaldığını doğrulayın.

#### Bölge II — Çürüme Bahçesi (`decay`)
- **Oda 06 (`decay_vines`):** `vine_interact.gd` ve `vine_puzzle_lever.gd` arasındaki mükerrerliği temizleyin. Sarmaşıklı engelin kılıç darbesiyle (`receive_sword_hit`) veya kolla doğrudan açılmasını sağlayın.
- **Oda 07 (`decay_catacombs`):** Karanlık odadaki `memory_shade_walking.gd` düşmanlarının 3. kombo vuruşunda düşürdüğü `ClaritySpark` (+%10 Berraklık / Lanet silme) parçacığının çekim (magnet) yarıçapını `28.0 px` yapın.
- **Oda 08 (`decay_weight`):** `weight_stone.gd` ve `pushable_stone.gd` birleşimini doğrulayın; `decay_weight.tscn` içindeki taşın görsel ölçeğini (`scale = Vector2(0.45, 0.45)`) ve çarpışma kutusunu (`22px`) görünür ve rahat itilir boyuta getirin.
- **Oda 09 (`decay_garden`):** `archive_door.gd` içinde kapının açılması için gereken `trusted_keeper` ve `ev_garden_shilda` şartlarından biri eksikse, oyuncuya tam olarak ne yapması gerektiğini ("Bahçedeki kırmızı çiçeği incele" veya "Shilda ile konuş") net söyleyin.
- **Oda 10 (`decay_shilda_wall`):** `encounter_zone.gd` + `cracked_wall.gd` karşılaşmasında oyuncu ölürse `decay_shilda_wall` girişinde yeniden doğacak; duvarın aldığı hasar (`hits()`) kalıcı kalacaktır.

#### Bölge III — Hafıza Kütüphanesi (`library`)
- **Oda 11 (`library_hall`):** `npc_actor.gd` (Arşivci) konuşmalarına oyuncunun lanetli olup olmadığına (`CurseManager.curse > 0.0`) göre dinamik bir giriş cümlesi ekleyin.
- **Oda 12 (`library_upper_stacks`):** Yüksek platformun altına oyuncuya cesedini basamak (`one_way_collision`) olarak kullanabileceğini hatırlatan kısa bir çevresel iz/not ekleyin.
- **Oda 13 (`library_witness`):** `251` mühür kodunun ipuçlarını `1927` ve `1995` kazı/deney kronolojisiyle uyumlu hale getirin.
- **Oda 14 (`library_page`):** Sayfa sıralama bulmacası (`page_order_puzzle`) çözüldüğünde kamera `focus_pulse` ile kapının açıldığını göstersin.
- **Oda 15 (`library_forbidden_wing`):** Oyuncu `ability_pickup.gd` ile Ruh Kesimi (`ability_soul_slash`) ve 1. Mühür Parçası (`seal_shard_1`) aldığında çıkış yolundaki mor mührü (`soul_seal.gd`) keserek test etmesini sağlayın.

#### Bölge IV — Yasak Laboratuvar (`experiment`)
- **Oda 16 (`experiment_cells`):** Deney tanklarındaki (`lore_point.gd`) metinlerin v3 kanonuna (Noroi'nin bir denek olduğu, X'in kurucu olduğu) %100 uyumlu olduğunu doğrulayın.
- **Oda 17 (`experiment_quarantine`):** `curse_cloud.gd` içinde ceset taşıyarak (`corpse.gd`) güvenli koridor açma mekaniği sonrası odanın çıkışında `memory_seal_point.gd` (Lanet Mühürleme Noktası) ile lanetin temizlenmesini doğrulayın.
- **Oda 18 (`experiment_circuit`):** `echo_altar.gd` üzerindeki etiketleri gotik Türkçe terimlerle (`"Yankı Sunağı"`, `"Kayıt Süresi"`) güncelleyin.
- **Oda 19 (`experiment_authority`):** `418` mührü ve Kurucu X kayıtlarının (`X?` konuşmacı token'ı) doğru çalıştığını doğrulayın.
- **Oda 20 (`experiment_core_conduit`):** `experiment_core_conduit.gd` içindeki `LEVER_HOLD_SECONDS` süresini `3.8` saniyeden `4.5` saniyeye çıkarın (mobil dokunmatik kontrollerde yetişmeyi adil hale getirin) ve aynı değeri `experiment_core_conduit.tscn` içindeki `EchoAltar` düğümüne de uygulayın.

#### Bölge V — Aynalar Salonu (`mirrors`)
- **Oda 21 (`mirrors_reverse`):** Tavandaki aynadan okunan görünmez platformlarda (`invisible_platforms`) boşluğa düşüldüğünde oyuncu aynı odanın (`mirrors_reverse`) başında doğsun ve son güvenli zeminde cesedi kalsın.
- **Oda 22 (`mirrors_labyrinth`):** `memory_shade_shielded.gd` kalkanlı gölgelerin kalkanı SoulSlash ile kırıldığında ekstra kamera sarsıntısı ve `ClaritySpark` düşmesini sağlayın.
- **Oda 23 (`mirrors_dual`):** İkili ayna yankı bulmacasında `EchoTwin`'in saldırı ve yetenek tekrarlarını doğrulayın.
- **Oda 24 (`mirrors_shrine`):** Sabit `"X / Dash"` metnini `MobileInputManager.control_name(&"dash")` yapın. Yetenek kazanıldıktan sonra çıkıştaki `curse_barrier.gd` içinden geçilsin.
- **Oda 25 (`mirrors_unbroken`):** `729` mührü çözüldüğünde Çekirdek Eşiği (`core_threshold`) kapısının açıldığını görsel/işitsel olarak vurgulayın.

#### Bölge VI — Bellek Çekirdeği (`core`)
- **Oda 26 - 30:** `core_threshold` ve `core_seal_chamber` içindeki Lanet Mühürleme Noktalarını doğrulayın. `core.tscn` içinde `core_crystal.gd` etkileşiminde iki mühür parçası, `core_seal` ve `ability_soul_slash` tamamsa `EndingManager.trigger(EndingManager.Ending.PART_ONE)` ile tek kanonik finalin (`final_sequence.gd`) sorunsuz başladığını doğrulayın.

---

### 📍 ADIM 2: FAZ 5 — HEADLESS TESTLERİN GÜNCELLENMESİ VE ÇALIŞTIRILMASI
1. **`scripts/dev/death_loop_audit.gd`**:
   - Eski testte oyuncunun her ölümde awakening odasına döndüğü varsayımı vardı. Bunu yeni kurala göre güncelleyin: Oyuncu öldüğü odanın içinde respawn olur ve üzerine +%25 lanet eklenir.
2. **`scripts/dev/memory_seal_audit.gd`**:
   - `CurseManager.curse == 0.0` iken kayıt YAPILMADIĞINI doğrulayın.
   - `CurseManager.add_curse(40.0)` sonrası mühürle etkileşimde lanetin `0.0`'a düştüğünü ve kaydın yazıldığını doğrulayın.
   - Kaldırılan seyahat modalı testlerini temizleyin.
3. **`scripts/dev/curse_reload_audit.gd` ve `scripts/main.gd` (`_headless_faz67_smoke`)**:
   - %100 lanet (`Possession`) durumunda `world_memory_state` bayraklarının silinmediğini ve lanetin `50.0`'ye çekildiğini doğrulayın.
4. **`scripts/dev/e2e_runner.gd`**:
   - F15 kontrolündeki `conduit` süresi kontrolünü `4.5s` (veya `>= 3.8s`) yapın.
5. **Testleri Çalıştırma:**
   ```powershell
   $env:TORIMON_TEST = "1"
   $godot = "C:\Users\Osman\OneDrive\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
   & $godot --headless --path . -s res://scripts/dev/death_loop_audit.gd
   & $godot --headless --path . -s res://scripts/dev/memory_seal_audit.gd
   & $godot --headless --path . -s res://scripts/dev/curse_reload_audit.gd
   & $godot --headless --path . -s res://scripts/dev/m1_rebirth_audit.gd
   & $godot --headless --path . -s res://scripts/dev/m2_seal_audit.gd
   & $godot --headless --path . -s res://scripts/dev/m3_transition_audit.gd
   & $godot --headless --path . -s res://scripts/dev/e2e_runner.gd
   ```

---

### 📍 ADIM 3: SÜRÜM ARTIRMA, APK DERLEME VE GITHUB RELEASES
1. **Sürüm Numaralarını Güncelleyin (`1.7.0`, versionCode `31`):**
   - `project.godot` (`config/version="1.7.0"`)
   - `export_presets.cfg` (`version/name="1.7.0"`, `version/code=31`)
   - `README.md`, `PLAY_TR.md`, `PROGRESS.md`, `scripts/dev/e2e_runner.gd`
2. **Android ARM64 APK Derleyin:**
   ```powershell
   $apkTarget = "C:\Users\Osman\AppData\Local\Temp\torimon-build\TheRoomRemembers-1.7.0-android-arm64.apk"
   New-Item -ItemType Directory -Force -Path "C:\Users\Osman\AppData\Local\Temp\torimon-build"
   & $godot --headless --path . --export-debug "Android" $apkTarget
   ```
3. **Git Commit & Tag:**
   ```powershell
   git add -A
   git commit -m "Release v1.7.0: In-room rebirth, persistent world, curse seal shrines, transition fixes (versionCode 31)"
   git tag -a v1.7.0 -m "Release v1.7.0 (versionCode 31)"
   git push origin main --tags
   ```
4. **GitHub Releases Yayınlayın:**
   ```powershell
   $apk = "C:\Users\Osman\AppData\Local\Temp\torimon-build\TheRoomRemembers-1.7.0-android-arm64.apk"
   $notes = "### THE ROOM REMEMBERS v1.7.0 (versionCode 31)
   - Oda İçi Güvenli Yeniden Doğuş (Awakening hariç 29 odada kendi odasında dirilme)
   - Kalıcı Dünya (Ölümde kapılar, bulmacalar, kırık duvarlar ve cesetler asla sıfırlanmaz)
   - Ölüm Sonrası Lanet Etkisi (+%25 lanet, %100 Possession koruması ile ilerleme kaybı yok)
   - Lanet Mühürleme Noktaları (Yalnızca lanetliyken çalışan, laneti sıfırlayıp kaydeden tapınaklar)
   - Oda 01 Softlock Çözümü (İtilebilir WeightStone, tehlike ayrıştırma)
   - Kapı Etkileşim Önceliği (<= 44px öncelik bonusu, deadlock kurtarma)
   - 30 Oda Bölge Revizyonları ve E2E / Audit Doğrulamaları"

   $env:GH_PAGER = ""
   # 1. Public Release Deposu (UpdateChecker için zorunlu)
   gh release create v1.7.0 $apk --repo jagwey/THE-ROOM-REMEMBERS-release --title "v1.7.0" --notes $notes

   # 2. Private Ana Depo
   gh release create v1.7.0 $apk --repo jagwey/THE-ROOM-REMEMBERS --title "v1.7.0" --notes $notes
   ```
