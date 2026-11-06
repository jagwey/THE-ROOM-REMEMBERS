# The Room Remembers — temel sorunları düzeltme promptu

Bu dosyanın tamamını geliştirmeyi yapacak asistana ver. İnceleme tarihi: 6 Kasım 2026. Bu bir uygulama talimatıdır; aşağıdaki değişiklikler bu incelemede oyuna uygulanmadı.

---

Godot 4 Android, yandan görünümlü 2D pixel art projem **The Room Remembers** üzerinde çalış. Önce temel arayüz ve oynanış hatalarını düzelt; yeni bölge, düşman, uzun diyalog veya içerik ekleme. Sorunları gizlemek için yazıyı küçültme, içeriği kesme, görselleri bozarak esnetme veya testleri otomatik başarılı sayma. Mevcut kodu okuyup değişiklikleri gerçekten uygula, çalıştır ve kanıtları teslim et.

## 1. Projeyi tanı ve başlangıcı kaydet

- Doğru proje klasörünü ve varsa AGENTS.md talimatlarını kontrol et. İncelenen proje `THE-ROOM-REMEMBERS`, oyun sürümü 0.8.0, yerel motor 4.7.2, temel çizim alanı 640×360. Sürüm değişmişse önce bu bulguları yeniden doğrula.
- `scripts/ui/hud_controller.gd`, `journal_ui.gd`, `curse_vfx.gd`, `ending_ui.gd`; bunların sahneleri; `player_controller.gd`; MobileInput, Dialogue, Death, Save, Corpse, Puzzle, Echo ve Ending yöneticilerini oku. `docs/gelistirme/INCELEME_TEST_RAPORU.md` ile bu klasördeki `UI_SORUN_ANALIZI.md` ve `ui_audit.json` dosyalarını incele.
- Kullanıcının mevcut değişikliklerini koru. Kayıt dosyasını test ederken gerçek oyuncu kaydını ezme. Testleri farklı uygulama adı/veri klasörüyle çalıştır.
- Açılış, Bekçi diyaloğu, uzun diyalog, boş/dolu günlük, final için mevcut ekran görüntülerini al. Önceki testlerin yalnızca headless çalıştığını unutma; bunlar görüntü ve gerçek telefon kanıtı değildir.

## 2. Görselin sınırı ile Control sınırını eşleştir

Ana hata yalnızca Label konumu değil. `assets/panels/dialogue.png` ve `journal.png` 320×180 dosyalar; ana panel küçük bir bölgede, çevresinde şeffaf alan ve altta ayrı bir süs var. Bütün PNG'yi panele vermek yazıyı görünür çerçeveden koparıyor ve ikinci süsü ekrana taşıyor.

- Orijinal görselleri koru. İlk aday kaynak bölgeler: diyalog `Rect2(62, 3, 195, 112)`, günlük `Rect2(64, 3, 191, 126)`. Bunlar alpha>8 bağlı bileşen ölçüleridir; yumuşak kenarlar için görsel kontrol yap, gerekiyorsa 1–2 piksel pay ekle. Çerçevenin gerekli bölümünü kesme.
- Sadece PNG'nin tüm alpha kutusunu almak çözüm değildir; alttaki istenmeyen süs de o kutuya dahildir. Ana bileşeni seç. `AtlasTexture.region`, uygun `NinePatchRect.region_rect` veya türetilmiş temiz PNG kullan; kaynak dosyayla ilişkisini belgele.
- Çerçeve ve okunacak alan aynı yerleşim köküne bağlı olsun. Content padding'i `MarginContainer`/StyleBox içerik paylarıyla kur. NinePatch patch margin'lerinin çocuk yazıyı kendiliğinden içeri aldığını varsayma.
- Ortadaki kırmızı halo, köşe süsleri ve kitap cildi esnetilerek bozulmasın. Gerekirse sabit oranlı süs katmanı ile ölçeklenen arka yüzeyi ayır. Günlük kitabını normal bir dikdörtgen panel gibi 9 parçayla gelişi güzel esnetme.
- Dünya ve sprite'ların piksel filtrelemesini koru. UI'da Türkçe glifleri eksiksiz, okunaklı bir font kullan; font boyutunu küçülterek taşmayı saklama.

