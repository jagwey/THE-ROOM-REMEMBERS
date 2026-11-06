# Prompt 2 — altı odalık ilk oynanabilir bölüm

---

The Room Remembers Godot 4 projesini mevcut kod üzerinden genişlet. Önce kayıt, ceset-plaka fiziği, aktif oda kökü, modal giriş ve dokunmatik final sorunlarının giderildiğini gerçek davranışlarla doğrula. Eksikler varsa önce onları çöz. Kullanıcının değişikliklerini koru. Sadece tasarım belgesi üretme: aşağıdaki altı odayı, geçişleri, bulmacaları, kısa Türkçe metinleri, kayıtlarını ve testlerini projeye uygula.

**Hedef:** ilk kez oynayan biri için 15–25 dakikalık anlamlı bölüm. Bu ölçülene kadar bir tasarım hedefidir. Hikâyeyi uzatan konuşmalar, çok yavaş yürüme, aynı işi tekrar eden zorunlu ölümler ve bekleme süreleri ekleme. Hareket mevcut yatay yürüme/dash/etkileşim düzenine dayansın. Zıplama henüz yok; zorunlu rota zıplama gerektirmesin. Ek hareket istiyorsan önce somut faydasını değerlendir, yeni mobil tuş yükünü kontrol et.

## Ana döngü

Gözlemle → güvenli bir deneme yap → dünya tepkisini fark et → bir ipucu öğren → yeni bağlamda uygula → kısa yol aç. Ölüm bu döngünün olası parçasıdır; her kapı için intihar zorunluluğu olmasın. Ceset kullanılabilen yerde dünya hatırası taşı gibi ölüm gerektirmeyen, ulaşılabilir bir alternatif de tasarla. Cesetle çözüm daha farklı bir hikâye/kolaylık sunabilir.

## Odalar ve görevler

### A01 — Uyanış / “Bir şey yer değiştirmiş”

Yaklaşık 1–2 dakika. Oyuncu güvenli biçimde yürür, dash yapar ve tek bir nesneyle etkileşir. Bekçi uzakta belirir. Zeminde eski bir çiçek ve aynı şeklin duvarda gölgesi bulunur. Yeni oyuncuya tüm terimleri açıklama. Çıkış ilk kez incelendiğinde “Kapı açılmıyor” yerine eksik unsurun görsel izini göster. İsteğe bağlı günlük: “Uyandığım yerde benden önce biri vardı.” İlk kontrol öğretimi tek satırlık, kaybolabilir ve Türkçe olsun.

### A02 — Eşik / “Dünya unutmaz”

Yaklaşık 2–3 dakika. Tek bir kırmızı yarık uyarılır ve risk görsel olarak okunur. Güvenli kol çevresinden geçmeye izin verir; riskli kısa yol ceset mekaniğini öğretebilir. Ölürse çiçekli ceset kalır, Bekçi yas tutar; ölmezse eski bir dünya hatırası taşı aynı ağırlık işlevini gösterir. Bir plaka ve yakındaki kapı ilk neden-sonuç örneğidir. Çözüldükten sonra kapı kalıcı kilitlensin; sonradan ceset silinse de kapanmasın. Oyuncu cesedi kapı ötesine itip yolu kapatırsa “hatırayı son güvenli konuma çağır” işlemiyle kurtulabilsin.

### A03 — Hatıra Mührü / “Sen biliyorsun, o bilmiyor”

Yaklaşık 2–3 dakika. Duvar dizisinde üç simge, kısa yankıda bunların sırasını belirleyen bir olay olsun. Oyuncu üç simgeli panelde kendisi seçim yapsın. Günlük ipucunu saklasın, cevabı otomatik girip kapıyı açmasın. Yanlış cevap kısa bir görsel tepki versin. İki başarısız denemeden sonra isteğe bağlı ikinci ipucu açılsın; cevabı zorunlu olarak söylemesin. Çözüm Uyanış mührünü kazandırsın ve güvenli odaya bir kısa yol açsın. İlk bölgenin bitişi tam oyunun finali olmasın.

### D01 — Çürüme Girişi / “Aynı koridor değil”

Yaklaşık 2–3 dakika. Duvardaki çatlak görünür bir olaydan sonra genişler; arka plan rastgele değişmez. Bir kol iki yoldan birini açar. Oyuncu ilk yolu inceleyip geri geldiğinde küçük bir çevre izi farklılaşır. Bu değişim haritayı anlaşılmaz kılmasın: sabit bir kırmızı çiçek referans noktası olsun. İki küçük oda arasındaki ilk geri dönüş burada anlam kazansın. Bölge geçiş checkpoint'i kaydedilsin.

### D02 — Solan Geçit / “İzin gölgesi”

