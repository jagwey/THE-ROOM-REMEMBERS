# Prompt 1 — mevcut oyunun temelini sağlamlaştır

Aşağıdaki talimatı geliştirme ajanına doğrudan ver:

---

Mevcut The Room Remembers Godot projesini yerinde düzelt. Proje kökü `C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\THE-ROOM-REMEMBERS`. Önce geçerli çalışma klasörünü, AGENTS.md dosyalarını ve git durumunu kontrol et. Kullanıcının değişikliklerini koru. İncelenen sürüm 0.8.0, motor Godot 4.7.2. Yazdığın her şey mevcut sürümde tekrar doğrulanmalı. Raporu körü körüne güncel gerçek sayma.

Oyun kimliği: yatay 2D piksel sanat, Android önceliği; karakter ölünce hayat bilgisi silinir, oyuncunun öğrendikleri ve dünyanın izleri kalır. Yeni bölge yazmadan önce aşağıdaki doğrulanmış sorunları çöz. Büyük yeniden yazım yapma; mevcut isim ve sahneleri mümkün olduğunca koru.

## Yapılacak işler

1. **Ağırlık plakası:** `scenes/rooms/awakening.tscn` içindeki plaka merkezi (520,300), şekli 40×16; ceset gövdesi 28×18 ve yerel y=-6. Zeminde oyuncunun ayakları yaklaşık y=288. Bu durumda ceset altı yaklaşık y=291, plaka üstü y=292 kalıyor; yatay olarak üstüne itilse de çözülmüyor. Algılama alanını zemin üzerindeki gerçek ceset gövdesini kapsayacak şekilde ayarla. Dekoru fizik alanından ayır. Oyuncunun kendisi plakayı çözemesin. Cesedi aşağı ışınlamak veya testte puzzle bayrağı yazmak çözüm değildir. Cesetlerin zemin üzerinde oturmasını, itilirken duvar/kapı içine geçmemesini sağla.

2. **Kayıt:** SaveManager.load_game tanımlı ama başlangıç akışında çağrılmıyor. İlk açılışta açık bir Yeni Oyun/Devam Et akışı kur. Devam Et dosyayı okuyup önce mantıksal durumu, sonra doğru odayı ve nesnelerini kurmalı. Player ve Main _ready içinde checkpoint ve oda bilgisini koşulsuz sıfırlamamalı. PuzzleManager.solved, kapı collider'ları, plaka görünümü, NPC ve günlük kayıt sonrasında aynı dünyayı yansıtmalı. Tek bir başlangıç koordinatörü kullan; yüklemeden önce otomatik kayıt mevcut ilerlemeyi ezmesin.

3. **Kayıt güvenliği:** Version 4 kayıtlarını yedekleyip yeni şemaya dönüştür. Eksik anahtarları varsayılanlarla derin birleştir. Bozuk dosyada oyunu çökertme; bir kopyasını koru ve Türkçe, anlaşılır seçenek sun. Geçici dosyaya yaz, başarıyla kapandıktan sonra ana kayıtla değiştir. Yeni Oyun mevcut kaydı silebileceği için oyun içinden açık seçim ister. Testleri ayrı user:// alanında yürüt; gerçek kullanıcının kaydını silme.

4. **Aktif oda:** CorpseManager.get_first_node_in_group("corpses_root") yerine aktif odanın açıkça verdiği kökü kullan. Core'da oluşturulan ceset şu an gizli Awakening köküne ekleniyor. Cesetler ve izler oda kimliğiyle kurulsun. Eski odanın trigger ve fiziği devre dışı kalsın. Geçişte çift spawn, yanlış checkpoint ve görünmez fizik gövdesi oluşmasın. Oda değişimi bitmeden kontrolü açma.

5. **Kontrol kilidi:** Ölüm sırasında 0,2 saniyede yaklaşık 22 piksel yürünebiliyor ve death animasyonu run'a dönüyor. Yürüme, saldırı, dash ve etkileşimi tek bir kontrol politikasıyla yönet. Öncelik: final/ölüm > modal bulmaca/günlük > konuşma/yankı > normal oyun. Fısıltı gibi yürürken okunabilen metinleri ayrı sınıflandır; her metin oyunu durdurmasın. Kilitleri neden/token ile tut; iki akıştan biri bitince diğerinin kilidini yanlışlıkla kaldırma. Ölüm/oda geçişi giriş kuyruğunu ve basılı butonları temizlesin.

6. **Mühür:** memory_seal.gd herhangi bir boş olmayan metni kabul ediyor; testte 999 da çözüldü. Üç sembollü dokunmatik giriş paneli kur; gerçek doğru cevapla karşılaştır. Yanlış seçim kapıyı açmasın. Çözüm ipucu yankı/günlükte bulunabilir ama panel kendi kendine çözülmesin. İlk aşamada 314 kullanılabilir. Sonraki sürümde yeni oyun başına seçilen, kayıtta sabit kalan sembol sırası kullanılabilir; ölümde rastgele değişmesin. Erişilebilir ipucu sistemi olsun, yanlış deneme ani ölüm veya uzun bekleme getirmesin.

7. **Final kontrolleri:** EndingUI yalnız klavye olayını dinliyor; mobil etkileşim sinyali satır ilerletmiyor. Tek bir devam eylemini klavye, dokunma ve mobil düğmeye bağla. Aynı dokunuş iki satır geçmesin. Headless otomatik geçiş gerçek test sonucunu maskelemesin; yalnız açık test kipinde etkin olsun. Final sonrasında Ana Menü/Yeni Oyun/Sonları Gör seçenekleri sun; kapatılmış epilog arkasında donmuş sahne bırakma.

8. **Kontrol belgesi:** PLAY_TR.md WASD diyor ama ui_left üzerinde A yok. WASD ve okları gerçekten bağla veya belgeyi düzelt. Android kontrolleri korunmalı. Günlük açıkken yürümeme/saldırmama, basılı joystick ile ölümden dönüş, iki parmak joystick+dash davranışlarını kontrol et.

## Kabul ölçütleri

- Temiz kullanıcı alanında açılış ve yeni oyun çalışır; kapanıp açılınca Devam Et aynı oda/kapı/ceset/günlük durumunu getirir.
- Doğal ölümle oluşan ceset gerçek etkileşimle itilerek plakayı çözer; sadece _set_pressed çağıran test yeterli değildir.
- Yanlış mühür cevabı reddedilir, doğru cevap kabul edilir; ölüm bu bilgiyi bozmaz.
- Core'da ölüm sonrası ceset Core kökünde görünür ve etkileşilebilir; Awakening'e sızmaz.
- Ölüm ve modal paneller sırasında normal oyun eylemleri işlemez; yeniden doğuşta giriş takılı kalmaz.
- Dördüncü ceset sonrasında üç fiziksel ceset ve en az bir kalıcı iz vardır; çözülmüş kritik kapı kapanmaz.
- İki finalin epilogu dokunmayla ilerler; aynı basış iki kez işlenmez; menüye dönülür.
- Mevcut iyi ve kötü yol tamamlanır. Hazırlık bayraklarını elle true yapan smoke yalnız bileşen testi olarak raporlanır.

Önce başarısız davranışı yeniden üret, sonra düzelt, sonra aynı senaryoyu tekrar çalıştır. Değişen dosyaları, test yöntemini ve kalan cihaz testi ihtiyacını raporla. Yeni görsel veya içerik eklemeyi bu aşamaya karıştırma. Android cihaz yoksa gerçek cihaz testi yaptığını yazma.