## 3. Diyalog yerleşimini yeniden kur

Mevcut diyalog `(64,236,512,104)`; joystick ve sağ eylem düğmeleriyle aynı bölgede. 1.248 karakterlik test metni Label yüksekliğini 297 piksele çıkarıyor, alt sınırı 567 oluyor; ekran yalnızca 360 piksel.

- HUD, diyalog ve modal katmanlarının sorumluluklarını ayır. Çerçeve, konuşmacı, gövde ve devam göstergesi ortak bir Container düzeninde yerleşsin. Çocukların rastgele sabit offset'lerini ana düzen yöntemi yapma.
- Mobil alt kontrol alanını açıkça ayır. Diyalog aktifken hangi kontrollerin gerektiğine karar ver: hikâye konuşmasında hareket/saldırı/dash kapanmalı; dokunmatik devam erişilebilir kalmalı. Savaş sırasında çıkan kısa ortam sözleri bu modal konuşmayla aynı davranışı paylaşmamalı.
- Diyaloğu kontrol alanından uzak bir üst/orta bölgede tasarla veya modal konuşma sırasında çakışan kontrolleri kaldır. 640×360 için örneğin x=16..624, y=76..200 başlangıç denemesi olabilir; bunu körü körüne sabitleme, karakter/Bekçi ve üst HUD ile görüntüde değerlendir.
- Metni gerçek font, genişlik ve kullanılabilir yüksekliğe göre sayfalara böl. Her sayfa çerçevenin iç bölgesine sığsın; uzun sözcükleri, satır sonlarını ve Türkçe karakterleri ele al. En fazla birkaç satır okunabilir metin göster; kalan içerik devam sayfasında eksiksiz bulunsun.
- Clip özelliği son güvenlik sınırı olabilir; görünmeyen metni kaybettiren ana çözüm olamaz. Tam metin ile sayfalardan yeniden birleştirilen metnin eşitliğini test et.
- Yazı adım adım çıkıyorsa ilk basış mevcut sayfayı tamamlasın, sonraki basış ilerletsin. Tek fiziksel dokunuş iki sayfa atlatmasın. Son sayfada doğru konuşma tamamlanma olayı bir kez çıksın.
- Uzun konuşmacı adı için de yer ayır; gövdenin üzerine büyümesin. Mevcut 40 karakterlik örnek testi geçti; bunu var olan bir hata diye sunma, sınır testi olarak ekle.
- Konuşma kimliği/nesli kullan. Eski gecikmiş callback, iptal edilmiş veya yeni açılmış konuşmayı ilerletemesin. Headless otomatik ilerlemeyi yalnızca açık bir test modu etkinleştirsin; gerçek giriş testinde kapalı olsun.

## 4. Günlüğü gerçek kitap sayfasına yerleştir

Mevcut görünür kitap yaklaşık x=200..439, y=51..209; başlık x=144'te başlıyor, gövde sayfanın soluna ve altına taşıyor. Gövdeyle Kapat düğmesinin alanları 80×10 piksel kesişiyor.

