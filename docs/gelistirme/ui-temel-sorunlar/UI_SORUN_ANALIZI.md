# Ekran görüntülerine dayalı temel sorun analizi

6 Kasım 2026 · oyun 0.8.0 · Godot 4.7.2 · 640×360 temel alan.

İstenen çıktı, temel sorunları düzelttirecek ayrıntılı prompttur. Bu incelemede oyun kaynakları veya PNG'ler değiştirilmedi. Kaynaklar okundu, panel görselleri incelendi, projenin ayrı kopyasında motor içi ölçümler ve davranış kontrolleri çalıştırıldı. Ana teslim `TEMEL_SORUNLARI_DUZELT_PROMPT.md` dosyasıdır. Yeni bölge/oyun süresi genişletmesi bu işin kapsamına alınmadı.

## En önemli sonuç

Yazının kayması tek bir konum hatası değil: görselin gerçek panel bölgesi ile Control dikdörtgeni farklı; içerik yüksekliği sınırlandırılmamış; alt kontroller ve diyalog aynı yere yerleştirilmiş. Günlükte aynı görsel sınırı sorunu var ve modal giriş kilidi de eksik. Önceki paketteki panel görselleri doğrudan arayüzde kullanılacak kadar temiz ayrılmamış; alttaki fazladan süs de bu görsellerde mevcut.

## 1. Görselden kaynaklanan çerçeve kayması — doğrulandı

Her iki kaynak PNG 320×180. Alpha>8 bağlı bileşen ölçümünde diyalog ana çerçevesi `[62,3,257,115)`; alttaki ayrı süs `[86,149,234,177)`. Günlük ana kitap `[64,3,255,129)`; ayrı alt süs `[108,151,206,177)` ve küçük parçalar mevcut. Köşeli aralıkların sağ/alt değerleri hariçtir.

HUD bütün diyalog PNG'sini NinePatchRect dokusu olarak kullanıyor. Yazı, görünen süsün iç sınırına değil Control kenarına göre konuyor. Bu, kısa metnin bile çerçevenin solunda görünmesini açıklıyor. Alttaki ikinci dekor da aynı dosyadan geliyor. PNG'nin tam alpha bounding box'ını almak bu fazlalığı temizlemez; ana bileşenin seçilmesi gerekiyor. Kaynak görsel, temiz oyun paneliyle aynı şey değildir.

Günlükte TextureRect 400×240 alanın içinde bütün 320×180 görseli oranını koruyarak gösteriyor. Gerçek kitap yaklaşık `(200,51.25)` başlangıçlı, `238.75×157.5` boyutlu kalıyor. Başlık x=144, gövde x=144'te; dolayısıyla kitabın solundan 56 piksel önce başlıyorlar. Ana çerçeveyi seçmek ve içeriği gerçek kâğıt alanına bağlamak gerekir.

İlgili kaynaklar: `scenes/ui/hud.tscn`, `scenes/ui/journal.tscn`, `scripts/ui/hud_controller.gd`, `assets/panels/dialogue.png`, `assets/panels/journal.png`.

## 2. Uzun diyalog ekran dışına çıkıyor — motor içinde tekrarlandı

Panel `(64,236,512,104)`; normal metin alanı `(82,270,472,58)`. 1.248 karakterlik Türkçe test metni 15 satır üretti. Label minimum yüksekliği 297'ye çıktı ve alt kenarı y=567 oldu. Viewport altı y=360, panel altı y=340. Otomatik satır sarma tek başına yüksekliği sınırlandırmıyor. Clip kapalı ve max_lines_visible=-1.

Çözüm: gerçek iç yüksekliğe göre sayfalama, Container yerleşimi, devam göstergesi ve tam metin korunumu. Sadece clip açmak metni görünmez yapar; sorunu çözmez. Testte 40 karakterlik konuşmacı adı sığdı; tüm konuşmacıların taştığı iddia edilmiyor.

## 3. Diyalog ile mobil kontrol alanları kesişiyor — doğrulandı

Joystick görseli `(12,232,80,80)`, dash `(452,240,76,76)`, etkileşim `(536,276,76,76)`. Diyalog `(64,236,512,104)` ile bu bölgelerde kesişiyor. Bu, metin okunurken düğmelerin çerçeveye girmesini açıklıyor. Geometrik kesişme ölçüldü; her düğmenin tamamen tıklanamaz olduğu sonucuna varılmadı.

Hikâye diyaloğu ile kısa ortam sözünün kontrol davranışı ayrılmalı. Hikâye konuşmasında hareket/saldırı alanları kapatılabilir; devam düğmesi erişilebilir kalmalı. Mobil kontrol bölgesinin üstüne sürekli 104 piksel yüksekliğinde diyalog koymak mevcut düzene sığmıyor.

