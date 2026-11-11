# 07 — Google Play Kontrol Listesi

Sürüm: v1.12.2 · commit `84a2032` · tarih: 2026-11-11
Kanıt sınıfları: **KOD** (statik okuma) · **PLAY-DOC** (resmi Google sayfası, web araması) · **KULLANICI** (Play Console / hesap işi, repodan doğrulanamaz) · **TEST EDİLMEDİ**

Bu liste bir hukuk/uyum belgesi değil; repoda ve resmi belgelerde doğrulanabilenleri ve kullanıcının yapması gerekenleri ayırır. Hiçbir madde "geçti" diye işaretlenmedi, kanıtı olmayan her şey TEST EDİLMEDİ ya da KULLANICI.

| # | Gereksinim | Durum | Kanıt | Not / Aksiyon |
|---|---|---|---|---|
| 1 | Hedef API (yeni uygulama/güncelleme API 36 olmalı) | KOD: uygun | `android/build/config.gradle` compileSdk 36, targetSdk 36, minSdk 24; PLAY-DOC: son tarih 31 Ağustos 2026 (uzatma 1 Kasım 2026, ikisi de geçti) | Preset'te `min_sdk`/`target_sdk` boş: Gradle şablonu değerleri belirliyor. Derlenen APK/AAB'nin manifestinde `targetSdkVersion=36` doğrulanmalı (`aapt2 dump badging`). TEST EDİLMEDİ |
| 2 | **AAB formatı** | **ENGEL** | `export_presets.cfg:27` `export_format=0` (APK) | Play yeni uygulamalar için AAB ister. `export_format=1` ile AAB üretimi denenmedi. Sürümlerin hepsi APK olarak GitHub'a gitti |
| 3 | **Release imzası / Play App Signing** | **ENGEL (belirsiz)** | PROGRESS.md:29 "release keystore yok"; v1.0–1.2 APK'ları "debug imzalı"; `package/signed=true` ama keystore alanı preset'te yok | Upload keystore üretilmeli (repo dışında, gizli tutulmalı), Play App Signing'e kayıt. Sır repoya girmemeli. KULLANICI |
| 4 | 16 KB sayfa boyutu | TEST EDİLMEDİ | PLAY-DOC: API 35+ hedefleyen, native kod içeren uygulamalar 1 Şubat 2027'den itibaren zorunlu. KOD: `compress_native_libraries=false`, yalnız arm64-v8a (olumlu) | Godot 4.7.2 şablonu ve `.so` dosyaları için `zipalign -c -P 16` ve APK Analyzer kontrolü yapılmalı. Emülatör (16 KB image) ile açılış testi yok |
| 5 | 64-bit | KOD: uygun | yalnız `arm64-v8a` | armeabi-v7a kapalı; eski 32-bit cihazlar kapsam dışı (minSdk 24 ama 32-bit yok) |
| 6 | Gizlilik politikası URL'si | **EKSİK** | Repoda gizlilik politikası dosyası yok | `INTERNET` izni var (güncelleme denetimi), bu yüzden politika gerekli. KULLANICI yazıp bir URL'de yayımlamalı |
| 7 | Data safety formu | KULLANICI | KOD: `update_checker.gd` GitHub API'ye anonim GET atıyor; kayıt yalnız `user://` altında; reklam/analitik/hesap yok | Beyan taslağı: kişisel veri toplanmıyor, paylaşılmıyor; ağ erişimi yalnız sürüm denetimi. Yine de beyan Play Console'da kullanıcı tarafından yapılır |
| 8 | Uygulama içi güncelleme / APK açma | **POLİTİKA RİSKİ** | `update_checker.gd`: başlık ekranında "Güncelle → vX" APK'yı açıyor (GitHub release) | Play'den dağıtılan uygulamanın kendi APK'sını Play dışından indirtmesi Play politikasıyla (cihaz ve ağ kötüye kullanımı / kendini güncelleme) çelişir. Play sürümünde bu düğme **kapalı** olmalı. Kod değişikliği gerekir (build bayrağı). Henüz yapılmadı |
| 9 | `INTERNET` izni | KOD | `permissions/internet=true` | Play sürümünde güncelleme denetimi kalkarsa izin de kaldırılabilir: veri beyanı sadeleşir |
| 10 | `VIBRATE` izni | KOD | `permissions/vibrate=true` | Normal izin, beyan gerekmez |
| 11 | İçerik derecelendirme anketi | KULLANICI | Oyun gotik/karanlık; kan, ölüm, ceset, psikolojik korku | Anket dürüst doldurulmalı. Şiddet/kan beyanı yüksek olacak; ESRB/PEGI eşleşmesi Play Console üretir |
| 12 | Hedef kitle / çocuklar | KULLANICI | Çocuklara yönelik değil | "13+/18" benzeri seçim; Families politikasına girmemeli |
| 13 | Mağaza varlıkları (ikon 512, feature graphic 1024x500, ≥2 ekran görüntüsü) | KULLANICI / EKSİK | Repoda mağaza görseli klasörü yok; oyun ikonu var (`android/`) | Telefon ekran görüntüleri gerçek cihazdan veya pencereli çalıştırmadan alınmalı |
| 14 | Mağaza metni (Türkçe + İngilizce) | KULLANICI | README İngilizce/Türkçe karışık; oyun metni Türkçe | Başlık/kısa/uzun açıklama yazılmadı |
| 15 | Varlık lisansları | **EKSİK** | Kök `LICENSE`, `ASSET_LICENSES`, `CREDITS` yok. Var: `ASSET_INVENTORY.md` | Yazı tipleri, ses ve görsellerin lisansı/kaynağı (PixelLab/AI üretimi dahil) belgelenmeli. AI ile üretilmiş içerik beyanı Play'de de sorulabilir. KULLANICI |
| 16 | Yeni kişisel geliştirici hesabı için kapalı test | KULLANICI | PLAY-DOC: 13 Kasım 2023 sonrası kişisel hesaplar için ≥12 test kullanıcısı, 14 gün kesintisiz | Hesap türü/tarihi bilinmiyor. Bu, yayın takvimine en az 14 gün ekler |
| 17 | Cihaz testi | **TEST EDİLMEDİ** | PROGRESS.md: v1.0 cihazda doğrulandı (QC59AM55BMCIEUHQ); ses cihazda dinlenmedi; 2 saatlik tur doğrulanmadı | v1.12.2 için gerçek cihaz/emülatör kanıtı yok |
| 18 | Çökme / ANR izleme | KULLANICI | Play Console Vitals yayın sonrası | Yayın öncesi `adb logcat` taraması yapılmadı |
| 19 | Pre-launch report | KULLANICI | Play Console, kapalı test yüklemesinde otomatik | AAB yüklendikten sonra okunmalı |
| 20 | Uygulama kategorisi | KOD | `package/app_category=2` (oyun) | Mağaza kategorisi Console'da ayrıca seçilir |

## Özet

Yayınlanabilirliği şu an engelleyenler: **AAB yok, release imzası yok, gizlilik politikası yok, varlık lisansları yok, Play içinde kendini güncelleme düğmesi, 16 KB ve hedef API'nin derlenmiş pakette doğrulanmaması, cihaz testi yok.** İçerik ve hesap tarafı kullanıcı işi.

## Kaynaklar
- [Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)
- [Play Console technical quality requirements](https://support.google.com/googleplay/android-developer/answer/17492799)
- [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
