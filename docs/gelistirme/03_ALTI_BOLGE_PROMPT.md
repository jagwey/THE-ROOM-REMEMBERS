# Prompt 3 — altı bölge, 17 oda, birbirini geliştiren kurallar

---

The Room Remembers'ın test edilmiş ilk altı odasını temel al. Godot 4 Android, yan görünüş, piksel sanat. Karakter unutur; oyuncunun bilgisi ve dünya izleri kalır. Mevcut depoyu incele, kullanıcı değişikliklerini koru. İlk bölümün kayıt ve fizik sorunları çözülmeden tüm dünyayı ekleme. Bu talimatı bölge bölge uygulayıp her bölgeyi oynanabilir teslim et.

**Tam sürüm tasarım hedefi:** ilk oynayışta yaklaşık 60–90 dakika. Ana rota 58–72 dakika bandında, isteğe bağlı keşif 8–15 dakika hedeflenebilir. Bunlar tasarım tahminidir; ölçüm yapılmadan gerçekleşmiş süre diye sunma. Deneyimli oyuncu daha hızlı bitirebilir. İyi bir kısa oyun, süre dolduran uzun oyundan değerlidir.

## Dünya düzeni

Sıra: Uyanış A01–A03 → Çürüme D01–D03 → Hafıza Kütüphanesi L01–L03 → Deney Alanı E01–E03 → Ayna Salonu M01–M03 → Çekirdek C01–C02. Toplam 17 ana oda. Uyanış/Çürüme tamamlandıktan sonra Kütüphane'de merkezi bir geçit aç: önceki iki bölgeye kısa yollar bağlansın. Bu geçit yeni bir oda sayılmasın. Tamamlanmış puzzle'ları tekrar çözmek zorunlu olmasın.

Her bölge bir hatıra parçası kazandırsın: Uyanış işaret, Çürüme iz, Kütüphane isim, Deney tanıklık, Ayna seçim. Çekirdek bunları birleştirir. İlk iki bölümün mührü, oyunun yalnız başlangıcıdır; bunlarla final açılmasın. Çekirdek erişim koşulları kalıcı tamamlama kaydıyla açıkça doğrulansın.

### 1. Uyanış — 3 oda, hedef 6–8 dakika

Tema: soğuk taş, yatak/masa izi, sessizlik. Soru: “Ben daha önce burada mıydım?” Kural: ölüm dünya üzerinde fiziksel bir iz bırakır; bazı kapılar bu izi hatırlar. İlk ağırlık ve üç sembol sırası burada öğrenilir. A01 güvenli öğretim, A02 neden-sonuç ve alternatif ağırlık, A03 gerçek sembol paneli. Bekçi'nin uyarısı ilk bakışta tehdit gibi görünür. Ödül: işaret parçası ve Çürüme kapısı.

### 2. Çürüme — 3 oda, hedef 10–12 dakika

Tema: kırılmış kemerler, kırmızı kökler, genişleyen çatlaklar. Soru: “Oda ölümlerimi mi, seçimlerimi mi hatırlıyor?” Kural: bir nesnenin önceki yeri kullanılabilir bir silüet izi oluşturabilir. Aynı cesedi üç plakaya sürüklemek yerine yer ve iz arasında seçim kur.

D01 değişmiş yol ve sabit görsel referans; D02 kısa süreli iz ağırlığı ve isteğe bağlı ilk gölge tehdidi; D03 iki sistemi birleştiren bahçe. Ödül: iz parçası, Uyanış kısa yolu. Ölüm sayısına göre dekor değişebilir; ana rota rastgele kaybolmasın. Bekçi burada bir çiçeğin zarar görmesini önler. Oyuncu onun kendisini değil dünyadaki bir hatırayı koruduğunu görür.

### 3. Hafıza Kütüphanesi — 3 oda, hedef 12–15 dakika

Tema: dev raflar, düşen sayfalar, durmuş saatler; daha az kırmızı, daha çok soluk lila. Soru: “Hatırladığım şey doğru mu?” Kural: aynı olayın farklı tanıklarını karşılaştırmak gerekir. Günlük cevap listesi yerine kanıt defteri olur.

