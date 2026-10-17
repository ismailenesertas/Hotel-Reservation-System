# Hastane Otomasyonu — Veritabanı Tasarımı

Bu klasör, Veritabanı Yönetim Sistemleri dersindeki hastane otomasyonu ödevi için hazırlanmıştır. Otel rezervasyon projesinin mevcut dosyalarına dokunmadan, bağımsız bir klasörde tutulur.

## İçerik
- [Varlık-İlişki Diyagramı ve tasarım açıklaması](erd.md)
- [PostgreSQL tablo oluşturma betiği](schema.sql)

## Modelleme kararları
- **1:N ilişkiler**, N tarafındaki tabloya yabancı anahtar eklenerek modellenir: Doktor → Poliklinik, Tahlil → Laboratuvar, Hemşire → Servis, Servis → Poliklinik.
- **Hasta–Poliklinik N:M** ilişkisi `Muayene` ara tablosuyla çözülür.
- Hastanın yaptırdığı tahlil ve bu tahlili isteyen doktor bilgisini aynı olayda tutmak için `TahlilIstem` ilişki tablosu kullanılır. Her kayıt bir hasta, bir doktor ve bir tahlil türü arasındaki istemi temsil eder.
- Her tabloda birincil anahtar; ilişkilerde yabancı anahtar kullanılır.

## Çalıştırma
PostgreSQL üzerinde `schema.sql` dosyasını çalıştırabilirsiniz. Betik tablo yapısını oluşturur; örnek hasta/işlem verileri eklemez.

> Bu bir ders prototipidir; gerçek hasta verileri veya üretim ortamı için tasarlanmamıştır.
