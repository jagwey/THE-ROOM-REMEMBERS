# 06 — Hata Kaydı (P0–P4)

Sürüm: v1.12.2 · commit `84a2032` · 2026-11-11
Öncelik: **P0** çökme/veri kaybı/ilerleme engeli · **P1** büyük deneyim/kanon/yayın engeli · **P2** belirgin kusur · **P3** küçük · **P4** iyileştirme.
Kanıt: **STATİK** = yalnız kod/veri okundu, **yeniden üretilmedi** · **HEADLESS** = betikle doğrulandı · **POLİTİKA** = Play belgesi.
Durum: aşağıdaki tablolar ilk tarama anındaki bulguyu gösterir (commit `84a2032`). Güncel düzeltme durumu hemen aşağıdaki **Düzeltme Durumu** bölümündedir; tablolardaki "Kanıt" sütunu ilk bulgunun kanıt sınıfıdır. Bu çalışma kopyasında düzeltmeler uygulandı ama **commit edilmedi**.

## Düzeltme Durumu (çalışma kopyası, commit yok)
Test = headless SceneTree denetimi (izole kopya, `TORIMON_TEST=1`). Gerçek cihaz / insan testi YOK.

| ID | Durum | Kanıt |
|---|---|---|
| BUG-001 | DÜZELTİLDİ (yeniden üretilemedi, savunma + test) | `DeathManager._gen` nesil sayacı + `reset_state()`; `softlock_reset_audit` 68 PASS |
| BUG-002 | AZALTILDI, yeniden ÜRETİLEMEDİ | `_possession_gen` + `set_cutscene(false)` sıfırlaması; gerçek tetik yolu doğrulanmadı. "Düzeltildi" denmez |
| BUG-003 | DÜZELTİLDİ (metin) | `awakening_crypt.tscn`: rol sızıntısı kaldırıldı; `lore_canon_audit` `TEXT_REGRESSIONS`. KARAR (2026-11-11): `shilda_past_discovered` artık Perde 1'de set edilmiyor; Yetki Masası (`experiment_authority`) itirafında set ediliyor, eski kayıt göçü de buna bağlandı. `lore_canon_audit` CANON-A, `story_flags_audit` negatif kontrol |
| BUG-004 | KISMEN DÜZELTİLDİ (metin) | "Kabul yılım" ve "1995'te ben girdim" kaldırıldı/yumuşatıldı; KARAR (2026-11-11): 1995 okunaklı olarak en erken kütüphane/deney aşamasında (Perde 3+) öğrenilir; Perde 1-2 dosyalarında "1995" yok (`awakening_balcony` damgası "yıl okunmuyor" yapıldı). `lore_canon_audit` CANON-B 23 dosyayı tarar. Karar sahibi onayı gerekirse değiştirilebilir |
| BUG-005 | DÜZELTİLDİ (metin) | X? konuşması sessiz "Kayıt" satırına çevrildi |
| BUG-006 / 007 | AÇIK | AAB ve keystore kullanıcı işi; bkz. `docs/play/PLAY_BUILD_CHECKLIST.md` |
| BUG-008 | KODLANDI + test | `UpdateChecker.is_disabled_build()` (`play_store` özelliği); `update_check_audit` varsayılan yapıda false'u doğrular. Play export ön ayarı kullanıcı tarafından açılmadıkça etkisiz |
| BUG-010 | DÜZELTİLDİ (savunma + test) | `_begin_possession` yeniden giriş koruması; `softlock_reset_audit` |
| BUG-011 | DÜZELTİLDİ (yeniden üretildi, önce FAIL) | `save_robustness_audit` (düzeltme öncesi 5 FAIL + 3 SCRIPT ERROR) |
| BUG-012 | DÜZELTİLDİ (yeniden üretildi) | `save_robustness_audit` |
| BUG-013 | HATA DEĞİL | Çalışma zamanında konuşmacı zaten "???" gösteriyor |
| BUG-014 | HATA DEĞİL | "Gölge" anonim takma ad, zaten maskeli |
| BUG-015 | DÜZELTİLDİ (metin) | `{deaths}` yer tutucusu (`lore_point.gd`, en az 1); `lore_canon_audit` |
| BUG-016, 019, 020, 021, 023 | AÇIK | Yapısal/yaratıcı karar gerektirir; oynanmadan yazılan yeni içerik kanonu/softlock riskini artırır, bu tur bilerek dokunulmadı |
| BUG-024 | AÇIK (karar: vaat düşür) | Tempo 42,6 dk ↔ 165–195 dk. İnsan testi ve tasarlanmış içerik olmadan uzatma yapılmadı; mağaza metni süre vaat etmiyor (`STORE_LISTING_DRAFT.md`) |
| BUG-017 | DÜZELTİLDİ (metin) | `experiment_observation.json` |
| BUG-018 | DÜZELTİLDİ | "Ruh Kesimi" her yerde (yalnız 2 dosyada yorum satırında "Kesiği" kaldı) |
| BUG-022 | KISMEN | "Araştırma Yardımcısı S." düzeltildi; "Gölge olmadan önce" kısmı AÇIK |
| BUG-024 | AÇIK (karar: vaat düşür) | Tempo kararı verildi: doğrulanmamış içerik eklenmedi, mağaza metni süre vaat etmiyor; gerçek uzatma insan testi sonrası |
| BUG-030 | KISMEN | (b) `start_new_game` eski kaydı silmiyor: yeniden üretildi + düzeltildi. (a) `_write_atomic` sonuç denetimi savunma amaçlı eklendi, yeniden üretilemedi |
| BUG-031 | AÇIK | Tasarım kararı gerektirir |
| BUG-032 | AÇIK, anlatıldığı gibi üretilemedi | Kod uyanışa değil canlı checkpoint'e düşüyor |
| BUG-037 | DÜZELTİLDİ | `journal_map.gd` yorum "40 oda" |
| BUG-043 | DÜZELTİLDİ (CLAUDE.md); README/PROGRESS güncellendi | |
| BUG-045 | AÇIK (bilinçli) | `.uid` dosyaları takipsiz; commit kullanıcı isteyince |
| BUG-046 | DÜZELTİLDİ | `move_time` `Run-Audit.ps1` listesinde |
| Diğerleri (033–036, 038–042, 044, 047, 050–052) | AÇIK | Dokunulmadı |