## 4. Günlük yerleşimi ve okunabilirlik — doğrulandı

Gövde `(144,116,336,134)`, Kapat `(400,240,80,28)`. Alanları 80×10 piksel kesişiyor. Kapat gerçek kitabın alt kenarından yaklaşık 31 piksel aşağıda başlıyor. Sekmeler ve başlık da kâğıt alanıyla ortak bir içerik düzeninde değil.

Gövde zaten kaydırılabilir ve clip açık; “günlükte hiç kaydırma yok” demek yanlış olur. Kaydırmanın varlığı, metnin kitap içinde hizalı olduğunu göstermez. Açık kâğıt üzerindeki soluk mor metin ayrıca zayıf okunuyor; koyu yazı ve ayrılmış gövde/alt düğme düzeni gerekiyor.

## 5. Günlük oyunun girişini durdurmuyor — davranışla doğrulandı

Günlük açıkken 0,2 saniyelik sağ hareket yaklaşık 22 piksel yer değiştirdi. Saldırı sinyali state'i attack yaptı ve saldırı alanını etkinleştirdi. Günlük açıkken etkileşim sinyali arkadaki diyaloğun kuyruğunu 1'den 0'a düşürdü. Player girişinde diyalog kontrolünün günlük kontrolünden önce olması bu sızıntıyla uyumlu.

Headless Input.parse_input_event dokunma denemesinde joystick etkinleşmedi; bu alt kontrol geçti fakat gerçek Android dokunma izolasyonunu kanıtlamıyor. HUD._input doğrudan çağrıldığında günlük açıkken joystick etkinleşip `(0.47619,0)` hareket üretti. Bu ikinci kontrol bir callback fixture'ıdır; gerçek kullanıcı dokunması diye sunulmamalı. Kodda modal koruması olmadığı için ayrıca değerlidir.

Yalnızca karartma Control'ünün mouse_filter ayarıyla çözülmez. HUD giriş işleyicisi, MobileInput sinyalleri ve oyuncu durumu ortak kilide uymalı; modal açılırken tutulan hareket temizlenmeli. Günlükte okurken tehlike/lanet zamanının davranışı ayrıca kararlaştırılmalı; yalnızca giriş kilidi dünyayı durdurmaz.

## 6. Diyalog temizleme paneli açık bırakıyor — doğrulandı

DialogueManager.clear() sonrası is_open=false iken HUD diyaloğu visible=true kaldı. Kuyruk yaşam döngüsüyle UI birbirinden kopabiliyor. İptal ve normal tamamlanma ayrılmalı. Körlemesine dialogue_closed yaymak tehlikeli bir düzeltme: mevcut bulmaca/güven tüketicileri kapanmayı başarı olarak yorumlayabilir. İptal yolunun oyun durumunu ilerletmediği de test edilmeli.

## 7. Çentik/güvenli alan düzeni — yapay inset ile tekrarlandı

L16/T8/R48/B12 uygulanan güvenli alan `(16,8,576,340)` oldu; sağ sınır 592, alt sınır 348. Etkileşim düğmesi sağda 628'e ve altta 360'a uzandı; güvenli alan dışına çıktı. Günlük düğmesi sağda 644'e uzandı; 640 genişlikli viewport'u da aştı. Parent küçülürken çocukların sabit offset'leri yeni kenarlara bağlanmıyor.

Bu, fiziksel çentikli telefonda yapılmış ölçüm değildir; düzenin sanal inset karşısındaki davranışıdır. Kod ayrıca ekran/pencere ölçülerini sabit 640×360 ile karıştırıyor; farklı oranlarda çizilen içerik alanının dönüşümü doğrulanmalı. Siyah yan bantlar `keep` ayarının beklenen sonucu olabilir; tek başına hata sayılmadı.

## 8. Fısıltı ve efektler — geometri doğrulandı, eşzamanlı görsel test gerekli

VFX fısıltı alanı `(160,280,320,28)` diyalog metniyle kesişiyor. VFX layer=15, HUD layer=10; efektler HUD'un üzerinde. Lanet ve konuşma olayları birlikte geldiğinde metin çakışması/okunabilirlik sorunu riski var. Bu kontrolde geometri ölçüldü; belirli bir normal oyun anında iki metnin aynı anda render edildiği kanıtlanmadı.

Fısıltı başına yeni tween oluşturulup öncekiler iptal edilmiyor; eski gizleme callback'inin yeni mesajı erkenden kapatması koddan çıkarılan olası yarış durumudur, bu turda davranışla tekrar edilmedi.

