# Google Play Mağaza Listesi (TASLAK)

> TASLAK. Spoiler içermez (Shilda'nın kimliği, X ve final anlatılmaz). Yayından önce gözden geçir.
> Karakter sınırları: kısa açıklama ≤ 80, uzun açıklama ≤ 4000 (Play Console'da doğrula).

## Uygulama adı
THE ROOM REMEMBERS

## Kısa açıklama
TR: Sen unutursun. Oda hatırlar. Gotik bir yan görünüşlü gizem ve bulmaca oyunu.
EN: You forget. The room remembers. A gothic side-scrolling mystery puzzle game.

## Uzun açıklama (TR)
Bir odada uyanırsın. Adını bilmiyorsun. Duvarlar seni tanıyor.

THE ROOM REMEMBERS, ölümün hafızayı silip dünyayı değiştirdiği, yan görünüşlü ve hikâye odaklı bir gotik gizem-bulmaca oyunudur. Noroi'yi yönetirsin: her ölümden sonra kendi hatıralarını kaybeder, ama oda unutmaz. Cesetlerin, izlerin ve yankıların sana ne olduğunu anlatır.

• Ölüm bir ceza değil, bir araç: Geçmiş bedenlerin bulmacalarda kullanılabilir.
• Altı perdelik bir yolculuk, 40 oda: Uyanış mahzeninden hafıza çekirdeğine.
• Aksiyon ve bulmaca dengesi: 3'lü kılıç kombosu, dash, yetenekler, basınç plakaları, mühürler ve yankı şalterleri.
• Hikâye anlatan ortam: Notlar, kanıtlar ve sessiz anlar. Her şeyi sana söylemeyen bir dünya.
• Pixel art ve karanlık atmosfer.
• Mobil için tasarlandı: dokunmatik kontroller, kaydet ve çık, otomatik kayıt.
• İnternet gerekmez. Hesap yok, reklam yok.

Oyun, Bölüm I'in sonunda biter.

## Long description (EN)
You wake up in a room. You don't know your name. The walls do.

THE ROOM REMEMBERS is a story-driven gothic mystery-puzzle game in a side-scrolling view, where death erases memory but the world keeps changing. You play Noroi: after every death he loses his own memories, but the room does not forget. Corpses, traces and echoes tell you what happened.

• Death is a tool, not a punishment: your past bodies can solve puzzles.
• Six acts, 40 rooms: from the awakening crypt to the memory core.
• Balanced action and puzzles: three-hit sword combo, dash, abilities, pressure plates, seals and echo switches.
• Environmental storytelling: notes, evidence and quiet moments. A world that does not tell you everything.
• Pixel art and dark atmosphere.
• Made for mobile: touch controls, save and quit, autosave.
• No internet required. No accounts, no ads.

The game ends with the conclusion of Part I.

## Etiketler / kategori önerisi
Kategori: Oyun > Macera (veya Bulmaca). Etiketler: pixel art, gizem, platform, hikâye, korku (hafif), tek oyunculu.
İçerik derecelendirmesi: karanlık temalar, fantezi şiddeti (kılıç dövüşü), kan/ceset anlatımı var. Anketi dürüst doldur.

## Mağaza görselleri
- [x] Uygulama ikonu 512×512 PNG: `assets/icon/icon_512.png` (mevcut; boyut Console'da doğrulanmalı)
- [x] Öne çıkan görsel 1024×500: `docs/play/store/feature_graphic_1024x500.png` (taslak; `make_feature_graphic.py` ile üretilir, oyunun kendi arka planları + ikon gözü + Pixeloid Sans OFL yazı tipi; AI üretimi yok; sahibi gözden geçirmeli)
- [ ] En az 2, tercihen 4–8 telefon ekran görüntüsü (gerçek cihazdan, spoiler yok: Shilda'nın maskesiz hâli, X ve final karelerini kullanma). ADAY: `docs/play/store/screenshots/*_1920x1080.png` (masaüstü yakalaması, `scripts/dev/room_visual_capture.gd`); 3 aday kaldı (`mirrors_1927` "1927 gecesi" altyazısı lore sızıntısı riski nedeniyle çıkarıldı). Sınırlar: masaüstü klavye ipucu satırı ("WASD · Z saldır…") ve oda başlığı bandı görüntüde; alt ~%12 düz koyu bant. Bu yüzden yalnız taslak: gerçek telefon (dokunmatik HUD) görüntüsüyle değiştir
- [ ] İsteğe bağlı kısa tanıtım videosu (YouTube bağlantısı)

## Notlar
- "Güncelle" düğmesi ve GitHub bağlantısı Play sürümünde kapalı olmalı (`play_store` özel özelliği; bkz. `PLAY_BUILD_CHECKLIST.md`). Açıklamada GitHub APK'sından söz etme.
- "Hesap yok, reklam yok, internet gerekmez" ifadeleri yalnız Play sürümünde internet izni kapalıyken doğrudur. Önce izni kapat, sonra doğrula.
- Oyun süresini sağlam ölçümden önce açıklamada belirtme (QA: tahmini oynanış süresi hedefin altında, bkz. `qa/release-readiness/03_GAMEPLAY_PUZZLES.md`).
