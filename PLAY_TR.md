# The Room Remembers — Çalıştırma (Godot 4.7 · FAZ 4)

## Proje

- Repo: `jagwey/THE-ROOM-REMEMBERS`
- Yerel: `C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\THE-ROOM-REMEMBERS`
- Motor: **Godot 4.7** (4.7.2)

## Açılış

1. Godot **4.7** → bu klasörü aç → **F5** (`scenes/main/main.tscn`).

## Kontroller

| Eylem | Klavye | Mobil |
|-------|--------|-------|
| Yürü | Ok / WASD | Joystick |
| Saldır / Dash / Etkileş | Z / X / E | Sağ düğmeler |
| Diyalog devam | E / Etkileş | |

## FAZ 3 — Bekçi

Silüet fısıltısı; kristal/kapı → uyar → yumuşak engel. **Bekçi öldürmez.**

## FAZ 4 — Ölüm / hafıza / ceset

1. Gizemden sonra ortadaki **hafıza yarığı** (kırmızı halo, ~x=450) görünür.
2. İlk temas → uyarı (“Zemin… yanlış.”). İçinde kalır veya tekrar girersen → **öğretici ölüm** (tuzak, Bekçi değil).
3. Yeniden doğuş: Awakening checkpoint `(120,280)`; karakter unutur (“Neredeyim?”); **dünya / cesetler kalır**.
4. Ceset max **3**; fazlası çiçek/leke/silüet. Bekçi yas modunda çiçek bırakır.
5. Cesede Etkileş → Echo / ağırlık stub satırları.
6. `world_memory_state.flags` + SaveManager kaydı (`user://torimon_save.json`).

## Sonraki (henüz yok)

FAZ 5 — Echo / bulmaca / günlük.
