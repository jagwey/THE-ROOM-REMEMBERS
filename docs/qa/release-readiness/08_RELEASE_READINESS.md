# 08 — Yayın Hazırlığı ve GO / NO-GO

Sürüm: v1.12.2 · commit `84a2032` · 2026-11-11

## KARAR: **NO-GO** (Google Play yayını için)

Gerekçe kısaca: kod tarafı headless testlerde sağlam (28/28 + 28/28), ama Play yayını için **paket, imza, politika, lisans ve cihaz kanıtı eksik**, **hikâye kanonunda 3 P1 çelişki** var, **ana yol süresi hedefin çok altında** ve **insan oyun testi hiç yapılmadı**. Bunların hiçbiri "yayın yapılamaz" demek değil; hepsi kapatılabilir işler. Şu an kanıt yok, bu yüzden GO verilemez.

GitHub APK dağıtımı (mevcut oyuncular) için ayrı değerlendirme: v1.12.2 zaten yayında; bu belge onu geri çekmeyi önermez.

## 25 soru

| # | Soru | Cevap | Kanıt sınıfı |
|---|---|---|---|
| 1 | Headless denetimler geçiyor mu? | Evet, 28/28 + move_time 28/28 | HEADLESS |
| 2 | Bilinen P0 var mı? | Hayır (statik taramada kanıtlı P0 yok; hiçbiri yeniden üretilmedi) | STATİK |
| 3 | Olası kilitlenme var mı? | Olası 2 (BUG-001/002), kanıtsız | STATİK |
| 4 | Geri dönüşsüz softlock var mı? | Bulunmadı (bulgu yokluğu, kanıt değil) | STATİK |
| 5 | Bulmaca bazlı çözülebilirlik doğrulandı mı? | Hayır | TEST EDİLMEDİ |
| 6 | 40 oda oynanarak gezildi mi? | Hayır; yalnız `room_graph` (headless) | HEADLESS |
| 7 | Kayıt/yükleme sağlam mı? | Headless geçti; tür koruması/atomik yazma açıkları var (BUG-011/012/030) | HEADLESS+STATİK |
| 8 | Ölüm/lanet/ceset döngüsü kararlı mı? | Headless geçti; gerçek cihaz yok | HEADLESS |
| 9 | Hikâye kanonla uyumlu mu? | Kısmen; 3 P1 (BUG-003/004/005) | STATİK |
| 10 | Shilda adı doğru zamanda mı açılıyor? | Ad evet; Perde 1'de rol sızıyor | STATİK |
| 11 | X finale kadar görünmez mi? | Hayır, `story_beat.gd:211` | STATİK |
| 12 | Tek final doğru mu? | Evet | HEADLESS |
| 13 | Oyun süresi hedefi karşılıyor mu? | Hayır: 42,6 dk ana yol ↔ 165–195 dk | HEADLESS ölçüm |
| 14 | Mobil kontroller test edildi mi? | Hayır (çoklu dokunuş dahil) | TEST EDİLMEDİ |
| 15 | Performans ölçüldü mü? | Hayır | TEST EDİLMEDİ |
| 16 | Görsel/ses kalitesi doğrulandı mı? | Hayır (ses cihazda dinlenmedi, PROGRESS.md) | TEST EDİLMEDİ |
| 17 | API 36 hedefi? | Gradle'da evet; paketlenmiş manifest doğrulanmadı | KOD |
| 18 | 16 KB sayfa? | Doğrulanmadı | TEST EDİLMEDİ |
| 19 | AAB üretiliyor mu? | Hayır (`export_format=0`) | KOD |
| 20 | Release imzası var mı? | Hayır / belirsiz | KOD+KULLANICI |
| 21 | Gizlilik politikası + veri güvenliği? | Politika yok; beyan taslağı hazır, Console'da kullanıcı yapar | KULLANICI |
| 22 | Varlık lisansları belgeli mi? | Hayır (LICENSE/CREDITS/ASSET_LICENSES yok) | KOD |
| 23 | Play politikasıyla çelişen kod var mı? | Evet: oyun içi APK güncelleme düğmesi | POLİTİKA |
| 24 | İnsan oyun testi yapıldı mı? | Hayır; protokol hazır | TEST EDİLMEDİ |
| 25 | Dokümantasyon güncel mi? | Hayır: CLAUDE.md v0.10.1, PROGRESS/README v1.11–1.12.2 yok, journal "30 oda" | KOD |

