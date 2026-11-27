# Otel Rezervasyon ve Konaklama Yönetim Sistemi 🏨

Bu proje, bir otel işletmesinin rezervasyon, konaklama, ödeme ve personel süreçlerini uçtan uca yönetmek amacıyla geliştirilmiş kapsamlı bir otomasyon sistemidir. İlişkisel veritabanı mimarisi (3NF), katmanlı backend yapısı ve RESTful API prensipleri kullanılarak tasarlanmıştır.

## 🚀 Kullanılan Teknolojiler

- **Backend:** Flask / Python
- **Mimari:** Katmanlı Mimari (Entity, Repository, Service, Controller Blueprint yapısı)
- **Veritabanı:** PostgreSQL
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

## ⚙️ Kurulum ve Çalıştırma

Gereksinimler: Python 3.10+, Docker Desktop. Komutlar proje kök dizininde PowerShell ile çalıştırılır.

### 1. Ortam değişkenleri
```powershell
Copy-Item backend\.env.example backend\.env
python -c "import secrets; print(secrets.token_hex(32))"   # SECRET_KEY için
python -c "import secrets; print(secrets.token_hex(32))"   # JWT_SECRET_KEY için
```
`backend/.env` içinde `SECRET_KEY`, `JWT_SECRET_KEY` ve `DB_PASS` değerlerini doldurun. Bu üç değer zorunludur; eksikse uygulama açık bir hata mesajıyla durur.
Gerçek değerler yalnızca `backend/.env` dosyasına yazılır. Bu dosya Git'e eklenmez; `.env.example` yalnızca şablondur.

### 2. Veritabanı (PostgreSQL, Docker)
```powershell
docker compose --env-file backend/.env up -d --wait
```
- Kullanıcı, parola, veritabanı adı ve port `backend/.env` dosyasından okunur. Port yalnızca `127.0.0.1` üzerinden açılır.
- Parola yalnızca veritabanı volume'ü **ilk** oluşturulurken uygulanır; `.env`'deki parolayı sonradan değiştirmek mevcut veritabanının parolasını değiştirmez.

Şemayı yükleme (**yalnızca ilk kurulumda** — betik mevcut tabloları silip yeniden oluşturur):
```powershell
docker cp database/schema.sql otel_postgres_db:/tmp/schema.sql
docker exec otel_postgres_db psql -U postgres -d otel_db -v ON_ERROR_STOP=1 -f /tmp/schema.sql
```

### 3. Backend (Flask)
```powershell
python -m venv .venv
.venv\Scripts\python -m pip install -r requirements.txt
cd backend
..\.venv\Scripts\python run.py
```
Sunucu varsayılan olarak `http://127.0.0.1:5000` adresinde, debug kapalı çalışır (geliştirme için `backend/.env` içinde `FLASK_DEBUG=1`).
Veritabanı bağlantı testi: `http://127.0.0.1:5000/api/db-test`

## 👨‍💻 Geliştirici
- **İsmail Enes Ertaş** - Karadeniz Teknik Üniversitesi / Yazılım Mühendisliği
