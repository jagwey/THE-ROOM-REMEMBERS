# Varlık Lisansları (DOLDURULACAK)

Play yayını ve olası itiraz için her varlık grubunun kaynağı ve lisansı belgelenmeli. Depoda LICENSE/CREDITS yok (QA BUG: 07 satır). Aşağıdaki "Kaynak" alanlarını **sen** doldur; ben kaynağı bilmediğim için tahmin yazmadım.

| Grup | Klasör | Kaynak (araç / kişi / site) | Lisans | Kanıt (fatura/ekran görüntüsü/sayfa) | Durum |
|---|---|---|---|---|---|
| Karakter sprite'ları | `assets/` | ? | ? | ? | DOLDUR |
| Arka plan / tile | `assets/` | ? | ? | ? | DOLDUR |
| UI | `assets/` | ? | ? | ? | DOLDUR |
| Müzik | `assets/` | ? | ? | ? | DOLDUR |
| Ses efektleri | `assets/` | ? | ? | ? | DOLDUR |
| Yazı tipleri | `assets/` | ? | ? | ? | DOLDUR |
| Yazı tipi: Pixeloid Sans | `assets/fonts/` | Pixeloid Sans | SIL OFL 1.1 (`assets/fonts/OFL-Pixeloid.txt` depoda) | depodaki lisans dosyası | CREDITS'e ekle |
| Mağaza görselleri | `docs/play/store/` | Oyunun kendi arka plan/ikon varlıkları + Pixeloid; `make_feature_graphic.py` ve `room_visual_capture.gd` (dev, pakete girmez) | Kaynak varlıkların lisansına bağlı (yukarıdaki satırlar DOLDUR olduğu sürece belirsiz) | — | Kaynak lisanslar netleşince kesinleşir |
| Godot motoru | (motor) | Godot Engine | MIT | https://godotengine.org/license | Notu CREDITS'e ekle |

AI ile üretilen varlıklar için: kullanılan aracın ticari kullanım şartlarını ve (Play "AI-generated content" beyanı gerekiyorsa) beyanı kontrol et.

Tamamlanınca bu içerikten kök dizinde `CREDITS.md` üret ve oyun içinde bir "Emeği Geçenler" ekranından bağla.
