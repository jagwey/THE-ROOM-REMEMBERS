# Prompt 01 — kalan temel hatalar

The Room Remembers'ın güncel kodunda diyalog sayfalama, atlas paneller, yeni font, UiGate, kod tuş takımı ve kayıt senkronizasyonu zaten var. Bunları yeniden yazma; önce oku. Aynı klasördeki güncel test raporunu ve next_audit.gd dosyasını incele, sorunları tekrar üret ve düzelt.

## Oynanış dursun, animasyonlar devam etsin

UiGate.pauses_world_threats() STORY katmanında false dönüyor. Oyuncunun girişini engellemek tüm oyunun durması değildir. Hikâye diyaloğu, günlük, kod girişi ve finalde oynanış mantığı dursun: oyuncu/düşman hareketi, saldırı, fiziksel tehlike, hasar, lanet, sayaçlar ve hareketli bulmaca süreleri ilerlemesin. Görsel idle animasyonları, atmosfer, parçacıklar, UI geçişleri ve tip yazıcı sürsün. Uyarı metni açıkken oyuncu ölmesin.

Günlük şu an get_tree().paused=true yaparak sprite animasyonlarını da durduruyor; yeni beklentiye uymuyor. Dünya mantığı ile sunumu bilinçli ayır. Bütün dünyayı PROCESS_ALWAYS yapıp tehlikeleri yeniden çalıştırma. Gerekirse ortak gameplay tick/gate ve bağımsız görsel düğümler kullan; mimariyi mevcut kodla uyumlu ve küçük tut. Gameplay timer/tween'leri de aynı kurala uysun. Idle callback'i hasar üretmesin. Modal açılınca havada olan oyuncunun yerçekimiyle düşüp düşmeyeceğini açıkça çöz; mevcut player hâlâ move_and_slide çağırıyor.

Duraklama birden çok kaynak tarafından tutulabilsin. Günlük kapanırken arkada konuşma varsa oyun açılmasın. Mühür paneli günlükle aynı bool'u paylaşarak birbirinin kilidini kaldırmasın. Oda yüklenirken ve uygulama odağı kaybolunca da giriş temizlensin. Kullanıcı devam etmek için dokunsun; otomatik diyalog ilerlemesi yalnız açık test bayrağıyla etkin olsun. Headless koşulunu tek başına otomatik ilerleme izni sayma.

## İptal edilen mühür işlemi ilerlemesin

Güncel memory_seal.gd dialogue_finished sonucunu bazı yerlerde bekliyor ama bool sonucunu değerlendirmiyor. Testte giriş konuşması clear() ile iptal edilince tuş takımı açıldı; doğru kod sonrası onay konuşması iptal edilince bulmaca çözüldü.

Başlangıç, kod girişi ve sonuç aşamalarının hepsinde completed/cancelled ayrımını uygula. İptal veya oda değişiminde _busy ve bekleyen panel temizlensin. Başarı bir kez kaydedilsin. Kod sonucu kesinleşmeden ve gerekli onay başarıyla tamamlanmadan dünya durumu değişmesin. Diğer await dialogue_closed/finished tüketicilerini de tara: EchoManager'da iptal sonrası active_echo kilidi, Shilda'nın meşgul durumu ve eski odadan kalan coroutine'leri özellikle kontrol et. Global herhangi bir konuşmanın bitmesi başka etkileşimi tamamlamasın; konuşma oturumu/token'ı kullan.

## Görsel düzeltmeler

Temiz checkout/import durumunda özel UI temasının henüz oluşmamış font import dosyalarına erişmesini de doğrula. Test kopyasında ilk import bu yüzden hata verdi; test çalıştırıcısı önce fontları hazırlayıp sonra gerçek temayı yükleyerek bunu aşıyor. Kaynak projede kalıcı, temiz kurulumu destekleyen yolu bul ve sıfır .godot önbelleğiyle doğrula; mevcut fontları veya temayı kalıcı kaldırarak çözme.

Yeni render'da uzun konuşmacı adı çerçevenin üst süsüne taşıyor. Konuşmacı için gerçek bir başlık bandı ayır; uzun adı sar veya düzeni büyüt. Yazı ve kırmızı halo birbirini örtmesin. Metin sayfası panel içinde kalsa bile bütün UI'yi görsel olarak kontrol et.

Günlük 130 piksel genişliğinde dar sol sütunu kullanırken sağ sayfanın çoğu boş. Başlık, sekmeler ve içeriği okunabilir iki sayfa düzenine taşı: solda kayıt listesi, sağda seçili kaydın ayrıntısı iyi bir başlangıçtır. Dar ekranda tek sayfa düzenine geçebilirsin. Cilt üzerine yazma; Kapat her durumda erişilebilir kalsın. Kaydırma metni cilde/kitap kenarına taşırmasın. Uzun başlık ve Türkçe glifleri kontrol et.

## Kabul

Hikâye açıkken tehlike/timer değerleri sabit, sprite frame_progress değişiyor; günlükte de aynı. İç içe modal kilitleri doğru. İptal edilmiş giriş/onay hiçbir kod paneli veya çözüm üretmiyor. İptal edilen yankı tekrar açılabiliyor. Basılı joystick ile modal aç/kapat hareket sızıntısı oluşturmuyor. Kısa/uzun konuşmacı, 2.450 karakter metin ve 30 günlük kaydı görsel olarak okunuyor. Android geri ve tek dokunuş tek eylem davranışını doğrula. 20 kontrolün eski sonuçlarını körlemesine başarıya çevirmeden anlamlı karşılıklarını çalıştır; değişen düğüm yollarını gerektiği kadar güncelle.
