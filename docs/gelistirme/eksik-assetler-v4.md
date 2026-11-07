# V4.1 — Eksik Sprite / Ses Listesi (sanatçı için)

Kaynak: `animations.json`, `assets/characters/*_sheet.png`. Hücre: Noroi 96×96, Shilda 128×128.
Sahte akıcılık (aynı kareyi tekrarlama) YAPILMADI; aşağıdakiler gerçekten çizilmesi gereken kareler.

## Mevcut kare sayıları (değişmedi)
| Karakter | Animasyon | Kare | FPS | Not |
|---|---|---|---|---|
| Noroi | idle | 4 | 5–6 | OK |
| Noroi | run | 4 | 10–12 | Akıcı koşu için 6–8 önerilir |
| Noroi | attack | 4 | 10–12 | OK |
| Noroi | dash | 2 | 12–14 | Havada da bu kare kullanılıyor |
| Noroi | hurt | 1 | 5 | 2–3 önerilir |
| Noroi | death | 2 (14,15) | 4 | 4–6 önerilir |

Hizalama ölçümü: 16 karenin hepsi tabanı y=92'de, yatay merkez x≈48 → pivot kayması/dikey titreme yok.

## Eksik Noroi kareleri (öncelik sırası)
1. `jump_start` — 1–2 kare (çömelme → itiş)
2. `rise` — 1–2 kare (yukarı)
3. `apex` — 1 kare (tepe, gövde toplu)
4. `fall` — 1–2 kare (aşağı, pelerin yukarı)
5. `land` — 1–2 kare (iniş çömelmesi)
6. `run` ara kareleri — +2..4 kare (toplam 6–8)
7. `hurt` +1–2, `death` +2–4
8. `interact` / `inspect` — 2–3 kare (eğilip bakma)

Kod hazır: oyuncu `air_phase` = jump_start / rising / apex / falling / landing / ground üretir.
Kareler geldiğinde yalnız `_update_anim()` içinde faz → animasyon eşlemesi eklenecek.

## Shilda (keeper)
- `observe`, `walk`, `attack`, `grieve` var. Eksik: `talk` (2–3 kare), `hurt` (1–2), dönüş (turn) 2 kare.

## Ses / müzik
- Tüm ses şu an **prosedürel** (`scripts/audio/sound_bank.gd`); `assets/` altında hiç .ogg/.wav/.mp3 yok.
- Müzik 01–16 dosyaları **YOK**. Gelirse önerilen yol: `assets/audio/music/01_title.ogg` … `16_*.ogg`.
  - 01 başlık ekranı, diğerleri bölge sırasına göre (awakening, decay, archive, garden, core, ending…).
- Eksik gerçek SFX (prosedürel yerine): ayak (taş/ahşap), iniş, kapı açılma/mühür kırılma, Shilda nefes/çığlık, sayfa çevirme.
