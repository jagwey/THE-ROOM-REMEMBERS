# PROGRESS
Dal: cursor/playable-story-flow-8e4e · Sürüm: v1.2.0 (versionCode 16)

## Tamamlandı
- Playable story flow, awakening gates, objectives, softlock düzeltmeleri (v0.10.1)
- Library/experiment/mirrors/core odaları + bulmacalar + endingler
- Claude Code ortamı: autoCompactWindow 200000, CLAUDE.md + PROGRESS.md

## v1.0 Overhaul (8 faz)
- [x] Faz 1: canvas_items+expand, fullscreen, F11, core 960px, kamera fit-zoom, parallax refit
- [x] Faz 3: corpse sınır+tween+toz+dinamik yankı, anchoring ceset korunur, code_seal_base (3 tepki, tuş takımı hep açık), Shilda ROOM_PRESENCE+Marker2D, WeightStone rubble, manifest import keep
- Not: docs/gelistirme/audit.gd eski (2 oda dönemi); HEAD ile aynı sonuç, regresyon değil
- [x] Faz 2 UI: font hiyerarşisi (14/16/19/24, gri AA, outline), GothicModalPanel (menü/sayfa bulmacası/ayna seçimi), diyalog çerçevesi+sayfalama, günlük %80 + Harita&Mühürler sekmesi (journal_map.gd), mobil HUD (yüzen joystick, Jump/Skill, çoklu dokunuş, set_button_cooldown). Audit 49/0 + controls 0
- [x] Faz 4: kamera (look-ahead hız tabanlı, zoom_to, ROOM_BASE_ZOOM, trauma), player (145 hız, accel/friction, zıplama+coyote+buffer, dash cd+afterimage, shadow dash, 3'lü kombo+hitstop+kıvılcım, receive_sword_hit, soul_slash_wave, lanet %80 drift); input jump/skill
- [x] Faz 5: echo_altar/echo_twin/echo_switch (circuit+mirrors_dual buton menüsü kaldırıldı), blood_thorn + awakening_seal_weight (accept_player=false, legacy migr.), curse_cloud (sünger ceset), lantern corpse+hidden_symbol, cracked_wall, Shilda COMBAT (pençe/atılma), sargı hafızası, mercy kill / possession
- [x] Faz 7 tamam (ses+atmosfer+vinyet), audit 49/0, controls 0 fail
- [x] Faz 6: 10 yeni oda (built_room.gd veri-güdümlü), toplam 30 (+core_memory_vault: truth_seen alternatif yolu, +core_bloom_garden: trusted_keeper onarımı); SIDE_DOORS (main.gd); Ruh Kesimi (Yasak Kanat) + Gölge Atılması (Ayna Tapınağı); 2 mühür parçası iyi son şartı; final metinleri kanona göre
- [x] Faz 8: release_audit 107/0 (30 oda, corpses_root, kapı hedef/spawn, softlock kapı grafiği, mühür parçaları); controls_audit 0 hata (+zıplama, dash cd, gölge atılması, ruh kesimi, yankı ikizi, çatlak duvar/savaş, lanet bulutu, mühür tepkileri, final şartı, ceset koruma). Düzeltilen: core_seal_chamber geri kapı spawn adı; ruh kesimi mesafe yedeği
- [x] Android iskelet (2026-11-07): başlık ekranı+duraklatma menüsü (session_menu: Başla/Devam/Yeni oyun, Ses %, Müzik, Joystick, user://settings.cfg), Android geri tuşu (bildirim+go_back_requested+KEY_BACK), arka plana geçince otomatik kayıt+menü, dokunmatik metinler (control_name), kompakt diyalog, sağ kapı etiketi. Cihazda doğrulandı (QC59AM55BMCIEUHQ): başlık, giriş diyaloğu, geri, home→devam, joystick/zıplama/saldırı/atılma. Audit 107/0, controls 0
- APK (debug): scratchpad/apk/trr-debug.apk (ASCII yol şart — apksigner Japonca yolda patlıyor)
- [x] GitHub release v1.0.0 (2026-11-07): https://github.com/jagwey/THE-ROOM-REMEMBERS/releases/tag/v1.0.0 — TheRoomRemembers-1.0.0-android-arm64.apk, tag v1.0.0 → 84f39bc; main henüz birleştirilmedi
- [x] Test geri bildirimi (2026-11-07): etkileşim nesnelerine hale (scripts/world/interact_glow.gd, RoomManager node_added), hız 145→175 / zıplama -290→-322, squash-stretch + anim fps↑, kapı ikonu/etiket/alan büyüdü, plaka mesajı tek sefer. Audit 107/0, controls 0. Cihaz testi: telefon kilitliydi, yapılmadı
- [x] GitHub release v1.0.1 (2026-11-07): https://github.com/jagwey/THE-ROOM-REMEMBERS/releases/tag/v1.0.1 — TheRoomRemembers-1.0.1-android-arm64.apk (versionCode 13, debug imzalı)
- [x] Detaylı ana menü (`scripts/ui/title_screen.gd`): atmosferik parallax arka plan + kıvılcımlar, kayıt özeti kartı (oda/keşif/ölüm/can/hedef), Ayarlar · Nasıl oynanır sayfaları, yeni oyun onayı, klavye/gamepad gezinme, sürüm etiketi
- [x] Fix: hikâye donmasında oyuncu animasyonu durmuyor (havada dash kuralı yalnız dikey hızda)
- [x] GitHub release v1.0.2 (2026-11-07): https://github.com/jagwey/THE-ROOM-REMEMBERS/releases/tag/v1.0.2 — TheRoomRemembers-1.0.2-android-arm64.apk (versionCode 14, debug imzalı)
- [x] GitHub release v1.1.0 (2026-11-07): https://github.com/jagwey/THE-ROOM-REMEMBERS/releases/tag/v1.1.0 — TheRoomRemembers-1.1.0-android-arm64.apk (versionCode 15, debug imzalı, V3 ölüm/respawn sistemi)
- [x] GitHub release v1.2.0 (2026-11-07): https://github.com/jagwey/THE-ROOM-REMEMBERS/releases/tag/v1.2.0 — TheRoomRemembers-1.2.0-android-arm64.apk (versionCode 16, debug imzalı, V4.1 kapı/etkileşim/zıplama/Kaydet-Çık/ikon)
- Bilinen eksik: ses cihazda dinlenmedi; 2 saat süre ve tüm oda turu cihazda doğrulanmadı; release keystore yok
- Test: scratchpad audit.sh (Godot 4.7.2 console, Downloads zip'ten çıkarıldı); TORIMON_TEST=1 gerekli

## v3 hikâye revizyonu (spec 3.0, plan docs/superpowers/plans/v3-story-overhaul.md, SDD ledger .superpowers/sdd/v3-story-overhaul/progress.md)
- [x] T1 lore/canon (2026-11-09, a985d0c): Noroi yazar/yetkili değil, X kazınmış, 1927/1995 ipuçları, Araştırma Yardımcısı S.; lore_canon_audit 0, release 111/0, e2e 50/0; pencereli kontrol edildi
- [x] T2 story flags + save v6 (2026-11-09): `GameState.story_flags` API (set/has/clear + sinyal, 13 bayrak), SAVE_VERSION 6 + v≤5 göçü, kancalar: first_death_completed, first_corpse_discovered, first_archive_record_read, core_access_granted, dimension_origin (awakening_crypt defteri), shilda_past (experiment_authority itirafı; QA turu 2'de taşındı); `story_flags_audit` 0 hata
- [x] T3 kayıt ayrımı (2026-11-09): committed (`SAVE_PATH`, yalnız `commit_save(reason, pos, room)`) + resume (`*_resume.json`, `save_game`/`save_resume_point`), `save_serial` ile Devam Et = yenisi, `load_committed()` resume'ü siler; `save_split_audit` 0 hata
- [x] T4 Hafıza Mühürleri (2026-11-09): 12 ana odada `memory_seal_point` (commit_save + banner + `discovered_seals` iki dosyada, güvenlik kapısı, Mühürler arası geçiş modalı, `seal_<oda>` spawn); `memory_seal_audit` 0 hata, release 111/0, e2e 50/0; pencereli kontrol edildi
- [x] T5 lanet bantları + ele geçirilme (2026-11-09): bantlar 0-49/50-69/70-89/90-99 (`set_curse`, `get_band`, `band_changed`), 100'de ölüm yerine `PossessionOverlay` (ilk ~4.5 sn, tekrar ~2 sn + girdiyle atlama, `GameState.possession_count` iki kayıtta kalıcı) → `load_committed()` + güvenli konum, lanet ≤25; DeathManager/ceset/yatak/final yok; `curse_reload_audit` + `death_loop_audit` güncel; pencereli 1920x1080 kontrol edildi
- [x] T6 yatak respawn (2026-11-09): normal ölüm her zaman `awakening` / `rebirth_bed` (120,280) (`DeathManager.REBIRTH_*`), oda checkpoint'i yalnız lanet yeniden yükleme/mühür yolculuğu için kaldı; ceset uzak odada, dünya kalır, committed `save_serial` değişmez; `death_loop_audit` genişletildi; pencereli kontrol edildi
- [x] T7 açılış/isim · T8 menüler · T9 tek final · T10 diyalog · T11 audit+test planı (ayrıntı aşağıdaki bölümlerde)

## Kalan
- docs/gelistirme/ altındaki izlenmeyen log/zip dosyaları: .gitignore veya temizlik kararı bekliyor
- Oda revizyonu + diyalog yeniden yazımı (2026-11-12): spec `docs/superpowers/specs/2026-11-12-room-overhaul-design.md` onaylandı, plan `docs/superpowers/plans/2026-11-12-phase0-critical-fixes.md`. Faz 0 (dal `feat/phase0-critical-fixes`, yerel commit, push yok) tamam → sırada Faz 1 diyalog → Faz 2–4 odalar.
- [x] Faz 0 T1 (2026-11-12): plaka canlı kural + geçişte kilit (`PuzzleManager.set_live/is_live/live_changed`, `gate_blocker` geçince `mark_solved`+kayıt, `latch_on_press` yalnız Sera SharedPlate), awakening `accept_player` kaldırıldı, decay_weight taş 92..862, `plate_rule_audit` 10/0, e2e 53/53 (baseline [])
- [x] Faz 0 T1 fix round 1 (2026-11-12): `gate_blocker` taraf sıfırlama (oda gizle/göster, teleport >160px, room_changed), canlı açılış sfx + HUD "Bir şey… açıldı.", HUD `live_changed` hedef yenileme, `blood_thorn` is_live, README canlı plaka kuralı, `plate_rule_audit` +3 test (reverse, spawn-past, decay_weight) + latch_on_press beyaz liste
- [x] Faz 0 T1 fix round 2 (2026-11-12): yüklemede/oda aktifleşince 0.6 sn canlı geri bildirim (sfx + HUD) susar (`gate_blocker` grace, `PuzzleManager.live_feedback`), HUD satır zamanlayıcısı yalnız en yenisi temizler, `plate_rule_audit` +2 test (17/0), e2e 53/53
- [x] Faz 0 T2 (2026-11-12): `core_ascent` yeniden yapıldı (üç platform, 112 px boşluk, Ruh Kesimi mührü `core_ascent_seal`, Gölge Atılması perdesi, yankı sunağı+plaka+kapı `core_ascent_echo`; LastStep `core_ascent` ID aynı), `soul_seal`/`curse_barrier` `refusal_line` export (oda adı: Yasak Kanat / Ayna Tapınağı), yeni `ascent_audit` (15/0, Run-Audit'te), plate_rule/room_graph/door 0 fail, e2e 53/53
- [x] Faz 0 T7 (2026-11-12): sürüm 1.14.0 / versionCode 44 (yayınlanmadı, APK yok); e2e F32 sürüm kontrolü sabit 1.13.0 yerine project.godot↔export_presets tutarlılığı; Run-Audit 34 dev denetimi, e2e 53/53; README v1.14.0 bölümü. Final review: Yükseliş sunak metni düzeltildi ("plakaya yürü ve bekle"), `gate_blocker` ağaç dışında ses çalmaz; Run-Audit 34/0, e2e 53/53. Ertelendi: kapıdan geçerek çözülünce sunak etiketi "hareket ediyor…"da kalıyor (Faz 2)
- [x] Faz 0 T6 (2026-11-12): Shilda sprite kesilme/zemine gömülme düzeltildi: `keeper_controller` sprite offset -51 -> -59 (ayaklar zemin üstü y288'de, eskiden 8 px aşağıda), `awakening_balcony` `keeper_observe` x700 (boşluk 660-724 üstü) -> x760; `ui_header_portrait_audit` +keeper_spawns_on_floor, +feet<=2px, +medallion_inside_panel (640x360/1280x720/2400x1080), e2e 53/53
- [x] Faz 0 T2 fix round 1 (2026-11-12): `core_ascent` sahte boşluk+köprü kaldırıldı (perde tek Atılma testi; platformlar gezinme içindir, zıplama sınavı değil), eski kayıt göçü `core_ascent_room.gd` (core_ascent çözülüyse seal/gap/echo çözülür; `soul_seal` dışarıdan çözülünce açılır), `ordered_relic` `soul_refusal_line`/`dash_refusal_line`, `ascent_audit` 25 test
- [x] Faz 0 T3 (2026-11-12): Ayna Tapınağı yan kapısı bulunur: `SIDE_DOORS` `mirrors_unbroken` girişine `title`+`mark`+`label_dy` (`door_title`='Ayna Tapınağı', `main._add_door_mark` nabız atan mor `DoorMark` ışığı), `mirrors_shrine.tscn` `Spawns/from_mirrors_unbroken` (88,288), Shilda `_mirrors_unbroken` beat'ine 'Ayna Tapınağı'na uğra' satırı; `door_audit` 3 yeni kontrol (shrine_spawn_exists, shrine_door_marked, all_side_doors_have_spawn), door/room_graph/dialogue_data 0 fail, e2e 53/53
- [x] Faz 0 T4 (2026-11-12): Katakomb `FlowerSource` (x=150, `flower_source.gd`, tükenmez, hayat başına) -> `character_current_life_knowledge["flower_in_hand"]`; `record_corpse_at` çiçeği cesede aktarır (`has_flower`, mevcut fener) ve sıfırlar, `reset_character_life` bayrağı sıfırlar, `mark_flower_on_corpse` çift sayım yok; `PuzzleManager.HINTS` `decay_catacombs`/`decay_catacomb_seal`; `main.gd` Sarnıç yan kapısından `ability` kaldırıldı (sahnede need_dash/need_soul yok); yeni `softlock_phase0_audit` 6/0 (Run-Audit'te), e2e 53/53
- [x] Faz 0 T4 fix round 1 (2026-11-12): `_trim_excess` çiçekli cesetten izde çift sayım yok, `_deserialize_life` `flower_in_hand` varsayılanı false, çiçek satırlarına '…', `softlock_phase0_audit` 13 test (DeathManager.request_death yolu, ipucu uzunlukları, etkileşim katmanı 8, eski kayıt, trim), e2e 53/53
- [x] Faz 0 T5 (2026-11-12): metin/veri düzeltmeleri: Çiçeklenme ipucu "önce en çok, sonra en az, sonra kalan" (bahçe diyalogları da), library_page ipucu deney→kapı→mühür, kayıt süresi tek sabit 8 sn (`echo_altar.record_seconds`, devre/story_beat metinleri), `ForwardCircuit` → `ForwardIntake` (experiment_cells), ölü `core_portal.gd` silindi, sayfa bulmacası kamera pulse hedefi ROOM_ORDER sonraki odanın kapısı (kapı yoksa pulse yok). Kontroller `dialogue_data_audit` (5 yeni); e2e 53/53, m3 120/0.
- [x] Faz 1 (diyalog) T1 (2026-11-12): `scripts/dev/dialogue_lint_audit.gd` (8 kural: three_dots, banned_word, english_residue, json_shilda_speaker, line_length, hint_length, speaker_format, unknown_placeholder; `Run-Audit.ps1` `dialogue_lint`). Mekanik düzeltmeler: "…", hatıra/bellek → anı/hafıza, `BÖLGE %02d`/`BÖLÜM I SONU`, `TRACE_KIND_TR` (günlük iz adları), oda başlıkları `Karantina Mahzeni`/`1927 Gecesi`, `cracked_mirror` başlıkları `RoomManager.ROOM_TITLES_TR`, 8 HUD hedef ipucu ≤70. Lint 0 FAIL, e2e 53/53.
- [x] Faz 1 (diyalog) T2 (2026-11-12): canon kontrolleri `lore_canon_audit.gd` `_check_canon_decisions` (x_name_late, shilda_human_late, no_hundreds, night_1927, vault_irony, intake_flower_owner, witness_order, garden_hint, pre_name_shilda). Düzeltmeler: "yüzlerce" kalktı (sayısız / sıra sıra), "1927 yazı" → "1927 gecesi", Hücreler'deki "X" sızıntısı → "███"/"Kurucu", Sarnıç + Okuma Hücresi insan ifadeleri ima'ya indi, Kasa ironisi ("tesisi kendi seçimiyle içeriden kilitledi"), Kabul çiçeği Shilda'nın. Hall sırası = Tanık sırası (saat, çiçek, mühür) ve bahçe ipucu = çözüm (4,1,2) zaten tutarlıydı, artık kilitli. Lint/lore_canon/dialogue_data/final_sequence 0 FAIL, e2e 53/53.
- [x] Faz 1 (diyalog) T4 (2026-11-12): Bölüm III-IV (14 oda: library_hall..experiment_observation) metinleri sade Türkçeye yazıldı; "███" -> "[kazınmış]", Okuma Hücresi "Kimdin sen burada?", `experiment_observation` yankısında Shilda'nın insan oluşu açık (Ben de insandım). Kod/sıra (251, 4-1-8, ses-mühür-çiçek, Tanık sırası) sabit. Lint/lore_canon/dialogue_data 0 FAIL, e2e 53/53. Rapor: .superpowers/sdd/2026-11-12-phase1-dialogue/task-4-report.md
- [x] Faz 1 (diyalog) T5 (2026-11-12): Bölüm V-VI + final (13 oda: mirrors_reverse..core) metinleri sade Türkçeye yazıldı; mirrors_1927 echo setinde X açığa çıkıyor ("Bana X deyin", kazınmış imza ona ait; adı yok), core_ascent metinleri sunak→plaka→bekle→kapı mekaniğine uyumlu, Noroi satırları tek cümle. Lint/lore_canon/dialogue_data/final_sequence/ascent 0 FAIL, e2e 53/53. Rapor: `.superpowers/sdd/2026-11-12-phase1-dialogue/task-5-report.md`
- [x] Faz 1 (diyalog) T6 (+review fixes 668b444) (2026-11-12): Shilda/sistem/UI metinleri sade Türkçeye (keeper_controller, corpse, echo_manager, room_transition, encounter_zone, main, code_seal_base, title_screen "SON KAYIT", HUD ipucu fiille biter, "Anı mührü"); Noroi tek cümle, Shilda 2-8 kelime, öncesi "Shilda" yok. Lint/lore_canon/dialogue_data/ui_header_portrait/room_header_fit/start_flow 0 FAIL, e2e 53/53. Rapor: `.superpowers/sdd/2026-11-12-phase1-dialogue/task-6-report.md`
- [x] Faz 1 (diyalog) T7 (2026-11-12): sürüm adayı v1.15.0 / versionCode 45 (yayınlanmadı, APK yok, push yok); README v1.15.0 bölümü; tam Run-Audit: 35 dev denetimi, 0 başarısız (`dialogue_lint` passed), e2e 53/53. Rapor: `.superpowers/sdd/2026-11-12-phase1-dialogue/task-7-report.md`
- [x] Faz 1 (diyalog) T3 (+review fixes) (2026-11-12): Bölüm I-II (13 oda: awakening..decay_cistern) metinleri sade Türkçeye yeniden yazıldı (oda tscn, awakening_vigil/decay_cistern/decay_greenhouse JSON, seal echo recall, shilda_garden_trust, decay_flower_evidence, ilgili campaign_objectives). ID/koşul/ayraç/çözüm sabit; `lore_canon_audit` pre_name_shilda artık eksik script yolunda FAIL verir. Lint/lore_canon/dialogue_data 0 FAIL, e2e 53/53. Rapor: .superpowers/sdd/2026-11-12-phase1-dialogue/task-3-report.md
## V3.0 ölüm/respawn (2026-11-07, güvenli nokta: tag `pre-v3-death-system`)
- [x] P0: Shilda ölüm kilidi kökü = DEATH katmanında yas diyaloğu geçilemiyordu + `dialogue_closed` iptalde gelmiyordu. Düzeltme: `DeathManager.wait_dialogue()` (dokunuş/otomatik ilerleme/zaman aşımı), HUD+interact DEATH'te diyalog ilerletir, keeper tüm beklemeler `dialogue_finished`, ölümde `_abort_combat()`, doğuş sonrası 2 sn saldırı yok, geçersiz oyuncu ref koruması, `keeper_defeated` kalıcı bayrak (gizlenir, iyi son kapanır, aynı anda ölümde önce doğuş), ölürken hasar yok (`GameState.damage`). Başta koşma: taklit fare olayı yok sayılır + nötr joystick şartı + doğuşta zemine oturtma. Adım sesi kapı/ölümde yok
- Test: `scripts/dev/death_loop_audit.gd` (6 döngü, pencereli dokunuşsuz 5.9 sn/ölüm) 0 hata; audit 107/0; controls 0. Cihaz testi yapılmadı
- [x] Ölüm durum makinesi (`DeathManager.Phase` + `phase_changed`), ruh (soluk mor Noroi + ışıltı, kamera `set_focus`), yatak mührü halka+kıvılcım, `play_wake`; ilk ölüm sinematik, sonrakiler hızlı; lanet ele geçirme = ceset/yas/ruh yok. Ceset: zemine oturtma (ışın), meta (facing/curse/time), tek yönlü çarpışma (geçiş tıkanmaz), ilk replik "Bu... benim kıyafetlerim mi?". Kamera silinmiş hedefe bağlanmaz. Test: death_loop (faz sırası, ruh temizliği, ele geçirme) headless 0 hata, pencereli 7.9 sn/ölüm
- [x] Göz açma girişi (`scripts/ui/eye_open_intro.gd`): yumuşak kenarlı siyah göz kapakları, kırpışma, koyu peçe, nefes sesi (`breath`), beyaz flaş yok; `UiGate.Layer.CUTSCENE` (girdi/HUD/günlük kapalı); ilk 2.2 sn, devam 0.9 sn; replikler gözler açılınca. Test: `scripts/dev/eye_intro_audit.gd` pencereli 0 hata (ort. parlaklık ≤0.24)
- [x] Günlük açıkken HUD gizli; adım sesi yumuşak taş + perde/şiddet çeşitliliği (sağ/sol); Shilda yası: ilk ölümde 3 replikli sahne, sonra diyalogsuz "Yine unuttun." (sonraki ölümler 7.9→3.6 sn)
- [x] Yankı tekrarı: oyuncu son 3 sn iz halkası (0.1 sn, 30 örnek, yalnız ölüm odası) → ceset `trail`; ilk incelemede soluk mor Noroi son anları oynar, cesette biter (eski kayıtta klasik hayalet). Test: death_loop (iz ≥4, tekrar düğümü oluşur/silinir) 0 hata
- [x] Göz açmada Menü düğmesi gizli + menü açılmaz (geri tuşu zaten sinematikte menü açmıyor, günlükte günlüğü kapatır). Kayıt: `.prev` yedek, bozuk ana kayıtta yedekten yükleme. Test: `scripts/dev/save_robust_audit.gd` 0 hata, eye_intro 0 hata
- [x] QA (2026-11-07): release 107/0, controls 0, death_loop headless+pencereli 0 (ilk ölüm 12.0 sn sinematik, sonrakiler 3.6 sn), eye_intro 0, save_robust 0. Android debug APK: scratchpad/apk/trr-v3-debug.apk (34 MB). Cihaz testi YAPILMADI; commit edildi, push yok
- Kalan V3: cihazda ses/göz açma/yankı tekrarı dinleme-izleme; ölüm sonrası ~3 sn hedefi için 0.6 sn kırpma opsiyonel
## V4.1 master güncelleme (2026-11-07, güvenli nokta: tag `pre-v4-update`)
- [x] Kaydet ve Çık: onay penceresi → kayıt doğrulanır (`save_game()` bool + geri okuma) → ana menüye döner (uygulama kapanmaz); hata → "Tekrar Dene". Devam Et tam kaydedilen konumdan (`life.resume`, tek kullanımlık; oda değişimi/ölüm siler → ölüm yine yatakta). Başlıkta "Oyundan Çık" onaylı ("Çıkış Yap"). Test: `scripts/dev/save_quit_audit.gd` 27/0; release 107/0, controls 0, death/eye/save_robust 0
- [x] Gotik kapılar: `assets/props/gothic_door_{back,frame,seal}.png` (96x160, karakterin 2.17 katı), `room_transition.gd` katmanlı (arka/iç ışık/çerçeve/mühür), yürü→karar→oda→açıl geçişi, çift dokunuş koruması, 4 kilit mesajı, ölümden sonra kilit açık kalır. Test: `scripts/dev/door_audit.gd` 28/0; release 107/0, controls/death/save/eye 0
- [x] Etkileşim: ortak sistem `interact_glow.gd` (tür renkleri krem/lila/kırmızı, yalnız gerçek hedef parlar + kısa isim etiketi, 0.1 sn hedef sorgusu), `can_interact()` filtresi (Shilda savaşta konuşulmaz), 250 ms tekrar koruması, HUD ipucu aynı etiketi kullanır. Test: `scripts/dev/interact_audit.gd` 21/0
- [x] Zıplama: coyote 0.10 / tampon 0.12, tepe noktası süzülmesi (tuş basılı + |vy|<60 → yerçekimi ×0.55), değişken yükseklik (62 px tam / 20 px dokunuş), `air_phase` (jump_start→rising→apex→falling→landing), iniş sesi 160+ hızda tek sefer, çift zıplama yok, dash ek zıplama vermez. Düzeltme: Zıpla düğmesi Skill ile çakışıyordu (`hud.tscn` yeniden yerleşim). Test: `scripts/dev/jump_audit.gd` 13/0
- [x] Başlık canlı (sis/mühür ışığı/çiçek/uzak Shilda, `_Atmos`), adaptif ikon `assets/icon/` (kullanıcının `image.svg` kırmızı göz illüstrasyonu, Godot ThorVG ile PNG'ye çevrildi; ön katman = görsel, arka = #0E080F), ayak sesi koşu karesine senkron, kitapta HUD gizli (doğrulandı), eksik liste `docs/gelistirme/eksik-assetler-v4.md` (müzik 01–16 yok)
- [x] Regresyon (2026-11-07): release 107/0, controls 0 fail, door 28/0, interact 21/0, jump 13/0, save_quit 0 fail, death_loop 90/0, save_robust 7/0, eye_intro 11/0. Debug APK: scratchpad `apk/trr-v4-debug.apk` (35 MB, ikon APK içinde doğrulandı). Cihazda test edilmedi.
## v1.4.0 (2026-11-07)
- [x] Arka plan hizası: `room_atmosphere.gd::_align_backdrop` far/mid/front'u zemin y=288'e kaydırır, parallax dikey kapalı; yeni `room_backdrop.gd` (gotik tavan kemeri/ribler, zemin taşları, süpürgelik, üst taş şerit, derinlik gölgesi; awakening_balcony için büyük sivri kemer açıklık + korkuluk/gökyüzü)
- [x] Gotik kapı: yeni `gothic_door_art.gd` (prosedürel, standart 52+2x10 x116, grand 60+2x14 x150; sivri kemer, tracery, kilit taşı, #05030a→#0d0816 iç, mühür). `room_transition.gd`: taban y=288, z1-2, bölge geçişinde grand, çarpışma kapıya göre; akış/çift dokunuş/kilit mesajları aynı
- [x] Kapı etiketi: kapı merkezinde, oda sınırlarına 16 px marjla kısıtlı, `UiGate.gate_changed` ile UiGate!=NONE iken gizli
- [x] `lore_point.gd`: fotoğraf beyaz kutu yerine koyu parşömen çerçeve; fısıltı "???" → "Shilda" (`shilda_named` bayrağı, yoksa `shilda_named_partial`'dan türetilir; shilda_name_beat'e dokunulmadı)
- [x] `door_audit.gd`: kapı/oyuncu oranı alt sınır 1.8→1.5 (kapı 116 px, oyuncu ~74 px), oyuncu yerleşimi y ofset 20→0. Test: door 0 fail, release 110/0, controls 0, stress_door_layering 0 FAIL. Balkon yakalaması doğrulanmadı (menüde kaldı); cihazda test yok
- [x] Taş itme (WeightStone + PushableStone, `pushable_stone.gd` artık weight_stone'dan türer): tek yönlü çarpışma (oyuncu yatayda engellenmez, üstüne çıkılır), layer 1|8; omuz itişi oyuncunun `input_x` girişiyle (itişte oyuncu ×0.6 yavaşlar), Etkileş = 36 px tween adımı (duvar/uçurum ışını, min/max_x); plaka her adımda `_recompute` + `weight_stone` slack
- [x] Etkileşim hedefi: `note_push()` ile 1.2 sn yapışık itiş hedefi (ceset/taş, ≤64 px, önde), diğer adaylarda yön ağırlıklı skor (arkadaki +28 px ceza)
- [x] Ölüm çiçeği küçüldü (scale 0.32, Vector2(6,-11)), fener ışığı yumuşadı; Ceset etiketi "Beden"
- [x] Etkileşim vurgusu: glow z 0 + show_behind_parent (arka planın önünde), Ceset/taş/Shilda artık glow alır; hedef olunca ana sprite'a 1 px krem kontur (shader) + nabız self_modulate, move_toward ile söner (kapılar hariç)
- Test: `scripts/dev/push_audit.gd` (yeni, 0 fail), release 110/0, controls 0, death_loop 90/0, jump 13/0, stress_weight_stone 23/0 (Etkileş testi adım modeline güncellendi)
- [x] Oda başlığı: `RoomManager.get_room_number_and_title()` ("ODA 01 · Uyanış" … 30 oda, ROOM_ORDER); HUD `RoomHeader` (üst orta, altın/lila çizgi + elmas, oda girişinde kısa parıltı); hedef etiketi kalplerin altına (y 40), oda adı öneki kaldırıldı (`CampaignObjectives.objective_for_room`, "Saata" yazım hatası düzeldi)
- [x] Kapılar: Menü düğmesi yalnız NONE katmanında (close_menu dahil); günlük (kitap) simgesi ve `open_journal()` yalnız NONE/JOURNAL; Skill düğmesi ilk yetenekten (`GameState.has_any_ability()`) sonra görünür; Jump/Skill gotik halka (`HudTouchButton.gothic_ring`); devam ikonu ">>" / "•" (PixeloidSans'ta ▼/■ yok)
- [x] journal.tscn: kitap 10 px aşağı (sekmeler/Kapat ekranda), sayfalar iç parşömene (0.14–0.86), DetailTitle autowrap WORD_SMART
- [x] Shilda: bilinmeden "???" etiketi (`get_interact_label`), `shilda_named` sonrası fısıltıda "Shilda"; `whisper("Noroi")` artık "???" a çevrilmez (`DialogueManager.resolve_whisper_speaker`)
- [x] Diyalog portreleri: `assets/portraits/*` (worktree'den kopyalandı), `scripts/ui/dialogue_portraits.gd` + `portrait_medallion.gd` (68 px madalyon, dairesel maske + vinyet, yalnız o düğümde lineer+mipmap filtre, konuşmacı değişince fade/slide); metin genişliği portreye göre sayfalanır
- [x] Sol kapı/başlangıç spawn'ı joystick'in sağında (`RoomManager._clear_of_joystick`, min x +150); `encounter_zone._on_room_changed` 2 argümana düzeltildi
- Test: yeni `scripts/dev/ui_header_portrait_audit.gd` (29 PASS / 0 FAIL: başlıklar, portre eşlemesi, fısıltı, günlük kapısı, hedef metni)
- Not: `interact_audit` önceden kırık (awakening'de `ShildaNameBeat` sahnede yok)
- [x] Ana karakter adı Shiren -> Noroi: tüm metin/diyalog/kod/JSON/docs, `assets/characters/noroi*` (git mv), portre eşlemesi `Noroi`; 9 headless audit 0 fail, `interact_audit` tolerans düzeltmesiyle geçiyor
- [x] Sürüm 1.4.0 (versionCode 18), debug APK scratchpad/build14/trr-1.4.0.apk (35.7 MB); dal claude/v1.4-fixes, GitHub release v1.4.0
## v1.4.1
- [x] "Sürekli menüye atıyor" (Android): `mobile_input_manager.gd` — FOCUS_OUT (bildirim perdesi/jest çubuğu/overlay) artık menü açmıyor, sadece kaydediyor; menü yalnız PAUSED'da. Oynanışta geri jesti (sol joystick kenar kaydırma) için 1.5 sn içinde ikinci geri gerekir, ilkinde "Menü için tekrar geri" ipucu. `session_menu.gd`: `is_menu_open()`, test kancası `TORIMON_FORCE_TITLE`. Yeni audit `scripts/dev/start_flow_audit.gd` (0 fail). Cihazda doğrulanmadı.
- [x] Konuşma portreleri: Noroi ve Shilda yeni görsellerden 384px (`assets/portraits/portrait_noroi*.png`, `portrait_shilda.png`)
- [x] Sürüm 1.4.1 / versionCode 19; tüm audit'ler 0 fail

## v1.4.4 — Shilda insansı (yayında)
- [x] Kaynak: `Downloads/The_Room_Remembers_Shilda_Insansi_Godot_Assets_v3.zip` (256x320 kare; `hurt` kareleri bozuk → kullanılmadı).
- [x] `assets/characters/keeper_sheet.png` + `keeper.tres` yeniden üretildi (104x128 hücre, ölçek 0.4, ayak y≈124, offset -60 aynı). Animler: observe/walk/attack/grieve(flower)/talk/warn/dash/flower/disappear. Shilda ≈1.25x Noroi boyu.
- [x] `assets/portraits/portrait_shilda.png` insansı portre (384x384).
- [x] Diyalog skinleri `assets/panels/dialogue_skins/` + `hud_controller.gd` `_apply_dialogue_skin()`: Shilda=kırmızı diken + isimlik, Noroi=beyaz çiçek + isimlik, diğer=gümüş. Mipmap'li lineer filtre, Sigil kaldırıldı.
- [x] Tüm audit'ler 0 FAIL; görsel kontrol (Shilda/Noroi/Bekçi diyalog + sahne) OK.
- [x] Commit + release v1.4.4 (public + private). APK debug keystore ile elle imzalandı (Godot apksigner hatası; sertifika v1.4.3 ile aynı).

## v1.4.3
- [x] Kritik: oyunda her dokunuş menüyü açıyordu. Sebep: `session_menu.gd` Menü düğmesini FULL_RECT MarginContainer içine koyuyordu → düğme tüm ekranı kaplıyordu (v1.3.0'dan beri). Düz Control ile değiştirildi.
- [x] `start_flow_audit.gd`: Menü düğmesi boyut/konum/ekran-merkezi kontrolü (hata öncesi FAIL, sonrası PASS). Tüm audit'ler 0 FAIL.
- [x] 1.4.3 / versionCode 21, APK + release (public release repo + private).

## v1.4.2
- [x] Oyun içi güncelleme kontrolü: `scripts/autoload/update_checker.gd` (autoload `UpdateChecker`), public repo `jagwey/THE-ROOM-REMEMBERS-release` latest release; başlık ekranında "Güncelle → vX" (`title_screen.gd`). Android internet izni açıldı. Release akışı `CLAUDE.md` → "Release" bölümünde.
- [x] Sürüm 1.4.2 / versionCode 20

## v1.4.5 (devam) — Konuşmacı sözleşmesi (ajan A)
- [x] Sözleşme: `""`/`Sistem`/`Kayıt` = anlatıcı (portre yok); `???` yalnız isim öncesi Shilda; `Shilda` isim sonrası; `Noroi` ana karakter. "Sen" ve "Bekçi" konuşmacıları kaldırıldı (portre eşlemesinden de).
- [x] `GameState.is_shilda_named()/set_shilda_named()/keeper_speaker_name()` tek kaynak (`player_progress_knowledge["shilda_named"]`); eski `shilda_named_partial` ve world flag otomatik göç. `DialogueManager.say_with(speaker, text, on_show)` satır-başı geri çağrısı: "Ben Shilda." satırında ad açılır.
- [x] Açılış satırları `""`; oda 1 hedefi isim öncesi "Gölgeyle konuş"; `seen_keeper` oyun başında set edilmiyor; yetim `shilda_name_beat.gd` + ShildaBeatShape silindi.
- [x] library_hall Türkçe karakterler + dekor etiketleri `UiTheme.apply_outlined` (`room_root.gd`); ending_manager epilog başlıkları Türkçe.
- Test: `ui_header_portrait_audit` konuşmacı sözleşmesi taraması + isim açıklama sırası; `e2e_runner` sürüm 1.4.4/22.

## v1.4.5 (devam) — Diyalog çerçeveleri + HUD çakışmaları (ajan B, bölüm 2)
- [x] 2.1: `assets/panels/dialogue_skins/*.png` temizlendi (artık pikseller). `hud_controller.gd`: anlatıcı = varsayılan çerçeve, isimlik/Speaker yok; `???` = varsayılan (bekçi) çerçeve + portrait_bekci (ayrı asset yok); Shilda = warning + name_shilda; Noroi = memory + name_noroi; satır başına anında geçiş; `>>` yerine next_arrow ikonu + nabız. `hud.tscn`: Dialogue 540x165, Continue TextureRect.
- [x] 2.2 HUD: `region_title_card.gd` diyalog/UiGate açıkken kuyruğa alır; masaüstünde dokunmatik düğmeler gizli (`_touch_seen`/`is_touch_ui`); RoomHeader genişliği dinamik (220-440, "..." yok); `room_transition.gd` kapı etiketi kamera+oda sınırına kenetli; `session_menu.gd` Menü düğmesi günlük düğmesinin altına (başlıkla çakışmasın).
- [x] 2.2 Günlük: DetailTitle şeritten kurdele soluna daraltıldı (HINT boyut, 4 satır + "…"); giriş düğmesi min 170; harita başlığı cilde değmiyor; bölge kutuları sayfa içinde (sağ -30), mühür elması sağ-üst, zincir span=rect.x-44; gösterge kurdele soluna; altın kısayol çizgileri (`SHORTCUT_LINKS` tahmini, ROOM_GRAPH yok); `_collect_rooms` 30 oda.
- [x] Yeni test: `scripts/dev/room_header_fit_audit.gd` (30 başlık, en geniş awakening_crypt 288px). ui_header_portrait/start_flow/room_header_fit 0 fail; controls/death_loop/m1_stress/door/release temiz.
- Ekran görüntüleri: scratchpad `...\scratchpad\B\s_*.png` (header_desktop, narrator, unknown, shilda, noroi, journal_notes, journal_map).

## v1.4.5 (devam) — Gorsel/dekor duzeltmeleri (ajan C, bolum 3)
- [x] awakening: far.png gotik tas yatak + cam tup (hastane yatagi/serum/ekran kalkti), mid.png sonuk isik lekesi temizlendi.
- [x] Decor tum odalarda zemine (y=288) oturtuldu (olcekli: books/candlestick/rubble/altar/pocket_watch); isik huzmeleri y<=288 ile sinirli (`room_atmosphere.gd` SHAFT_*), `light_beam.png` ust/alt alpha fade; core runeleri z_index 3.
- [x] Yeni props: telescope, ledger, memory_echo, weight_stone, memory_frame; door_closed/door_open 64x96 gotik yeniden cizildi, kapi spritelari zemine hizalandi. lore_point: parsomen cerceve yerine MemoryFrame, sprite alt kenari zemine.
- [x] keeper: `sprite.offset.y=-51` (ayak zemine), balkon/tum silhouette y=280; `flower` animasyonu (kneel/gul/birak) olay sahnesinde oynar (grieve ayni); keeper_sheet kenar tasmasi temizlendi.
- [x] noroi: sheet satir 4 (jump/fall, turetilmis kareler), `noroi.tres` jump+fall, `player_controller._update_anim` yukselirken jump / dusarken fall; atak karesi bleed pikselleri temizlendi.
- [x] Dogrulama: tum headless auditler 0 fail (controls, death_loop, door, eye_intro, interact, jump, push, resume_m3, room_header_fit, start_flow, update_check, ui_header_portrait, m1_stress, release 110/0, save_quit, save_robust), e2e 50/50. 1920x1080 ekran goruntuleri scratchpad `...\scratchpad\C\shots\*_f.png` (7 oda) gozle kontrol edildi.
- Eksik: jump/fall elle cizilmedi (run/idle karelerinden turetildi); kapi collision sekilleri yeniden boyutlanmadi; atak hilal ucu silindi (yeniden konumlanmadi).

## v1.4.5 (devam) — Fizik/kayit + game feel (bolum 4-5)
- [x] `cracked_wall.gd`: kirilinca layer/mask=0 + `_shape.disabled=true` aninda (+set_deferred). m1_stress kok neden: kirilma `set_deferred("disabled")` ile erteleniyordu, denetim ayni karede okuyunca FAIL. Kirilmada kamera `focus_pulse`.
- [x] `room_manager.apply_initial_room` artik `_setup_m3_mechanics` cagirir ("Devam Et" sonrasi catlak ayna/golge kaybolmaz). Test: `scripts/dev/resume_m3_audit.gd`.
- [x] Acilis kancasi: ilk cep saati etkilesiminde soguk mavi flas + `clock_tick` (tik + kalp atisi) (`pocket_watch_inspect.gd`, bir kez).
- [x] Hitstop 40/45 ms; hit'te tas kirintisi parcaciklari; inis tozu (`_spawn_dust`); Shilda saldiri telegraph sesi `keeper_telegraph` (windup'ta); `follow_camera.focus_pulse` (0.5 sn odak+halka) gate_blocker/vine_gate/cracked_wall'da.
- [x] `audio_manager.gd`: konusmaciya gore prosedurel dialog blip (Noroi/Shilda/Arsivci/???/anlatici), -19 dB, headless/test'te kapali.

## v1.4.5 — Son QA turu + yayın (2026-11-08)
- [x] HUD: `_layout_objective_and_hint()` hedef satır sayısına göre boyutlanır, ipucu altına itilir (core'da üst üste binme yok).
- [x] `region_title_card.gd`: koyu zemin (Backing), diyalog/UiGate açılınca kart gizlenip kuyruğa geri alınır, kapanınca yeniden gösterilir; `is_showing()` statik.
- [x] `room_transition.gd`: kapı etiketi kamera dışındayken ve bölge kartı ekrandayken gizli.
- [x] Doğrulama (TORIMON_TEST=1): 17 headless audit rc=0, SCRIPT ERROR yok (release 110/0, e2e 50/50). 1920x1080 pencereli masaüstü+dokunmatik çekimler (intro, ???→Shilda açılışı, balkon, decay_weight, core, günlük notlar/harita) gözle kontrol edildi; çekimler scratchpad'de, repoda değil.
- Eksik: jump/fall türetilmiş kareler; kapı collision şekilleri; SHORTCUT_LINKS tahmini; ayrı "???" portre asset'i yok; masaüstü istemi "E / El".
- [x] Yayın v1.4.5 (versionCode 23): commit 879f34d (dal claude/v1.4.1, push edildi), release public `THE-ROOM-REMEMBERS-release` + private. APK Godot export-debug (scratchpad kopyasından), sertifika SHA-256 16fd69… önceki sürümlerle aynı. e2e versiyon kontrolü 1.4.5/23.
- [x] Oda nesne/kapı çakışma düzeltmesi (>=110px): decay_garden, awakening, balcony, library_hall, core, seal, witness, cells, mirrors_*, core_* + Shilda keeper_observe marker'ları; SIDE_DOORS/MIRROR_POSITIONS güncellendi. Kontrol: scratchpad rooms/overlap_check.gd (repo dışı)

## v1.4.5 (devam) — HUD/günlük/modal düzeltmeleri (ajan D)
- [x] HUD: hedef/ipucu genişliği safe area'ya sıkıştırıldı + sarma (`_fit_guidance_width`); ipucu dokunmatikte gizli; SafeArea TITLE'da gizli; Zıpla düğmesi El'den uzaklaştırıldı; keypad `⌫` -> `Sil`; dokunmatik ipucu "El ·".
- [x] Bölge/oda adları tek kaynak: `RoomManager.ROOM_TITLES_TR` + `RegionTitleCard.REGION_CARDS["name"]`; kart arka planı alfa 0.94; bölge değişince eski kuyruk temizlenir. CampaignObjectives'ten oda adı öneki kaldırıldı.
- [x] Günlük: DetailTitle genişletildi (max 2 satır), sol başlık aşağı, harita bağlantı çizgisinden uzak, mühür ◇ metne değmiyor (`journal_map.gd`, `journal.tscn`).
- [x] Esc/kapanış: `GothicModalPanel.on_close`; Çatlak Ayna paneli UiGate'i görünürlüğe bağlı; ayna seçimi Esc ile `UiGate.set_story(false)`.
- [x] Menü Title Case; "atıl" tek terim. Açık: `mirrors_shrine.tscn` satır 33 "X / Dash" (oda tscn, dokunulmadı).
- Testler (TORIMON_TEST=1): e2e 50/50, ui_header_portrait, room_header_fit, controls, start_flow, release_audit (110/110) geçti. e2e F18 yalnız eski string aramasını güncelledi.

## v1.4.5 (devam) — sanat/glow/pad (ajan E)
- [x] `interact_glow.gd`: AnimatedSprite2D (Shilda) için kare boyutundan merkez/tepe, etiket hale+"..." üstünde (gap 32); "???" -> "Shilda"; `cracked_mirror.gd` -> "Çatlak Ayna".
- [x] `core_choice_pad.gd`: düz daire/X-A kaldırıldı; gotik rün + "Bağı Kopar [E]" / "Birlikte Mühürle [E]".
- [x] Sanat: noroi `fall` gerçek düşüş pozu (r4c2-3), portrait_noroi_sad, keeper enkaz temizliği + ayrı `flower` kareleri (boş hücreler 4,6-6,7) + `disappear` son boş kare kaldırıldı; door_closed/weight_stone/light_beam/library+mirrors mid kenar yumuşatma.
- [x] Yeni `assets/props/mirror_cracked.png` (32x56). Bağlanmadı: `cracked_mirror.tscn` hâlâ crystal.png (ana oturum bağlamalı, scale ~1).
- Açık: decay_weight.tscn WeightStone scale 0.25 (24px, collision 22px) -> ~0.4-0.5 + collision (tscn, dokunulmadı). Testler: e2e 50/50, interact_audit 0, release 110/0.

## v1.4.8 — Gözlem Balkonu ruh mührü tuzağı (2026-11-08)
- Sorun: Oda 02'ye mahzenden (Shilda duvarı → mahzen → balkon) gelince `from_awakening_crypt` doğuşu mührün sağında (x=880); sola mühür, sağda mühür isteyen kapı → Ruh Kesimi yoksa çıkış yok.
- Düzeltme: soul_seal.gd `back_side` (1/-1): mühür arka yüzden yaklaşınca kendiliğinden çözülür (BackSensor Area2D). awakening_balcony.tscn `back_side = 1`. Önden hâlâ yalnız Ruh Kesimi açar.
- Hedef metni: mühür çözülünce "Mor mühür çözüldü. Mahzen ile balkon arası artık açık." (campaign_objectives.gd).
- release_audit.gd yeni kontrol "No soul-seal traps": her doğuşun bulunduğu yanda mühür istemeyen çıkış ya da `back_side` olmalı (düzeltmesiz FAIL, düzeltmeyle PASS).
- QA: geçici scratchpad testi (önden kapalı/arkadan açılır/geri yürünür) headless + pencereli 1920x1080 geçti, çekimler gözle kontrol edildi. 17 headless audit rc=0 / 0 script error, e2e 50/50, release 111/0.
- [x] Yayın v1.4.8 (versionCode 26, dal claude/v1.4.1): public `THE-ROOM-REMEMBERS-release` + private. APK export-debug (scratchpad build48), sertifika SHA-256 16fd69… aynı. e2e versiyon kontrolü 1.4.8/26; README/PLAY_TR v1.4.8.

## v1.4.7 — ölüm sonrası dokunmatik düğmeler kayboluyordu (2026-11-08)
- Kök neden: HUD `_update_control_visibility()` ölümde (UiGate DEATH, `DeathManager.is_dying`) joystick+düğmeleri gizliyor ama dirilişte `gate_changed` hiç yayılmıyordu → düğmeler oyundan çık/gir yapana dek görünmez.
- [x] Fix `scripts/autoload/ui_gate.gd`: `DeathManager.phase_changed` → `_emit()` (ölümde basılı girdiler de temizlenir).
- [x] Regresyon: `death_loop_audit` dirilişte `gate_changed(NONE)` bekliyor (eski kodda FAIL, yenide PASS).
- [x] QA: 17 headless script rc=0 / 0 hata (e2e 50/50, release 110/0); pencereli 1920x1080 2 ölüm döngüsü → dirilişte joystick/zıplama/saldırı görünür (alpha 1.0), görüntü kontrol edildi.
- [x] Yayın v1.4.7 (versionCode 25, dal claude/v1.4.1): public `THE-ROOM-REMEMBERS-release` + private. APK export-debug (scratchpad build47), sertifika SHA-256 16fd69… aynı. e2e versiyon kontrolü 1.4.7/25; README/PLAY_TR v1.4.7.

## v1.4.6 — Shilda adı, oda çakışmaları, HUD kırpılması: son QA (2026-11-08)
- Shilda ilk replikten adıyla ("Ben Shilda. Oraya gitme."), "???" kalmadı; oda etkileşim/kapı arası ≥110px (tek bilinçli istisna ShildaGarden).
- Günlük haritası: bölge adı kutuya sığana kadar küçülür, mühür ◇ sağ köşede sabit (journal_map.gd `_draw_region`).
- Çekirdek pad etiketi ekran kenarına kırpılmaz (core_choice_pad.gd `_process` kaydırma); dokunmatikte "El · …" ve rünün üstünde (Atıl düğmesi örtmüyor).
- QA: 17 headless audit rc=0 / 0 script error, e2e 50/50, release 110/0; pencereli 1920x1080 + 1800x810 (20:9, dokunmatik) çekim gözle kontrol edildi.
- Sürüm v1.4.6 ile yayınlandı (aşağıda).

## v1.4.6 — Beden taşıma + Ruh Kesişi kapısı (2026-11-08)
- Beden taşıma yeniden: corpse.gd `pick_up/drop`, oyuncu takip eder, boşluk/köprüden zıplayarak geçer; ölüm/oda değişiminde bırakılır. Oyuncu taşırken %90 hız (player_controller `CARRY_SLOW`).
- Kemik Mahzeni: beden x330→~610 taşınıp 5·8·6 sembolleri açılıyor, kod 586 öğreniliyor (Sym reveal_radius 200, hidden_symbol dikey tolerans 120px). Sırttaki bedende ikinci "Bırak" etiketi yok (interact_glow.gd).
- Ruh Kesişi yokken onu isteyen metinler kapalı: campaign_objectives / room_transition / soul_seal yeteneğe göre metin seçer; kalkanlı gölge TURN_DELAY 0.7 → yetenek olmadan arkadan vurulabiliyor; blood_thorn `body_line/solved_line`.
- QA: 17 headless audit rc=0 / 0 script error, e2e 50/50, release 110/0; pencereli 1920x1080 taşıma çekimi (masaüstü + dokunmatik) gözle kontrol edildi.
- [x] Yayın v1.4.6 (versionCode 24, commit f2fcccc, dal claude/v1.4.1 push edildi): public `THE-ROOM-REMEMBERS-release` + private. APK Godot export-debug (scratchpad build46), sertifika SHA-256 16fd69… aynı. e2e versiyon kontrolü 1.4.6/24; README/PLAY_TR v1.4.6.

## v3 hikaye Task 7 — Shilda "???" -> isim sahnesi (2026-11-09)
- [x] Zorla `set_shilda_named(true)` kalktı (main.gd, keeper). Ad tek kaynak: `shilda_name_known` bayrağı (`is_shilda_named()` buna delege; eski anahtarlar göç eder). Ad bilinene dek tüm Shilda/??? satırları `???` kartı + siyah silüet portre (`shilda_unknown`); "???" için ayrı isimlik görseli `name_unknown.png` (aynı süslü plaka).
- [x] Açılış: göz açılır, Noroi "Burası neresi?" -> `intro_completed`. Cep saati: "Saat durmuş. Ama içeriden hâlâ ses geliyor." Shilda uyanış odasında yalnız `first_death_completed` sonrası.
- [x] Kırık Geçit silüet beat'i (`first_shadow_seen`/`first_warning_heard`), ilk beden "Bu... benim kıyafetim." / "Bunu kim bıraktı?", isim sahnesi (Shilda ile ilk etkileşim; "Ben Noroi." satırında ad açılır). Geç odada (mirrors_/core, Shilda present) ad hâlâ yoksa isim sahnesi bir kez otomatik oynar; sessiz isim yalnız Shilda gizliyse (core_final) son çare. Hedef "Gölgeyle konuş" yalnız ilk ölümden sonra.
- Testler (TORIMON_TEST=1): ui_header_portrait 45/0, start_flow 31/0, interact 23/0, e2e 50/50, death_loop 110/0, memory_seal 100/0, release 111/0; pencereli 1920x1080 çekimler gözle kontrol edildi.
- [x] Fix round 1: siluet beat'i oda değişiminde iptal (yerleşimi engellemez), story_beat zorla isim kalktı, `keeper_naming_audit.gd` eklendi (keeper_naming 20/0, ui_header 46/0, diğerleri aynı).

## v3 hikaye Task 8 — Menüler: Jenerik + duraklatma + onaylar (2026-11-09)
- [x] Başlık: Yeni Oyun / Devam Et / Ayarlar / Jenerik / Oyundan Çık (güncelleme düğmesi korundu). Kayıt yoksa Devam Et pasif; kayıt varken Yeni Oyun onayı ("Kayıtlı ilerlemen silinecek..."; Evet/Vazgeç). Nasıl Oynanır sayfası kalktı (slot yok).
- [x] Jenerik: kayan gotik sayfa (`scripts/ui/credits_data.gd`, Task 9 ile ortak; yalnız README'nin desteklediği satırlar, uydurma kişi yok). Başlıkta "Son Hafıza" kartı Türkçe oda adı gösterir (`_room_display_name`).
- [x] Duraklatma: Devam Et / Ayarlar (mevcut ses/müzik/tam ekran/joystick/titreşim kontrolleri, alt sayfa) / Kaydet ve Çık / Ana Menüye Dön; "Yeni oyun" yok. Kaydet ve Çık onayı -> `commit_save(&"save_and_quit")` -> başlığa (uygulama kapanmaz). Ana Menüye Dön onayı -> commit yok, `SaveManager.discard_resume()` ile resume dosyası silinir, Devam Et son commit'li kaydı yükler.
- [x] `grab_focus` !is_inside_tree hataları giderildi (korumalı ertelenmiş `_focus`).
- Testler (TORIMON_TEST=1): save_quit 34/0, start_flow 46/0, ui_header_portrait 0 fail, interact 0 fail, release 111/0; pencereli 1920x1080 `t8_*.png` çekimleri gözle kontrol edildi.
- [x] Task 8 fix round 1: Nasıl Oynanır bloğu (dokunmatik/masaüstü) duraklatma Ayarlar sayfasında; onay başlıkları "Kaydet ve Çık"/"Ana Menü"; Kaydet ve Çık güvenliyse oyuncu konumunu korur (aksi checkpoint); dokunmatik çekimler kontrol edildi. save_quit 38/0, start_flow 0 fail.

## v3 hikaye Task 9 — Tek final: Bölüm I Sonu + jenerik (2026-11-09)
- [x] `EndingManager` enum yalnız {NONE, PART_ONE}; BAD_KILL_KEEPER / SEVER_BOND / GOOD_TRUST_SEAL, epilog ve `can_attempt_*` silindi. `can_begin_final()` = core_seal + iki mühür parçası + Ruh Kesiği.
- [x] Shilda öldürülemez: vuruşta geri çekilir/engeller (`is_defeated()` hep false). `core_choice_pad.gd` ve core.tscn'deki iki pad kaldırıldı; core_choice izi yok.
- [x] `scripts/story/final_sequence.gd`: Ruh Kesiği mührü kırar (`final_seal_broken`), Shilda insan formu (YER TUTUCU tint+hale), §31/§32 satırları, X belirir (`x_revealed`, YER TUTUCU siluet `final_x_actor.gd`), 4 DOMAIN ekranı, çekirdek parçası çekilir, portal, "Noroi... beni duyuyor musun?", THE ROOM REMEMBERS / END OF PART I, jenerik, `game_completed` + `commit_save(&"final")` + başlığa dönüş. Girdi kilitli; satırlar yalnız `final_seen` (settings) sonrası atlanabilir.
- [x] Jenerik ortak: `scripts/ui/credits_scroll.gd` (başlık ekranı Jenerik sayfası + final aynı bileşen, `CreditsData`). main.gd `_headless_faz67_smoke` tek finale güncellendi.
- [x] `scripts/dev/final_sequence_audit.gd` eklendi; death_loop/controls/e2e eski son API'sinden `can_begin_final`/vuruş-ölümsüzlüğe taşındı.
- Testler (TORIMON_TEST=1): final_sequence 22/0, release 111/0, e2e 50/50, death_loop 109/0, curse_reload 66/0, save_quit 38/0, start_flow 46/0, lore_canon 5/0, story_flags 27/0, controls 32/0; pencereli 1920x1080 `t9_*.png` (shilda_human, x_reveal, domain, end_of_part_i, credits) gözle kontrol edildi.
- Not: `TORIMON_SMOKE=1` faz67 smoke curse_fail=false (Task 5 sonrası ölüm yerine ele geçirilme; Task 9 öncesinden kalan), final kısmı good=true.

## v3 hikaye Task 10 — Diyalog cilası: Shilda evreleri, §18 kuralları (2026-11-09)
- [x] Bölge-evre: 1 Mesafeli uyanış/çürüme, 2 Merak kütüphane, 3 Güven deney, 4 Acı aynalar, 5 Ortak amaç çekirdek. `keeper_controller.gd` `_queue_stage_talk(room)` Shilda sakin konuşmasını odaya göre seçer; §19 örnek satırları `story_beat.gd` içinde (deney "Benden önce kimler vardı?", aynalar çiçek değişimi, çekirdek "Buradan birlikte çıkacağız.").
- [x] Uzun satırlar kısaltıldı/bölündü (story_beat, keeper_controller, page_order_puzzle, core_memory_vault.tscn); eski iki-yol final metni temizlendi. `Shilda|` etiketleri korundu, echo_manager değişmedi.
- [x] `lore_canon_audit`: satır uzunluğu kontrolü (>90 uyarı listesi, >120 fail). Önce en uzun 142 (4 satır >120), sonra 88 (0 >90, 289 satır).
- Testler (TORIMON_TEST=1): lore_canon 289 satır/0 fail, interact 0 fail, e2e 50/50, release 111/0, ui_header_portrait 0 fail. Ekran görüntüleri: scratchpad qa/shots t10_stage1/stage4/stage5/longest.png, taşma yok.

## v3 hikaye Task 11a — Park edilen 19 bulgu temizliği (2026-11-09)
- [x] Kayıt/durum (125fdd0): clear_story_flags sinyal yayar; v6 göçü eski kayıttan intro/gölge/uyarı türetir; güvensiz Kaydet ve Çık audit; çukur gerçek-ölçü tehlike kontrolü.
- [x] Ölüm/lanet (7f662a4): `_soul_to_bed()` argümansız, ölü dal silindi; death_loop/curse_reload `first_death_completed` anlamlı assert; smoke ele geçirilme bekler.
- [x] Final (78442ea): ölü EndingUI (kod+sahne+uid) silindi; tamamlanmış oyunda inert kristal satırı; atlama olay tabanlı (`SkipListener`); final audit 18 satır sırası; CLAUDE.md tek final.
- [x] Menüler (1208bf2): başlık Ayarlar'a Nasıl Oynanır bloğu + Titreşim (yalnız mobil/dokunmatik), Tam Ekran dokunmatikte gizli.
- [x] Diyalog (ab0c046): giriş satırı, çekirdek evre konuşması, bölgeye göre yasak uyarı, devre/ikili oda satırları karakterde.
- Testler (TORIMON_TEST=1): release 111/0, death_loop 0, curse_reload 0, save_quit 0, story_flags 0, start_flow 0, final_sequence 0, lore_canon 291 satır/0, interact 0, e2e 50/50, faz67 smoke exit 0 (curse_possession=true).
- Not: keeper `is_defeated`/`_hide_defeated` stubları main.gd smoke/audit referansı yüzünden kaldı. story_flags_audit "current_scene is null" hatası önceden var.

## v3 hikaye Task 11b — Test altyapısı, tam audit koşusu, ekran turu (2026-11-09)
- [x] `Run-Audit.ps1`: 23 dev audit + e2e_runner + faz67 smoke izole kopyada (TORIMON_TEST=1); ikinci import geçişi, kök dosyalar (export_presets/PROJECT/TEST_*) kopyalanır, `-IncludeLegacy` opsiyonel; PASS/FAIL regex düzeltildi.
- [x] `docs/gelistirme/v3-test-plan.md`: spec §36 -> audit haritası + "Otomatik KAPSANMAYAN" listesi.
- [x] Düzeltmeler: `final_sequence.gd` SkipListener `set_input_as_handled()`; `ui_header_portrait_audit.gd` giriş satırı regex'i (11a sonrası bayat); PROJECT/TEST_INFRA/TEST_READY eski ending metinleri v3 tek finale güncellendi.
- Testler (Run-Audit, 25 dev audit + e2e): hepsi geçti, 0 fail (e2e 50/50, release 111, death_loop 110, memory_seal 100, curse_reload 67, final_sequence 27, start_flow 46, faz67 exit 0).
- Ekran turu 1920x1080 (scratchpad qa/tour/shots, qa/shots): title_settings, newgame_intro, seal_*, curse_band50/90/possession_mid, bed_1/2/3, t7_*, t9_*; gözle kontrol edildi. Rapor: `.superpowers/sdd/v3-story-overhaul/task-11b-report.md` (git-ignored).
- Not: eski `audit.gd` `seal` senaryosu AUDIT_TIMEOUT (v0.10.1 öncesi, varsayılan koşudan çıkarıldı). Run-Audit düzeltmesi 3'ten fazla deneme aldı (farklı sorun sınıfları).

## v3 hikaye — Final branch review + düzeltme (2026-11-09)
- [x] Opus final review: 0 Critical / 2 Important / 8 Minor.
- [x] Düzeltme e221a4e: X'in gizli repliği ayrı `X?` token'ı ile "???" (Shilda'ya çözülmez, portre yok, nötr blip); ele geçirilme sırasında `request_death`/`damage` no-op; `load_committed()` başarısızsa uyarı + güvenli konum; `_finish` session_menu yoksa sahne yeniden yüklenir; ölü `possession` dalları silindi. Re-review: APPROVED.
- Testler (TORIMON_TEST=1): final_sequence 32/0, curse_reload 84/0, death_loop 110/0, release 111/0, lore_canon 7/0, e2e 50/50, faz67 exit 0. Pencereli 1920x1080: X repliği "???", portre yok — gözle kontrol edildi.
- Park (küçük): `CurseManager.possessing` yeni oyunda/yüklemede sıfırlanmıyor (ulaşılabilir yol yok); M2 hata yolu odaya yeniden girmiyor; M5 fallback `reset_registry` atlıyor; README/TEST_READY F13 satırı, `.bak` yorumu, ölü `UiGate.Layer.ENDING`.
- Durum: v3 planı tamam. Cihaz (Android) testi yapılmadı.

## Release v1.5.0 (2026-11-09)
- `claude/story-x` (v1.4.9) `-s ours` ile birleştirildi (73d44cf): v3 metni onu geçersiz kılıyor; story-x'in Türkçe metin cilası taşınmadı.
- Sürüm 1.5.0 / versionCode 28 (9818bf2); e2e 50/50 (sürüm kontrolü dahil). `origin/claude/v1.4.1` ve `origin/main` → 9818bf2 (fast-forward).
- APK `TheRoomRemembers-1.5.0-android-arm64.apk` (34,2 MB, debug imza SHA-256 16fd6975…, öncekilerle aynı).
- Yayın: public `jagwey/THE-ROOM-REMEMBERS-release` v1.5.0 (latest) + private `jagwey/THE-ROOM-REMEMBERS` v1.5.0.

## Entegrasyon + Release v1.5.1 (2026-11-09)
- story-x (v1.4.9 metin cilası) ve serene (gotik terimler) v3 kanonuna göre aktarıldı (9b5547e). X adı/isim ifşası, Tanık I/II/III, çoklu final, eksik prop ipuçları v3 ile çeliştiği için atlandı; Noroi suçluluk itirafları temizlendi; `HIKAYE_KANON.md` silindi.
- Testler (TORIMON_TEST=1): Run-Audit 25/0; build kopyasında e2e 50/50. Pencereli 1920x1080 diyalog görüntüleri gözle kontrol edildi.
- Sürüm 1.5.1 / versionCode 29 (a2a215c); APK `TheRoomRemembers-1.5.1-android-arm64.apk` (34,2 MB, imza 16fd6975…). Yayın: public release (latest) + private v1.5.1. `origin/main` = `origin/claude/v1.4.1` = a2a215c.
- Dal temizliği: cursor/*, android_live_playtest, generate_claude_prompt_fixes, adoring/token-usage, claude/v1.4-fixes (yerel+remote), origin/claude/story-x silindi. Ana checkout artık `main`'de.
- Temizlik: eski oturum dalları (story-x, nice-wing, serene), worktree'leri ve eski stash 1c54526 silindi; yerel+remote yalnız `main` ve `claude/v1.4.1`. Cihaz testi yapılmadı.

## Noroi v2 sprite paketi (2026-11-09)
- Referans görsellere göre (gümüş saç, kırmızı lanetli göz, kırık-beyaz pelerin, siyah üniforma) mevcut 20 frame yeniden boyandı; yüz artık cilt tonlu (eski "bembeyaz yüz" sorunu). Layout aynı: 384x480, 4x5, 96x96 → `noroi.tres` değişmeden çalışır.
- Çıktı: `out/noroi_v2/noroi_v2_assets.zip` (sheet, frame_00..19, 384x384 portre, animasyon GIF önizlemeleri, OKUBENI.txt). Oyundaki asset'ler henüz DEĞİŞTİRİLMEDİ; commit yok.
- Bilinen eksik: hurt/death (14-15) frame'lerinde yüz görünmüyor (yalnız saç rengi değişti).
- Kullanıcı v2 recolor'ı "kalitesiz" diye REDDETTİ. Sıradaki yol: AI ile referanstan yeni sprite sheet üretimi (PixelLab üyeliği yok → Gemini/Flow görsel üretimi, kullanıcı PNG verir, ben 96x96 grid/tres/zip'e çeviririm). 2026-11-11: PixelLab denemesi iptal edildi (ücretsiz deneme bitmiş, kredi harcanmadı, oyun dosyaları değişmedi).


## Kapsamlı Oyun Denetimi & Kalite Artırma — Milestone 1, 2, 3 & E2E Tamamlandı (2026-11-10)
- [x] Shilda White Guardian V2.0 HD Asset Remaster:
  - 557.049 piksellik alfa sisi temizlendi (anti-aliased soft threshold).
  - 1:1 orijinal 224x224 canvas ve 8 duygu portresi (384x384, neutral/gentle/smile/sad/worried/angry/determined/eyes_closed) oluşturuldu.
  - 33 piksellik zıplama/titreme giderildi, ağırlık merkezi ve ayak tabanı (Y=196) kilitlendi.
  - `addons/trr_shilda_white` ve `assets/portraits/shilda/` entegre edildi. Headless ve header denetimlerinden (48/48) 0 hata ile geçti.
- [x] Milestone 1 (P0 Temel Mekanikler & Yarış Durumları):
  - 100% lanet ele geçirilmesi ile ölüm döngüsü yarış durumu çözüldü (`CurseManager.possessing` mutex koruması).
  - Ceset itme dinamik oda sınırlarına bağlandı (`corpse.gd`).
  - Basınç plakası üzerindeki cesetlerin dekoratif ize dönüşmesi engellendi (`corpse_manager.gd` anchoring).
  - Stres testleri (`curse_death_concurrency_stress_audit.gd` 53/53, `m1_challenger2_audit.gd` 24/24) 0 hata ile onaylandı.
- [x] Milestone 2 (V3 Hikâye Kanonu, Noroi Hafızası & Shilda Sistemleri):
  - Feature 6: Noroi 3 katmanlı hafıza izolasyonu uygulandı; her ölümde `character_current_life_knowledge` sıfırlanır, `awakening` yatağına döner. Cep saati (`pocket_watch_inspect`), mühür rezonansı (`awakening_seal_echo_recall`), kanlı diken (`blood_thorn`) ve geçit replikleri amnezik kanona göre arındırıldı.
  - Feature 7: Eski "Shiren" isim kırıntısı ve boş dizin tamamen temizlendi (`lore_canon_audit` 0 hata).
  - Feature 8 & 9: Shilda ismi tanışma öncesi gizlendi ("???", "Gölge", "Bekçi"); §17 diyaloğu iptal edilirse isim bayrağı açılmaz (`keeper_naming_audit` 18/18 PASS).
  - Feature 10 & 11: 5 sütunlu eylem odaklı güven modeli (`GameState.get_shilda_trust_state()`, `is_shilda_trusted()`) entegre edildi. Savaşta öldürülemezlik, savunma kalkanı efekti (`_spawn_defensive_shield()`) ve barışma diyaloğu eklendi.
  - Feature 12 & 13: Tek kanonik final (END OF PART I, Kurucu X gelişi öncesi çıkış kapısının aralanması) uygulandı; `PLAY_TR.md`'den eski 5 alternatif son temizlendi; `docs/specs/shilda_human_asset_spec.md` şartnamesi hazırlandı (`final_sequence_audit` 0 hata).
- [x] Milestone 3 & 4 (3 Kademeli İpuçları, Türkçe Metin, UI & Güvenlik):
  - `PuzzleManager` 3 kademeli ilerlemeli ipucu sistemi (`get_hints`, `get_current_hint` - Hedef / Yönelim / Açık) 7 ana bulmaca için eklendi.
  - `session_menu.gd` "Kaydet ve Çık" onay penceresi doğrulandı (`save_quit_audit` 0 hata).
  - 30 odanın kapı, geçiş, çarpışma ve sahne bütünlüğü doğrulandı (`release_audit` 111/111 PASS).
  - Kontroller, yetenekler ve dövüş mekanikleri doğrulandı (`controls_audit` 33/33 PASS, `push_audit` 0 hata, `door_audit` 0 hata, `interact_audit` 0 hata).
- [x] Milestone 5 (E2E Opaque-Box Doğrulama):
  - `res://scripts/dev/e2e_runner.gd` 4 kademeli (Tier 1-4, 50 kontrol) master test paketi koşturuldu:
  - **OVERALL TOTAL: 50 | PASSED: 50 | FAILED: 0 | PENDING: 0**.

## v1.7.0 BÃ¼yÃ¼k Mekanik, GeÃ§iÅŸ, Lanet/Ã–lÃ¼m & 30 Oda Revizyonu (2026-11-10) - CURSOR DEVRÄ°
### âœ… TAMAMLANANLAR (Faz 1, Faz 2, Faz 3):
- [x] **Faz 1: Ã–lÃ¼m, KalÄ±cÄ± DÃ¼nya ve Yeniden DoÄŸuÅŸ Mimarisi (M1)**:
  - \scripts/autoload/death_manager.gd\: Oda 01 (\wakening\) dÄ±ÅŸÄ±ndaki 29 odada Ã¶lÃ¼m durumunda oyuncu bulunduÄŸu odanÄ±n (\RoomManager.get_active_room_id()\) gÃ¼venli spawn/checkpoint noktasÄ±nda yeniden doÄŸar. Oda 1 yataÄŸÄ±na zorunlu dÃ¶nÃ¼ÅŸ (\REBIRTH_BED\) kaldÄ±rÄ±ldÄ±.
  - \scripts/autoload/curse_manager.gd\: Ã–lÃ¼m gerÃ§ekleÅŸtiÄŸinde \
eload_current_scene\ veya \load_committed\ ile dÃ¼nya sÄ±fÄ±rlanmaz; aÃ§Ä±lan kapÄ±lar, bulmacalar, kÄ±rÄ±lan duvarlar ve cesetler kalÄ±cÄ± kalÄ±r.
  - Ã–lÃ¼m sonrasÄ± oyuncuya otomatik +%25 lanet (\CurseManager.add_curse(25.0, &"death")\) eklenir; en az 50.0 seviyesine Ã§Ä±karÄ±lÄ±r.
  - %100 Lanet (\Possession\) durumunda dÃ¼nya ilerlemesi (\world_memory_state\, \PuzzleManager\) silinmez; oyuncu son mÃ¼hÃ¼r odasÄ±na taÅŸÄ±nÄ±p laneti %50'ye Ã§ekilir.
  - DoÄŸrulama: \m1_rebirth_audit.gd\, \m1_challenger1_audit.gd\, \m1_stress_challenger2.gd\, \m1_forensic_auditor_suite.gd\ (250+ kontrol, 0 FAIL).
- [x] **Faz 2: Lanet MÃ¼hÃ¼rleme NoktalarÄ± (\memory_seal_point.gd\) (M2)**:
  - \scripts/world/memory_seal_point.gd\: ArtÄ±k sÄ±radan bir checkpoint deÄŸil, yalnÄ±zca "Lanet MÃ¼hÃ¼rleme NoktasÄ±" olarak Ã§alÄ±ÅŸÄ±r.
  - Lanet yokken (\<= 0.0\) etkileÅŸim reddedilir, kayÄ±t yapÄ±lmaz ("KanÄ±mda aktif bir lanet yok...").
  - Lanetliyken (\> 0.0\) laneti emer (\clear_curse\), checkpoint belirler, \commit_save\ yapar ve "LANET MÃœHÃœRLENDÄ°" afiÅŸini gÃ¶sterir.
  - MÃ¼hÃ¼rler arasÄ± hÄ±zlÄ± seyahat menÃ¼sÃ¼ kaldÄ±rÄ±ldÄ±; hÄ±zlÄ± seyahat yalnÄ±zca \cracked_mirror.gd\ Ã¼zerinden gerÃ§ekleÅŸir.
  - DoÄŸrulama: \m2_seal_audit.gd\, \m2_challenger1_stress.gd\, \m2_adversarial_forensic_suite.gd\ (143+ kontrol, 0 FAIL).
- [x] **Faz 3: KapÄ±/GeÃ§iÅŸ Deadlock'Ä±, Oda 01 Softlock'u ve Yan KapÄ±lar (M3)**:
  - \scenes/rooms/awakening.tscn\ & \scripts/world/memory_hazard.gd\: PlakanÄ±n soluna itilebilir \WeightStone\ ((840, 288)) eklendi; \wakening_rift\ tehlikesi plaka bulmacasÄ±ndan koparÄ±ldÄ± (cep saati gÃ¶rÃ¼lÃ¼nce aktif).
  - \scripts/world/core_portal.gd\: Ä°ÅŸlevsiz/sahte core_portal dÃ¼ÄŸÃ¼mÃ¼ kaldÄ±rÄ±ldÄ±.
  - \scripts/world/room_transition.gd\: \
eset_transition_lock()\ eklendi; sahneye giriÅŸ, Ã§Ä±kÄ±ÅŸ ve oda deÄŸiÅŸimlerinde geÃ§iÅŸ kilidi ve cutscene sÄ±fÄ±rlamasÄ± saÄŸlandÄ±.
  - \scripts/player/player_controller.gd\: KapÄ±lara (\
oom_door\) <= 44.0 px mesafede -200 etkileÅŸim Ã¶ncelik bonusu eklendi.
  - \scripts/main.gd\: \SIDE_DOORS\ 224px bay katlarÄ±na hizalandÄ±, nesnelere en az 120px aÃ§Ä±klÄ±k ve dÃ¶nÃ¼ÅŸte 48px iÃ§eride doÄŸuÅŸ saÄŸlandÄ±.
  - DoÄŸrulama: \scripts/dev/m3_transition_audit.gd\ (115 kontrol, 0 FAIL).

---

### ✅ CURSOR TAMAMLADI (Faz 4 & Faz 5 & Release) — 2026-11-10
- [x] Faz 4 Bölge I–VI oda revizyonları uygulandı.
- [x] Faz 5 audit güncellemesi + headless koşu (death_loop, memory_seal, curse_reload, m1/m2/m3, e2e 50/50).
- [x] Sürüm 1.7.0 / versionCode 31; APK derlendi; GitHub Releases.

## v1.8.0 — Kapı kontrol fix + polish (2026-11-10)
- [x] P0: ODA 03 sonrası kaybolan joystick — kök neden: kapı `_travel` await'i eski odada `PROCESS_MODE_DISABLED` kalıyordu; geçiş `RoomManager.run_door_travel` üzerinde; `door_controls_audit` eklendi.
- [x] Polish: gotik kapı collision hizası, ClaritySpark ortak spawn/magnet, ???/X? ayrı portreler, Bölüm II teaser; jump/fall sheet satır 4 doğrulandı.
- [x] Sürüm 1.8.0 / versionCode 32; ses/Play Store yok.

## v1.8.1 — Kalite geçişi (2026-11-10)
- [x] Hareket: `reset_transition_lock` her oda değişiminde nötr-joystick kilidini yeniden kuruyordu; oyuncu sağa basılı tutunca yerinden oynamıyordu. Kilit yalnız geçiş başında kurulur.
- [x] Taş itme: zemin ışını gövdenin içinden başlayınca Godot çarpışmayı kaçırıyor, kefaret taşı adım atmıyordu. Işın artık zeminin üstünden bakıyor.
- [x] Etkileşim: arkadaki yan kapı 44px içinde -200 ile ayakucundaki nesneyi yutuyordu. Öncelik yalnız öndeki kapıda ve küçük (-16).
- [x] Diyalog: açılış, arşivci ve deney/yetki satırları daha konuşulur hale geldi (kanon ve satır uzunluğu korundu).
- [x] Odalar: tavan dolgusuna bölge motifi (sarmaşık, raf, tank, ayna kırığı, çekirdek, mum).
- [x] Bulmaca ilk çözümünde `seal_open` + "HATIRLANDI" afişi (testlerde afiş yok).
- [x] Sürüm 1.8.1 / versionCode 33.

## v1.9.0 — Derin oynanış geçişi (2026-11-11)
- [x] Odalar: Çiçek Bahçesi (4-1-2 taş sırası, güven kapısı), Hafıza Kasası (1927/1995/Son), Üst Raflar (ses-mühür-çiçek tahtası), Ayna Labirenti (yükselen yol + soluk kırmızı yalan), Karantina (sis sonrası raf), Gözlem Balkonu (kopuk zemin).
- [x] Hikâye: açılış kancası, saat 3:14, isim sahnesi, finalde Noroi'nin cevabı. Günlük ipucu 3 kademe (hedef / yön / açık).
- [x] His: plaka ve kapı sarsıntısı, sunak parçacığı, çözümde lanet -8. Bölge motifleri: bahçe, kasa, karantina, labirent.
- [x] Denetim: `room_identity_audit`. Sürüm 1.9.0 / versionCode 34.

## Üç saatlik hikâye — tasarım (2026-11-11)
- [x] Spec yazıldı: `docs/superpowers/specs/2026-11-11-uc-saatlik-hikaye-design.md` (30→40 oda, 6 perde, 2 geri dönüş turu, oda başına diyalog JSON'u, 7 parça). Kod değişmedi, commit yok.
- [x] Spec onaylandı (kullanıcı uygulamaya geç dedi).
- [x] v1.9.0 headless denetim: `Run-Audit.ps1` 26/26 geçti, `dev_failed: 0`. Yapılmadı: insan oynanışı, 1920x1080 görüntü kontrolü, mevcut diyalog kalite okuması.
- [x] Uygulama Cursor'a devredildi. İş promptu: `docs/gelistirme/06_UC_SAATLIK_HIKAYE_CURSOR_PROMPT.md` (kapı tablosu, yetenek kilidi, denetim güncellemeleri içinde). Bu oturumda kod değişmedi, commit yok.

### Yapılacaklar (Cursor)
- [x] Parça 1 / T1: `DialogueData` autoload + `data/dialogue/*.json` + `dialogue_data_audit` + `Run-Audit.ps1` (`'data'` kopyası) + export `include_filter`.
- [x] Parça 1 / T2: on iskelet oda (`built_room.gd`), `main.tscn`, `ROOM_ORDER`/`ROOM_TITLES_TR` 40, `campaign_objectives.gd`.
- [x] Parça 1 / T3: ana yol kapıları yeniden hedeflenir; `decay_shilda_wall` bahçeden önceye (genişlik 1440, bahçe kapısı x=1260).
- [x] Parça 1 / T4: `required_ability` (`room_transition.gd`) + `SIDE_DOORS` (bahçe→duvar silinir, dört yeni yan kapı).
- [x] Parça 1 / T5: `room_graph_audit` + eski denetimlerde 30→40 ve `decay_vines`→`awakening_vigil`.
- [x] Parça 1 / T6: v1.9.0 kayıt uyumu, tam denetim yeşil (28 dev + e2e + smoke, dev_failed 0), 1920x1080 kontrol (Nöbet Odası, Çatlak Duvar, Kırık Gece). Sürüm artırılmadı.
- Not: yankı anahtarları (devre x=320, ayna x=320) kapı x'i spec'te kalsın diye 96 px dışına alındı. Üst raflarda arşivci x=148. Kapı denetimi kapı↔kapı/etkileşim ölçer; kol-taş ve kart-mühür çiftleri eski bulmaca düzeni. Duvar ipucu ve çiçek kartında ad yok (bahçeden önce).
- [x] Parça 2: Perde 1 (Uyanış, Nöbet Odası'nda ilk karşılaşma). Yatak odasında yüz yüze yok; taze çiçek. Geçitte kendi sesi. Nöbet sahnesi ???, ad yok, yol açılınca gölge gider. Sürüm artmadı.
- [x] Parça 3: Perde 2 (Sera, duvar kovalamacası ipuçları, bahçede ad sahnesi). Sera plakası ortak mühür. Duvar ipucu üç kademe, üç ölümden sonra tek çarpma. Ad çiçekte açılır. Sürüm artmadı.
- [x] Parça 4: Perde 3 (Kütüphane, Saatler Odası, Okuma Hücresi). Saatler 1927 sonra 1995. Hücrede gün çentikleri. Sürüm artmadı.
- [x] Parça 5: Perde 4 (Deney, Kabul Odası). Dosya sonra palto: Denek 14 Noroi'dir. Gözlem camı Tur 2'de (Parça 6). Sürüm artmadı.
- [x] Parça 6: Perde 5 (Aynalar, Bedenler Galerisi, Kırık Gece) + iki geri dönüş turu. Galeri ceset sayar. 1927 izlenir. Sarnıç günlüğü ve gözlem notu Gölge Atılması ardında. Sürüm artmadı.
- [x] Parça 7: Perde 6 (Son Merdiven) + süre ölçümü. Yankı, Ruh Kesimi ve Gölge Atılması aynı basamakta; sonra «Gidelim.» Ölçüm (`playtime_measure.gd`): 405 satır, okuma 21.6 dk, ana yol 42.6 dk, yanlarla 52.1 dk. Hedef 165–195 tutmadı; bu alt sınır, insan kaybolması değil. Sürüm 1.10.0 / versionCode 35.
- [ ] Sürüm hazırlığı ve Play Store kontrol listesi (yalnız kullanıcı isteyince). Yayın yok: THE-ROOM-REMEMBERS-release'e dokunulmadı.
- [x] QA turu 1 (2026-11-11, v1.12.2 / 84a2032): kod değişmedi. 28 headless denetim + move_time_audit 28 geçti. Raporlar `qa/release-readiness/` (00-09). Karar: Play için NO-GO (AAB/imza/gizlilik/lisans/cihaz testi yok; 3 kanon P1; ana yol 42,6 dk ↔ 165-195). BUG-001/002 yeniden üretim testi bekliyor; kanon düzeltmeleri kullanıcı onayı bekliyor. Not: bu dosyada v1.11.x-1.12.2 bölümleri yok; CLAUDE.md v0.10.1 diyor (gerçek 1.12.2).
- [x] v1.11.0 / versionCode 36. Sunum geçişi: havada basamaklar (balkon dilimleri silindi; kalanlar zincir/ayak/duvar çıkması), ön plan sütunları kaldırıldı, jenerik Torimon Studio ve kenar kırpması, sürüm etiketi `config/version`, diyalog/hedef sesi, Gradle Android şablonu (`docs/gelistirme/ANDROID_APK_GECERLILIK.md`).
- [x] BUG-001/002/010 kilitlenme düzeltmesi (2026-11-11, sürüm artmadı, commit yok): yeni `scripts/dev/softlock_reset_audit.gd` (Run-Audit listesinde). Düzeltme öncesi 5 FAIL: ölüm sırasında Yeni Oyun -> eski ölüm coroutine'i yeni oyunda `first_death_completed` + lanet 50 yazdı; `fail_curse_possession` x3 -> possession_count +3, 3 overlay (yeniden giriş). Soul `free()` ve possession+Yeni Oyun/Ana Menü cutscene takılması yeniden üretilemedi (savunma amaçlı koruma eklendi). Düzeltme: `DeathManager._gen` + `reset_state()`, `CurseManager._possession_gen` + `_begin_possession` yeniden giriş koruması, `reset_for_new_life` cutscene bırakır, `start_new_game`/`return_to_title` `reset_state()` + `set_cutscene(false)`. Sonuç: softlock_reset 68/0, curse_reload 92/0, death_loop 113/0, m1_stress 64/0, save_split 32/0, save_quit 44/0, controls 32/0, move_time 28/0.
- [x] QA turu 2 (2026-11-11, sürüm artmadı, commit yok): save sağlamlığı (BUG-011/012/030b) `SaveManager`: yeni oyun eski kaydı yeni kayıt yazılana dek silmez, `_write_atomic` sonucu doğrular, yüklemede tip zorlama (`_int_of`, `_float_of`, `_coerce_container`). Yeni `save_robustness_audit.gd` (düzeltme öncesi 5 FAIL + 3 script hatası → 32 PASS). `UpdateChecker.is_disabled_build()` (`play_store` özelliği; Play export ön ayarı kullanıcı işi) + `update_check_audit` doğrulaması. Kanon metin düzeltmeleri (BUG-003/004/005/015/017/018/022 kısmen; `lore_canon_audit` `TEXT_REGRESSIONS`). `Run-Audit.ps1` listesine `softlock_reset`, `save_robustness`, `move_time` eklendi. CLAUDE.md sürüm satırı, journal yorumu "40 oda". Yeni `docs/play/` (PLAY_BUILD_CHECKLIST, PRIVACY_POLICY_DRAFT, ASSET_LICENSES_TODO, STORE_LISTING_DRAFT, CREDITS_TEMPLATE). Durum tablosu: `qa/release-readiness/06_BUG_REGISTER.md`. Karar hâlâ NO-GO (08). Açık: AAB/keystore, gizlilik URL'si, lisanslar, tempo, cihaz/insan testi, BUG-016/019/020/021/023/031/032, BUG-045 (`.uid` dosyaları takipsiz).
- [x] Görsel uyum taraması + mağaza varlıkları (2026-11-11, sürüm artmadı, commit yok, oyun kodu/varlığı DEĞİŞMEDİ): 12 temsili oda masaüstünde yakalandı (`scripts/dev/room_visual_capture.gd`, dev aracı, Run-Audit dışı); 6 perdenin sanatı palet/HUD/piksel stili olarak tutarlı bulundu, bu yüzden varlık değişikliği yapılmadı. Not: ikon (boyalı anime gözü) piksel oyundan farklı stil, sahibinin kararı; alt kenarda düz koyu zemin bandı var. Yeni: `docs/play/store/feature_graphic_1024x500.png` (+ `make_feature_graphic.py`), 3 aday ekran görüntüsü `docs/play/store/screenshots/` (masaüstü klavye ipucu satırı görünüyor; gerçek cihaz görüntüsü gerekir). `STORE_LISTING_DRAFT.md` ve `ASSET_LICENSES_TODO.md` güncellendi. Karar hâlâ NO-GO.
- [x] Kanon politikası A+B (2026-11-11, sürüm artmadı, commit yok): (A) `shilda_past_discovered` artık awakening_crypt defterinde değil, `story_beat._experiment_authority()` içinde itiraf diyaloğu `ok` olunca kurulur; `save_manager` v≤5 göçünde yalnız `puzzles.experiment_authority` varsa türetir (crypt_ledger yalnız `dimension_origin_discovered`). (B) Perde 1-2 (awakening_*/decay_*) odalarında "1995" okunaklı verilmez: tek geçiş `awakening_balcony.tscn` fotoğraf damgası "yıl okunmuyor, soluk rakam izi" yapıldı; library/experiment/core 1995 kullanımları korundu. `lore_canon_audit` CANON-A/B regresyonları, `story_flags_audit` v5 fixture + crypt_ledger negatif kontrolü. Sonuç: lore_canon 30/0, story_flags 36/0, save_robustness 32/0, final_sequence 35/0.
- [x] v1.12.3 / versionCode 40 GitHub release (2026-11-11): APK `build/android/TheRoomRemembers-1.12.3-android-arm64.apk` (112,8 MB, debug keystore, sertifika SHA-256 16fd69…, v1.12.2 ile aynı; apksigner doğrulandı). Yayın: https://github.com/jagwey/THE-ROOM-REMEMBERS-release/releases/tag/v1.12.3. Derleme: gradle repo yolunda (OneDrive/Japonca) başarısız; scratchpad kopyasında `android_source.zip` yeniden açılıp (libs/ gerekli) `--export-debug` ile alındı. Kaynak commit/push yapılmadı; Play/AAB/keystore park halinde (QA kararı Play için hâlâ NO-GO).
- [x] v1.12.4 / versionCode 41 (2026-11-11): oyuncu geri bildirimi 'Kırık Geçit geçilmiyor'. `awakening_passage.tscn` MemoryStrip: `lethal=false` (tek temasta yalnız bir kalp, ölüm yok), `ring_gap_deg` 140→230, `ring_spin` 0.55→0.3, `arm_grace` 1.5→3.0. `e2e_runner` T4-05 hâlâ geçiyor; tam `Run-Audit.ps1` 31 denetim, 0 başarısız. Sürüm pin'i e2e'de 1.12.4/41.
- [x] Release temizliği kuralı (2026-11-11): GitHub 2 GB sınırı için her iki repoda güncel + en fazla 3 eski sürüm tutulur, daha eskiler `gh release delete --cleanup-tag` ile silinir (CLAUDE.md > Release). Şu an silinecek eski sürüm yok.
- [x] v1.12.5 / versionCode 42 (2026-11-11): görsel yenileme sürümü. 16 PNG kullanıldı. Saatler Odası, Gözlem Camı, Kırık Gece ve Sera'daki etkileşimler yeni çizimlerle belirginleştirildi. Çürüme ve ayna tavan motifleri seyrekleştirildi, kütüphane ve deney alanında dekor mevcut duvar çizimine bırakıldı. Üç diyalog çerçevesi ve dört final ekranı eklendi. Dört oda Godot penceresinde incelendi. 1280×720 ve 1440×648 boyutlarında dört uzun Türkçe konuşma simüle dokunuşla sayfalandı ve kapandı. Diyalog açıkken oyuncu yerinde kaldı ve bekleme animasyonu sürdü. Tam denetim 31/31, e2e 53/53. Fiziksel Android cihaz testi yapılmadı.
- [x] v1.13.0 / versionCode 43 (2026-11-12): otonom QA + metin cilası. Hatalar: BUG-033 (possession/kapı geçişinde otomatik kayıt atlanır, `mobile_input_manager._unsafe_to_autosave`), BUG-035 (ceset rebuild remove_child + aktif oda kökü, odasız kök yalnız son çare), BUG-039 (ending_bad/sever stinger kaldırıldı), BUG-016/019/020/021/023/031/032/045 (Uyanış sahne/JSON eşleşmesi, "kuruluş" terimi, 1995 satırı, "Altmış sekiz yıl", çift learn_memory_code, ability_pickup commit_save, bozuk kayıtta yedek), BUG-042 çözüldü. 10 diyalog JSON replikleri sıkılaştırıldı; Shilda duvarı ipucu cracked_wall kuralıyla eşleşti; 2 objective metni netleşti. lore_canon_audit +8 regresyon, save_robustness_audit (e)/(f). Doğrulama: Run-Audit 31/0, e2e 53/53. Oda yerleşimi değişmedi (insan playtest yok). APK: build/android/TheRoomRemembers-1.13.0-android-arm64.apk.
