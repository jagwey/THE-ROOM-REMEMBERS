# Şu an oyun nasıl?

6 Kasım 2026, yerel proje incelemesi. Godot 4.7.2, project.godot sürüm etiketi hâlâ 0.8.0. Oyun kaynakları bu incelemede değiştirilmedi; mevcut kullanıcı/Cursor değişiklikleri korundu. Yeni inceleme ve promptlar yalnız bu klasöre eklendi.

## Durum değerlendirmesi

Önceki sürüme göre arayüz ve temel akış ilerlemiş: kaynak panel bölgeleri AtlasTexture ile seçiliyor, Türkçe font ve sayfalama var, günlük yeniden düzenlenmiş, mühür için sayısal giriş paneli var, kayıt yükleme/Puzzle senkronizasyonu ve aktif oda ceset seçimi eklenmiş. Sahnelere ek dekorlar bağlanmış. Eski 14 kontrol/11 başarısız raporu bu sürümün sonucu değildir.

Hâlâ bir maceradan çok iki odalı oynanış prototipi. `scenes/rooms` içinde yalnız awakening.tscn ve core.tscn var; main.gd iki odanın görünürlük/işlem durumunu değiştiriyor. Çürüme, Hafıza Kütüphanesi, Deney Alanı ve Ayna Salonu için arka plan dosyaları var ama bu bölgelere ait oynanabilir sahneler yok. İncelenen script/scene metinlerinde bu dört bölgenin 12 arka planına doğrudan res:// referansı bulunmadı; bu statik tarama genel olarak bütün dinamik yüklemelerin yokluğunu kanıtlamaz. Asıl güçlü kanıt oda sahnelerinin ve geçişlerin henüz kurulmaması.

33 GDScript dosyası bulundu. Altı bölgenin her birindeki üç arka plan dosyası 640×360. Assets altında wav/ogg/mp3 dosyası bulunmadı. Müzik ve geniş oda sanatı hazır varsayılamaz.

## Yeni test — 20 beklenti, 16 geçen, 4 geçmeyen

Proje assets/scenes/scripts/themes ile ayrı klasöre kopyalandı; config/name değiştirilerek kullanıcı kaydı ayrıldı. Güncel font/theme bağımlılıkları dahil edildi. Testte `TORIMON_FRESH=1`, `TORIMON_NO_AUTO_DIALOGUE=1` ve boş smoke bayrağı kullanıldı. `next_audit.gd`, `next_audit.json` ve log aynı pakette. TESTI_CALISTIR.ps1 bağımsız yeni kopyada yeniden çalıştırıldı ve aynı 20/16/4 sonucunu verdi.

İlk boş import önbelleği denemesinde özel tema, fontların .fontdata çıktıları henüz oluşmadan yüklenmeye çalıştı; hata mesajları görüldü ve çalıştırıcının ilk import denemesi tamamlanamadı. Çalıştırıcıda sadece test kopyasında ilk import için özel tema yüklemesi kaldırılıp fontlar import edildi, ardından asıl config geri konup import tekrar doğrulandı. Bu yöntemle yeniden çalışma tamamlandı. Oyunun dağıtılabilir temiz checkout/import akışı ayrıca kontrol edilmeli; oyunun kaynak config'i burada değiştirilmedi. Son bootstrap/import logları pakette, ilk başarısız deneme debug/ilk-import-hatasi.log altında korunuyor.

Geçen kontroller: sahne açılışı, manuel diyalogun açık kalması, story giriş kilidi, konuşmada oyuncunun hareketsiz kalması, sprite'ın konuşmada işlemeye devam etmesi, clear sonrası HUD'un kapanması, 2.450 karakter metnin 15 sayfaya bölünüp aktif sayfanın panele sığması, whitespace hariç içerik karşılaştırması, günlük giriş kilidi, gövde/Kapat ayrılığı, günlük kapandıktan sonra story kilidinin korunması, geniş sınır fixture'ında kamera takibi, aynı süreçte kayıt roundtrip/Puzzle sync, yakına konmuş cesedin plaka tarafından algılanması, Çekirdek cesedinin aktif Core altında bulunması ve final dokunma callback'i.

**Dört geçmeyen beklenti:**

1. **Hikâye diyaloğunda tehlike duraklama sözleşmesi eksik.** UiGate.pauses_world_threats STORY için false. Hareket/saldırı kilitli olması bütün tehlikelerin durduğu anlamına gelmiyor. Testte merkezi sorgu ölçüldü; gerçek telefonda her hazard'ın oyuncuyu öldürmesi simüle edilmedi. Keeper fizik işlemi de modal guard içermiyor.
2. **Günlükte görsel animasyonlar donuyor.** Günlük get_tree().paused=true yapıyor; player.sprite.can_process=false oldu. Kullanıcının “oyun dursun ama animasyonlar sürsün” isteğini karşılamıyor.
3. **Mühür giriş konuşması iptal edilince kod paneli açılıyor.** Intro sırasında DialogueManager.clear çağrıldı; seal_root.visible=true oldu. memory_seal.gd dialogue_finished sonucunu bu akışta değerlendirmiyor.
4. **Mühür başarı konuşması iptal edilince çözüm yine kaydoluyor.** Testte 314 girildi, onay diyaloğu clear ile iptal edildi; awakening_memory_code solved=true oldu. İptal ve başarı ayrımı event düzeyinde eklenmiş olsa da tüm tüketicilerde tamamlanmamış.

Test scriptinin 0 çıkış kodu bütün beklentilerin geçtiğini değil, raporun üretildiğini gösterir. Paket çalıştırıcısı başarısız beklentiler varsa 1 döndürür. Bu 20 kontrol önceki 14 kontrolle birebir aynı değildir; yüzdelik kalite artışı hesabı yapma.