## GO için gereken en kısa yol (öncelik sırasıyla)
1. **Kullanıcı kararları:** (a) kanon düzeltmelerini onayla (BUG-003/004/005); (b) tempo: içerik uzatma mı, mağaza vaadini düşürme mi; (c) Play'de otomatik güncelleme düğmesi kapatılsın mı.
2. BUG-001/002: yeniden üretim testi → minimal düzeltme → curse_reload + death_loop yeniden.
3. Play build bayrağı (güncelleme düğmesi + INTERNET kapalı), AAB export, upload keystore (repo dışı).
4. Gizlilik politikası URL'si, LICENSE/CREDITS, mağaza varlıkları ve metni.
5. Emülatör + gerçek cihaz: açılış, 30 dk oynama, `logcat`, 16 KB, `targetSdkVersion`.
6. İnsan oyun testi (05) ve ≥12 kişilik 14 günlük kapalı test (yeni kişisel hesap ise).
7. Dokümantasyon: CLAUDE.md sürümü, PROGRESS.md/README.md v1.11.x–1.12.2, journal_map yorumu.

## Güncelleme (QA turu 2, çalışma kopyası, commit yok)
Karar DEĞİŞMEDİ: **NO-GO**. Kod tarafı güçlendi, ama Play paketi/imza/politika/cihaz/insan testi ve tempo kararı açık.

Tablo değişiklikleri (yukarıdaki satırlar ilk tarama anındaki durumu gösterir):
- #3/#7: BUG-001/010/011/012/030(b) için düzeltme + `softlock_reset_audit` (68 PASS) ve `save_robustness_audit` (32 PASS; düzeltme öncesi FAIL gözlendi). BUG-002 yeniden üretilemedi, yalnız azaltma. HEADLESS kanıt; gerçek cihaz yok.
- #9/#10: BUG-003/004/005/015/017/018 metin düzeltmeleri `lore_canon_audit` `TEXT_REGRESSIONS` ile korunuyor. 1995 zamanlaması (Perde 3+) ve `shilda_past_discovered` bayrağı (Yetki Masası) otonom karara bağlandı, CANON-A/B ile korunuyor; sahibi isterse değiştirilebilir. Tam hikâye akışı oynanarak doğrulanmadı.
- #23: `UpdateChecker.is_disabled_build()` kodlandı (`play_store` özelliği). Play export ön ayarında Custom Features'a `play_store` eklenmeden etkisiz; INTERNET izni de ayrıca kapatılmalı.
- #22: `docs/play/ASSET_LICENSES_TODO.md` ve `CREDITS_TEMPLATE.md` hazır; içerik kullanıcı bilgisi gerektiriyor.
- #21: `docs/play/PRIVACY_POLICY_DRAFT.md` taslak; URL ve Console beyanı kullanıcıda.
- #25: CLAUDE.md sürümü, journal yorumu düzeltildi; README/PROGRESS güncellendi.
- #1: Tam `Run-Audit.ps1` sonucu için aşağıdaki "Son koşu" bölümüne bak.

Hâlâ açık (GO'yu engelleyen): AAB + upload keystore (BUG-006/007), gizlilik URL'si, varlık lisansları, tempo (BUG-024), cihaz/insan testi, ≥12 kişilik kapalı test, mağaza görselleri (öne çıkan görsel taslağı ve masaüstü aday ekran görüntüleri `docs/play/store/` altında hazır; gerçek cihaz ekran görüntüleri ve spoiler incelemesi açık).

## Son koşu (tam headless denetim, izole kopya)
`Run-Audit.ps1` (izole kopya, `TORIMON_TEST=1`): **31 dev denetimi, 0 başarısız**. Yeni/ilgili satırlar: `softlock_reset` 68, `save_robustness` 32, `update_check` 8 (BUG-008 doğrulaması dahil), `move_time` 28, `lore_canon` 30 (CANON-A/B dahil), `story_flags` 36, `death_loop` 113, `curse_reload` 92, `e2e_runner` 53, `release` 141. HEADLESS kanıt; fixture ile geçen final doğal oyun rotasını kanıtlamaz.

## Bu oturumda neyin kanıtlandığı
İlk tur: sürüm eşitleme, 28 headless denetim + move_time, statik tarama, Play yapılandırma okuması. İkinci tur: yukarıdaki düzeltmeler ve yeni denetimler (headless); gerçek cihaz, dokunmatik, performans ve insan testi yok. Sonradan (kullanıcı isteğiyle) v1.12.3 / versionCode 40 GitHub APK olarak yayınlandı; Play kararı (NO-GO) değişmedi.
