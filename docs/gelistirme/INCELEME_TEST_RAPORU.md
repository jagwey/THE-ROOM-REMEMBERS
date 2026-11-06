# The Room Remembers — kod ve davranış incelemesi

**Tarih:** 6 Kasım 2026. **İncelenen proje:** `THE-ROOM-REMEMBERS`. **Sürüm:** 0.8.0. **Çalıştırılan motor:** Godot 4.7.2.stable.official.ed1daf0bf.

## Sonuç

Oyunun iki dakikada bitmesi yalnız denge sorunu değil: mevcut yapı iki odalı bir mekanik dilim. Altı temanın görselleri bulunması, altı oynanabilir bölge olduğu anlamına gelmiyor. Kötü sona ilk odada üç başarılı saldırıyla ulaşılabiliyor. İyi yol da yalnız bir ağırlık bulmacası, bir yankı, otomatik açılan kod mührü ve güven konuşmasından oluşuyor. Çekirdek odasında yeni bir oynanış sınavı bulunmuyor.

Üstelik mevcut iyi yolda fiziksel bir ilerleme engeli var: zemindeki ceset, plaka alanının yaklaşık bir piksel üstünde kalıyor. Bu nedenle başarılı smoke çıktısı, normal oyuncunun iyi sona ulaşabildiğini göstermiyor.

**10 senaryoda 19 davranış kontrolü çalıştırıldı: 11 başarılı, 8 başarısız.** Buradaki başarılı sonuçların bir kısmı mevcut davranışı doğruluyor; özellikle “üç saldırı final açıyor” bir tasarım problemi olmasına rağmen ilgili testin beklediği davranış gerçekleştiği için başarılı sayıldı. Bu sayı bir kalite puanı değildir.

## Yöntem ve sınırlar

- 29 oyun script'i, iki oda sahnesi, ana sahne, oyuncu/Bekçi/ceset/UI bağlantıları, başlangıç ayarları, kontrol belgesi ve kayıt akışı incelendi.
- Çalışma kaynakları ayrı bir test klasörüne kopyalandı. Proje adı `TorimonReview_20261106_Isolated` yapıldı. Test kullanıcı dizini `C:/Users/Osman/AppData/Roaming/Godot/app_userdata/TorimonReview_20261106_Isolated` oldu. Kullanıcının gerçek oyun kaydı kullanılmadı.
- Temiz import başarılı oldu; testler gerçek Godot fizik ve sahne ağacında headless çalıştı. Ana sahne her senaryoda yeni süreçte açıldı. Kayıt yaz/oku senaryoları aynı izole kayıt alanını kullandı.
- Testler geliştirme amaçlı başlangıç durumları kullandı. Yanlış kod testi 999 bilgisini fixture olarak ekledi; saldırı testinde oyuncu Bekçi yakınına yerleştirildi ve yarık kapatıldı; iyi son zincirinde nesneler doğrudan çağrıldı ve plaka için yalnız test kopyasında +4 piksel tanısal değişiklik yapıldı. Bunlar doğal, kesintisiz oynanış veya insan bitirme süresi kanıtı değildir.
- Diyaloglar headless kipinde otomatik geçiyor. Mobil epilog testinde bu otomatik geçiş özellikle kapatıldı. Dokunmatik sinyal/sentetik olay sonucu fiziksel Android cihaz sonucu değildir.
- APK dosyası mevcut: 32.117.782 bayt. Bu incelemede APK yeniden üretilmedi, telefona kurulmadı, cihaz performansı veya ses/görüntü kalitesi test edilmedi.
- Kaynakların önce/sonra SHA-256 karşılaştırmasında 40 oyun dosyası aynı kaldı. Oyun kodu, sahneleri ve project.godot değiştirilmedi. Teslim edilen yeni dosyalar rapor, promptlar ve test araçlarıdır.

## İki dakikalık yapıyı oluşturan eksikler

