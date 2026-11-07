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

## Kritik kararlar
- v0.10.1: awakening gate, objective, softlock korumaları, core_choice bulmacası endinglerden önce
- Çalışma planı ve durum: `PROGRESS.md` (her alt görevden sonra güncelle, sıkıştırma sonrası ilk onu oku)