## Kamera bulgusu

follow_camera.gd zaten mevcut. Gerçek oda sınırı 640×360, viewport 640×360: clamp her eksende tek merkez değerine düşüyor. Oyuncu konumu değişince kamera (320,180)'de kaldı. Testte sınır 1920×360 yapılıp oyuncu x=1000'e taşınınca kamera x≈975'e geldi. Bu, mevcut takip mantığının geniş sınırda hareket edebildiğini gösterir; oyunda gerçek geniş oda bulunduğunu veya render'da kusursuz olduğunu göstermez.

Doğru sonraki adım yeni kamerayı sıfırdan yazmak değil: geniş oda kompozisyonu, oda verisinden bounds, spawn/exit/checkpoint ve kontrollü geçiş kurmak. Godot'un [Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html) belgesi gerçek ekran merkezinin node konumundan farklı olabileceğini açıklar; görsel doğrulama gerçek kamera merkeziyle yapılmalı. [Parallax2D](https://docs.godotengine.org/en/stable/classes/class_parallax2d.html) katman oranı ve tekrar kapsamı için başvuru alındı.

## Güncel görüntülü çalışma

Mevcut `scripts/dev/polish_capture.gd` ayrı kopyada Windows görüntü sürücüsüyle çalıştırıldı, yedi 640×360 PNG üretildi. Bu, önceden üretilmiş görüntüleri incelemekten ayrı yeni bir çalıştırmadır. PNG kayıtları err=0; scriptin page_rejoin_ok kontrolü true. Görüntüler `screens` altına kondu. Manuel insan oynanışı değil; sahne durumları scriptle kuruldu.

Uzun diyalog ve dolu günlük görüntüleri doğrudan incelendi:

- Diyalog artık üst bölgede ve normal gövde çerçeve içinde. Ancak uzun test konuşmacısı çerçevenin üst çizgisine/süsüne taşıyor. Gövde geometrisi testi bunu yakalamaz.
- Günlük kitap sınırına daha iyi oturuyor ve Kapat sağ sayfada. İçerik yaklaşık 130 piksel genişliğindeki sol sütuna sıkışmış, sağ sayfanın çoğu boş. Okunabilir bir liste+ayrıntı düzeni daha uygun. Mevcut hali tüm arayüzün tamamlandığı anlamına gelmez.
- Yeni dekorlar görünür; daha çok asset kullanımı ile kompozisyon kalitesi ayrı değerlendirilmeli. Oyuncu silueti ve etkileşim okunabilirliği yeni geniş odalarda tekrar kontrol edilmeli.

## Var olan smoke testi

Ayrı kopyada güncel ana sahne, açık TORIMON_SMOKE=1 ve fresh bayrağıyla çalıştırıldı. Log: `FAZ67_SMOKE ok curse_fail=true world=true bad=true good=true indicator=true`. Bu test ölüm/yeniden doğuş ve iki final kod yolunu fixture hazırlığıyla çalıştırıyor. Bulmaca bayraklarını elle hazırladığı için oyuncunun doğal yoldan iki finale ulaşabildiğini veya mevcut uzunluğu kanıtlamıyor.

## Ek kod riskleri — bu tur davranışla tamamen doğrulanmadı

- EchoManager, seen bilgisini konuşma tamamlanmadan kaydediyor ve dialogue_closed bekliyor. İptalde active_echo veya yeniden deneme akışı takılabilir; yeni prompt bunu özellikle test ettiriyor.
- PuzzleManager sync yalnız iki Uyanış flag'ini geri kuruyor; yeni puzzle ID'leri genel kayıt şemasına geçirilmeden bölgeler büyütülmemeli.
- Bekçi gizem bayrağından sonra üç darbeyle kötü finali hâlâ tetikleyebiliyor. Tam macerada sonların son bölgeye taşınması tasarım değişikliği gerektirir.
- EndingManager.current epilog paneli kapandıktan sonra kilitli kalabilir; menü/devam akışı ayrıca doğrulanmalı.
- Ceset üç sınırı eski ağırlığı kaldırabilir; kalıcı kapı/alternatif ağırlık politikası olmadan yeni odalarda softlock riski var.

## Sınırlar ve önerilen ilerleyiş

Doğal insan oynanışı, tam kayıt sonrası yeni süreçten devam, gerçek cihaz çoklu dokunma/çentik, performans, tüm tehlikelerin durması ve tamamlanmış altı bölge bu testlerle doğrulanmadı. Kayıt testi aynı süreçte roundtrip; plaka testi cesedi yakınında oluşturan fixture; final dokunması doğrudan callback. Mevcut Corpse AnimatableBody otomatik yere düşen bir rigidbody değildir; bu test doğal itme kanıtı sayılmaz.

Önce kalan dört temel hata ve okunabilirlik; sonra geniş dünya/kamera; ardından Uyanış+Çürüme altı odalık bölüm; sonra Kütüphane; sonra Deney/Ayna/Çekirdek. Tam hikâye tasarım hedefi 18 oda ve ilk tahmin olarak 60–90 dakika. Süre yalnız insan testi sonrası değerlendirilebilir. Bu öneri, kullanıcının iki dakikalık deneyimini ölçülmüş yeni bir süreyle değiştirmiyor.

Hikâye için önceki referans konuşmanın son 10 turu okundu: Bekçi için Shilda adı kullanıcı tarafından seçilmiş; kaynak kodda Shiren adı var. Yeni olay detayları yaratıcı devam önerisidir, önceki konuşmanın eksiksiz kanonu diye sunulmaz.
