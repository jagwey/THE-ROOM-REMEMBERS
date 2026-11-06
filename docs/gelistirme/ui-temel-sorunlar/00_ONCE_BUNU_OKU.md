# Temel sorunlar paketi

Başlangıç: **TEMEL_SORUNLARI_DUZELT_PROMPT.md** dosyasının tamamını geliştirmeyi yapacak asistana ver. Bu paket sorunları inceler ve uygulanacak işi tarif eder; oyun koduna düzeltme uygulanmadı.

- `UI_SORUN_ANALIZI.md`: nedenler, ölçüler, doğrulanan ve henüz doğrulanmayan davranışlar.
- `ui_audit.gd`: motor içi inceleme senaryosu; oyun tarafından import edilmemesi için klasörde .gdignore var.
- `UI_TESTINI_CALISTIR.ps1`: orijinal projeyi değiştirmeden ayrı kopyada testi çalıştırır.
- `ui_audit.json`, `ui_audit.log`, `summary.json`: çalıştırıcının bağımsız yeniden denemesinden sonuçlar. 14 beklenti, 3 geçen, 11 geçmeyen. Çıkış kodu 1 mevcut hataların yakalandığını gösterir.
- `panel_olcumleri.json`: PNG ana çerçevesi ve alttaki ayrı süslerin alpha bileşen ölçüleri; dosyalar yeniden çizilmedi/kırpılmadı.
- `kaynak_koruma_kontrolu.json`: bu inceleme boyunca 44 kaynak/config/panel girdisinin değişmediğini gösteren hash karşılaştırması.
- `kullanici-gunluk.png`, `kullanici-diyalog.png`: kullanıcının gönderdiği başlangıç görüntüleri. Yeni render veya düzeltilmiş ekran görüntüsü değildir.

Önerilen iş sırası: görsel kaynak bölgesi → ortak içerik düzeni ve sayfalama → günlük → modal giriş/iptal yaşam döngüsü → güvenli alan ve mobil → temel oynanış gerileme testleri. İçerik büyütme promptlarını bundan sonra uygulat.

Gerçek Android dokunma, cihaz çentiği, cihaz performansı ve düzeltme sonrası görsel doğrulama bu incelemede yapılmadı. Hiçbir otomatik test sonucu insan oynama süresini kanıtlamaz.
