# Cursor — güncel projeden tam oyuna

6 Kasım 2026. Bu paket kod değişikliği değil, güncel projeye göre uygulama talimatıdır. Yeni test ve görüntülerle hazırlandı; önceki raporun 11 başarısız sonucunu güncel durum diye tekrar etmez.

## Cursor'a ilk mesaj

The Room Remembers projesinde aşağıdaki geliştirme paketini uygula. Önce `docs/gelistirme/sonraki-asama/GUNCEL_DURUM_VE_TEST.md` ve bütün numaralı promptları oku. Sonra 01'i uygula, test et; 02'ye geç ve aynı şekilde sırayla ilerle. Yeni bir onay istemek için her dosyanın sonunda durma; gerçekten gereken bilgi eksikse sor, diğer bağımsız işleri sürdür. Bütün fazları bir anda yüzeysel sahnelerle tamamlanmış sayma. Her fazın çalışan halini doğrula ve ilerleme kaydını güncelle.

Mevcut kullanıcı değişikliklerini koru. Oyun Godot 4, Android öncelikli, 640×360 temel alanlı, yandan görünümlü pixel art. Oyuncu Shiren, Bekçi'nin hikâyedeki adı Shilda. Eski görünen "Bekçi" adı başlangıçta kimliği gizlemek için kalabilir; güven/isim sahnesinden sonra Shilda olarak göster. Teknik keeper ID'lerini topluca değiştirerek kayıt uyumluluğunu bozma.

Oyun fikri: karakter unutuyor, oyuncu öğreniyor, dünya izleri saklıyor. Yeni bölgeler bu fikre farklı oynanış kuralları eklemeli. Daha çok yürüyüş ve uzun metin tek başına genişletme değildir.

## Sıra

1. `01_KALAN_TEMEL_HATALAR.md`: duraklama, iptal ve UI kalitesi.
2. `02_TAKIP_KAMERA_ODA_DUNYA.md`: geniş odalar, kamera, geçiş, kayıt ve oda mimarisi.
3. `03_UYANIS_CURUME_OYNANABILIR_BOLUM.md`: ilk altı oda ve tam bir öğretme/uygulama döngüsü.
4. `04_HAFIZA_KUTUPHANESI_HIKAYE.md`: üç kütüphane odası, arşivci, kanıt bulmacası, Shilda ve hikâye devamı.
5. `05_DENEY_AYNA_CEKIRDEK.md`: kalan dokuz oda, sonuçları görünen seçimler ve iki final.
6. `06_TAM_OYUN_TEST_VE_SUNUM.md`: doğal rotalar, Android, save migration, ses ve görsel son kontrol.

Her fazda kodu gerçekten uygula. Sonraki fazın kapısını açan placeholder yerine biten kapsamı açıkça göster. Hedef ilk bölüm için 15–25 dakika, tam oyun için ilk tasarım hedefi 60–90 dakika; bunlar ölçülmüş süre değildir. İnsan oynanışından sonra ayarla.

## Ortak kurallar

- Mevcut assetleri görsel olarak incele ve uygun yerlerde kullan. `ASSET_INVENTORY.md` ve eski asset raporlarını kodla karşılaştır; bir raporda "kullanılıyor" yazması sahnede gerçekten bağlandığını kanıtlamaz.
- Altı bölgenin hazır arka planları yalnız 640×360; bunları 2.000 piksel genişliğe gerip oda sayma. Kenarları dikişsiz değilse tekrar ederek çoğaltma. Mevcut katmanlar, modüler dekor/zemin ve gerektiğinde açıkça belirtilen eksik çizimlerle yeni kompozisyon kur.
- Dekor ile çarpışma ayrı olsun. Oyuncunun yürüdüğü zemin, oynanabilir geçit ve etkileşim nesnesi görünüşte anlaşılmalı. Arka plana çizilmiş bir kapı, çalışan kapı değildir.
- Yeni yaşam bilgisi, oyuncunun kalıcı bilgisi ve dünyanın kalıcı durumu ayrı kalsın. Ölüm oyuncunun günlüğünü, açtığı ana geçitleri ve öğrenilmiş mekanikleri silmesin.
- Olaylar sabit ID'lerle ve bir kez uygulanabilir şekilde kaydedilsin. Panel iptali başarı sayılmasın. Sahne kaldırılınca eski coroutine/callback yeni odaya ödül vermesin.
- Hareket şu an yürüme/dash/etkileşim; zıplama yok. Oda tasarımında görünmez bir zıplama yeteneği varsayma. Kot farkını merdiven, rampa veya güvenilir asansörle çöz. Zıplamayı ayrı kontrol/tasarım işi olarak değerlendirmeden ekleme.
- Üç ceset sınırı eski kilitleri yeniden kapatıp oyuncuyu sıkıştıramasın. Kritik çözüm kalıcılaşmalı veya erişilebilir alternatif ağırlık bulunmalı. Ölüm sayısı/grind ana ilerleme şartı olmasın.
- Tamamlanan her faz için kısa rapor, gerçek ekran görüntüsü ve test sonucu bırak. Çalıştırmadığın şeyi doğrulanmış sayma. Otomatik fixture başarıları doğal oynanış veya telefon testi değildir.

Yeni anlatı detayları bu paketin yaratıcı devam önerisidir; kullanıcının onayladığı önceki hikâye diye sunulmaz. Mevcut oyundaki olaylar ve doğrulanmış Shiren/Shilda isimleri korunarak uyumlu hale getir.
