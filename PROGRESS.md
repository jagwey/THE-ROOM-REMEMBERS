# PROGRESS
Dal: cursor/playable-story-flow-8e4e · Sürüm: v1.0.0 (versionCode 12)

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
- Bilinen eksik: ses cihazda dinlenmedi; 2 saat süre ve tüm oda turu cihazda doğrulanmadı; release keystore yok
- Test: scratchpad audit.sh (Godot 4.7.2 console, Downloads zip'ten çıkarıldı); TORIMON_TEST=1 gerekli

## Kalan
- docs/gelistirme/ altındaki izlenmeyen log/zip dosyaları: .gitignore veya temizlik kararı bekliyor
- Sonraki geliştirme görevi: kullanıcıdan bekleniyor