## Özet
| Öncelik | Sayı | Not |
|---|---|---|
| P0 | 0 | Statik taramada kanıtlı P0 yok; hiçbiri yeniden üretilmedi |
| P1 | 8 | 2 olası kilitlenme (kanıtsız), 3 kanon/hikâye, 3 yayın |
| P2 | 15 | 3 save/kilit, 11 hikâye/kanon, 1 tempo |
| P3 | 18 | |
| P4 | 3 | |

## P1

| ID | Alan | Bulgu | Kanıt | Önerilen düzeltme / test |
|---|---|---|---|---|
| BUG-001 | Ölüm/kilit | `death_manager.gd:362/395/471` `await tw.finished` tween'leri `_soul`'a bağlı. Sahne yeniden yüklenir veya `_soul` serbest kalırsa coroutine dönmez; `is_dying` true kalır, girdi kilitlenir. `_on_root_child_exiting` (:50-55) yalnız time_scale'i bırakıyor | STATİK, yeniden üretilmedi | Önce yeniden üretim testi (ölüm sırasında `reload_current_scene`); sonra tween/`_soul` geçerlilik koruması + `is_dying` sıfırlama |
| BUG-002 | Lanet/kilit | `curse_manager.gd:127/131` `await overlay.play/finish` sahne yenilemesinde asılı kalır; `possessing` ve `UiGate._cutscene` takılı. `start_new_game` (`save_manager.gd:45-48`) ve `return_to_title` (`session_menu.gd:313-326`) `UiGate.set_cutscene(false)` çağırmıyor. Tetik yolu dar | STATİK, yeniden üretilmedi | `UiGate.set_cutscene(false)` ve `possessing=false` sıfırlamasını bu iki yola ekle; ardından curse_reload + death_loop yeniden |
| BUG-003 | Hikâye/kanon | `awakening_crypt.tscn:44-46` Perde 1'de "Denek 14" ve Shilda rolünü sızdırıyor (Shilda'yı Perde 1'de hemen tanıtmama kararına aykırı) | STATİK | Metni maskele veya Perde 2 bahçeye taşı. **ÇÖZÜLDÜ (2026-11-11):** metin maskelendi, `shilda_past_discovered` Yetki Masası'na taşındı |
| BUG-004 | Hikâye/kanon | `story_beat.gd:113,139` ve `library_clockroom.json` 1995 / "kabul yılım" önceden biliyor; `story_beat.gd:169-171` (experiment_cells) aynı bilgiyi haber olarak sunuyor; `library_clockroom.tscn:42` aynı çelişki | STATİK | Tek kaynak seç: ya önceden bilir ya öğrenir. **ÇÖZÜLDÜ (2026-11-11):** "öğrenir" seçildi, 1995 yalnız Perde 3+ |
| BUG-005 | Hikâye/kanon | `story_beat.gd:211` X? sesi final öncesi konuşuyor. Kural: X finale kadar görünmez, perde başına tek iz | STATİK | Sesi iz/efekte çevir veya satırı kaldır. Onay ister |
| BUG-006 | Play/yayın | AAB yok (`export_format=0`) | KOD | `export_format=1` dene; Play Console AAB ister |
| BUG-007 | Play/yayın | Release imzası/upload keystore yok (PROGRESS.md:29) | KOD+KULLANICI | Keystore repo dışında üretilmeli; sır repoya girmez |
| BUG-008 | Play/politika | Başlıkta "Güncelle → vX" düğmesi GitHub APK'sını açıyor (`update_checker.gd`). Play içinde kendini Play dışından güncelleme politika riski | POLİTİKA+KOD | Play build'inde düğme/`INTERNET` kapalı olacak bayrak. **Kod değişikliği, kullanıcı onayı ister** |

