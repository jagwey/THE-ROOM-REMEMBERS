# Prompt 04 — Hafıza Kütüphanesi ve hikâyenin devamı

İlk altı oda ve oda yönetimi tamamlandıktan sonra Hafıza Kütüphanesi'ni üç gerçek oynanabilir oda olarak ekle. Kullanılmayan library/far.png, mid.png, front.png; bookshelf, books, chains, light_beam; photograph, cassette, pocket_watch, key ve npc sprite'larını inceleyerek uygun olanlarını bağla. Dosyaların bulunması bu bölgenin hazır olduğu anlamına gelmez; geometri, etkileşim, kayıt ve hikâye olayları da uygulanmalı.

## Hikâye çerçevesi — yeni devam önerisi

Kütüphane kitap saklamıyor; ölümde insandan kopan hatıraları katalogluyor. Katalogda olay, onu hatırlayan kişi ve hatıranın değiştiği an ayrı kayıtlar. Bu yüzden iki kayıt çeliştiğinde biri mutlaka yalan değildir; biri önceyi, diğeri sonrayı anlatabilir.

Noroi yalnız kurban değil: bir kaybı geri çevirmemek için belleği koruyan düzene bir zamanlar yardım etmiş. Kimi kaybettiği bu bölümde kesin açıklanmasın; mevcut onaylı hikâye farklıysa bu öneriyi uyumla. Shilda tanıklığı koruyan Bekçi. Hem yardım ediyor hem gerçeğin bir bölümünü saklıyor. “Asıl kötü oymuş” gibi basit bir ters köşe kurma.

Önceki yaşamların izleri dünya belleği, günlük oyuncunun kalıcı bilgisi, Noroi'nin anlık hatırlayışı ayrı katmanlardır. Karakter unutunca oyuncunun topladığı kanıt ve mekanik ilerleme silinmesin. Günlük gerçek kaynakla yorumun farkını gösterebilsin.

## lb_01 — Katalog Holü

Yaklaşık 1600–2200 piksel genişlikte, raflarla açılıp kapanan iki yürüyüş hattı kur. Kamerayı yeni odaya bağla. Eksik kaydı olan NPC **Arşivci** ile tanıştır; bu yeni karakterin görevini kısa tut. Konuşması 2–3 satır: “Adını arama. Burada adlar silinir.” / “Peki ne kalır?” / “Kimin kimi beklediği.”

Arşivci'nin kimliği bu sürümde çözülmesi gerekmeyen yan soru olsun; ana çıkışı uzun konuşmaya bağlama. İlk rafı incelemek bir kayıt kartı ve günlük kanıtı verir. Kapı sembollerinde saat, çiçek ve mühür tekrar eder; renk dışında şekil de kullan. Oyuncuya bir sonraki odada ne arayacağını göster.

## lb_02 — Üç Tanıklık

Üç kısa, yeniden oynatılabilir yankı alanı kur. Sadece konuşma penceresi zinciri değil, yerel sahne değişimleri kullan: ışık, bir kapının eski konumu, NPC silueti, kısa görsel olay. Mevcut EchoManager bir diyalog kataloğudur; gerçek kayıt/replay sistemi varmış gibi davranma. Bu bölüm için veriyle tanımlı kısa sahne olayları uygula; bütün dünyayı zamanda geri saran sistem gerekmiyor.

Tanıklıklar:

1. **Saat:** Kristalin ışığı yanmadan önce saat duruyor; felaketin zamanı sanılan anın deney başlangıcı olduğu anlaşılır.
2. **Çiçek:** Fotoğrafta kapı açık, yankıda aynı çiçeğin yanında kapanıyor; çiçeğin yalnız ölüm sonrası bırakılmadığı görülür.
3. **Mühür:** Kayıttaki el Shilda'nın siyah eline benzemiyor; Noroi'nin kırmızı mührüyle uyuşuyor. Bu bir şüphe kanıtıdır, henüz kesin itiraf değildir.

