# Prompt 02 — takip kamerası ve gerçek oda dünyası

Önce 01'in durumunu doğrula. Mevcut follow_camera.gd zaten oyuncuyu takip ediyor; sorun bütün gerçek odaların 640×360 ekran alanına sıkıştırılması. Yeni testte aynı odada kamera (320,180)'de kaldı; 1920×360 sanal sınır ve taşınmış oyuncuyla x yaklaşık 975'e ilerledi. Bu bir kamera fixture'ı; geniş oda henüz oyunda yok. Çalışan kısmı koruyup gerçek geniş odaları ve oda yönetimini ekle.

## Oda sözleşmesi

Ana sahnedeki sadece enter_core/enter_awakening dallarıyla büyüme. Mevcut mimariye uyumlu RoomDefinition/RoomController ve merkezi oda geçişi kur. Her odanın kalıcı room_id, bölge ID'si, bounds, named spawn noktaları, çıkışları, checkpoint'i, müzik/atmosfer bilgisi ve kalıcı puzzle ID'leri olsun. Kamera sınırı sahne verisinden gelsin; main.gd içinde sürekli sabit Rect2(0,0,640,360) kalmasın.

Tek bir aktif oynanış odası olsun. Oyuncu ve UI tekil kalsın. Eski oda görünmez ama çarpışmaları aktif halde beklemesin. Geçiş sırasında girişleri kilitle, bekleyen etkileşimleri güvenli iptal et, çıkıştan gelen karşı spawn'ı seç, dünya durumunu kur, kamerayı sınırına oturt ve sonra aç. Sürekli üst üste çalışan fade veya çift oda yükleme olmasın.

## Kamera hissi

Uyanış'ın devam odasında en az 1920 piksel genişliğinde gerçek zemin, dekor ve etkileşim yerleştir. Yalnız duvar sınırını büyütmek yeterli değil. Yürüyüş ve dash sırasında oyuncu ekranı ilerletsin. Küçük bir dead zone ve yön değişiminde yumuşak ileri bakış uygula; başlangıç denemesi olarak 48–72 piksel ileri bakış ve 8 civarı takip katsayısı kullanılabilir, görüntüde ayarla.

Yumuşatmayı hem özel lerp hem motor smoothing'iyle iki kere uygulama. Kare hızından bağımsız tepki kur. Physics/render güncelleme zamanlarını birlikte kontrol ederek pixel art titremesini önle. Aynı ölçekteki odada merkez sabit kalabilsin. Viewport'tan küçük odada clamp alt/üst sınırı ters dönmesin; merkezleme kuralı tanımla. Oda geçişi, yükleme ve respawn'da smoothing reset/snap ile eski odadan uzun kamera uçuşu oluşmasın.

Konuşmada kamera oyuncuyu kaybetmesin; konuşma odağı geçici kullanılacaksa iptal/bitme sonrası eski ayarları geri yükle. HUD CanvasLayer üzerinde kalsın, kamera hareketiyle kaymasın. Varsayılan kamera sarsıntısı ekleme.

## Parallax ve assetler

Mevcut Parallax2D katmanlarını koru ve geniş alana uygun kompozisyon kur. Başlangıç oranları uzak 0,15, orta 0,45, yakın 0,8–1 olabilir; görselde ayarla. Hazır 640×360 arka planlar dikişsiz tile olarak kanıtlanmış değil. Dokuyu 3 kat genişletme veya görünür dikişlerle tekrarlama. Açık uçları sütun, duvar modülü, kemer, karanlık niş ve ön planla bilinçli birleştir; eksik sanat varsa bunu belgeleyip oynanabilir prototipi ayrı tut.

Kamera sınırında boşluk açılmasın; her katmanın kamera boyunca kapladığı alanı hesapla. repeat_size kullanırsan kaynak genişliği, scroll_scale ve viewport ihtiyacını doğrula. Görsel dekoru yanlışlıkla dünya zemini veya fizik duvarı yapma.

## Kayıt ve cesetler

Oda ID'si, checkpoint/spawn ID'si ve yerel konumu kayda ekle. Dünya ve yerel koordinatları karıştırma. Eski kayıtları migrate et; bilinmeyen oda güvenli başlangıca dönsün. CorpseManager'da aktif oda bulunamazsa gruptaki ilk odaya sessiz fallback yerine kontrollü çözüm kullan. Cesetler/izler ilgili oda yüklenince kurulsun. PuzzleManager.sync_from_world yalnız iki awakening flag'ini biliyor; yeni puzzle'ları genel ID tabanlı persist et.

## Kabul

Gerçek geniş odada iki yöne yürüyüş/dash ile kamera ve üç parallax katmanını video/görüntüyle doğrula. Sol/sağ sınır, küçük oda, 30/60/120 FPS karşılaştırması, geçiş ortasında giriş, ölüm/respawn ve kapatıp devam senaryolarını çalıştır. Eski odanın hazard/çarpışması etkilemesin. Sabit 16:9 düzen ve geniş telefon ekranlarında güvenli alan doğru kalsın. Uyanış ve Çekirdek mevcut yollardan hâlâ açılabilsin; yeni rotaya bağlanmaları ilerleyen fazda yapılacak.

Resmî referanslar: [Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html), [Parallax2D](https://docs.godotengine.org/en/stable/classes/class_parallax2d.html). Gerçek kamera merkezini gerektiğinde get_screen_center_position ile ölç; yalnız node konumunu render kanıtı sayma.