1. **Dünya küçük:** `scenes/rooms` altında yalnız awakening.tscn ve core.tscn var. Her biri 640×360 sınırında tek ekranlık oda. Aradaki dört tema için oynanabilir oda grafiği yok.
2. **Final çok erken:** `scripts/keeper/keeper_controller.gd:26` üç vuruş eşiğini tanımlıyor; `:339–354` vuruşları sayıp kötü sonu açıyor. Bölgeleri tamamlama koşulu yok. Testte yalnız awakening ziyaret edilmişken üç gerçek saldırı sinyali BAD sonucunu verdi.
3. **Mühür düşünme istemiyor:** `scripts/world/memory_seal.gd:25–36` bellekte boş olmayan kod bulunmasını yeterli sayıyor. Oyuncu cevap girmiyor. “314” hikâye bilgisi mevcut olsa da sistem başka bir metni de kabul ediyor.
4. **Yankı çoğunlukla metin:** EchoManager bilgi ve günlük veriyor; henüz mekân içinde oynanan hareket tekrarına dayalı bir bölüm yok. Cesedin ilk yankısından sonra diğer izlerle kurulacak farklı ilişkiler eksik.
5. **Çekirdek bir son düğmesi:** `scripts/autoload/ending_manager.gd:34–40` ağırlık, kod, herhangi bir yankı ve trusted_keeper koşullarını kontrol ediyor. Yeni bölge parçası, birleşik bulmaca veya final sınavı yok.
6. **Sistemlerin tekrar uygulanması yok:** hareket, dash, lanet, dünya izi ve Bekçi tavırları var; her birini farklı bağlamda kullanacak oda/karar zinciri çok kısa.
7. **Sunum iskeleti:** ana sahnedeki BGM/SFX düğümlerinde stream yok. Menü/Devam Et/final sonrası akış tamamlanmamış. Normal düşman rotası, bölgesel NPC görevleri ve artan mücadele eğrisi yok. Bunların hepsini eklemek zorunlu değil; mevcut ana fikri taşıyan içerik öncelikli olmalı.

## Davranış testleri ve bulgular

### 1. Açılış ve yatay hareket — başarılı

`baseline.log`: ana sahne açıldı; iki oda bulundu. 0,4 saniyelik sağ yön girişinde yaklaşık 45,83 piksel ilerledi. Bu, fizik adımı farkıyla SPEED=110 değerine yakın. Hareket sistemi çalışıyor. Bu test tüm odaları veya insan kontrol hissini doğrulamaz.

### 2. WASD belgesiyle gerçek kontrol farklı — başarısız, orta öncelik

`PLAY_TR.md` WASD/oklar yazıyor. Runtime InputMap kontrolünde A, ui_left'e bağlı değil. Oklar ve sanal joystick kullanılıyor. Kontrolü veya belgeyi eşitlemek gerekir. Kaynak: `scripts/autoload/mobile_input_manager.gd:24` çevresi ve project.godot giriş haritası.

### 3. Kayıt dosyası yazılıyor, yeni açılışta geri gelmiyor — başarısız, yüksek öncelik

`save_write.log`: audit_marker ve açık kapı durumuyla dosya yazıldı. Sonraki ayrı süreçte `save_read.log`: dosya var, marker MISSING, kapı false. `SaveManager.load_game()` elle çağrıldığında marker doğru geldi. Dosya okuma fonksiyonu çalışıyor; başlangıç entegrasyonu eksik. Kaynak: `scripts/autoload/save_manager.gd:21`; script aramasında bu adın oyun içindeki başka çağrısı bulunmadı. `scripts/main.gd:11` çevresi başlangıcı yine Awakening'e kuruyor.

**Etki:** oyuncu ilerlemesi diskte bulunmasına rağmen oyun kaldığı yerden başlamıyor. Sonraki otomatik kayıt eski durumu ezebilir. Büyütmeden önce çözülmeli.

### 4. Elle yükleme bile puzzle durumunu eşitlemiyor — başarısız, yüksek öncelik

`save_read.log`: load_game sonrasında dünya kapı bayrağı true, PuzzleManager.is_solved(awakening_weight) false. PuzzleManager._ready ilk açılışta çalışıyor; sonradan yüklenen kaydın çözülmüş durumunu yeniden kurmuyor. Kaynak: `scripts/autoload/puzzle_manager.gd:9–14`, `scripts/autoload/save_manager.gd:32–38`.

**Etki:** kapı görseli, fizik engeli ve final hazırlığı aynı dünya için farklı cevaplar verebilir. Sadece load_game çağrısı eklemek yeterli değildir.

### 5. Ölürken yürümek mümkün — başarısız, yüksek öncelik

`death.log`: request_death sonrasındaki 0,2 saniyede 21,99997 piksel hareket; is_dying=true iken animasyon run. Yeniden doğuş ve bir cesedin korunması ise başarılı.

Kaynak: `scripts/player/player_controller.gd:56` yalnız final durumunu durduruyor; `scripts/autoload/death_manager.gd:13` is_dying'i açıyor fakat kontrolcü bunu kullanmıyor. play_death sonraki fizik güncellemesinde idle/run akışına dönüyor.

**Etki:** ölüm konumu ile görülen karakter ayrışıyor, kamera/etkileşim/animasyon tutarlılığı bozuluyor. Kontrol kilidi hareket dışındaki saldırı/dash/etkileşim yollarını da kapsamalı.

### 6. Yanlış kod da mührü çözüyor — başarısız, içerik ve mantık sorunu

`seal.log`: test başlangıcına memory_codes.awakening=999 verildi; on_interact sonrası puzzle solved=true. Bu test normal UI'den 999 girildiğini söylemez; zaten normal kod giriş UI'si yok. Kod yolu herhangi bir boş olmayan bilgiyi otomatik çözüm sayıyor.