- Temiz kitap görselini merkezde ve oranını koruyarak yerleştir. İç metin alanını dış PNG sınırından değil, gerçek açık kâğıt sınırından türet. Köşeler, cilt, orta dikiş ve ayraç üstüne yazı koyma.
- Tek okunabilir sayfa alanı veya iki ayrı sayfa alanı seç; metni dikişin üzerinden kontrolsüz geçirme. Dar ekranda kullanılabilir alan azalıyorsa daha sade bir içerik düzenine geç, fontu minikleştirme.
- Başlık ve sekmeler ya kitap içindeki ayrılmış alanda ya da kitapla açıkça hizalı ayrı araç çubuğunda olsun. Rastgele kitap dışına taşmasın.
- İçeriği esneyen gövde ve sabit alt araç satırı olarak ayır. Kapat düğmesi gövdenin üstüne gelmesin; kaydırma alanı o düğmenin önünde bitsin.
- Uzun notlar için var olan kaydırmayı koru; parmakla dikey kaydırmayı gerçekten dene. Sekme değişince kaydırmanın sıfırlanması/korunması davranışını açıkça belirle. Boş sayfa mesajını ortalanmış, kısa ve okunabilir göster.
- Açık kâğıtta koyu mürekkep rengi kullan; mevcut soluk mor yazının kontrastını iyileştir. Odak, seçili sekme ve basılı düğme belirgin olsun.
- Günlük açılınca oyun hareketi/saldırısı/dash'i ve arkadaki diyaloğu ilerleten girişleri kilitle. Aktif joystick parmağını, basılı eylemleri ve kalan hareket vektörünü sıfırla. Kapanınca eski basılı durum kendiliğinden geri gelmesin.
- Okuma sırasında tehlikeler ve lanet zamanı oyuncuyu cezalandırmasın. Dünyayı durduracaksan UI'nin işlemeye devam ettiği process_mode düzenini kur; yalnızca oyuncu girişini durduracaksan hasar/timer tarafını da açıkça ele al. Modal kilit ile dünya zamanının durmasını birbirine karıştırma.
- Ekrandaki Kapat, klavye ve Android geri hareketi tutarlı şekilde en üst modalı kapatsın. Günlük açıkken alttaki Etkileş düğmesi bir konuşmayı ilerletmesin.

## 5. Giriş sahipliği ve diyalog iptali

- Tek bir açık arayüz durumu/öncelik düzeni kur: final > günlük/modal > hikâye diyaloğu > normal oyun. Ölüm ve oda geçişinin kilitleri de bununla tutarlı olsun. İç içe durumlarda bir panel kapanınca başka panelin kilidini yanlışlıkla bırakma.
- Yalnızca üstte şeffaf karartma Control koymak yeterli değildir. HUD `_input` ve MobileInput eylem sinyalleri de modal duruma saygı duysun. Arayüz dokunuşu dünyaya geçmesin.
- `DialogueManager.clear()` şu anda yöneticiyi kapatıyor ama HUD görünür kalıyor. Açılış/kapanış/iptal yaşam döngüsünü düzelt; kuyruk ve panel her zaman aynı durumda olsun.
- **İptali normal tamamlanma olarak yayınlama.** Mevcut tamamlanma sinyallerini bulmacalar ve güven konuşmaları dinliyor olabilir. Sırf paneli gizlemek için aynı sinyali yaymak bulmacayı çözebilir. Gerekirse completed/cancelled sonucu taşıyan tek bitiş olayı veya ayrı iptal olayı kullan; tüm tüketicileri güncelle. Her konuşma tam bir sonuca bir kez ulaşsın.
- Telefon odağı kaybı, uygulama arka plana gitmesi, ölüm, oda değişimi, menü açılması ve dokunuş iptalinde tutulan girişleri bırak. Joystick parmağı ve düğme parmakları birbirinin sahipliğini almasın.
- TouchScreenButton çoklu dokunmayı destekler fakat Node2D olduğundan Control anchor'ları yoktur. Mevcut Button'ları gelişigüzel bununla değiştirip responsive düzeni bozma; uygun yerleşim kökü veya olay takibiyle çöz. Fareden üretilen dokunuş ile dokunuştan üretilen fare olayını çift eyleme dönüştürme.

## 6. Güvenli ekran alanı ve farklı oranlar

