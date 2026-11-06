# Prompt 06 — bütün oyun testi ve son kalite geçişi

Önce numaralı fazların gerçekten uygulandığını incele. Bu faz yeni içerik üretmek için değil, tamamlanan kapsamı doğrulamak ve eksikleri kapatmak için. 18 oda sahne dosyası olması oyunun tamamlandığını göstermez.

## Doğal oynanış rotaları

Yeni oyundan iki finale ayrı ayrı git. Hata ayıklama komutları, flags elle doldurma, teleport veya hazır çözüm çağırma kullanma. Böyle bir fixture gerekli teknik testte kullanılabilir ama ayrı raporlanmalı. Günlük ipuçlarını ilk defa görüyormuş gibi takip et; kod paneli ve kanıt sırası gerçekten oyuncunun erişebildiği bilgiyle çözülmeli.

En az bir rotada ölüm, yarım kalmış yankı, yanlış mühür, günlükte okuma, bölgeye geri dönüş ve uygulamayı kapatıp devam olsun. Bir rotada Shilda'yla erken anlaşmazlık ve barışma olsun. Koşul sağlanmıyorsa final erişimi anlaşılır olsun; oyuncu sessizce yanlış kapının önünde kalmasın.

İnsan testiyle toplam süreyi ve bölüm sürelerini ölç. Salt yürüme, zorunlu okuma, tekrar ve gerçek bulmaca çözme süresini ayır. Önceden konan 60–90 dakika hedefi otomatik başarı ölçütü değildir. İki dakikadan uzun olması için geçitleri uzatmak veya diyaloğu yavaşlatmak çözüm sayılmaz.

## Teknik ve UI kontrolleri

- Tüm odalarda aktif kamera, sınırlar, spawn, çıkışlar, parallax kapsamı, dekor/çarpışma uyumu.
- Ekrandan küçük oda, geniş oda, respawn ve oda geçişinde kamera sıçraması/boşluk/titreme.
- Hikâye, günlük, kod paneli ve finalde mantık donarken görsel animasyonların sürmesi.
- 2.450+ karakter metin, uzun konuşmacı, 30 kayıt, boş/dolu günlük, geri hareketi ve güvenli alan.
- İptal edilen konuşma/yankı/tuş takımı başka bulmacayı çözmüyor; tekrar açılabiliyor.
- Eski kayıt migration, yeni kayıt, iki süreç arasında devam, eksik/bozuk dosyada anlaşılır fallback. Gerçek oyuncu kaydını testte ezme.
- Üç ceset sınırı, odalar arası izler, kalıcı çözümler ve tekrar girilen odada duplicate nesneler.
- Final sonrası ana menü/son öncesi devam/yeni oyun akışında giriş veya EndingManager kilidi kalmaması.

Yeni auditler yalnız UiGate bool'larını okumakla kalmasın: gerçek tehlike/timer değerlerini ve frame_progress'i süre aralığında karşılaştır. Her test beklentisinin neyi doğruladığını yaz. Mevcut helper metni whitespace'i silerek karşılaştırıyor; bunu “kaynak metin birebir korunuyor” diye sunma. Türkçe harf, noktalama, paragraf ve uzun kelime sınırlarını ayrıca test et.

## Android ve sunum

Gerçek telefonda joystick ile eylem düğmelerini birlikte kullan; parmak bırakma, ekran dışına sürükleme, uygulamadan çıkıp dönme, geri hareketi ve farklı oranları dene. Dokunmatik callback'i doğrudan çağırmak OS olay akışı testi değildir. Cihaz yoksa cihaz testi yapılmadığını açıkça yaz.

Hedef cihazda kare süresi, bellek, geçiş süresi ve çizim yükünü ölç; kanıtsız 60 FPS iddiası yapma. Görsel küçültme/efekt azaltma gerekiyorsa atmosferi koruyan seçenekler ekle. Lisansı belli gerçek sesler varsa müzik/efekt/sessize alma ayarı ve kayıtlanan ses seviyesi kur. Asset eklenmemişse boş AudioStreamPlayer'a ses sistemi tamamlandı deme.

Başlangıç/ara/final durumlarını gösteren gerçek ekran görüntüleri ve kısa oynanış videosu al. Dekorların oyuncuyu boğduğu, kapıların arka plana karıştığı, ışığın yazıyı kapattığı sahneleri düzelt. UI ve menülere geliştirme jargonu koyma.

## Teslim

Uygulanan kapsam, gerçek test sonuçları, kalan hatalar, eksik sanat/ses, süre ölçümü ve varsa güncel APK'yı sun. APK üretimi ve fiziksel cihazda oynanış ayrı maddeler olsun. Proje çalıştırma adımlarını ve kayıt geçişini belgele. Tamamlanmayan fazları dürüstçe işaretle; bütün özelliklerin adı kodda geçiyor diye oyunu bitmiş ilan etme.