L01 **Kayıp Katalog:** üç kitaplık nesneden ikisi aynı olayı farklı anlatır. Kısa metinler ve görsel işaretler kullan; uzun kitap okumak zorunlu olmasın. NPC “Sayfa Taşıyan”, isimlerin bir bölümünü unutmuştur. Oyuncu konuşmayı atlayabilir, görsel ipuçlarıyla ilerleyebilir.

L02 **Saat Rafı:** üç saat “önce/sonra” ilişkisiyle sıralanır. Tam saat aramak yerine olaydaki üç eylemin sırasını seç: çiçeğin bırakılması, kapının kapanması, mührün yanması. Yanlış dizilim rafı tehlikeli biçimde ezmesin; kısa gölge tepki versin. Başarı bir sonraki odaya geçiş ve önceki tanığın çelişkisini açar.

L03 **Yasak İsim:** iki kanıtı aynı panelde karşılaştır. NPC'ye inanmak, Bekçi'nin izini takip etmek veya ek bir yan nişi incelemek seçenekleri olsun. Ana cevap tesadüfi diyalog seçimiyle kilitlenmesin. Ödül: isim parçası; Bekçi ilk kez karakterin eski adını söylemeye yaklaşır. Bölge sonunda hub kısa yolları açılır.

### 4. Deney Alanı — 3 oda, hedef 12–15 dakika

Tema: metal sedyeler, kırmızı kristal devreleri, deney odaları. Soru: “Bu döngü kimin kararıydı?” Kural: fiziksel ağırlık yanında kaydedilmiş bir hareket izi ikinci devreyi çalıştırır. Yankı burada ilk kez kısa, oynanışa etki eden bir tekrar olur; önceki EchoManager metin kataloğu tek başına bunu sağlamaz.

E01 **Kayıt Hücresi:** güvenli alanda 3–5 saniyelik yatay hareketi kaydet ve hayalet olarak bir kez oynat. Başlangıç/bitiş işaretleri açık olsun. Gerekirse yalnız yürüyüş ve etkileşim kaydet; saldırı/dash tekrarını başlangıç kapsamına alma. Nesneye işlenmiş kayıt kapasitesi anlaşılır görünsün.

E02 **Çift Devre:** hayalet bir sensörü çalıştırırken oyuncu başka bir kolu kullanır. Ceset veya dünya taşı sabit ağırlık görevi görür. Hassas milisaniye eşleştirmesi isteme; sensörün makul bekleme payı olsun. Yeniden kaydetmek ücretsiz ve hızlı olsun. Ayrı bir mekanik için yeni mobil tuş yerine bağlama göre Etkileş kullan.

E03 **Tanığın Odası:** bir deneyin yankısı ile duvardaki rapor çelişir. Oyuncu mekanizmayı çalıştırırken sonuçlarından birini korur veya serbest bırakır. Bu bir yanlış seçince oyunun bittiği test değildir; dünya/NPC tepkisini ve sonraki final bağlamını değiştirir. Ödül: tanıklık parçası. Çatışma: karakterin döngü kurulurken sorumluluğu olduğuna dair ilk somut kanıt.

### 5. Ayna Salonu — 3 oda, hedef 10–12 dakika

Tema: uzun aynalar, kırılmış yansımalar, siyah boşluk. Soru: “Kendim hakkında hangi hikâyeyi seçiyorum?” Kural: iki görünüş aynı dünyayı farklı gösterir. Oyuncuya kontrol etmeden görünmez duvarla çarpma cezası verme.

M01 **Ters Koridor:** gerçek ve yansıma katmanında aynı kapının farklı açıklıkları görünür. Aktif katman ekran kenarı/desenle belirtilsin. Karakterin konumu katman geçişinde güvenli noktaya doğrulansın. Baştan tüm kontrolleri tersine çevirme; gerekiyorsa yalnız yansıma nesnesi karşı yönde hareket etsin ve güvenli alanda öğret.