Not: Play için gizlilik politikası, lisans/kredi belgeleri ve derlenmiş paket doğrulaması da engel; ayrıntı `07_GOOGLE_PLAY_CHECKLIST.md` (BUG numarası verilmedi, kullanıcı işi).

## P2

| ID | Alan | Bulgu | Kanıt |
|---|---|---|---|
| BUG-010 | Lanet | `curse_manager.gd:106-110/140-148` `_begin_possession`'da yeniden giriş koruması yok: çift overlay, çift `possession_count` olası | STATİK |
| BUG-011 | Save | `save_manager.gd:282` `player_progress_knowledge` tür kontrolü/varsayılan birleştirme olmadan atanıyor | STATİK |
| BUG-012 | Save | `save_manager.gd:347-372` `corpses`, `flowers_left`, `forbidden_touched` için tür koruması yok | STATİK |
| BUG-013 | Hikâye | `awakening_balcony.tscn:36` Shilda konuşuyor (maske "???" kuralı) | STATİK |
| BUG-014 | Hikâye | `campaign_objectives.gd:6,87` "Gölge konuşursa dinle" Shilda'yı önceden işaret ediyor | STATİK |
| BUG-015 | Hikâye | Sabit "41" ölüm sayacı: `decay_shilda_wall.tscn:44,46`, `awakening_crypt.tscn:44` | STATİK |
| BUG-016 | Hikâye | `awakening_vigil` kanıt metni ile JSON uyuşmuyor | STATİK |
| BUG-017 | Hikâye | `experiment_observation.json` içinde meta (oyun dışı) cümle | STATİK |
| BUG-018 | Hikâye | "Ruh Kesiği" / "Ruh Kesimi" tutarsız | STATİK |
| BUG-019 | Hikâye | 1927 "Kazı" ifadesi kanonla uyuşmuyor (X 1927'de boyutu kurdu) | STATİK |
| BUG-020 | Hikâye | Kapı yılı 1927 ↔ 1995 çelişkisi | STATİK |
| BUG-021 | Hikâye | Tally işaretleri 1927'de bitiyor ↔ `decay_cistern.json` "68 yıl" | STATİK |
| BUG-022 | Hikâye | Shilda için "Gölge olmadan önce"; "Güvenlik görevlisi: Shilda" ↔ "Araştırma Yardımcısı S." | STATİK |
| BUG-023 | Hikâye | Kod 729 iki kez öğretiliyor | STATİK |
| BUG-024 | Tempo | Ana yol ölçüldü 42,6 dk (yan odalarla 52,1) ↔ hedef 165–195 dk. Mağaza vaadi ve içerik beklentisiyle uyuşmuyor | HEADLESS ölçüm (`playtime_measure`) |

## P3

| ID | Bulgu | Kanıt |
|---|---|---|
| BUG-030 | `_write_atomic` yazma sonucunu denetlemiyor; `start_new_game` eski committed save'i yeni commit başarılı olmadan siliyor | STATİK |
| BUG-031 | Yetenek/mühür parçası alımları yalnız resume save yazıyor; "Ana Menüye Dön" bu ilerlemeyi siliyor | STATİK |
| BUG-032 | `_reload_committed` bozuk committed save'de sessizce uyanışa düşüyor | STATİK |
| BUG-033 | Arka plan/odak kaybı otomatik kaydı olası possession veya kapı geçişi sırasında çalışıyor | STATİK |
| BUG-034 | `OS.shell_open` URL doğrulanmıyor (düşük risk) | STATİK |
| BUG-035 | Ceset yeniden kurulumunda çift sayım ve yanlış oda yedeği | STATİK |
| BUG-036 | `.claude/worktrees/...` için `.gdignore` yok | STATİK |
| BUG-037 | `journal_map.gd:18` "30 oda" yorumu (gerçek 40) | STATİK |
| BUG-038 | `library_witness_room.gd` BOM | STATİK |
| BUG-039 | `sound_bank.gd` eski `ending_*` stinger'ları | STATİK |
| BUG-040 | Aşırı uzun kanıt metinleri | STATİK |
| BUG-041 | Tekrar eden bekçi satırları | STATİK |
| BUG-042 | "Bu hücreyi unutmam" tekrarı/uygunluğu | STATİK |
| BUG-043 | CLAUDE.md "v0.10.1" (gerçek 1.12.2); PROGRESS.md/README.md v1.11.x–1.12.2 bölümleri yok | KOD |
| BUG-044 | PROGRESS.md satır ~286–309 mojibake (kasıtlı dokunulmadı) | KOD |
| BUG-045 | `scripts/dev/playtime_measure.gd.uid` ve `ordered_relic.gd.uid` takip edilmiyor | git |
| BUG-046 | `Run-Audit.ps1` `move_time_audit`'i içermiyor | KOD |
| BUG-047 | Mağaza varlıkları/metni yok (kullanıcı işi) | KULLANICI |

## P4
| ID | Bulgu |
|---|---|
| BUG-050 | `player_controller` ve `room_transition` içinde kare başı grup sorguları |
| BUG-051 | Her ölümde yeni Shader oluşturuluyor |
| BUG-052 | Mobil performans ölçümü yok (bkz. 04) |

## Doğrulanmış temiz (kanıt sınıfıyla)
- time_scale yönetimi temiz görünüyor, v1.12.2 yürüme simetrisi: HEADLESS (`move_time_audit` 28/28) + STATİK.
- Geri dönüşsüz `required_ability` kilitlenmesi bulunmadı: STATİK (kanıt değil, bulgu yokluğu).
- `update_checker` bloklamıyor (async, 8 sn zaman aşımı, hata sessiz, headless'ta atlanıyor, token yok): STATİK + `update_check` HEADLESS 7 PASS.
- Sır taraması: yalnız `death_manager.gd` içinde zaman-tutma kimliği olan `token` değişkeni; gizli anahtar yok.
- "Shiren" oyun verisinde yok; Shilda adı bahçeden önce maskeli; tek final (`ending_manager.gd`): STATİK.

## Okunmayan/örneklenmeyen alanlar (kapsam açığı)
`game_state.gd`, `room_manager.gd` (`run_door_travel`), `puzzle_manager.gd`, `final_sequence.gd` gövdesi, `possession_overlay.gd`, `echo_manager.gd`, HUD/joystick çoklu dokunuş, `player_controller.gd` çoğu, `scripts/ui/*` metinleri, çoğu `scripts/world/*.gd` söylem metni, `puzzle_manager` ipuçları, README/docs.

## Düzeltme döngüsü kuralı
Her düzeltme: yeniden üret → kök neden → minimal düzeltme → regresyon testi. Kanıtsız statik bulgulara test yazılmadan düzeltme yapılmaz.