**Etki:** öğrenilen ipucunu uygulama adımı yok. Gerçek sembol girişi hem oyunun hafıza temasını güçlendirir hem anlamlı bir karar ekler. Kaynak: `scripts/world/memory_seal.gd:25–36`.

### 7. Çekirdek cesedi gizli Uyanış odasına ekleniyor — başarısız, yüksek öncelik

`core_corpse.log`: aktif oda core; oluşturulan cesedin ebeveyni `/root/Main/World/Awakening/Corpse`; visible=false, can_process=false. Kaynak: `scripts/autoload/corpse_manager.gd:95` ilk corpses_root grubunu seçiyor. İki odada da bu grup var; ilk kök aktif oda garantisi vermiyor.

**Etki:** oda sayısı arttıkça izler görünmez veya yanlış yerde olur. Aktif oda kökü açıkça verilmelidir.

### 8. Üç ceset sınırı ve hafıza katmanları — başarılı

`trim.log`: dört ceset kaydından sonra üç fiziksel kayıt ve bir iz var. Dünya bayrağı reset_character_life sonrasında korunuyor, hayatın interacted listesi temizleniyor. Bu, oyunun ana fikri için kullanılabilir sağlam bir başlangıç. Global üç ceset sınırıyla yeni bulmacaların kilitlenmeyeceği ayrıca test edilmeli.

### 9. Dokunmatik final devam etmiyor — başarısız, yüksek öncelik

`ending_touch.log`: headless otomatik geçiş kapatıldı. Sentetik touch bas/bırak ve MobileInputManager.press_interact sinyali sonrasında epilog index=0 kaldı. Klavye interact olayının UI handler'ına verilmesi index'i 1 yaptı.

Kaynak: `scripts/ui/ending_ui.gd:55–68`; UI eylem olaylarını dinliyor, mobil signal'a bağlı değil. `scripts/ui/hud_controller.gd:37` mobil düğmeyi MobileInputManager'a bağlıyor. Headless _process her kare satır geçirdiği için eski smoke bu eksikliği göremiyor.

**Sınır:** fiziksel telefon testi yapılmadı. Bu bulgu mevcut olay bağlantısının eksikliğini doğrular; Android geri tuşu, ekran oranı ve gerçek çoklu dokunma ayrıca denenmeli.

### 10. Üç gerçek saldırı ilk odada kötü son açıyor — mevcut davranış doğrulandı

`bad_attacks.log`: oyuncu yakın konuma yerleştirildi, yarık yalnız testte kapatıldı. Üç mobil saldırı sinyali, gerçek AttackArea çarpışması ve kontrolcü üzerinden Bekçi'ye ulaştı; strikes=3, ending=1, rooms_visited=[awakening]. Bu bir insanın kaç saniyede oraya yürüdüğünü ölçmez; erken final koşulunu doğrular.

**Öneri:** erken şiddete tepki/ilişki sonucu ver; finali gerçeğin öğrenildiği ve ana bölgelerin tamamlandığı bir karara taşı. Yalnız HP artırmak problemi çözmez.

### 11. Zemindeki ceset plakayı çalıştırmıyor — başarısız, ilerleme engeli

`plate_chain.log`: oyuncunun gerçek zemin yüksekliğinde ceset oluşturuldu. Yankı okundu ve iki itme etkileşimi yapıldı. Ceset x=520, y=287,9922 oldu; plaka x=520, y=300. Kapı false kaldı. Overlap listesinde bir gövde bulunması çözüm değildir: listedeki dünya zemini ağırlık sayılmıyor.

Geometri: ceset gövdesi merkez y=-6, yarı yükseklik 9 → alt kenar ayak_y+3 ≈290,9922. Plaka üst kenarı 300−8=292. Yaklaşık 1,008 piksel boşluk var. Ceset yerçekimi uygulayan gövde değil; kendiliğinden aşağı oturmuyor.

**Tanısal kontrol:** aynı cesedi yalnız test kopyasında +4 piksel aşağı taşımak plakayı ve kapıyı açtı. Bu kaynak düzeltmesi değildir; nedenin doğrulanmasıdır. Algılama alanı/zemin oturuşu doğru kurulmalı.

Kaynak: `scenes/world/corpse.tscn:6` ve `:18`; `scenes/rooms/awakening.tscn:33` ve `:134`; `scripts/world/pressure_plate.gd:33` çevresi.

### 12. İyi son zinciri tanısal destekle çalışıyor — sınırlı başarı

