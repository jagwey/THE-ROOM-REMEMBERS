# THE ROOM REMEMBERS (Godot 4.7.2, GDScript)
Yan görünüşlü bellek/lanet oyunu. Kapalı kaynak, private repo. Paket: com.torimon.theroomremembers (Android arm64).

## Mimari
- Ana sahne: `scenes/main/main.tscn`, giriş `scripts/main.gd`
- `scripts/autoload/` global yöneticiler (game_state, death/corpse/curse/echo/ending/puzzle/dialogue/mobile_input, palette)
- `scripts/{player,keeper,world,story,ui,camera}/`; araçlar `scripts/dev/` (audit/capture)
- Veri: `manifest.*`, `palette.json`, `animations.json`; varlıklar `assets/`
- Geliştirme notları/promptlar: `docs/gelistirme/`

## Komutlar
- Çalıştır: Godot 4.7.2 ile bu klasörü aç, F5
- Audit: `docs/gelistirme/Run-Audit.ps1`, `scripts/dev/*.gd` (headless)

## Kurallar
- Kod/identifier İngilizce, oyun metni Türkçe, UTF-8
- Sadece göreve ilgili dosyaları oku; log/zip/png dump okuma
- Yayın/commit yalnız kullanıcı isteyince
- Sır/anahtar/parola hiçbir dosyaya yazma
- **GÖREV SONU DOKÜMANTASYON KURALI (ZORUNLU):** Her ajan / alt ajan bir işi, revizyonu veya görevi bitirdiğinde; yapılan tüm değişiklikleri, yeni mekanikleri, mimariyi ve sürüm bilgisini MUTLAKA `README.md` ve `PROGRESS.md` dosyalarına yansıtacaktır. Dokümantasyon asla bayat bırakılamaz.

## Release (ÖNEMLİ)
- Kaynak repo `jagwey/THE-ROOM-REMEMBERS` **private**. Oyuncuların gördüğü APK'lar **public** repo'ya gider: https://github.com/jagwey/THE-ROOM-REMEMBERS-release
- Oyun içi güncelleme: `scripts/autoload/update_checker.gd` açılışta `api.github.com/repos/jagwey/THE-ROOM-REMEMBERS-release/releases/latest` okur (token YOK). `tag_name` > `config/version` ise başlık ekranında "Güncelle → vX" düğmesi APK'yı açar. Android `permissions/internet=true` gerekli.
- Her sürümde: `project.godot` `config/version` + `export_presets.cfg` `version/code` (+1) ve `version/name` artır → APK derle → `TheRoomRemembers-X.Y.Z-android-arm64.apk`.
- Yayın: `gh release create vX.Y.Z <apk> --repo jagwey/THE-ROOM-REMEMBERS-release --title vX.Y.Z --notes "..."` (tag `v` önekli, APK asset adı `.apk` ile bitsin). İsteğe bağlı aynı APK private repoya da.
- Release'i oraya atmazsan oyuncular güncellemeyi göremez.
- **Release temizliği (ZORUNLU, GitHub 2 GB sınırı):** her iki repoda (`THE-ROOM-REMEMBERS-release` ve `THE-ROOM-REMEMBERS`) en fazla güncel sürüm + 3 eski sürüm kalır. Yeni release yayınlandıktan sonra en yeni 4'ten eskilerini sil: `gh release delete vX.Y.Z --repo <repo> --cleanup-tag --yes`. Silmeden önce `gh release list --repo <repo>` ile kontrol et; `latest` asla silinmez.

## Kritik kararlar
- Güncel sürüm: v1.13.0 (kaynak: `project.godot` `config/version`; bu satır bayatlayabilir, orayı kontrol et)
- v0.10.1: awakening gate, objective, softlock korumaları, tek final (BÖLÜM I SONU / END OF PART I), core_choice kaldırıldı
- Çalışma planı ve durum: `PROGRESS.md` (her alt görevden sonra güncelle, sıkıştırma sonrası ilk onu oku)
