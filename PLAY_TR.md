# THE ROOM REMEMBERS — Oynanış ve Çalıştırma Rehberi (`v1.8.1` · Godot 4.7)

## 1. Proje Bilgileri
- **Depo:** [`jagwey/THE-ROOM-REMEMBERS`](https://github.com/jagwey/THE-ROOM-REMEMBERS)
- **Motor:** Godot **4.7.2** (`gl_compatibility`)
- **Ana Sahne:** `scenes/main/main.tscn` (**F5**)
- **Güncel Android Sürümü:** **[v1.8.1 (`TheRoomRemembers-1.8.1-android-arm64.apk`)](https://github.com/jagwey/THE-ROOM-REMEMBERS-release/releases/tag/v1.8.1)** (`com.torimon.theroomremembers`, `versionCode 33`)

---

## 2. Kontroller

| Eylem | Klavye (PC) | Android (Dokunmatik HUD) |
| :--- | :--- | :--- |
| **Yürü** | `WASD` / `Yön Tuşları` | Sol Sanal Joystick (Sabit / Yüzen) |
| **Zıpla** | `W` / `Space` / `Yukarı` | Sağ HUD — **Zıpla (`^`)** |
| **Saldır (3'lü Kombo)** | `Z` / `J` | Sağ Alt — **Kılıç** |
| **Dash / Gölge Atılması** | `X` / `K` | Sağ Alt — **Dash** |
| **Etkileş / İt / Konuş** | `E` / `F` | Sağ Orta — **El (`Interact`)** |
| **Yetenek (Ruh Kesimi)** | `C` / `L` | Sağ HUD — **Ruh Kesimi (`Skill`)** |
| **Günlük & Harita** | `I` / `Tab` | Sağ Üst — **Günlük (Kitap)** |
| **Duraklat / Menü** | `Esc` | Sağ Üst — **Menü** / Android Geri Tuşu |

---

## 3. Adım Adım Tam Akış (6 Bölge · 30 Oda)

1. **Bölge I — Uyanış Mahmuzu (`awakening`):**
   - Yerdeki **Durmuş Cep Saati**'ni incele (`3:14` ipucu) → ortada **Shilda** ile konuş → sağdaki **basınç plakasına** basarak kapıyı aç.
   - **Gözlem Balkonu** ve **İlk Bedenler Mahzeni** yan odalarında ilk kanıtları topla.
   - **Kırık Geçit**'te kırmızı bellek yarıklarından `Dash` ile atla; ceset yankısından **`314`** kodunu öğren ve **Mühürlü Eşik**'te tuş takımına gir.
2. **Bölge II — Çürüme Bahçesi (`decay`):**
   - **Sarmaşıklı Koridor** ve **Ağırlık Odası**'nda taşları veya önceki cesetlerini plakalara iterek geçitleri aç.
   - **Çürüme Bahçesi**'nde Shilda ile konuşup ona güvenmeyi seç (`trusted_keeper` — İyi Son için gereklidir).
3. **Bölge III — Hafıza Kütüphanesi (`library`):**
   - **Kayıp Sayfa Odası**'nda yırtık sayfaları doğru sıraya diz.
   - **Yasak Kanat**'taki sunaktan **Ruh Kesimi (`SoulSlash`)** yeteneğini kazan (mor mühürleri, sarmaşıkları ve kalkanlı gölgeleri uzaktan kırar).
   - **Tanık Odası**'ndan **`251`** mühür kodunu ve **1. Mühür Parçasını (`seal_fragment_library`)** al.
4. **Bölge IV — Yasak Laboratuvar (`experiment`):**
   - **Yankı Devresi** ve **Çekirdek İletkeni**'nde `EchoAltar` kullanarak gölge ikizinle (`EchoTwin`) eşzamanlı şalterleri tetikle.
   - **`418`** mührünü açarak Aynalar Salonu'na geç.
5. **Bölge V — Aynalar Salonu (`mirrors`):**
   - **Ayna Tapınağı**'nda **Gölge Atılması (`ShadowDash`)** yeteneğini kazan (lanet bariyerlerinden ve kalkanlı gölgelerin içinden hasar almadan geçer).
   - **`729`** mührünü çöz ve **2. Mühür Parçasını (`seal_fragment_mirrors`)** al.
6. **Bölge VI — Bellek Çekirdeği (`core`):**
   - **Bellek Mahzeni**'nde gerçeği gör (`truth_seen`), **Mühür Odası**'nda iki mühür parçasını birleştir ve **Çekirdek**'e in.
   - **Kanonik Final (BÖLÜM I SONU):** Ruh Kesiği ile ana mühür kırılır; Shilda insan formuna döner. Çıkış kapısı aralanırken Kurucu X ortaya çıkar ve boyutlar arası deneyin perdesini aralar.

---

## 4. Android APK Derleme ve Otomatik Test Komutları

### Android APK Dışa Aktarma
```powershell
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA\Temp\torimon-build | Out-Null
godot --headless --path . --export-debug "Android" "$env:LOCALAPPDATA\Temp\torimon-build\TheRoomRemembers-1.7.0-android-arm64.apk"
```

### Headless Denetim ve Smoke Testleri
```powershell
# 107 kontrollü sürüm ve oda/kapı grafiği denetimi
godot --headless --path . --script res://scripts/dev/release_audit.gd

# Kontroller, yetenekler, dövüş ve bulmaca denetimi
godot --headless --path . --script res://scripts/dev/controls_audit.gd

# Ölüm döngüsü ve Yankı Tekrarı (Echo Replay) denetimi
godot --headless --path . --script res://scripts/dev/death_loop_audit.gd

# Kayıt sistemi (.bak / .prev ve Kaydet & Çık) denetimi
godot --headless --path . --script res://scripts/dev/save_robust_audit.gd
```
