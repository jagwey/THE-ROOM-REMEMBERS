# Temel UI / diyalog / günlük düzeltme raporu

Tarih: 6 Kasım 2026 · oyun 0.8.0 · Godot 4.7.2 · 640×360  
Kaynak: yalnızca yerel disk (`THE-ROOM-REMEMBERS`). Oyun kaynağı public GitHub’a push edilmedi.

---

## Özet

Atlas bölgeli diyalog/günlük panelleri, TR sayfalama + tip yazıcı, modal giriş kilidi (UiGate), günlük kitap düzeni, mühür kod girişi, ceset/oda/plaka/kayıt/final düzeltmeleri ve dekor asset bağlaması uygulandı. Görüntülü ekran görüntüleri alındı; headless smoke FAZ67 geçti. **Gerçek Android cihaz testi yapılmadı.**

---

## Madde durumu

| Madde | Durum | Kanıt / not |
|-------|--------|-------------|
| Diyalog panel PNG ana çerçeve (alt süs hariç) | **düzeltildi** | Atlas `Rect2(61,2,197,114)`; kaynak PNG dokunulmadı |
| Diyalog mobil düğmelerden uzak / hikâyede kontroller gizlenir | **düzeltildi** | Üst-orta panel; story’de joy/attack/dash gizli, Interact kalır |
| Uzun TR sayfalama (küçültme/clip ana çözüm değil) | **düzeltildi / doğrulandı** | `pages_rejoin_ok=true`; tip yazıcı + sayfa; görüntü: `screens/02_*.png`, `03_*.png` |
| Tip yazıcı: ilk basış tamamlar | **düzeltildi** | `DialogueManager.advance()` |
| Whisper (VFX) vs hikâye diyaloğu | **düzeltildi** | CurseVFX üst-orta kuyruk; hikâye modal |
| İptal ≠ tamamlanma | **düzeltildi** | `clear()` → `dialogue_cancelled`; `dialogue_closed` yalnız başarı |
| Günlük kitap içi + scroll + Kapat ayrı | **düzeltildi / doğrulandı** | Sol sayfa ScrollContainer; sağ Kapat; `screens/05_*.png`, `06_*.png` |
| Günlük oyunu durdurur, giriş temizler, Android geri | **düzeltildi** | `get_tree().paused` + PROCESS_ALWAYS UI; `ui_cancel` / WM_GO_BACK |
| Safe area / anchor mobil düğmeler | **düzeltildi** | Sağ-alt / sol-alt anchor; güvenli alan map |
| Kayıt yükleme + Puzzle sync | **düzeltildi** | `main.gd` continue; `PuzzleManager.sync_from_world` |
| Ağırlık plakası doğal ceset | **düzeltildi** | Shape büyütme + mesafe slack (ışınlama yok) |
| Ölüm giriş kilidi | **düzeltildi** | `DeathManager` → player `_input_locked` |
| Ceset aktif oda kökü | **düzeltildi** | `CorpseManager._find_active_corpses_root` |
| Mühür: yanlış kod reddi + giriş UI | **düzeltildi** | Yalnız `314`; HUD pad; boş/yanlış çözmez |
| Final dokunmatik devam | **düzeltildi** | `ending_ui` dim touch + interact |
| WASD InputMap | **düzeltildi** | `ui_left/right/up/down` + oklar |
| Asset entegrasyonu | **düzeltildi** | Bkz. `ASSET_KULLANIM.md` |
| Görüntülü ekran görüntüleri | **doğrulandı** | Display driver Windows; 7 PNG |
| Headless FAZ67 smoke | **doğrulandı** | `curse_fail=true world=true bad=true good=true` |
| Gerçek Android cihaz | **doğrulanmadı** | Cihaz yok; APK üretimi = cihaz testi değil |
| Çentikli telefon / çoklu dokunma | **doğrulanmadı** | Sanal inset kodu var; fiziksel cihaz yok |
| 60 FPS iddiası | **doğrulanmadı** | Ölçülmedi |

