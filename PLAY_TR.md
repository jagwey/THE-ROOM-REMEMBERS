# The Room Remembers — Çalıştırma (Godot 4.7 · v0.10.1)

## Proje

- `jagwey/THE-ROOM-REMEMBERS` · Godot **4.7.2** · F5
- Ana sahne: `scenes/main/main.tscn`

## Kontroller

Yürü (WASD/oklar) · **Z/J** saldır · **X/K** dash · **E/F** etkileş · **I/Tab** günlük · mobil HUD aynı (büyük dokunmatik alan + safe-area).

## İlk 5 dakika

1. Cep saatine **E** · ortada Shilda beat · sağdaki **basınç plakasına** bas  
2. Kapı açılınca **Kırık Geçit**’e gir (oda genişler, kamera takip eder)  
3. Kırmızı yarıkları **X** ile atla veya alttan dolaş; yankıdan **314** kodunu al  
4. Mühür odasında kodu gir → **Çürüme** → bahçe arşivi → kütüphane… çekirdeğe kadar  

HUD üstte tek satır hedef gösterir. Ölüm dünya hafızasını silmez; erken Bekçi vuruşu oyunu bitirmez (kötü son yalnız çekirdekte).

## Dikey dilim

- 18 bağlı oda · Noroi / Shilda hikâyesi · iki bilinçli final (+ çekirdekte kötü son)
- Yankı + ağırlık / bellek kodu 314 + günlük
- Lanet: %100 → hayat biter, dünya kalır
- Android APK: GitHub Releases

## Android debug APK

```powershell
New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA\Temp\torimon-build | Out-Null
godot --headless --path . --export-debug "Android" "$env:LOCALAPPDATA\Temp\torimon-build\TheRoomRemembers-0.10.1.apk"
```

## Smoke

```powershell
$env:TORIMON_SMOKE="1"; $env:TORIMON_FRESH="1"
# --quit-after kullanma (kare cinsinden erken keser); smoke kendi quit eder
godot --headless --path .
```
