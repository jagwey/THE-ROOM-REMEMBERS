# Tek başlangıç promptu

Aşağıdaki metin bütün büyütme sürecini yönetmek için kullanılabilir. Ayrıntılı alt promptlar bu dosyayla aynı klasördedir.

---

The Room Remembers oyununu mevcut projem üzerinden büyüt. Godot 4, Android öncelikli yatay 2D piksel sanat. Çalışma kökü `C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\THE-ROOM-REMEMBERS`. Oyunun kimliği: Noroi ölünce hayat bilgisi silinir; oyuncu öğrendiklerini, dünya ise cesetleri, çiçekleri ve seçimlerin izlerini tutar. Beyaz saç/açık atkı/kırmızı mühür ve siyah Bekçi/beyaz göz/kırmızı halo görünüşlerini koru.

Önce mevcut kodu, git durumunu ve proje kurallarını incele. Kullanıcı değişikliklerinin üstüne yazma. 6 Kasım incelemesindeki 0.8.0 sürümünde yalnız iki tek ekranlık oda vardı. Bekçi'ye üç vuruşla final açılıyordu; mühür otomatik çözülüyordu. Kayıt açılışta yüklenmiyor, PuzzleManager yükleme sonrasında eşitlenmiyor, ölümde hareket sürüyor, Core cesedi gizli Awakening köküne ekleniyor, dokunmatik etkileşim epilogu ilerletmiyor ve zemin cesedi plakaya değmiyordu. Bunları güncel kodda yeniden doğrula; çözülmüş sorunları tekrar yazma.

Klasördeki `INCELEME_TEST_RAPORU.md` ve sıralı promptları oku. Paket proje içindeyse `docs/gelistirme` altında bulunur. Dışarıdan yalnız bu metin verilmişse aşağıdaki plan yeterli bağlamdır; erişemediğin dosyayı okumuş gibi davranma.

**Aşama 1:** Mevcut iki odalı yolu güvenilir yap. Gerçek kullanıcı kaydından ayrı alanda test et. Kayıt/Devam Et akışını, doğru oda kurulumunu, puzzle-state eşitlemesini, ceset-plaka çarpışmasını, ceset aktif oda kökünü, ölüm/modal kontrol kilitlerini, gerçek sembol girişini ve mobil final/menüyü düzelt. Eski kayda dönüştürme ve bozuk kayıt kurtarması ekle. Mevcut kullanıcı ilerlemesini silme.

**Aşama 2:** Altı odalık, ilk oynayış için 15–25 dakika hedefli ilk bölüm uygula: A01 güvenli uyanış; A02 iz/ağırlık ve ölüm gerektirmeyen alternatif; A03 gerçek sembol sırası; D01 değişen ama okunabilir koridor; D02 nesnenin önceki yerindeki silüet izi; D03 kuralların birleştiği bahçe ve Bekçi'nin koruduğu çiçek. Çürüme sonu tam oyun finali değil bölüm tamamlanması olsun. Erken üç saldırı oyunu bitirmesin.

**Aşama 3:** Test edilmiş bölümden altı bölgeye genişle: Uyanış 3, Çürüme 3, Hafıza Kütüphanesi 3, Deney Alanı 3, Ayna Salonu 3, Çekirdek 2 oda. Toplam 17 oda. Kütüphane kanıt karşılaştırma ve olay sırası; Deney kısa hareket yankısı ve çift devre; Ayna iki görünüşte doğrulama; Çekirdek önceki kuralların birleşimi ve bilinçli final seçimi içersin. Tam oyun için 60–90 dakika tasarım hedefi kullan; bunu ölçülmüş süre gibi sunma.

**Aşama 4:** Bekçi'yi basit boss'a dönüştürmeden ilişkiyi derinleştir. Uyarı, müdahale, yas ve işbirliği dünya eylemleriyle gösterilsin. Noroi'nin döngünün kurulmasında rolü olabileceğini parça parça ortaya çıkar. İki sonu da son bölge ve anlamlı sınav sonrasına taşı: birlikte mühürleme veya bağı koparma. Kazara saldırı veya görünmez ilişki sayacı ilk dakikada sonu kilitlemesin. Menüler ve sonlar tamamen dokunmatik kullanılabilsin.

**Aşama 5:** Kayıttan yeniden başlatma, odalar arası cesetler, dört ölüm, çözülmüş kapıların kalıcılığı, yanlış/doğru sembol, gerçek girişlerle ana rota ve iki finali test et. Bayrakları true yaparak geçen smoke'u doğal ilerleme diye raporlama. Headless otomatik metin geçişini touch testinde kapat. Cihaz varsa Android'de kontrol, safe area, arka plan/dönüş, ses ve performansı ölç. Cihaz veya insan testi yapılamıyorsa bunu açıkça belirt.

Süreyi yavaş yürüyüş, uzun bekleme, aynı bulmacanın kopyası ve zorunlu ölüm döngüleriyle doldurma. Yeni kuralı öğret, güvenli denet, sonra önceki kuralla birleştir. Kritik yollar silinebilen üç cesede kalıcı olarak bağımlı olmasın; çözüm state'i ve kurtarma yöntemi olsun. Zıplama henüz yok: zorunlu rotayı mevcut kontrol düzeniyle kur. Yeni bir büyük sistem gerekiyorsa onun gerektirdiği mobil kontrol, görsel ve test kapsamını da tamamla.

Her aşamayı uygulanmış, açılabilir ve test edilmiş teslim et. Üretmediğin sanatı, atamadığın sesi, oynamadığın rotayı ve ölçmediğin süreyi tamamlanmış sayma. Yeni hesabı, ücretli hizmeti veya yayınlamayı bu işe ekleme. Kaynak değişiklikleri, test kanıtları ve kalan sınırlamalarla bitir.
