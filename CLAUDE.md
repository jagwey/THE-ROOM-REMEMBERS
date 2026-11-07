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

## Release (ÖNEMLİ)
- Kaynak repo `jagwey/THE-ROOM-REMEMBERS` **private**. Oyuncuların gördüğü APK'lar **public** repo'ya gider: https://github.com/jagwey/THE-ROOM-REMEMBERS-release
- Oyun içi güncelleme: `scripts/autoload/update_checker.gd` açılışta `api.github.com/repos/jagwey/THE-ROOM-REMEMBERS-release/releases/latest` okur (token YOK). `tag_name` > `config/version` ise başlık ekranında "Güncelle → vX" düğmesi APK'yı açar. Android `permissions/internet=true` gerekli.
- Her sürümde: `project.godot` `config/version` + `export_presets.cfg` `version/code` (+1) ve `version/name` artır → APK derle → `TheRoomRemembers-X.Y.Z-android-arm64.apk`.
- Yayın: `gh release create vX.Y.Z <apk> --repo jagwey/THE-ROOM-REMEMBERS-release --title vX.Y.Z --notes "..."` (tag `v` önekli, APK asset adı `.apk` ile bitsin). İsteğe bağlı aynı APK private repoya da.
- Release'i oraya atmazsan oyuncular güncellemeyi göremez.

## Kritik kararlar
- v0.10.1: awakening gate, objective, softlock korumaları, core_choice bulmacası endinglerden önce
- Çalışma planı ve durum: `PROGRESS.md` (her alt görevden sonra güncelle, sıkıştırma sonrası ilk onu oku)