Yaklaşık 3–4 dakika. Güvenli odada denenen bir baskı plakası/hatıra kopyası kombinasyonu kullan. Aynı plaka bulmacasını tekrar etme: bu kez mekanizma, nesnenin bırakıldığı son güvenli yeri hatırlar ve oyuncu başka odaya gittiğinde kısa süreli bir silüet ağırlığı üretir. Durum açık bir kırmızı hat üzerinden anlaşılır. Çözüm yalnız hassas zamanlama gerektirmesin. İlk tehdit olarak tek bir yavaş gölge döngüsü eklenebilir: ön uyarı → geçişi kapatma → toparlanma. Vurmak kısa süre dağıtır, dash ile kaçmak veya dikkatini nesneyle çekmek de mümkündür. Dövüş zorunlu değildir. Tehdit oyuncu okurken vurmasın.

### D03 — Çürümüş Bahçe / “Bekçi bir şeyi koruyor”

Yaklaşık 3–4 dakika. Daha önce görülen ağırlık ve iz kuralları birlikte kullanılır. Üç anahtar aratmak yerine iki bağlantılı karar kur: bir hatıra kapıyı açık tutar, diğeri çürüyen yolu güvenli hâle getirir. Bekçi önce engeller; koruduğu çiçeği fark eden oyuncu onun salt düşman olmadığını anlar. Çürüme mührü kazanılır ve Uyanış'a kısa yol açılır. Sonunda “Bölüm tamamlandı — Kütüphane yolu açılıyor” ekranı kullan; sahte iyi/kötü final gösterme. Henüz yapılmamış Kütüphane oynanabilir gibi sunulmasın.

Ana odaların etkileşim hedefleri yaklaşık 13–19 dakika eder; ilk keşif, geçişler ve 2–3 küçük isteğe bağlı gözlemle hedef 15–25 dakikadır. Bu hesabı garanti gibi yazma; ölçümler kısa çıkarsa yeni karar içeren içerik ekle.

## Uygulama kuralları

- Her odaya sabit ID: A01, A02, A03, D01, D02, D03. Nesnelere oda+yerel ID ver. Aynı puzzle_id veya tek bir awakening kapı bayrağını bütün bulmacalarda kullanma.
- RoomDirector aktif odayı, checkpoint'i, kamera sınırını ve ceset kökünü yönetsin. Aktif olmayan odalar etkileşim almasın. Kapı koşulları veriden okunabilsin.
- Her odada güvenli giriş, ana etkileşim, anlaşılır çıkış hedefi ve en az bir ayırt edici görüntü olsun. Bir büyük arka planı farklı adla yüklemek yeni oda sayılmaz.
- Ceset sınırı üç kalabilir. Kritik bulmaca çözümü kalıcı state olarak kaydedilsin; global trim yeni bir ilerleme engeli yaratmasın. Hatırayı geri çağırmak önceki hikâye bilgisini silmesin.
- Lanet zamanla otomatik yükselmesin; oyuncunun anlaşılır risklerine bağlı olsun. İlk denemelerde görünmeyen bedellerle cezalandırma. Kırmızı tonu her nesnede tehlike anlamına gelmesin; mühür/tehlike/etkileşim biçimlerini de ayır.
- Günlük kısa: “gördüğüm”, “çıkardığım”, “emin olmadığım”. Oyuncuya gösterilen iddia ile dünyanın gerçeğini ayır.
- Beyaz saç, açık atkı/pelerin, kırmızı mühür; siyah Bekçi ve kırmızı halo tasarımını koru. Mevcut assets klasörünü incele. Gerekli olmayan yeni görsel üretme; eksik görselleri belgeli geçici nesnelerle işaretle.
- Harita tamamlanmamışsa menüde tamamlanmış bölüm sayısı doğru görünsün. Telemetri yerel dosyada olsun; hesap, ağ hizmeti veya ücretli araç ekleme.

## Kabul

Altı oda yeni oyundan sırayla oynanmalı; her bulmaca gerçek etkileşimle çözülebilmeli. Kaydedip kapatma sonrası aynı noktadan devam edilebilmeli. Ölmeden alternatif rota çalışmalı. Ölüm/üç ceset/dördüncü ceset/odalar arası geri dönüş kritik kapıları bozmasın. Bekçi'ye erken saldırmak oyunu bitirmesin; kısa tepki ve ilişki sonucu üretsin. Bölüm bitişine ana hedefler yapılmadan erişilemesin.

En az üç ilk kez oynayan kişiyle süre, ipucu kullanımı, kaybolunan yer ve gereksiz tekrar sayısını ölçmek için hazır form oluştur. İnsanlar erişilebilir değilse sonuç uydurma; yalnız otomatik rota ve içerik ölçülerini raporla. Değişen dosyaları ve çalıştırılan testleri teslim et.