## 9. Önceki temel oyun sorunları hâlâ dikkate alınmalı

Önceki incelemenin testleri bu tur yeniden topluca çalıştırılmadı; ilgili kaynaklar karşılaştırıldı/okundu. Ayrıntılı kanıt ve sınırlamalar üst klasördeki INCELEME_TEST_RAPORU.md ve eski JSON dosyalarında.

- Dosyaya kayıt yazılması var, başlangıç yükleme akışı ve PuzzleManager durum senkronizasyonu eksik.
- Cesedin doğal oturuşu ağırlık plakası sınırını yaklaşık 1 piksel kaçırıyor; aşağı kaydırılmış fixture doğal çözüm kanıtı değil.
- Ölüm sırasında normal hareket akışı sürüyor.
- Çekirdek cesedi gruptaki ilk world_root olan görünmez Uyanış'a eklenebiliyor.
- Hafıza mührü boş olmayan yanlış kodu da kabul ediyor; oyuncuya gerçek giriş arayüzü eksik.
- Finalde dokunmatik ilerleme eksik; headless otomatik ilerleme bunu maskeleyebiliyor.
- Kontrol açıklamasındaki WASD ile InputMap uyuşmuyor.
- Bekçi'ye üç vuruşla Uyanış'ta kötü sona ulaşılabilmesi kısa sürenin önemli tasarım nedenlerinden. Bu, arayüz düzeltmesiyle çözülmez; yeni içerik eklemeden önce mevcut son şartları açıkça tanımlanmalı.

## Sorun diye işaretlenmeyen noktalar

- Günlük gövdesinde kaydırma zaten açık.
- 40 karakterlik konuşmacı testte panel içinde kaldı.
- Shiren ve Bekçi'nin ayrı ayrı 16 animasyon karesinde alpha taban çizgileri tutarlı: Shiren frame alt sınırı 92, Bekçi 124; mevcut sprite offset'leriyle ikisi de kök y=0 tabanına oturuyor. Ekran görüntüsünden hareketle “bütün animasyonların ayak pivotu bozuk” sonucu çıkarılmadı. Gerçek animasyon oynanışı ayrıca gözle değerlendirilmeli.
- Farklı oranlardaki siyah bantlar otomatik hata değildir.

## Test kapsamı ve kullanım

`ui_audit.json`: 14 beklenti, 3 geçen, 11 geçmeyen kontrol. Her geçmeyen beklenti ayrı bir bağımsız kök hata değildir; örneğin kitap yerleşimi birkaç beklentiyi birlikte etkiliyor. Test scriptinin çıkış kodu 0 olması scriptin tamamlandığını gösterir, ürünün geçtiğini değil. Yeni çalıştırıcı başarısız beklentiler varsa 1 döndürür.

`ui_audit.gd` ayrı proje kopyasında gerçek sahneyi açıp motorun Control ölçülerini ve bazı davranışları okur. Test, headless ve sabit 640×360 viewport ile çalıştı. Doğrudan callback, geometri ve sanal inset senaryoları JSON içinde işaretli. Gerçek Android çoklu dokunma, notch, geri hareketi, görsel render, cihaz performansı ve insan oynanış süresi doğrulanmadı. APK bu tur yeniden üretilmedi.

Yeniden çalıştırmak için bu klasörde PowerShell ile: `./UI_TESTINI_CALISTIR.ps1 -ProjectPath 'PROJE_KLASORU'`. Motor adı PATH'te yoksa `-GodotPath 'GODOT_EXE_TAM_YOLU'` ver. Test kopyası ve test kullanıcı verisi ayrı tutulur; sonuçların yeri ekrana yazılır. Kaynak proje düzeni değiştirilirse scriptte düğüm yolları güncellenmelidir. Script bir düzeltme aracı değildir, mevcut hataları gösterir.

## Resmî araştırmanın sonucu

Godot'un [NinePatchRect](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html) ve [AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html) belgeleri kaynak bölgesi seçimini; [Container](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) belgesi ortak içerik yerleşimini destekliyor. Bu proje için temiz çerçeve bölgesi + ortak içerik kapsayıcısı yaklaşımı buradan geliyor; önerilen piksel koordinatları ise yerel dosyaların ölçümüdür.

[Çoklu çözünürlük rehberi](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) oran/anchor kararları için; [DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html) ekran güvenli alanının anlamı için kullanıldı. [TouchScreenButton](https://docs.godotengine.org/en/stable/classes/class_touchscreenbutton.html) çoklu dokunmayı destekler, ancak Node2D oluşu nedeniyle Button yerine düşünmeden konamaz. Öneriler kurulu motor üzerinde çalıştırılarak doğrulanmalıdır.