M02 **Yanlış Hatıra:** iki kısa rota farklı ayrıntılar gösterir; üçüncü ipucu önceki günlük kanıtıyla çelişkiyi çözer. Her seferinde bütün odayı dolaşmak gerekmesin. NPC “Yansıma”, karakterin kelimelerini tekrar ederken küçük bir fark bırakır. Kısa ipucu ve çevre kompozisyonuyla hikâye anlat.

M03 **Kararın Aynası:** tanıklık, isim ve Bekçi davranışından çıkarılan sonuçla bir mühür seçilir. Seçim güvende yapılır; döngü sonu yaklaşırken etkisi açıkça anlaşılır. Ödül: seçim parçası ve Çekirdek erişimi. Erken saldırı sayısı tek başına burada finali belirlemesin; oyuncunun ilişkiyi onarma imkânı olsun.

### 6. Çekirdek — 2 oda, hedef 8–10 dakika

Tema: siyah boşluk, kırmızı çekirdek, bir araya gelen motifler. Soru: “Hatırlamak sürdürmek mi, bırakmak mı?” C01 **Birleşme:** önceki kurallardan ikisini birleştir: hayalet zamanlaması + kalıcı iz; ya da ayna bilgisi + fiziksel ağırlık. Beş küçük anahtar yuvasına eşya koydurmak yerine oyuncunun öğrendiğini sınayan iki bağlantılı adım kur. Bölge parçaları eksikse eksik bölge adı ve geri dönüş yolu göster.

C02 **Son Mühür:** iki aşamalı kısa olay. Önce dünya bozulurken okunabilir güvenli konumları seç; sonra Bekçi ile güvene dayalı eşzamanlı mühür veya bilinçli ayrılma yolu. Kötü yolun da oynanış sınavı olsun; üç vuruşla tüm içerik atlanmasın. İki yol benzer içerik ağırlığı taşısın. Final seçimi bir kez ve açıkça onaylanır; kazara dokunma sonu belirlemez. Sonuçlar önceki kanıtlara bağlansın.

## Üretim sınırları

En fazla iki normal tehdit ailesi kullan: yavaş devriye gölgesi ve uyarı vererek alanı kapatan sabit yankı. NPC'ler ve Bekçi bunlardan ayrı davranış taşır. Sırf süre uzatmak için düşman dalgaları, rastgele ganimet, yetenek ağacı veya üretim sistemi ekleme. Dövüş varsa kaçınma/çevre çözümü alternatifleri olsun. Can, dash aralığı ve temas hasarı görünür kurallarla dengelensin.

Her bölge için gerekli görsel, animasyon, VFX ve ses listesini mevcut dosyalarla eşleştir. Üç parallax katmanı bulunan görsel, otomatik olarak oynanış collision'ı veya platform değildir. TileSet/çarpışma ve dekor ayrı kurulmalı. Yeni sanat geçici ise açıkça belirt. Aynı palette kal; kırmızı vurguyu görsel gürültüye dönüştürme.

Hikâye ve ses için kısa sessizlikler kullan ama bu süreleri zorunlu bekleme olarak sayma. Müzik ve ses kaynakları gerçekten atanmış olsun; boş AudioStreamPlayer düğümlerine “ses tamam” deme.

## Tamamlanma koşulları

17 odanın erişim grafiği, sabit ID'leri, checkpoint'leri, dönüşleri ve kayıt durumları belgelenmeli. Her bölgede yeni bir kural, o kuralı güvenle deneme alanı, önceki kuralla birleşen uygulama ve somut dünya sonucu bulunmalı. Hiçbir kritik kapı tek bir silinebilen cesede sonsuza kadar bağımlı kalmamalı. Bir bölgeyi test etmeden diğerine geçme. Ana yol ve iki final, debug bayrağı olmadan tamamlanmalı. İnsan testinde süre hedefi tutmuyorsa bunu belirt; yürüyüşü yavaşlatarak veya metinleri uzatarak sayıyı düzeltme.
