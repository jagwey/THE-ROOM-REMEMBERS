# THE ROOM REMEMBERS (Godot 4.7.2, GDScript)
Yan görünüşlü bellek/lanet oyunu. Kapalı kaynak, private repo. Paket: com.torimon.theroomremembers (Android arm64).

## Mimari
- Ana sahne: `scenes/main/main.tscn`, giriş `scripts/main.gd`
- `scripts/autoload/` global yöneticiler (game_state, death/corpse/curse/echo/ending/puzzle/dialogue/mobile_input, palette)
- `scripts/{player,keeper,world,story,ui,camera}/`; araçlar `scripts/dev/` (audit/capture/preview)
- Sahneler: `scenes/{main,player,keeper,props,rooms,ui,world,dev}/` (`preview.tscn` → `scenes/dev/preview.tscn`)
- Veri & varlıklar: `data/dialogue/` (oda diyalog JSON'ları), `data/meta/` (`manifest.*`, `palette.*`, `animations.json`), `assets/`
- Belgeler (`docs/`): `reference/` (`PROJECT.md`, `ASSET_INVENTORY.md`, `PLAY_TR.md`), `testing/` (`TEST_INFRA.md`, `TEST_READY.md`), `qa/release-readiness/`, `gelistirme/`, `play/`, `specs/`, `superpowers/`, `archive/`

## Komutlar
- Çalıştır: Godot 4.7.2 ile bu klasörü aç, F5
- Audit: `docs/gelistirme/Run-Audit.ps1`, `scripts/dev/*.gd` (headless)

## Kurallar
- Kod/identifier İngilizce, oyun metni Türkçe, UTF-8
- Sadece göreve ilgili dosyaları oku; log/zip/png dump okuma
- Yayın/commit yalnız kullanıcı isteyince
- Sır/anahtar/parola hiçbir dosyaya yazma
- **KÖK DİZİN TEMİZLİĞİ:** Kök dizine asla yeni `.md`, `.json`, `.gd` veya `.tscn` dosyası bırakma; tam klasör yapısı ve yerleşim kuralları için `PROGRESS.md` (`## Proje Dizin Mimarisi`) bölümüne uy.
- **GÖREV SONU DOKÜMANTASYON KURALI (ZORUNLU):** Her ajan / alt ajan bir işi, revizyonu veya görevi bitirdiğinde; yapılan tüm değişiklikleri, yeni mekanikleri, mimariyi ve sürüm bilgisini `PROGRESS.md` dosyasına yansıtacaktır; `README.md` ise spoiler vermeden oyuncu/vitrin özeti, GIF/ekran görüntüleri ve sürüm bağlantısı açısından güncel tutulur. Dokümantasyon asla bayat bırakılamaz.

## T3 Code Çoklu Ajan Koordinasyonu & Otomatik Kota Devri (Zorunlu)
- **Ana thread koordinatör kalır:** Çok adımlı veya ağır işlerde işi alt ajanlara (`delegate_task`) dağıt; ana sohbet kullanıcıyla anlık soru-cevap ve durum takibi için serbest kalsın.
- **Periyodik kontrol:** Alt ajanların durumunu takip et (çalışan görevi gereksiz döngüde poll etmeden, tamamlanma/hata bildirimlerinde, sunucu yeniden başlangıcında veya kullanıcı sorduğunda `t3_thread_read` ile kontrol et).
- **Kota / limit bitince otomatik devir (failover):** Bir alt ajan (veya aktif sağlayıcı) kota/limit hatasına (`Individual quota reached`, rate limit, capacity exhaustion vb.) takılırsa ya da yarım kalırsa, işi kaybetmeden kalan adımları `orchestrator_capabilities` içindeki bir sonraki sağlıklı sağlayıcıya/modele (örn. `antigravity_2` ↔ `antigravity` ↔ `claudeAgent` ↔ `codex`) devret ve kullanıcıya hangi sağlayıcıya geçildiğini tek satırda bildir.
- **Kayıpsız devir:** Devir öncesinde önceki alt ajanın yaptığı dosya değişikliklerini ve commit'leri koru; kaldığı yerden temiz biçimde devam et.
- **Model seçimi (zorunlu):** Sonnet kullanma; her zaman üst düzey modellerle çalış (**Opus** `claude-opus-5-5`, **Neon** `gemini-4-neon`, **Argon** `gemini-4-argon`, **Sol** `gpt-6.2-sol`, **Astra** `gpt-6.2-astra`).

## Release (ÖNEMLİ)
- Kaynak repo `jagwey/THE-ROOM-REMEMBERS` **private**. Oyuncuların gördüğü APK'lar **public** repo'ya gider: https://github.com/jagwey/THE-ROOM-REMEMBERS-release
- Oyun içi güncelleme: `scripts/autoload/update_checker.gd` açılışta `api.github.com/repos/jagwey/THE-ROOM-REMEMBERS-release/releases/latest` okur (token YOK). `tag_name` > `config/version` ise başlık ekranında "Güncelle → vX" düğmesi APK'yı açar. Android `permissions/internet=true` gerekli.
- Her sürümde: `project.godot` `config/version` + `export_presets.cfg` `version/code` (+1) ve `version/name` artır → APK derle → `TheRoomRemembers-X.Y.Z-android-arm64.apk`.
- Yayın: `gh release create vX.Y.Z <apk> --repo jagwey/THE-ROOM-REMEMBERS-release --title vX.Y.Z --notes "..."` (tag `v` önekli, APK asset adı `.apk` ile bitsin). İsteğe bağlı aynı APK private repoya da.
- Release'i oraya atmazsan oyuncular güncellemeyi göremez.
- **Release temizliği (ZORUNLU, GitHub 2 GB sınırı):** her iki repoda (`THE-ROOM-REMEMBERS-release` ve `THE-ROOM-REMEMBERS`) en fazla güncel sürüm + 3 eski sürüm kalır. Yeni release yayınlandıktan sonra en yeni 4'ten eskilerini sil: `gh release delete vX.Y.Z --repo <repo> --cleanup-tag --yes`. Silmeden önce `gh release list --repo <repo>` ile kontrol et; `latest` asla silinmez.

## Kritik kararlar
- Güncel sürüm: v1.20.6 (kaynak: `project.godot` `config/version`; bu satır bayatlayabilir, orayı kontrol et)
- v0.10.1: awakening gate, objective, softlock korumaları, tek final (BÖLÜM I SONU / END OF PART I), core_choice kaldırıldı
- Çalışma planı ve durum: `PROGRESS.md` (her alt görevden sonra güncelle, sıkıştırma sonrası ilk onu oku)
