# Asset kullanım — wired vs unused (6 Kasım 2026 polish)

## Bu turda sahneye bağlananlar

| Asset | Nereye |
|-------|--------|
| `assets/layers/candlestick.png` | Uyanış Decor |
| `assets/layers/vines.png` | Uyanış Decor |
| `assets/layers/rubble.png` | Uyanış Decor |
| `assets/layers/books.png` | Uyanış Decor (mühür yanı) |
| `assets/layers/flowers.png` | Uyanış Decor |
| `assets/layers/column.png` | Uyanış Decor |
| `assets/props/candles.png` | Uyanış Decor |
| `assets/props/pocket_watch.png` | Uyanış Decor |
| `assets/layers/altar.png` | Çekirdek Decor |
| `assets/layers/chains.png` | Çekirdek Decor |
| `assets/layers/light_beam.png` | Çekirdek Decor |
| `assets/layers/embers.png` | Çekirdek Decor |
| `assets/panels/dialogue.png` atlas `Rect2(61,2,197,114)` | HUD diyalog (alt süs hariç) |
| `assets/panels/journal.png` atlas `Rect2(63,2,193,128)` | Günlük kitap (alt süs hariç) |

## Zaten bağlı (değişmedi)

- Karakter: shiren / keeper / npc sheets
- BG: awakening + core far/mid/front
- HUD: joystick, attack, dash, interact, journal, hearts
- Props: crystal, curse, door, seal, pressure_plate, body_echo, red_flower, halo, core_crystal layer

## Hâlâ kullanılmayan (bilinçli / sonraki içerik)

| Asset | Not |
|-------|-----|
| `backgrounds/decay,library,experiment,mirrors/*` | Oda sahneleri yok |
| `panels/inventory.png`, `menu.png` | Menü/envanter UI yok |
| `hud/pause,settings,speech,tab_*,diamond_*,health_bar` | Alternatif HUD; diamond_selected lanet göstergesinde kullanılıyor |
| `layers/arch,bookshelf,candlestick(ok),mirror*,tank,vines(ok)` | mirror/tank/bookshelf sonraki odalar |
| `props/cassette,key,memory_mote,photograph,slash` | Hikâye prop’ları henüz etkileşimli değil |
| `tiles/*` | Tilemap sahnesi yok |
| `characters/npc*` | Sahneye yerleştirilmedi |

Kaynak PNG dosyaları kırpılmadı; atlas region ile ana çerçeve seçildi (`panel_olcumleri.json` ile uyumlu).
