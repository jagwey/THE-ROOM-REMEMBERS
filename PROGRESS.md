# PROGRESS
Dal: cursor/playable-story-flow-8e4e · Sürüm: v1.1.0 (versionCode 15)

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
- Bilinen eksik: ses cihazda dinlenmedi; 2 saat süre ve tüm oda turu cihazda doğrulanmadı; release keystore yok
- Test: scratchpad audit.sh (Godot 4.7.2 console, Downloads zip'ten çıkarıldı); TORIMON_TEST=1 gerekli

## Kalan
- docs/gelistirme/ altındaki izlenmeyen log/zip dosyaları: .gitignore veya temizlik kararı bekliyor
## V3.0 ölüm/respawn (2026-11-07, güvenli nokta: tag `pre-v3-death-system`)
- [x] P0: Shilda ölüm kilidi kökü = DEATH katmanında yas diyaloğu geçilemiyordu + `dialogue_closed` iptalde gelmiyordu. Düzeltme: `DeathManager.wait_dialogue()` (dokunuş/otomatik ilerleme/zaman aşımı), HUD+interact DEATH'te diyalog ilerletir, keeper tüm beklemeler `dialogue_finished`, ölümde `_abort_combat()`, doğuş sonrası 2 sn saldırı yok, geçersiz oyuncu ref koruması, `keeper_defeated` kalıcı bayrak (gizlenir, iyi son kapanır, aynı anda ölümde önce doğuş), ölürken hasar yok (`GameState.damage`). Başta koşma: taklit fare olayı yok sayılır + nötr joystick şartı + doğuşta zemine oturtma. Adım sesi kapı/ölümde yok
- Test: `scripts/dev/death_loop_audit.gd` (6 döngü, pencereli dokunuşsuz 5.9 sn/ölüm) 0 hata; audit 107/0; controls 0. Cihaz testi yapılmadı
- [x] Ölüm durum makinesi (`DeathManager.Phase` + `phase_changed`), ruh (soluk mor Shiren + ışıltı, kamera `set_focus`), yatak mührü halka+kıvılcım, `play_wake`; ilk ölüm sinematik, sonrakiler hızlı; lanet ele geçirme = ceset/yas/ruh yok. Ceset: zemine oturtma (ışın), meta (facing/curse/time), tek yönlü çarpışma (geçiş tıkanmaz), ilk replik "Bu... benim kıyafetlerim mi?". Kamera silinmiş hedefe bağlanmaz. Test: death_loop (faz sırası, ruh temizliği, ele geçirme) headless 0 hata, pencereli 7.9 sn/ölüm
- [x] Göz açma girişi (`scripts/ui/eye_open_intro.gd`): yumuşak kenarlı siyah göz kapakları, kırpışma, koyu peçe, nefes sesi (`breath`), beyaz flaş yok; `UiGate.Layer.CUTSCENE` (girdi/HUD/günlük kapalı); ilk 2.2 sn, devam 0.9 sn; replikler gözler açılınca. Test: `scripts/dev/eye_intro_audit.gd` pencereli 0 hata (ort. parlaklık ≤0.24)
- [x] Günlük açıkken HUD gizli; adım sesi yumuşak taş + perde/şiddet çeşitliliği (sağ/sol); Shilda yası: ilk ölümde 3 replikli sahne, sonra diyalogsuz "Yine unuttun." (sonraki ölümler 7.9→3.6 sn)
- [x] Yankı tekrarı: oyuncu son 3 sn iz halkası (0.1 sn, 30 örnek, yalnız ölüm odası) → ceset `trail`; ilk incelemede soluk mor Shiren son anları oynar, cesette biter (eski kayıtta klasik hayalet). Test: death_loop (iz ≥4, tekrar düğümü oluşur/silinir) 0 hata
- [x] Göz açmada Menü düğmesi gizli + menü açılmaz (geri tuşu zaten sinematikte menü açmıyor, günlükte günlüğü kapatır). Kayıt: `.prev` yedek, bozuk ana kayıtta yedekten yükleme. Test: `scripts/dev/save_robust_audit.gd` 0 hata, eye_intro 0 hata
- [x] QA (2026-11-07): release 107/0, controls 0, death_loop headless+pencereli 0 (ilk ölüm 12.0 sn sinematik, sonrakiler 3.6 sn), eye_intro 0, save_robust 0. Android debug APK: scratchpad/apk/trr-v3-debug.apk (34 MB). Cihaz testi YAPILMADI; commit edildi, push yok
- Kalan V3: cihazda ses/göz açma/yankı tekrarı dinleme-izleme; ölüm sonrası ~3 sn hedefi için 0.6 sn kırpma opsiyonel
