# 05 — İnsan Oyun Testi Protokolü

Bu belge **bir test sonucu değildir**. Yapay zekâ insan testi yapamaz; aşağıdaki alanlar şimdilik **TEST EDİLMEDİ**. Cevap uydurulmaz; testçiler doldurur.

## Testçiler
- 5–8 ilk kez oynayan kişi (oyunu hiç görmemiş), en az 3'ü Android telefonda.
- 2 gotik/korku platform oyuncusu, 2 sıradan mobil oyuncu, 1 erişilebilirlik odaklı (renk körlüğü/küçük ekran).
- Play kapalı testi için ayrıca ≥12 kişi / 14 gün (hesap kuralı, bkz. 07).

## Oturum yapısı
1. 2 dk: ön anket (yaş grubu, tür deneyimi, cihaz, ekran boyutu). Oyun hakkında bilgi verilmez.
2. 60–90 dk: sessiz oynama. Gözlemci yönlendirmez; takıldığı yeri, süreyi ve sözlü tepkiyi not eder.
3. 10 dk: sonrası anket + kısa görüşme.

## Gözlemci kaydı (her oda)
Oda id · giriş saati · çıkış saati · ölüm sayısı · takılma (sn) · yanlış yön · ipucu aradı mı · UI karışıklığı · çökme/donma · ekran görüntüsü.

## Sorular (1–5 + serbest metin)
| Alan | Soru |
|---|---|
| Anlaşılırlık | Ne yapman gerektiğini ilk 5 dk içinde anladın mı? |
| Kontrol | Joystick/sıçrama/etkileşim tuşları rahat mıydı? Yanlış basma oldu mu? |
| Ölüm | Ölüm döngüsünü ve "unutma" fikrini anlattırabilir misin? Cezalandırıcı mıydı? |
| Hikâye | Noroi, Shilda, X kimdi? Neden oradaydılar? (açık uçlu, doğru cevap önceden yazılmaz) |
| Bulmaca | Takıldığın bulmaca? Çözümü sezgisel miydi, yoksa deneme-yanılma mı? |
| Tempo | Sıkıldığın bölüm? Çok hızlı geçtiğini düşündüğün bölüm? |
| Görsel/ses | Okunabilirlik, karanlık oda, ses seviyesi, titreşim. |
| Cihaz | Isınma, pil, takılma, uygulamayı arka plana atınca ne oldu? |
| Genel | Tekrar oynar mısın? Arkadaşına önerir misin? Hangi cümleyle? |

## Başarı ölçütleri (öneri, hedef değil kanıt)
- İlk oynamada ana yol tamamlama oranı ≥ %70.
- Aynı odada 3 dk'dan fazla takılma oranı < %15.
- "Ölüm/unutma" fikrini doğru anlatan oyuncu ≥ %70.
- Çökme/donma: 0.

## Cihaz ve ölçüm kontrol listesi (gözlemci + `adb`)
- `adb logcat -b crash` taraması; FPS (`dumpsys gfxinfo`); pil ve sıcaklık; RAM.
- Uygulamayı ölüm, possession ve kapı geçişi sırasında arka plana atıp geri getirme (BUG-001/002/033 şüphesi).
- Döndürme, çoklu dokunuş, ekran kilidi, çağrı kesintisi.

## Kayıt formu
`qa/release-readiness/playtest-results/<tarih>-<testci>.md` (şablon: yukarıdaki tablolar). Sonuçlar gelmeden 08'deki "İnsan testi" satırı **TEST EDİLMEDİ** kalır.
