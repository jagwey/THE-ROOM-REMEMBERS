# The Room Remembers — büyütme paketi

**Ekran görüntülerindeki arayüz sorunları için güncel başlangıç:** `ui-temel-sorunlar/TEMEL_SORUNLARI_DUZELT_PROMPT.md`. Diyalog taşması, kitap hizası, modal giriş, güvenli alan ve önceki temel oyun sorunlarını birlikte ele alır. Ölçümler ve yeniden çalıştırılabilir 14 kontrol aynı klasördedir. İçerik büyütmeden önce bu promptu uygulat.

6 Kasım 2026. İncelenen sürüm: project.godot içindeki 0.8.0; Godot 4.7.2. Bu paket oyun genişletmesi değil; mevcut kodun incelemesi, çalıştırılmış davranış testleri ve geliştirme için hazır talimatlardır. Oyun kaynakları değiştirilmedi.

## Neden iki dakikada bitiyor?

Şu an altı bölgeli bir maceranın mekanik prototipi var. Oynanabilir dünya yalnızca Uyanış ve Çekirdek adlı iki tek ekranlık odadan oluşuyor. Kötü son, Uyanış'ta Bekçi'ye üç başarılı vuruştan sonra açılabiliyor. İyi yol tek ceset, tek yankı, tek ağırlık plakası, otomatik çözülen mühür ve güven konuşmasına dayanıyor. İkinci oda yeni bir sınav kurmadan son etkileşimi sunuyor.

Bu yüzden birkaç uzun koridor, daha fazla can veya daha uzun diyalog eklemek oyunu büyütmeye yetmez. Oyuncunun önce gözlemlediği, sonra denediği, ardından başka bağlamda kullandığı kurallar gerekli. En güçlü mevcut fikir: karakter unutuyor, oyuncu öğreniyor, dünya izleri tutuyor. Genişletmeyi bunun etrafında kurdum.

## Dosyaların sırası

1. `INCELEME_TEST_RAPORU.md`: önce gerçek sorunları ve test sınırlarını oku.
2. `01_TEMELI_SAGLAMLASTIR_PROMPT.md`: kayıt, plaka, aktif oda, giriş kilitleri, dokunmatik final. İlk geliştirme işi bu olmalı.
3. `02_ILK_15_25_DAKIKA_PROMPT.md`: Uyanış ve Çürüme'den oluşan altı odalık oynanabilir bölüm. Önce bunu tamamla ve insanlarla süre ölç.
4. `03_ALTI_BOLGE_PROMPT.md`: 17 odalı, 60–90 dakika tasarım hedefli tam içerik. İlk bölüm iyi çalıştıktan sonra uygula.
5. `04_HIKAYE_BEKCI_FINALLER_PROMPT.md`: Bekçi'nin niyeti, çevresel hikâye, anlamlı iki final.
6. `05_ANDROID_OYNANIS_TEST_PROMPT.md`: gerçek ilerleme, kayıt, dokunmatik ve performans doğrulaması.
7. `MASTER_PROMPT.md`: bütün süreci yönetecek tek başlangıç talimatı.

Süreler tasarım hedefidir. Otomatik test sürelerinden insan oynama süresi çıkarılmadı. “İki dakika” kullanıcının deneyimidir; bu incelemede kronometreli insan oynanışı yapılmadı.

## Öncelik

Önce mevcut yolu güvenilir yap; sonra altı odalık bölüm; sonra yeni bölgelere geç. Üç saatlik içerik sözü vermek yerine 15–25 dakikalık ilk bölümün keyifli olup olmadığını ölç. Aynı koridora daha fazla geri dönüş eklemeyi ilerleme sayma.

## Korunacak kimlik

Beyaz dağınık saçlı Shiren, açık pelerin/atkı ve kırmızı mühür; uzun siyah Bekçi, beyaz gözler, kırmızı halo; koyu mor ve taş tonları, az miktarda güçlü kırmızı; yan görünüş ve piksel filtreleme. Torimon proje/evren adı olarak kalabilir; ekranda oyun adı The Room Remembers olmalı.

Kaynak konsept panosu stil referansıdır. Önceden hazırlanmış görsellerin varlığı, altı bölgenin oynanabilir olduğu veya animasyonların oyun içinde kusursuz göründüğü anlamına gelmez. Yeni mekanik gerektiren sprite, VFX, ses ve çarpışmalar ayrıca hazırlanmalı ve sahnede kontrol edilmeli.
