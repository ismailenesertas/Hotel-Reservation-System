# Otel Rezervasyon ve Konaklama Yönetim Sistemi 🏨

Bu proje, bir otel işletmesinin rezervasyon, konaklama, ödeme ve personel süreçlerini uçtan uca yönetmek amacıyla geliştirilmiş kapsamlı bir otomasyon sistemidir. İlişkisel veritabanı mimarisi (3NF), katmanlı backend yapısı ve RESTful API prensipleri kullanılarak tasarlanmıştır.

## 🚀 Kullanılan Teknolojiler

- **Backend:** Flask / Python
- **Mimari:** Katmanlı Mimari (Entity, Repository, Service, Controller Blueprint yapısı)
- **Veritabanı:** PostgreSQL / MSSQL (SQLAlchemy ile)
- **Kimlik Doğrulama:** JWT (JSON Web Token)
- **API Belgelendirme ve Test:** Swagger (Flasgger), Postman

## 🏗️ Veritabanı Mimarisi ve İş Kuralları

Sistem, iş kurallarını yalnızca uygulama katmanında değil, doğrudan veritabanı seviyesinde koruyacak şekilde tasarlanmıştır:
- **3NF Normalizasyon:** En az 13 tablodan oluşan (Oda, Misafir, Rezervasyon, Konaklama vb.) optimize edilmiş yapı.
- **Tetikleyiciler (Triggers):** 
  - Çakışan tarihli rezervasyonları engelleme.
  - Check-in/out anında oda durumlarını (dolu, temizlikte vb.) otomatik güncelleme.
  - Sistemdeki kritik değişiklikleri `IslemLog` tablosuna kaydetme.
- **Saklı Yordamlar (Stored Procedures):** Boş oda arama, sezonluk fiyat + ek hizmetlere göre toplam tutar hesaplama ve aylık doluluk/gelir raporları üretme.
- **Görünümler (Views):** Günlük giriş/çıkış listeleri ve anlık oda durumlarının takibi.
- **İşlemler (Transactions):** Check-out ve ödeme süreçlerinde veri tutarlılığını sağlamak için ROLLBACK yapısı.

## 👥 Kullanıcı Rolleri ve Özellikler

Sistem, JWT tabanlı rol yetkilendirmesi ile 3 farklı kullanıcı tipine hizmet verir:
1. **Misafir:** Kayıt/giriş yapabilir, boş oda arayabilir, rezervasyon oluşturabilir/iptal edebilir ve geçmiş konaklamalarını görüntüleyebilir.
2. **Resepsiyon:** Günlük misafir listesini yönetir, check-in ve check-out işlemlerini gerçekleştirir, konaklama hesabına ek hizmet (spa, oda servisi vb.) yazar ve ödeme alır.
3. **Yönetici (Admin):** Oda, oda tipi, sezon fiyatı ve personel bilgilerini yönetir (CRUD). Sistemin aylık mali ve doluluk raporlarını inceler.

## 👨‍💻 Geliştirici
- **İsmail Enes Ertaş** - Karadeniz Teknik Üniversitesi / Yazılım Mühendisliği
