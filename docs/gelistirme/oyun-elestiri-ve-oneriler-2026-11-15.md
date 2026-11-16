# THE ROOM REMEMBERS — Eleştiri ve Öneriler (2026-11-15, v1.18.3 üstü)

Durum: Metin cilası yapıldı (aşağıda §1). §2–§6 **öneri**; onay gelmeden uygulanmaz.

## 1. Yapılan metin cilası (commit edilmedi)
- 44 dosya, ~110 satır: 10 diyalog JSON, 26 oda `.tscn`, 7 script.
- Düzeltilenler: anlamsız/yarım cümleler ("iz hâlâ ıslak", "Geçit gevşedi"), virgülle yapışık cümleler, komut gibi konuşan Noroi satırları, Shilda'nın faz tonuna uymayan satırlar, birebir tekrar eden satırlar (bahçe body_line ×5, eşik solved_line ×2, duvar kapı mesajı ×2).
- Mantık hatası: Aynalı Zemin açık ipucu "Şeritlerde dur" diyordu, oysa kırmızı şerit öldürüyor. Artık "Kırmızı şeritlere basma; tuşlar ters, atlayarak sağ uca var."
- Denetimler: lore_canon, dialogue_lint, dialogue_data, clue_solvability, phase2/3/4_rooms, door, room_header_fit, save_quit, fast_travel → **11/11 geçti, 0 FAIL**.

## 2. En büyük sorun: oyun süresi
- Ölçüm (playtime_measure): ana yol ~43 dk, yan odalarla ~52 dk. Hedef 3–3,5 saat. **Arada 2+ saat açık var.**
- Yürüyerek süre uzatmak çözüm değil. Önerilen kaynaklar:
  1. **Her bölüme 1 "derin bulmaca" odası** (6 oda × ~10 dk = +60 dk): birden çok mekaniği birleştiren, not toplayıp çözülen odalar (ör. yankı + ceset + ters kontrol aynı odada).
  2. **Geri dönüş (backtracking) anahtarları** (+20–30 dk): Ruh Kesimi / Gölge Atılması alındıktan sonra eski odalarda açılan kilitli köşeler; içlerinde Shilda'nın insanlık dönemine ait kayıtlar. Hızlı seyahat artık var, bu mantıklı.
  3. **Hikâye sahnelerini doldurmak** (+20 dk okuma): spec ~950 satır istiyor, şu an ~405. Eksik olan Shilda'nın Güven/Acı fazları.
  4. **Opsiyonel zorlu odalar** (+15–20 dk): her bölüme 1 "Yankı Sınavı" (zamanlı, ödül: defter sayfası / kostüm rengi).

## 3. Zayıf ve gereksiz odalar
| Oda | Sorun | Öneri |
|---|---|---|
| core (Çekirdek girişi) | Bulmaca yok, yalnız yürüme | Ya kaldır (eşik doğrudan bağlansın) ya kısa yankı-kapı bulmacası ekle |
| decay_vines | Metni yok, yalnız geçiş | Yaşayan sarmaşık: ceset düşünce sarmaşık geri çekilir, yol açılır |
| decay_cistern | Amaç belirsiz, yalnız diken satırı | Su seviyesi bulmacası: plaka suyu indirir, altında not |
| awakening_passage | Neredeyse geçiş | Halka kilidini 2 adıma çıkar ya da balkonla birleştir |
| library_page | Bulmaca metni görünmüyor | Kartlara başlık + kısa olay cümlesi; Kayıt B ile bağ kur |
| mirrors_reverse | Tek giriş satırı | Noroi'nin yön değişince 1–2 tepki satırı, zeminde ayna efekti |
| mirrors_unbroken | Shilda yüzleşmesi çok kısa | Yüzleşmeye 4–6 satır: Noroi soruyor, Shilda kaçamak cevap veriyor |
| experiment_cells | Yalnız kilit mesajı | Duvar çentikleri / hücre numarası ipucu, Denek 14 izi |
| library_reading_cell | Güven fazı satırı yok | "S." çentiği + kuru çiçek + 1 Shilda satırı |

## 4. Metin / hikâye eleştirisi
- **Güçlü:** 1927/1995 iki zaman çizgisi, Denek 14 = Noroi açılması, kasa ironisi, bahçede özür sahnesi.
- **Zayıf:** Shilda'nın fazları (Mesafeli → Merak → Güven → Acı → Ortak amaç) metinde sıçrıyor; Güven ve Acı arası neredeyse boş.
- **Şüpheli satırlar:**
  - experiment_quarantine "Sis canlıyı sever." Bulmacayla bağı belirsiz.
  - library_hall Kayıt B "Önce deney, sonra kapı." Raf sırasıyla bağı belirsiz.
  - İkisi bulmaca mantığına göre yeniden yazılmalı.
- **Testle kilitli tekrarlar:** Bu satırlar test tarafından birebir aranıyor; testler gevşetilirse çeşitlendirilebilir.
  - Mühür odası bağ hata satırı ×3.
  - Tapınak refusal_line ×3.
  - "Çıkış Yap" / "Oyundan Çık" ad farkı.

## 5. Ayarlar menüsü önerileri
Şu an: ses (tek döngü düğmesi), müzik aç/kapa, tam ekran, joystick modu, titreşim.
- Ayrı **Müzik** ve **Efekt** ses kaydırıcıları.
- **Metin hızı** (yavaş / normal / anında).
- **Ekran sarsıntısı** aç/kapa (erişilebilirlik).
- **Yazı boyutu** (normal / büyük): mobilde diyalog küçük.
- **İpucu seviyesi** (yok / yön / açık): PuzzleManager'da zaten 3 kademe var, oyuncu seçsin.
- **Dil** hazırlığı (TR/EN) — opsiyonel, ileride.

## 6. Oda güzelleştirme (görsel/ses, kısa liste)
- Uyanış: ıslak zemin dekalı, damla sesi, kristal yakınında ışık titremesi.
- Balkon: uzak şimşek, rüzgâr, dürbünde vinyet.
- Bahçe: taşta taç sayısı kadar ışık noktası; uyanışta yükselen ton.
- Kasa: sütunlarda yıl parıltısı, açılışta uzun yankı.
- Sera: gölgenin geçtiği saksıda toprak izi.
- Galeri: ceset sayacı, camda yüzler.
- 1927: saat durunca ses kesilsin, camın ardında X silüeti.
- Tapınak: gölge bir adım önden yürüsün.
- Labirent: kırmızı taş titremesi.
- Her bağ/kilit çözülüşünde farklı ses.

## Önerilen sıra
1. Ayarlar (§5): küçük, hızlı, oyuncu hemen fark eder.
2. Zayıf odalar (§3) + şüpheli satırlar.
3. Hikâye doldurma (Shilda Güven/Acı).
4. Derin bulmaca odaları ve geri dönüş anahtarları (süre hedefi). Büyük iş, ayrı spec ister.
