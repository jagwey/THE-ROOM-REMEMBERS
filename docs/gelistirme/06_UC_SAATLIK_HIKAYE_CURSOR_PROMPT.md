# 06 — Üç Saatlik Hikâye: Cursor İş Promptu

Bu dosyayı Cursor'a olduğu gibi ver. Hazırlandığı tarih: 2026-11-11. Taban: v1.9.0 (commit `241de69`, versionCode 34).

---

## 0. Görev

THE ROOM REMEMBERS (Godot 4.7.2, GDScript) oyununu 30 odadan 40 odaya, ilk oynanışı 165–195 dakikaya çıkar. Tasarım onaylandı ve yazılı:

- **Spec (bağlayıcı):** `docs/superpowers/specs/2026-11-11-uc-saatlik-hikaye-design.md` — önce bunu baştan sona oku.
- **Kanon:** `docs/superpowers/specs/torimon-v3-spec.md` (§17 ad, §19 Shilda'nın beş evresi, §20 bölgeler, §31–32 tek final). Kanon ve tek final değişmez.
- **Durum:** `PROGRESS.md` (son bölüm). Her alt görevden sonra satır düzenleyerek güncelle, dosyayı baştan yazma. Eski bölümlerdeki bozuk karakterli satırlara dokunma.

İş 7 parça. Sırayla yap; her parçanın sonunda denetimler yeşil olmadan sonrakine geçme. Parça 1 tek başına yayınlanmaz (Parça 2 ile çıkar).

## 1. Değişmez kurallar

- Commit, push, release, yayın: **yalnız kullanıcı açıkça isteyince.** Kendiliğinden yapma.
- Sır, anahtar, parola, keystore şifresi hiçbir dosyaya yazılmaz.
- Kod ve identifier İngilizce, oyun metni Türkçe, UTF-8. Ana karakter **Noroi** (asla Shiren).
- Yalnız görevle ilgili dosyaları oku; log/zip/png dökme. Geçici dosyayı repoya koyma.
- Testler `TORIMON_TEST=1` ile koşar. Her kod değişikliğinden sonra headless denetim + 1920x1080 görüntü kontrolü.
- Aynı hata üç kez tekrarlarsa dur ve kullanıcıya sor.
- Diyalog yazım kuralı: kısa satır, kutu başına en çok iki cümle, açıklama diyaloğu yok. Ana yol odası 15–25 satır, yan oda 8–12.
- Shilda'nın adı bahçe sahnesinden (`decay_garden`, Perde 2 sonu) önce hiçbir metinde geçmez. Konuşan adı için sabit `"Shilda"` yazma; `GameState.keeper_speaker_name()` kullan (ad öğrenilmeden `???` döner).

## 2. Şu anki durum (ölçülmüş)

- v1.9.0 üzerinde `docs/gelistirme/Run-Audit.ps1`: 26 denetimin 26'sı geçti, `dev_failed: 0`.
- Bu, betikli davranış denetimidir. **Yapılmayanlar:** insan gözüyle baştan sona oynanış, 1920x1080 görüntü kontrolü, mevcut diyalogların kalite okuması, eski vaka paketi (`cases: 0`).
- Bu oturumda kod değişmedi. Commit edilmemiş dosyalar: spec, bu prompt, `PROGRESS.md`. (Cursor bulut ajanı kullanılacaksa önce bunların commit edilmesi gerekir; karar kullanıcının.)

## 3. Doğrulanmış kod gerçekleri

- **Oda kaydı iki yolla:** (a) `scripts/main.gd` `ROOM_DEFS` (elle kurulmuş 18 ana oda); (b) `scripts/world/built_room.gd` odaları `_ready()` içinde kendini kaydeder. Tüm odalar `scenes/main/main.tscn` içinde `World` altında örneklenir (`ext_resource id="x_<room_id>"` + `[node name="<PascalCase>" parent="World" instance=ExtResource("x_<room_id>")]`).
- **`built_room.gd` kapıları:** `doors = [{"x","y"(ops.),"to","spawn","req","msg"}]`. Her giriş `Door_<to>` üretir (konum `(x, 268)`), hedef spawn `d.get("spawn", "from_<room_id>")`. Ayrıca `from_<to>` spawn'ını `clampf(x ± 48, 48, room_width − 48), 288` konumuna kendisi koyar. İskelet oda şablonu: `scenes/rooms/awakening_balcony.tscn` ve `scenes/rooms/decay_shilda_wall.tscn`.
- **Yan kapılar:** `main.gd` `SIDE_DOORS` + `_add_side_doors()`; `Side_<target>` kapısını `(x, 268)` konumuna koyar, hedef spawn `from_<rid>`, dönüş spawn'ı `from_<target>` = `x ± 48, 288`.
- **Kilit:** `scripts/world/room_transition.gd` `is_locked()` yalnız `required_puzzle` + `PuzzleManager.is_solved` bakar. **Yetenek kilidi yok.** Yetenekler `GameState.player_progress_knowledge` içinde bool: `"ability_soul_slash"` (`library_forbidden_wing`), `"ability_shadow_dash"` (`mirrors_shrine`, Perde 5).
- **Kapı adı** `RoomManager.ROOM_TITLES_TR`'den gelir; başlığı olmayan oda "Geçit" görünür. `room_manager.gd` `ROOM_ORDER` HUD'daki "ODA NN" sırasını verir.
- **Hedef odaya göre kapı arayan kodlar** (yeniden hedeflerken kırma): `scripts/story/page_order_puzzle.gd:160` (`library_forbidden_wing`), `scripts/story/story_beat.gd:291` (`core_threshold`), `scripts/dev/release_audit.gd:192` (`core_seal_chamber`).
- **Kayıt:** oda String id ile saklanır (`GameState.character_current_life_knowledge["room"]`); mevcut id'ler değişmediği için eski kayıtlar geçerli kalmalı.
- **Dışa aktarım:** `export_presets.cfg` iki preset de `export_filter="all_resources"`, `include_filter=""`. Ham `.json` dosyalarının pakete girdiği doğrulanmadı.

## 4. Parça 1 — Temel (oynanabilir 40 oda iskeleti)

### T1. Diyalog verisi
- `data/dialogue/<room_id>.json` klasörü (şema spec'te). Örnek dosya: `data/dialogue/awakening_vigil.json`.
- Yeni autoload `DialogueData` → `scripts/autoload/dialogue_data.gd`, `project.godot` autoload listesine ekle.
- Tek okuma noktası: `DialogueData.get_set(room_id: StringName, set_id: StringName) -> Array` — her eleman `[speaker, text]`.
  - `"@shilda"` → `GameState.keeper_speaker_name()`.
  - `variants`: yukarıdan aşağı ilk eşleşen. `when` anahtarları yalnız: `min_deaths`, `flag`, `not_flag`, `named`, `solved`.
  - Dosya veya set yoksa `push_error` + boş dizi (çökme yok).
- Eski satırları topluca taşıma; yalnız yeni/yeniden yazılan odalar JSON kullanır.
- Denetim `scripts/dev/dialogue_data_audit.gd`: her JSON ayrıştırılır; bilinmeyen `when` anahtarı ve boş `t` hata; satır/kelime toplamını yazdırır; `@shilda` çözümünü adlı/adsız iki durumda sınar; eksik set için boş dizi döndüğünü sınar.
- `docs/gelistirme/Run-Audit.ps1`: kopyalanan klasör listesine (`@('assets','scenes','scripts','themes')`, satır 16) `'data'` ekle; `$devAudits` listesine `dialogue_data` ekle.
- `export_presets.cfg` iki presette `include_filter="data/dialogue/*.json"`. `res://` üzerinden yüklenebildiğini sına.

### T2. On iskelet oda
`built_room.gd` ile, her biri tek geçişli (Parça 1'de bulmaca yok, ileri kapıda `req` yok), `checkpoint = Vector2(120, 288)`:

| room_id | Türkçe ad | bölge | tür |
|---|---|---|---|
| `awakening_vigil` | Nöbet Odası | awakening | ana yol |
| `decay_greenhouse` | Sera | decay | ana yol |
| `decay_cistern` | Sarnıç | decay | yan |
| `library_clockroom` | Saatler Odası | library | ana yol |
| `library_reading_cell` | Okuma Hücresi | library | yan |
| `experiment_intake` | Kabul Odası | experiment | ana yol |
| `experiment_observation` | Gözlem Camı | experiment | yan |
| `mirrors_gallery` | Bedenler Galerisi | mirrors | ana yol |
| `mirrors_1927` | Kırık Gece | mirrors | yan |
| `core_ascent` | Son Merdiven | core | ana yol |

- Ana yol odası `room_width = 1280.0`, yan oda `960.0`. `scenes/main/main.tscn`'e örnekle.
- `ROOM_TITLES_TR`'ye on başlık. `ROOM_ORDER` (40):
  `awakening, awakening_balcony, awakening_crypt, awakening_passage, awakening_seal, awakening_vigil, decay_vines, decay_weight, decay_greenhouse, decay_shilda_wall, decay_garden, decay_catacombs, decay_cistern, library_hall, library_witness, library_clockroom, library_page, library_upper_stacks, library_forbidden_wing, library_reading_cell, experiment_cells, experiment_intake, experiment_circuit, experiment_authority, experiment_quarantine, experiment_core_conduit, experiment_observation, mirrors_reverse, mirrors_dual, mirrors_gallery, mirrors_unbroken, mirrors_labyrinth, mirrors_shrine, mirrors_1927, core_threshold, core_ascent, core_seal_chamber, core_memory_vault, core_bloom_garden, core`
- `scripts/story/campaign_objectives.gd` `_BY_ROOM`'a on giriş. Ad öğrenilmeden hedef metninde "Shilda" yerine "gölge".

### T3. Ana yol kapılarını yeniden hedefle
Kural: yeni odanın sol kapısı `{"x": 40.0, "to": <önceki>, "spawn": <öncekinde zaten var olan spawn>}`, sağ kapısı `{"x": room_width-40, "to": <sonraki>, "spawn": <sonrakinde var olan spawn>}`. Komşu odanın kapısı yeni odaya döner, `target_spawn_id = "from_<komşu_room_id>"` (built_room kendisi üretir). Yeniden hedeflenen ileri kapıdaki mevcut `required_puzzle` korunur.

| Yeni oda | Önceki odadaki kapı | Sonraki odadaki kapı | Yeni odanın kapıları (to / spawn) |
|---|---|---|---|
| `awakening_vigil` | `awakening_seal` `ExitToDecay` → `awakening_vigil` / `from_awakening_seal` (req `awakening_memory_code` kalır) | `decay_vines` `ExitToSeal` → `awakening_vigil` / `from_decay_vines` | sol → `awakening_seal` / `from_decay`; sağ → `decay_vines` / `from_seal` |
| `decay_greenhouse` | `decay_weight` `ExitToGarden` → `decay_greenhouse` / `from_decay_weight` | (sonraki `decay_shilda_wall`) | sol → `decay_weight` / `from_garden`; sağ → `decay_shilda_wall` / `from_decay_greenhouse` |
| `library_clockroom` | `library_witness` `ForwardPage` → `library_clockroom` / `from_library_witness` (req `library_witnesses` kalır) | `library_page` geri kapısı → `library_clockroom` / `from_library_page` | sol → `library_witness` / `from_page`; sağ → `library_page` / `from_witness` |
| `experiment_intake` | `experiment_cells` ileri kapısı → `experiment_intake` / `from_experiment_cells` (req `experiment_cells_seen` kalır) | `experiment_circuit` `BackCells` → `experiment_intake` / `from_experiment_circuit` | sol → `experiment_cells` / `from_circuit`; sağ → `experiment_circuit` / `from_cells` |
| `mirrors_gallery` | `mirrors_dual` ileri kapısı → `mirrors_gallery` / `from_mirrors_dual` (req `mirrors_dual` kalır) | `mirrors_unbroken` geri kapısı → `mirrors_gallery` / `from_mirrors_unbroken` | sol → `mirrors_dual` / `from_unbroken`; sağ → `mirrors_unbroken` / `from_dual` |
| `core_ascent` | `core_threshold` ileri kapısı → `core_ascent` / `from_core_threshold` (req `core_threshold` kalır) | `core_seal_chamber` `BackThresh` → `core_ascent` / `from_core_seal_chamber` | sol → `core_threshold` / `from_seal_chamber`; sağ → `core_seal_chamber` / `from_threshold` |

**`decay_shilda_wall` ana yola taşınır (bahçeden önce):**
- Şu an: genişlik 1280; `CrackedWall` x=1000, `FlowerRoom` x=1120, mahzen kapısı x=1240. Duvarın ötesinde ikinci kapıya yer yok.
- Yap: `room_width = 1440.0`; sol kapı `{"x": 40.0, "to": "decay_greenhouse", "spawn": "from_decay_shilda_wall"}`; bahçe kapısı `{"x": 1260.0, "to": "decay_garden", "spawn": "from_weight", "req": "decay_shilda_wall_broken", "msg": "Duvar yolu kapatıyor."}`; mahzen kapısı x=1400'e (`to: awakening_crypt`, mevcut `req`/`msg` aynı). Zemin ve sınırların 1440'a uyduğunu doğrula.
- `decay_garden` `ExitToWeight` → `decay_shilda_wall` / `from_decay_garden`.
- `FlowerRoom` lore satırındaki sabit `"Shilda|..."` konuşan adı, ad öğrenilmeden `???` görünecek şekilde `keeper_speaker_name()` üzerinden çözülsün.
- Kovalamaca artık zorunlu: bu parçada tamamlanabilir olduğunu sına. Üç kademeli ipucu + üç ölümden sonra kolaylaştırma Parça 3'te.

### T4. Yetenek kilidi + yan kapılar
- `room_transition.gd`: `@export var required_ability: StringName = &""`. `is_locked()` şunu da kilit sayar: `required_ability != &""` ve `GameState.player_progress_knowledge.get(String(required_ability), false)` yanlış. Bu durumda kilit mesajı: `"Bu geçit için Gölge Atılması gerek."` (mevcut `LOCKED_VARIANTS` döngüsünü bozma).
- `SIDE_DOORS` girişleri isteğe bağlı `"ability"` anahtarı alır; `_add_side_doors()` bunu kapıya kopyalar.
- `SIDE_DOORS`'tan sil: `"decay_garden": [{"x": 224.0, "to": "decay_shilda_wall"}]`.
- `SIDE_DOORS`'a ekle (x değerleri mevcut kapı ve etkileşimlerden ≥96 px uzak seçildi):

| ana oda | x | hedef | kilit |
|---|---|---|---|
| `decay_weight` | 720 | `decay_cistern` | `ability: "ability_shadow_dash"` |
| `library_witness` | 590 | `library_reading_cell` | yok |
| `experiment_circuit` | 700 | `experiment_observation` | `ability: "ability_shadow_dash"` |
| `mirrors_dual` | 700 | `mirrors_1927` | `req: "mirrors_gallery"`, msg uygun Türkçe |

- Yan odanın dönüş kapısı: `{"x": 40.0, "to": "<ana oda>", "spawn": "from_<yan_oda_id>"}`.
- Not: `decay_weight` 720, `PathGate`'in (x=560) ötesinde; plaka bulmacası çözülmeden ulaşılmaz, kasıtlı.

### T5. Denetimler
- Yeni `scripts/dev/room_graph_audit.gd` (`$devAudits`'e ekle): 40 oda kayıtlı; her kapının hedef odası ve hedef spawn'ı var; her odada güvenli spawn; aynı odada iki kapı/etkileşim 96 px'ten yakın değil; bulmacalar çözülmüş sayılarak `awakening` → `core` ana yol kapı kapı yürünebiliyor; her yan odadan geri dönülebiliyor; `ability_shadow_dash` yokken iki yetenek kapısı kilitli, varken açık.
- Güncelle: `release_audit.gd:119` ve `:206` (`== 30` → `40`), `room_header_fit_audit.gd:31` (`30` → `40`), `door_audit.gd:110` ve `:158` (`decay_vines` → `awakening_vigil`), `e2e_runner.gd` T3-04 / T4-03 etiketlerindeki "30".
- Kapıda olmayan eski denetimler, önemsizse düzelt: `door_controls_audit.gd:116`, `m3_transition_audit.gd:312–320`.

### T6. Kayıt uyumu ve kapanış
- v1.9.0 biçiminde bir kayıtla (oda id'si eski 30'dan biri) yükleme sınaması: oda bulunur, spawn güvenli.
- `Run-Audit.ps1` tamamen yeşil (`dev_failed: 0`). 1920x1080'de en az şu odaların görüntüsünü kontrol et: `awakening_vigil`, `decay_shilda_wall`, `mirrors_1927`.
- `PROGRESS.md` güncelle.

## 5. Parça 2–7 (ayrıntı spec'te)

Her parçada: odanın bulmacası + hikâye vuruşu + diyalog JSON'u + kanıt kartları; ardından denetimler, 1920x1080 kontrol, süre ölçümü, `PROGRESS.md`.

- **Parça 2 — Perde 1 (Uyanış).** `awakening → awakening_passage → awakening_seal → awakening_vigil`, yanlar `awakening_balcony`, `awakening_crypt`. Shilda ile ilk yüz yüze karşılaşma Perde 1 sonunda `awakening_vigil`'de, konuşan `???`. İlk odalarda karşılaşma yok.
- **Parça 3 — Perde 2 (Çürüme).** `decay_vines → decay_weight → decay_greenhouse → decay_shilda_wall → decay_garden`, yanlar `decay_catacombs`, `decay_cistern`. Ad bahçede öğrenilir. Duvar kovalamacasına üç kademeli ipucu ve üç ölümden sonra kolaylaştırma.
- **Parça 4 — Perde 3 (Kütüphane).** `library_hall → library_witness → library_clockroom → library_page`, yanlar `library_upper_stacks → library_forbidden_wing`, `library_reading_cell`.
- **Parça 5 — Perde 4 (Deney).** `experiment_cells → experiment_intake → experiment_circuit → experiment_authority`, yanlar `experiment_quarantine`, `experiment_core_conduit`, `experiment_observation`.
- **Parça 6 — Perde 5 (Aynalar) + iki geri dönüş turu.** `mirrors_reverse → mirrors_dual → mirrors_gallery → mirrors_unbroken`, yanlar `mirrors_labyrinth`, `mirrors_shrine`, `mirrors_1927`. Gölge Atılması alındıktan sonra `decay_cistern` ve `experiment_observation` turları.
- **Parça 7 — Perde 6 (Çekirdek) + süre.** `core_threshold → core_ascent → core_seal_chamber → core`, yanlar `core_memory_vault`, `core_bloom_garden`. Toplam ilk oynanış 165–195 dk ölçülür.

Toplam hedef: ~950 satır / ~6.000 kelime diyalog, kanıt kartı 15 → ~28, 40 odanın her birinde en az bir hikâye vuruşu ve bir bulmaca, softlock yok, eski kayıtlar açılıyor.

**Mevcut içerikte zayıf bulduğun yeri düzeltme yetkin var** (kullanıcı verdi): diyalog, ipucu, tempo, his. Kanonu ve tek finali bozma; ne değiştirdiğini `PROGRESS.md`'ye yaz.

## 6. Sürüm hazırlığı (yalnız kullanıcı isteyince)

- `project.godot` `config/version`, `export_presets.cfg` `version/code` (+1) ve `version/name` artır. APK adı `TheRoomRemembers-X.Y.Z-android-arm64.apk`.
- GitHub: `gh release create vX.Y.Z <apk> --repo jagwey/THE-ROOM-REMEMBERS-release --title vX.Y.Z --notes "..."`. Oyun içi güncelleme bu public repoyu okur.
- Play Store için kontrol listesi (durumlarını doğrula, varsayma): AAB çıktısı, Play'in güncel hedef API şartı, yayın imzası (keystore ve şifre kullanıcıda, dosyaya yazılmaz), gizlilik politikası adresi, içerik derecelendirme anketi, mağaza metni ve ekran görüntüleri, `permissions/internet` gerekçesi. Play Console girişi ve yükleme kullanıcının işi.

## 7. Raporlama

Her parça sonunda kısa Türkçe rapor: değişen dosyalar, denetim sonucu (gerçek sayı), ölçülen süre, yapılmayan veya doğrulanmayan her şey açıkça.