Plaka testindeki +4 piksel ayarından sonra mühür, Bekçi güven konuşması, Core geçişi ve kristal etkileşimi çalıştırıldı. prep={weight:true, code:true, echo:true, trusted:true}, ending=2 elde edildi. Bu sonuç iş mantığının zincirini doğrular; plaka düzeltilmeden doğal rotanın tamamlandığını göstermez. Bu kontrol ayrı olarak `fixture_assisted_good_chain` adını taşıyor.

## Eski smoke neden yeşil?

İzole kopyada mevcut `TORIMON_SMOKE=1` yolu ayrıca çalıştırıldı. `existing_smoke.log` çıktısı:

`FAZ67_SMOKE ok curse_fail=true world=true bad=true good=true indicator=true`

Ancak `scripts/main.gd:93–97` ağırlık/kod çözümlerini, yankıyı, güveni ve kapıyı doğrudan ayarlıyor. Böylece gerçek plaka etkileşimi atlanıyor. Aynı şekilde headless final otomatik geçişi mobil sorunu atlıyor. Smoke'u silmek gerekmez; kapsamını “akış/bileşen kontrolü” olarak adlandırıp yanına gerçek rota testleri eklemek gerekir.

## Testten ayrı, kod okumasıyla görülen riskler

Bunlar yukarıdaki sekiz başarısız runtime kontrolüne eklenmemiştir:

- Journal görünürken fizik hareketinde genel modal kilit yok. Diyalog/yankı/oda geçişiyle aynı kontrol politikası gerekli.
- Corpse._push konumu adım adım değiştiriyor; duvar/kapı için sweep veya güvenli fizik çözümü görünmüyor. Dar koridorlar eklenince ayrıca sınanmalı.
- enter_awakening yeni Awakening checkpoint'i kurmuyor; önce Core checkpoint'i alınmış bir dönüşte oda/konum uyumu kontrol edilmeli. Şu an Core'da oyuncuya açık dönüş portalı da yok.
- Birden fazla odada ilk gruptaki nesneyi almak aktif oda garantisi vermez. Yalnız ceset değil yeni NPC/puzzle yönlendirmesinde de açık referans gerekir.
- Hazard açıldığında oyuncu zaten içindeyse aynı giriş olayının tekrar gelmesine güveniliyor olabilir. Önceki geçiş konumu ile arm olma zamanı ayrı test edilmeli.
- Final UI kapanınca EndingManager.current etkin kalıyor. Menü/yeni oyun akışı olmadığından oyuncu hareketsiz sahneye dönebilir.
- Mevcut üç ceset sınırı global. Yeni bölgelerin kritik mekanizmalarını tek bir eski cesede bağımlı yapmak ilerleme kaybı yaratabilir. Kalıcı çözüm durumu ve güvenli geri çağırma tasarlanmalı.

## Önerilen geliştirme sırası

1. Plaka, kayıt/restore ve puzzle eşitleme; aktif oda cesetleri; kontrol kilitleri; dokunmatik final.
2. Altı odalık Uyanış+Çürüme bölümü; yeni oyuncu için 15–25 dakika hedef. Gerçek sembol girişi ve bir yeni dünya izi kuralı.
3. Kütüphane, Deney, Ayna, Çekirdek: toplam 17 oda; her bölge farklı bir kuralı önce öğretip sonra birleştirsin.
4. İki finali bu ilerlemeye bağla. İlk odadaki üç vuruşu final koşulu olmaktan çıkar.
5. Gerçek oynanış ve Android testiyle süreyi ve kontrol hissini ölç. 60–90 dakika yalnız tam sürüm tasarım hedefi olarak kalsın.

Ayrıntılı, doğrudan kullanılabilir talimatlar `01`–`05` dosyalarında; tek başlangıç talimatı `MASTER_PROMPT.md` içinde.

## Yeniden çalıştırma

PowerShell 7'de, paket klasöründe:

```powershell
./Run-Audit.ps1 -ProjectPath 'C:\Users\Osman\OneDrive\Desktop\Projects プロジェクト\THE-ROOM-REMEMBERS'
```

Script yeni bir geçici proje ve benzersiz test kayıt alanları oluşturur; oyun kaynaklarına yazmaz. Test script'i `audit.gd`, ham kanıtlar `audit_*.json` ve ilgili `.log` dosyalarıdır. Mevcut sürümde başarısız davranışlar bulunduğundan runner'ın çıkış kodu 1 olması beklenir; süreçlerin açılması tek başına bütün kontrollerin geçtiği anlamına gelmez. Bu araç mevcut iki odalı sahne yollarına bağlı bir başlangıç denetimidir; oda yapısı değişince senaryolar da güncellenmelidir.

Teslim edilen PowerShell runner da ayrıca çalıştırıldı; benzersiz kullanıcı alanlarıyla aynı 10 senaryo / 19 kontrol / 11 başarılı / 8 başarısız sonucu tekrarlandı. Ayrı kanıtlar `runner-verification` klasöründedir.
