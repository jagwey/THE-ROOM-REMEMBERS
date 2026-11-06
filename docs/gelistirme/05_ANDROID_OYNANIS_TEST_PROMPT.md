# Prompt 5 — gerçek ilerleme, Android ve süre doğrulaması

---

The Room Remembers'ın mevcut Godot projesini test et. Önce sürümü, git durumunu, aktif sahneyi ve varsa AGENTS.md kurallarını oku. Gerçek kullanıcı kayıtlarına dokunma; test başına ayrı user:// dizini kullan. Kullanıcı değişikliklerini koru. Test araçları ve kayıtları üret; çalıştırmadığın testi geçmiş gibi yazma.

Mevcut FAZ67 smoke, puzzle ve güven bayraklarını elle ayarlıyor; bu yüzden gerçek rota testi değildir. Ayrıca headless diyalog ve epilog otomatik ilerlemesi dokunmatik sorunlarını gizleyebilir. Test sonuçlarında bu farkı açıkça koru.

## Katman 1 — açılış ve kayıt

Temiz alanda yeni oyun, geçerli kayıtla devam, sürüm 4 kaydını yükseltme, eksik anahtarlı kayıt, bozuk JSON, uygulama kapandıktan sonra yeniden açma. Beklenen oda, checkpoint, dünya bayrakları, ceset konumları, NPC durumu, günlük ve puzzle state'i birlikte doğrulansın. Aynı teste “kayıt dosyası var” diyerek geçme: ikinci işletim sistemi süreci gerçekten yüklesin. Yükleme tamamlanmadan hiçbir otomatik kayıt eski veriyi ezmesin. Yeni Oyun seçimi doğru alanları sıfırlasın.

## Katman 2 — fizik ve kontrol

Zeminde doğal ölüm, duvar dibinde ölüm, oda geçişinden hemen önce ölüm; cesedin gerçek dokunmatik etkileşimle itilmesi; plaka algısı; kapı collider'ı; dördüncü cesedin iz olması; başka odadaki cesetlerin doğru yerde kalması. Aktif oda kökü ve görünürlük de doğrulansın. Üç ceset sınırına ulaşmak hiçbir ana hedefi geri döndürülemez biçimde kapatmasın.

Ölüm animasyonu sırasında joystick, saldırı ve dash çalışmamalı. Modal günlük/panel açılınca basılı joystick bırakılmış gibi davranmalı. Diyalog ilerletme aynı dokunuşla nesne etkileşimini de tetiklememeli. Yeniden doğuş sonrası kontrol normal geri gelmeli. Mobil düğmelerden gelen sinyal ile klavye girişi aynı kontrol politikasına uymalı.

## Katman 3 — gerçek rotalar

Yeni oyundan bölüm sonuna, beş bölge parçasından Çekirdek'e, oradan her iki finale ayrı kayıtlarla git. İlerleme testleri nesneye yaklaşsın ve gerçek eylem yolunu kullansın. `PuzzleManager.mark_solved`, `trusted_keeper=true`, kapı bayrağı yazma, doğrudan final fonksiyonu çağırma yoluyla başarılı sonuç üretme. Bunlar yalnız ayrı etiketli bileşen fixture'larında kullanılabilir.

Yanlış sembol cevabı kapıyı açmasın; doğru cevap açsın. Ana ipucu atlanınca geri dönüp alınabilsin. İkinci kez görülen yankı sonsuz ödül vermesin. Kütüphane/Deney/Ayna nesneleri ilk girişte, yeniden girişte, kayıttan yüklemede ve ölümden sonra aynı kurala uysun. Tüm bölgelere kısa yol ve geri dönüşler sınansın. Tamamlanmamış odanın kapısı oyuncuyu boş sahneye sokmasın.

Her odanın ilerleme koşulunu bir makine okunur listede tut: giriş, nesne ID, gerekli olay, kalıcı sonuç, çıkış. Otomatik senaryo bunu gerçek girişlerle uygulasın. Zaman aşımı olduğunda son konum, aktif panel, beklenen hedef, açık diyalog ve state snapshot'ı kaydedilsin. Test oyununda debug kısayolları açık olabilir; normal oyuna sızmasın.

## Katman 4 — dokunmatik ve görüntü

Headless otomatik epilog geçişini kapatıp gerçek touch event ve mobil etkileşim sinyalini test et. Gerçek Android cihazda ayrıca joystick+saldırı, joystick+dash, parmağın düğmeden kayması, uygulamanın arka plana alınması, Android geri tuşu, ekran kenarı/safe area, final ve menü akışını dene. Emülatör testi ile fiziksel cihaz testini ayrı raporla.

16:9 ve daha uzun telefon oranlarında arayüz taşmasın; metinler ve butonlar oyun alanıyla doğru eşleşsin. Letterbox varsa koordinat hesabına katılsın. HUD yarı saydam görünüp dokunuşu yanlış yere göndermesin. En az bir küçük ekran ve bir büyük ekran düzenini kontrol et. Güvenli alan ve okunabilirlik yalnız proje ayarında değer bulunmasıyla doğrulanmış sayılmaz.

Render edilmiş görüntüde sprite kesikleri, parallax sıçraması, ayağın zemine oturması, tutarsız piksel boyutu, halo katman sırası ve kırmızı tehlike okunabilirliğini incele. PNG/sheet dosyaları var diye bu kontrolleri geçmiş sayma. BGM/SFX gerçekten duyulsun ve sessize alma seçeneği çalışsın.

## Katman 5 — performans ve süre

Başlangıç hedefi cihazda akıcı 60 FPS olabilir; zayıf cihaz için kararlı 30 FPS seçeneği değerlendir. Sonuçları gerçek cihaz/model, çözünürlük, grafik yöntemi ve oyun durumuyla raporla. En yoğun sahnede en az beş dakika ölç; ortalama FPS yanında kare süresi dağılımını, belirgin takılmayı, bellek değişimini ve nesne sayısını kaydet. Headless motor hızı Android performansı değildir. Aktif olmayan bölgelere ait gereksiz işlem ve efektleri kapat. On ölüm, beş geçiş ve kayıttan dönüş sonrasında nesne sayısı sürekli artmasın.

İlk bölümü en az üç yeni oyuncuyla denemek için yerel form oluştur: başlangıç/bitiş, aktif oynama, menü/bekleme, ölüm, ipucu, kaybolma, tekrar, “burada ne yapacağımı anlamadım” anı, en ilginç karar. Tam oyun için de aynı yöntemi kullan. Veri yoksa 15–25 veya 60–90 dakika hedeflerinin doğrulanmadığını açıkça yaz. Hızlı bitirmeyi hata sayma; anlamlı karar ve kavrama ölçüsünü de değerlendir.

## Teslim

Test betikleri, tekrar üretme adımları, gerçek loglar, başarılı/başarısız/çalıştırılmadı ayrımı, kalan riskler. Bir fonksiyonun çağrılması “tam oyun testi”, bir APK'nın üretilmesi “telefonda oynandı” demek değildir. Başarısız davranışları düzeltmek görev kapsamındaysa düzelt ve aynı senaryoyu tekrar çalıştır. Sadece değerlendirme istenmişse kaynak kodunu değiştirmeden bulguları raporla. Mağazaya yayınlama veya dış hizmet ekleme.