- 640×360 temel düzeni koruyabilirsin. `keep` nedeniyle farklı ekran oranlarında oluşan siyah bantlar tek başına hata değildir; dünyayı eğip bükerek kaldırma.
- DisplayServer güvenli alanı, pencere alanı ve oyunun çizildiği içerik alanının koordinat sistemlerini ayır. Çentik bilgisini gerçek içerik dikdörtgeniyle kesiştirip UI koordinatlarına çevir. Masaüstü/pencereli/headless ortamda boş veya anlamsız güvenli alan için tam içerik alanına dönüş yap.
- Ekran çözünürlüğünü körlemesine 640/360 ile çarpmak yeterli değildir; varsa bantları ve koordinat başlangıcını hesaba kat. Zaten viewport koordinatlarında gelen dokunma olayını tekrar ekran ölçeğiyle çarpma. Her dönüşümü tek bir yerde tanımla ve ölçerek test et.
- Sağ ve alt düğmeler SafeArea'nın kenarlarına anchor/container ile bağlı olsun. Parent küçülünce sabit offset'lerle eski konumda kalmasın. L16/T8/R48/B12 sanal inset testinde tüm kontroller güvenli alan içinde kalmalı.
- Joystick'in görünür alanı ile kabul ettiği dokunuş alanını bilinçli eşleştir. Mevcut 42×2,2 piksel kabul yarıçapını, 40 piksel civarındaki görsel yarıçapla karşılaştır; görünmez alan günlük veya diyalog dokunuşunu çalmasın. Erişilebilir dokunma payını ölçülü koru.
- Yön/çözünürlük değişince düzen yeniden hesaplansın. Düğmelerin güvenli alan içinde olması kadar fiziksel telefonda rahat basılabilmesi de doğrulansın.

## 7. Fısıltı ve efekt katmanları

- VFX fısıltısı `(160,280,320,28)` ve diyalog yazısı aynı bölgede. İkisini aynı anda birbirinin üstüne yazma. Ortam sözlerini ayrı bir bildirime taşı veya modal konuşma sırasında kuyruğa al. Önemli uyarıları kaybetme.
- Fısıltı yenilenirken eski tween'i iptal et veya kimlik kontrolüyle eski callback'in yeni metni gizlemesini önle. Uzun fısıltılar da sığmalı; sarma/süre/kuyruk davranışını belirle.
- Lanet karartması ve halo, HUD yazısını okunmaz hale getirmesin. VFX katmanı şu anda HUD'un üstünde; atmosferi dünya üzerinde tut, gerekli UI uyarısını okunur katmanda göster. Günlük modal karartmasıyla lanet efektini ayrı ele al.

## 8. Aynı geçişte temel oynanış bozukluklarını da kapat

Önce eski raporu yeniden doğrula; sürüm değiştiyse körlemesine uygulama.

1. Kayıt: başlangıçta yükleme akışı ekle; GameState ve PuzzleManager gibi gerçek durum sahiplerini senkronize et. Yeni oyun/devam ayrımı, bozuk kayıt fallback'i ve kayıt sürümü açık olsun. Dosya yazılıyor olması devam sisteminin çalıştığı anlamına gelmez.
2. Ağırlık plakası: ceset ile Area2D sınırları normal fizik yerleşiminde yaklaşık 1 piksel kaçırılıyor. Oyuncunun doğal şekilde ittiği ceset plakayı tetiklesin; cesedi testte aşağı ışınlayarak başarılı sayma. Çarpışma katmanlarını ve fizik toleransını doğrula.
3. Ölüm: respawn tamamlanana kadar hareket/saldırı/dash kapalı olsun; yeni bedene eski giriş taşınmasın.
4. Aktif oda: ceset oluşturulurken gruptaki ilk world_root yerine gerçekten aktif odanın kökünü kullan. Çekirdek'te ölüm, görünmez Uyanış odasına ceset eklemesin. Oda geçişi sonrası bağlantıları da temizle.
5. Hafıza mührü: her boş olmayan kodu kabul etme. Doğru/yanlış/boş giriş ayrımı ve mobilde kullanılabilir giriş veya mevcut ipuçlarını kullanan seçim arayüzü kur. Kod testte verilmeden bulmacanın gerçekten çözülebilmesi gerekir.
6. Final: klavye dışında gerçek dokunmatik devam/yeniden başlatma akışı kur. Headless otomatik ilerleme kapalıyken girişle test et; finalden çıkarken UI kilitleri ve kayıt tutarlı olsun.
7. Kontrol açıklamaları: WASD vaat ediyorsan gerçek InputMap'i tamamla; aksi halde açıklamayı doğru yap. Aynı giriş hattı klavye ve mobil için ortak oyun kurallarına uysun.
8. Erken final: Bekçi'ye üç vuruşla açılan mevcut kötü sonu belgele; bunun ne zaman erişilebilir olması gerektiğini açıkça tanımla. Temel hata düzeltmesi sırasında finali sırf süre uzasın diye kaldırma veya canını artırma. İçerik genişletmesi ayrı iş olarak kalsın.