---

## Değişen dosyalar (özet)

- `scripts/autoload/ui_gate.gd` **(yeni)**
- `scripts/autoload/dialogue_manager.gd`, `mobile_input_manager.gd`, `corpse_manager.gd`, `save_manager.gd`, `puzzle_manager.gd`
- `scripts/ui/hud_controller.gd`, `journal_ui.gd`, `ending_ui.gd`, `curse_vfx.gd`
- `scripts/player/player_controller.gd`, `scripts/main.gd`
- `scripts/world/pressure_plate.gd`, `memory_seal.gd`, `memory_hazard.gd`
- `scenes/ui/hud.tscn`, `journal.tscn`
- `scenes/rooms/awakening.tscn`, `core.tscn`
- `project.godot` (UiGate autoload, WASD)
- `scripts/dev/polish_capture.gd` **(yeni, test)**
- `docs/gelistirme/ui-temel-sorunlar/screens/*.png`
- `docs/gelistirme/ui-temel-sorunlar/ASSET_KULLANIM.md`

---

## Test komutları

```powershell
# Görüntülü UI kanıtı
$env:TORIMON_FRESH='1'
godot --path . -s res://scripts/dev/polish_capture.gd --display-driver windows

# Headless smoke (oyuncu kaydını yedekle)
$env:TORIMON_SMOKE='1'; $env:TORIMON_FRESH='1'
godot --path . --headless
# Beklenen: FAZ67_SMOKE ok curse_fail=true world=true bad=true good=true
```

---

## Ekran görüntüleri

Proje: `docs/gelistirme/ui-temel-sorunlar/screens/`  
Agent Store: media/ui-polish/ (aynı 7 dosya)

- `01_dialogue_short.png`
- `02_dialogue_long_page1.png`
- `03_dialogue_long_page2.png`
- `04_normal_play.png`
- `05_journal_empty.png`
- `06_journal_full.png`
- `07_after_journal.png`

---

## Font (Pixeloid Sans) — 6 Kasım 2026

**Seçim:** Pixeloid Sans + Bold (GGBotNet), SIL OFL 1.1.  
**Neden:** Projede font yoktu (Godot varsayılan sans). Pixeloid okunaklı piksel UI fontu; 1027 glif; Türkçe `ğüşıöçĞÜŞİÖÇ` doğrulandı; 640×360’ta net; gotik/retro sahneyle uyumlu temiz piksel sans. Kaynak: `assets/fonts/` + `OFL-Pixeloid.txt`.

**Uygulama:** `themes/torimon_ui.tres` proje teması + `UiTheme` autoload. Hiyerarşi: hint 10 · body 12 · speaker/title 13 bold · ending title 16 bold · journal body 10. Antialiasing kapalı.

**Sayfalama:** yeni metriklerle `page_rejoin_ok=true` (görüntülü capture 08–14).

**Ekranlar:** `screens/08_font_*.png` … `14_font_*.png` (+ Agent Store `media/ui-polish/`).

---

## Kalan sınırlamalar

1. Android cihaz / notch / çoklu parmak doğrulanmadı.
2. Erken kötü son (Bekçi’ye 3 vuruş) tasarım olarak duruyor — bilinçli; içerik genişletmesi ayrı iş.
3. Kullanılmayan oda arka planları (decay/library/…) hâlâ sahnesiz.
4. Diyalog panel yüksekliği karakterin üstünü kısmen örter; okunabilirlik öncelikli, ince ayar yapılabilir.
5. Headless otomatik diyalog varsayılan açık; görüntülü manuel için `TORIMON_NO_AUTO_DIALOGUE=1`.
6. Pixeloid “temiz” piksel sans; daha gotik/display bir piksel font istenirse ayrı turda değiştirilebilir (TR glif şartı korunmalı).
