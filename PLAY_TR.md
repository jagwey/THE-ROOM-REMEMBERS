# The Room Remembers — Çalıştırma (Godot 4.7 · FAZ 8)

## Proje

- `jagwey/THE-ROOM-REMEMBERS` · Godot **4.7.2** · F5
- Ana sahne: `scenes/main/main.tscn`

## Kontroller

Yürü (WASD/oklar) · **Z/J** saldır · **X/K** dash · **E/F** etkileş · **I/Tab** günlük · mobil HUD aynı (büyük dokunmatik alan + safe-area).

## Dikey dilim (FAZ 1–8)

- Mobil joystick + düğmeler, kalpler (TR)
- Bekçi: gözlem → uyarı → müdahale (erken öldürme yok)
- Ölüm / yeniden doğuş + dünya hafızası (ceset ≤3)
- Yankı + ağırlık / bellek kodu 314 + günlük
- Lanet: erken HUD bar yok; veil/halo; %100 → hayat biter, dünya kalır
- Kötü son (Bekçi’ye 3 saldırı) · İyi son (güven + mühür)
- Parallax Awakening/Core, moodboard paleti, Android debug APK yolu

## Android debug APK

```text
Godot 4.7.2 → Proje → Dışa Aktar → preset "Android"
çıktı: build/android/TheRoomRemembers-debug.apk
```

Gereksinimler: JDK 17+, Android SDK (`platforms;android-34`, `build-tools;34.0.0`, `platform-tools`), export templates `4.7.2.stable`, debug keystore.

CLI (Windows’ta repo yolu ASCII değilse imza için ASCII çıktı yolu kullan):

```powershell
New-Item -ItemType Directory -Force -Path $env:TEMP\torimon-build | Out-Null
godot --headless --path . --export-debug "Android" "$env:TEMP\torimon-build\TheRoomRemembers-debug.apk"
Copy-Item "$env:TEMP\torimon-build\TheRoomRemembers-debug.apk" build\android\ -Force
```

## Smoke (opsiyonel)

```powershell
$env:TORIMON_SMOKE="1"
godot --headless --path . --quit-after 600
```