## 9. Tamamlanma ölçütleri

Değişiklikten sonra eski testlerin ve yeni UI kontrollerinin karşılığını çalıştır. Düğüm yapısı değiştiyse test yollarını güncelle fakat hata yakalayan beklentiyi silme. Bir doğrudan callback testini gerçek dokunma testi diye raporlama.

- Kısa, 1.248 ve en az 2.000 karakterlik Türkçe diyalog; uzun sözcük, satır sonu ve uzun konuşmacı adı. Hiçbir sayfa panel veya viewport dışına taşmasın. Metin kaybı ve çift ilerleme olmasın.
- Boş günlük, 30 uzun not, tüm sekmeler; ilk/son satıra kaydırma; Kapat düğmesi her durumda erişilebilir olsun. Kitap çizgisi ve metin tutarlı hizalansın.
- Günlük açıkken hareket, saldırı, dash, joystick, alttaki diyalog ve hasar/timer davranışlarını ayrı test et. Özellikle joystick basılıyken günlük açma ve farklı parmakla kapatma senaryosunu dene.
- Diyalog clear/cancel sonrası panel ve kuyruk kapansın; hiçbir bulmaca veya güven durumu iptal yüzünden ilerlemesin. Arka arkaya 50 aç/kapat ve hızlı fısıltı yenilemede eski callback sızmasın.
- 1280×720, 1920×1080, 2400×1080, 1280×800 ve 1024×768 pencere/ekran örnekleri; simetrik ve asimetrik inset; resize. Siyah bantların içine yanlışlıkla kontrol koyma. Görünür içerik alanı ve güvenli alan ölçülerini rapora ekle.
- Render edilen önce/sonra ekran görüntülerini al; normal oyun, kısa/uzun diyalog, boş/dolu günlük ve finali göster. Headless ölçüm ekran görüntüsü yerine geçmez.
- Android cihazda joystick+saldırı/dash, konuşmayı ilerletme, günlük kaydırma, Android geri ve uygulamadan çıkıp geri dönmeyi test et. Cihaz yoksa bunu açıkça “test edilmedi” yaz; APK üretmek cihaz testi sayılmaz.
- Yeni oyun ve devam, normal itmeyle plaka, ölüm kilidi, Çekirdek cesedi, yanlış/doğru mühür, iki finalin mobil girişi tekrar doğrulansın. Test fixture'ı ile açılan yol ve doğal oynanış ayrı sonuçlar olsun.
- Motor import/parse/runtime hatası kalmasın. Hedef cihazda kare süresini ölç; ölçmeden performans veya 60 FPS iddiasında bulunma.

## 10. Teslim

Çalışan değişiklikler, düzenlenen dosyalar ve kısa gerekçeleri; test komutları/sonuçları; önce/sonra görselleri; varsa güncel Android çıktısı; kalan sınırlamalar teslim et. Her maddeyi “düzeltildi / doğrulandı / doğrulanmadı” olarak açıkça ayır. Kaynakları okumadan tüm projeyi yeniden yazma. Yeni oynanış içeriğine ancak bu temel akışlar tutarlı çalıştıktan sonra geç.

## Resmî başvuru kaynakları

- NinePatch kaynak bölgesi ve kenarları: https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html
- AtlasTexture bölge seçimi: https://docs.godotengine.org/en/stable/classes/class_atlastexture.html
- Container yerleşimi: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html
- Çözünürlük, stretch ve oranlar: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- TouchScreenButton ve çoklu dokunma: https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html
- DisplayServer güvenli ekran alanı: https://docs.godotengine.org/en/stable/classes/class_displayserver.html

Belgelerin stable sürümüyle kurulu motorun API'sini karşılaştır; örnek çözümü kopyalayıp çalıştığını varsayma.
