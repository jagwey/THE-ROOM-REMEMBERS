# Google Play Yayın Kontrol Listesi (v1.12.2 tabanlı)

Durum işaretleri: [x] kodda yapıldı ve test edildi · [ ] senin yapman gerekiyor · [?] doğrulanmadı.
Gizli bilgi (keystore, parola) bu dosyaya veya depoya YAZILMAZ.

## Kodda hazır
- [x] `UpdateChecker.is_disabled_build()` — export ön ayarında `play_store` özel özelliği (Custom Features) varsa GitHub güncelleme denetimi ve "Güncelle" düğmesi kapanır. (`scripts/autoload/update_checker.gd`)

## Export ön ayarı (Godot > Project > Export)
- [ ] **İkinci bir Android ön ayarı** oluştur: "Android Play". Custom Features alanına `play_store` yaz.
- [ ] Bu ön ayarda `permissions/internet` kapat (Play sürümünde ağ gerekmiyor; yalnız VIBRATE kalsın).
- [ ] Format: **AAB** (Gradle build / `export_format` AAB). Play yeni uygulamalar için AAB ister; APK yalnız GitHub dağıtımı için kalır.
- [ ] `version/code` her yüklemede artmalı; `version/name` = `config/version`.
- [ ] targetSdk güncel Play şartını karşılıyor mu kontrol et (şu an 36 olarak okundu) [?].

## İmzalama
- [ ] Upload keystore oluştur (parolayı depoya YAZMA). Play App Signing'i etkinleştir.
- [ ] Keystore'un yedeğini depo dışında sakla.

## Mağaza & politika
- [ ] Gizlilik politikası: `docs/play/PRIVACY_POLICY_DRAFT.md` taslağını doldurup bir web sayfasında yayımla; URL'yi Play Console'a gir.
- [ ] Veri güvenliği (Data safety) formu: veri toplanmıyor/paylaşılmıyor (Play sürümünde ağ kapalı olduğundan doğrula).
- [ ] İçerik derecelendirme anketi (korku/karanlık temalar, şiddet düzeyini dürüst işaretle).
- [ ] Hedef kitle: çocuklara yönelik DEĞİL olarak işaretlemeyi değerlendir (gotik/korku).
- [ ] Varlık lisansları: `docs/play/ASSET_LICENSES_TODO.md` tablosunu doldur; AI üretimi varlıklar için ilgili beyan.
- [ ] Mağaza görselleri: ikon 512x512, öne çıkan görsel 1024x500, en az 2 telefon ekran görüntüsü (Android'de gerçek çekim).
- [ ] Kısa (≤80) ve uzun (≤4000) açıklama — spoiler vermeden.

## Test (Play şartı + kalite)
- [ ] Kişisel hesap ise: kapalı testte en az 12 test kullanıcısı, 14 gün kesintisiz (güncel kuralı Play Console'da doğrula) [?].
- [ ] Gerçek cihaz testi: düşük RAM / orta seviye cihaz, dokunmatik kontroller, kaydet-çık-devam, arka plana alma.
- [ ] İnsan oyun testi: `qa/release-readiness/05_PLAYTEST_PROTOCOL.md` protokolüne göre.
- [ ] Pre-launch report (Play Console) çıktısını incele.

## Bilinen açık engeller
Bkz. `qa/release-readiness/08_RELEASE_READINESS.md` (karar, kanıtlar ve açık P1/P2 listesi) ve `07_GOOGLE_PLAY_CHECKLIST.md`.
