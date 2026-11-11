# 09 — QA Değişiklik Günlüğü

> Hiçbir şey commit/push/release edilmedi; sürüm numarası değişmedi (v1.12.2). Değişiklikler yalnız çalışma kopyasında.

## 2026-11-11 — v1.12.2 (84a2032) QA turu 2: düzeltmeler

### Kod
- `death_manager.gd`: `_gen` nesil sayacı + `reset_state()` — eski ölüm koroutinleri yeni oyunu/yüklemeyi bozmasın (BUG-001).
- `curse_manager.gd`: `_possession_gen` ve `_begin_possession` yeniden giriş koruması (BUG-002 azaltma, BUG-010).
- `session_menu.gd`, `save_manager.gd`: Ana menü / yeni oyun / yükleme yolları `DeathManager.reset_state()` ve `UiGate.set_cutscene(false)` çağırıyor.
- `save_manager.gd` (BUG-011/012/030): `start_new_game` yeni kaydı yazmadan eski kaydı silmiyor; `_write_atomic` yazma sonucunu ve geçici dosyayı doğruluyor; yükleme tarafında tip zorlama yardımcıları (`_int_of`, `_float_of`, `_coerce_container`, `_deserialize_progress`) bozuk/yanlış tipli kayıtlarda çökmeyi önlüyor.
- `update_checker.gd`: `is_disabled_build()` — `play_store` özel özelliği olan yapıda güncelleme denetimi kapalı (BUG-008). Play export ön ayarı kullanıcı tarafından açılmalı.
- `lore_point.gd`: `{deaths}` yer tutucusu (en az 1); `core_crystal.gd`, `puzzle_manager.gd`, `story_beat.gd`: kanon metin/akış düzeltmeleri.
- `journal_map.gd`: yorum "40 oda" (BUG-037).

### İçerik (Türkçe metin)
- `awakening_crypt.tscn`, `decay_shilda_wall.tscn`, `library_clockroom.tscn/.json`, `experiment_observation.json`: Shilda/X/1995 rol sızıntıları ve kanon çelişkileri düzeltildi (BUG-003/004/005/015/017/022 kısmen).
- `PLAY_TR.md`: "Ruh Kesimi" adlandırması (BUG-018).

### Testler / araçlar
- Yeni: `scripts/dev/softlock_reset_audit.gd` (68 PASS), `scripts/dev/save_robustness_audit.gd` (düzeltme öncesi 5 FAIL + 3 script hatası → sonra 32 PASS).
- `update_check_audit.gd`: `is_disabled_build()` doğrulaması eklendi.
- `lore_canon_audit.gd`: `TEXT_REGRESSIONS` eklendi.
- `Run-Audit.ps1`: `softlock_reset`, `save_robustness`, `move_time` listeye eklendi (BUG-046).

### Dokümantasyon
- `CLAUDE.md`: güncel sürüm satırı düzeltildi (BUG-043).
- Yeni `docs/play/`: `PLAY_BUILD_CHECKLIST.md`, `PRIVACY_POLICY_DRAFT.md`, `ASSET_LICENSES_TODO.md`, `STORE_LISTING_DRAFT.md`, `CREDITS_TEMPLATE.md` (hepsi taslak/şablon; bilinmeyen lisanslar tahmin edilmedi).
- `qa/release-readiness/00–09` güncellendi.

### Görsel tarama ve mağaza varlıkları
- Yeni dev aracı `scripts/dev/room_visual_capture.gd` (masaüstü, non-headless; 12 temsili oda PNG). Oyun kodu ve oyun varlıkları DEĞİŞMEDİ: 6 perdenin sanatı palet/HUD/piksel stili açısından tutarlı bulundu.
- Yeni `docs/play/store/`: `feature_graphic_1024x500.png`, `make_feature_graphic.py`, `screenshots/` (3 aday, 1920×1080; masaüstü klavye ipucu satırı görünüyor, bu yüzden yalnız taslak; gerçek cihaz görüntüsü gerekir).
- Not: ikon boyalı anime stili, oyun piksel stili (sahibinin tercihi); alt kenarda düz koyu zemin bandı.

### Kanon kararları (2026-11-11, otonom, geri alınabilir)
- 1995 yılı okunaklı olarak yalnız Perde 3+ (kütüphane/deney) içinde; Perde 1-2'de yok (`awakening_balcony.tscn` damgası "yıl okunmuyor").
- `shilda_past_discovered` artık `story_beat.gd` `_experiment_authority()` içinde set ediliyor; `awakening_crypt.tscn` yalnız `dimension_origin_discovered` veriyor; v5 kayıt göçü (`save_manager.gd`) buna uyarlandı.
- Yeni korumalar: `lore_canon_audit` CANON-A / CANON-B, `story_flags_audit` negatif kontrol ("crypt_ledger tek başına shilda_past_discovered türetmez").
- Tempo (BUG-024): doğrulanmamış içerik eklenmedi; mağaza metni süre vaat etmiyor.

### Doğrulanamayanlar (dürüstlük notu)
- BUG-002 yeniden üretilemedi; yalnız savunma korumaları var.
- BUG-030(a) disk dolu senaryosu üretilemedi.
- Gerçek cihaz, gerçek dokunmatik, performans ve insan oyun testi YAPILMADI.
- Tempo (42,6 dk ölçüm vs 165–195 dk hedef) çözülmedi.

### Bilerek yapılmayanlar
Keystore/AAB/export ayarları, gizlilik politikası URL'si, varlık lisansları, kapalı test; kanon yapısal kararları (BUG-016/019/020/021/023); `.uid` dosyalarının commit'i (BUG-045).

## 2026-11-11 — v1.12.2 (84a2032) QA turu 1
Repo koduna dokunulmadı; yalnız `qa/release-readiness/` belgeleri eklendi.
- Yerel `main` `origin/main` (v1.12.2) ile `git merge --ff-only` eşitlendi.
- 28 headless denetim izole kopyada: 0 başarısız; `move_time_audit` 28 PASS.
- Statik softlock taraması (15 bulgu), hikâye/diyalog taraması (24 bulgu), Play yapılandırma okuması.