Her kritik bilgi hem sahnede bir işaret hem günlükte bir kanıt olarak bulunsun. Ana bulmaca için kısa metin alternatifi olsun; oyuncu küçük bir pikseli göremedi diye kilitlenmesin. Oyuncu metni hızlı geçse de gerekli nesne/şekil ipucuna tekrar erişebilsin. Yapay uzun beklemeler koyma.

## lb_03 — Unutulan Sayfa

Üç tanıklığın sırasını bir okuma masasında kuran dokunmatik bulmaca yap. Ekranda üç kart, seçili yuva ve yer değiştirme düğmeleri olabilir; sürükleme tek giriş yolu olmasın. Sıra bu bölüme özgü gözlenen neden-sonuçtan çıksın; yine 314 yazmak veya rastgele şifre bulmak olmasın. Önerilen mantık: deney başlatıldı → kapı kapatıldı → koruma mührü devreye alındı.

Yanlış sıra kalıcı zarar vermesin. Hangi iki parçanın çeliştiğini gösteren kısa bir geri bildirim versin; çözümü hemen söylemesin. Kanıtları tekrar inceleme ve düzeni sıfırlama erişilebilir olsun. Bir kerelik doğru çözüm `library.sequence_reconstructed` gibi kalıcı ID ile kaydedilsin. İptal bunu çözmesin. Çözüm sonrası Deney Alanı'na giden geçit açılsın ve geri dönüş kısa yolu kurulsun.

Son sahnede Shilda'nın adı bilinçli biçimde açığa çıksın. Örnek ton:

- Noroi: “Kaydı sen mi sildin?”
- Shilda: “Hayır. Silmemi sen istedin.”
- Noroi: “O zaman neden sakladın?”
- Shilda: “Bir gün bunu yeniden sorarsın diye.”

Konuşmanın ardından oyuncu masadaki kaydın arka yüzünü kendisi inceleyebilsin: Noroi'nin işareti deney yetki mühründe de vardır. Sonraki hedef böyle doğsun: “Deney kaydının aslını bul.” Tek uzun lore anlatımıyla bütün gerçeği açıklama.

## Veri, ilişki ve kayıt

Kayıtlara sabit evidence_id, source_id, room_id ve discovered/completed durumu ekle. Başlığa göre duplicate önlemek yerine ID kullan. Günlükte “Görülen”, “Çıkarım”, “Açık soru” alanları oluştur; sadece menü metni değil gerçek toplanmış verilere bağla.

Yankı ilk keşif, tamamlanma ve iptal durumlarını ayır. İlk satır açıldı diye görülmüş/tamamlanmış sayma. İptal sonrası tekrar oynatılabilsin; active_echo temizlensin. Oda değişince eski callback yeni ödül vermesin. Bulmaca çözümünü ve Deney kapısını kapatıp yeniden açılan uygulamada doğrula.

Shilda ilişkisini yalnız gizli trust sayacına bağlama. Oyuncunun kaydı dinlemesi, gerçeği araştırması ve saldırı sonrası barışmayı seçmesi gibi açıklanabilir olayları tut. Birkaç yanlış cevap veya erken saldırı ana hikâyeyi kalıcı kapatmasın.

## Kabul

Arşiv kapısından Deney Alanı eşiğine doğal kontrolle git. Üç yankıyı farklı sırada gör; biri iptal edilip tekrar açılsın. Yanlış kart sırası, eksik kanıt, doğru sıra, bulmacada günlük açma, ölüm ve kapatıp devam senaryolarını dene. Raflar/ön plan oyuncuyu gizlemesin; kamera ve parallax bütün rota boyunca çalışsın. Kütüphane içi ekran görüntüleri ve kullanılan asset listesini teslim et. Bu bölümün süresini insan testi olmadan ölçülmüş diye yazma.
