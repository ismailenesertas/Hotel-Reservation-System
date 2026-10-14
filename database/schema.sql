-- =============================================================================
-- VERİTABANI YÖNETİM SİSTEMLERİ DERSİ PROJESİ
-- Proje: Otel Rezervasyon ve Konaklama Yönetim Sistemi
-- DBMS: PostgreSQL 15+
-- Normalizasyon: 3. Normal Form (3NF)
-- =============================================================================

-- Bağımlılık sırasına göre eski tabloları temizleme
DROP TABLE IF EXISTS IslemLog CASCADE;
DROP TABLE IF EXISTS TemizlikKaydi CASCADE;
DROP TABLE IF EXISTS Odeme CASCADE;
DROP TABLE IF EXISTS KonaklamaHizmeti CASCADE;
DROP TABLE IF EXISTS EkHizmet CASCADE;
DROP TABLE IF EXISTS Konaklama CASCADE;
DROP TABLE IF EXISTS Rezervasyon CASCADE;
DROP TABLE IF EXISTS Kullanici CASCADE;
DROP TABLE IF EXISTS Personel CASCADE;
DROP TABLE IF EXISTS Misafir CASCADE;
DROP TABLE IF EXISTS SezonFiyati CASCADE;
DROP TABLE IF EXISTS Oda CASCADE;
DROP TABLE IF EXISTS OdaTipi CASCADE;

-- -----------------------------------------------------------------------------
-- 1. ODA TİPİ (OdaTipi)
-- -----------------------------------------------------------------------------
CREATE TABLE OdaTipi (
    id SERIAL PRIMARY KEY,
    tip_adi VARCHAR(50) NOT NULL UNIQUE, -- standart, deluxe, suit vb.
    kapasite INT NOT NULL CHECK (kapasite > 0),
    aciklama TEXT,
    temel_fiyat NUMERIC(10, 2) NOT NULL CHECK (temel_fiyat >= 0)
);
COMMENT ON TABLE OdaTipi IS 'Oda kategorileri, kişi kapasitesi ve taban fiyat bilgisi';

-- -----------------------------------------------------------------------------
-- 2. ODA (Oda)
-- -----------------------------------------------------------------------------
CREATE TABLE Oda (
    id SERIAL PRIMARY KEY,
    oda_no VARCHAR(10) NOT NULL UNIQUE,
    kat INT NOT NULL,
    oda_tipi_id INT NOT NULL REFERENCES OdaTipi(id) ON DELETE RESTRICT,
    durum VARCHAR(20) NOT NULL DEFAULT 'bos' 
        CHECK (durum IN ('bos', 'boş', 'dolu', 'temizlikte', 'bakimda', 'bakımda'))
);
COMMENT ON TABLE Oda IS 'Fiziki odalar, kat bilgisi ve güncel doluluk/temizlik durumu';

-- -----------------------------------------------------------------------------
-- 3. SEZON FİYATI (SezonFiyati)
-- -----------------------------------------------------------------------------
CREATE TABLE SezonFiyati (
    id SERIAL PRIMARY KEY,
    oda_tipi_id INT NOT NULL REFERENCES OdaTipi(id) ON DELETE CASCADE,
    baslangic_tarihi DATE NOT NULL,
    bitis_tarihi DATE NOT NULL,
    gecelik_fiyat NUMERIC(10, 2) NOT NULL CHECK (gecelik_fiyat >= 0),
    CONSTRAINT chk_sezon_tarih CHECK (bitis_tarihi >= baslangic_tarihi)
);
COMMENT ON TABLE SezonFiyati IS 'Oda tiplerine göre dönemsel dinamik gecelik fiyatlar';

-- -----------------------------------------------------------------------------
-- 4. MİSAFİR (Misafir)
-- -----------------------------------------------------------------------------
CREATE TABLE Misafir (
    id SERIAL PRIMARY KEY,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    tc_pasaport_no VARCHAR(30) NOT NULL UNIQUE,
    telefon VARCHAR(20) NOT NULL,
    eposta VARCHAR(100) NOT NULL UNIQUE,
    dogum_tarihi DATE NOT NULL,
    kayit_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE Misafir IS 'Otelde kalan veya rezervasyon yapan konuk bilgileri';

-- -----------------------------------------------------------------------------
-- 5. PERSONEL (Personel)
-- -----------------------------------------------------------------------------
CREATE TABLE Personel (
    id SERIAL PRIMARY KEY,
    ad VARCHAR(50) NOT NULL,
    soyad VARCHAR(50) NOT NULL,
    gorev VARCHAR(30) NOT NULL 
        CHECK (gorev IN ('resepsiyon', 'kat gorevlisi', 'kat görevlisi', 'yonetici', 'yönetici')),
    ise_giris_tarihi DATE NOT NULL DEFAULT CURRENT_DATE,
    aktif BOOLEAN NOT NULL DEFAULT TRUE
);
COMMENT ON TABLE Personel IS 'Resepsiyon, temizlik ve yönetici personel kayıtları';

-- -----------------------------------------------------------------------------
-- 6. KULLANICI (Kullanici - JWT & Rol Tabanlı Yetkilendirme)
-- -----------------------------------------------------------------------------
CREATE TABLE Kullanici (
    id SERIAL PRIMARY KEY,
    kullanici_adi VARCHAR(50) NOT NULL UNIQUE,
    sifre_hash VARCHAR(255) NOT NULL,
    rol VARCHAR(20) NOT NULL 
        CHECK (rol IN ('misafir', 'resepsiyon', 'yonetici', 'yönetici')),
    misafir_id INT REFERENCES Misafir(id) ON DELETE CASCADE,
    personel_id INT REFERENCES Personel(id) ON DELETE CASCADE,
    olusturma_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_kullanici_iliski CHECK (
        (rol = 'misafir' AND misafir_id IS NOT NULL AND personel_id IS NULL) OR
        (rol IN ('resepsiyon', 'yonetici', 'yönetici') AND personel_id IS NOT NULL AND misafir_id IS NULL) OR
        (rol IN ('yonetici', 'yönetici') AND personel_id IS NULL AND misafir_id IS NULL) -- Süper yönetici esnekliği
    )
);
COMMENT ON TABLE Kullanici IS 'Sisteme giriş yapan hesaplar ve RBAC rolleri';

-- -----------------------------------------------------------------------------
-- 7. REZERVASYON (Rezervasyon)
-- -----------------------------------------------------------------------------
CREATE TABLE Rezervasyon (
    id SERIAL PRIMARY KEY,
    misafir_id INT NOT NULL REFERENCES Misafir(id) ON DELETE RESTRICT,
    oda_id INT NOT NULL REFERENCES Oda(id) ON DELETE RESTRICT,
    giris_tarihi DATE NOT NULL,
    cikis_tarihi DATE NOT NULL,
    kisi_sayisi INT NOT NULL CHECK (kisi_sayisi > 0),
    durum VARCHAR(20) NOT NULL DEFAULT 'beklemede' 
        CHECK (durum IN ('beklemede', 'onayli', 'onaylı', 'iptal', 'tamamlandi', 'tamamlandı')),
    olusturma_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rezervasyon_tarih CHECK (cikis_tarihi > giris_tarihi)
);
COMMENT ON TABLE Rezervasyon IS 'Tarih aralığı, oda ve misafir bazlı rezervasyon kayıtları';

-- -----------------------------------------------------------------------------
-- 8. KONAKLAMA (Konaklama - Fiili Check-in / Check-out)
-- -----------------------------------------------------------------------------
CREATE TABLE Konaklama (
    id SERIAL PRIMARY KEY,
    rezervasyon_id INT NOT NULL UNIQUE REFERENCES Rezervasyon(id) ON DELETE RESTRICT,
    gercek_giris_zamani TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    gercek_cikis_zamani TIMESTAMP,
    islemi_yapan_personel_id INT NOT NULL REFERENCES Personel(id) ON DELETE RESTRICT
);
COMMENT ON TABLE Konaklama IS 'Misafirin otele fiilen giriş ve çıkış yaptığı süre';

-- -----------------------------------------------------------------------------
-- 9. EK HİZMET (EkHizmet)
-- -----------------------------------------------------------------------------
CREATE TABLE EkHizmet (
    id SERIAL PRIMARY KEY,
    hizmet_adi VARCHAR(100) NOT NULL UNIQUE, -- Kahvaltı, Spa, Otopark, Oda Servisi vb.
    birim_fiyat NUMERIC(10, 2) NOT NULL CHECK (birim_fiyat >= 0)
);
COMMENT ON TABLE EkHizmet IS 'Otelde sunulan ücretli ekstra hizmet tanımları';

-- -----------------------------------------------------------------------------
-- 10. KONAKLAMA HİZMETİ (KonaklamaHizmeti)
-- -----------------------------------------------------------------------------
CREATE TABLE KonaklamaHizmeti (
    id SERIAL PRIMARY KEY,
    konaklama_id INT NOT NULL REFERENCES Konaklama(id) ON DELETE CASCADE,
    hizmet_id INT NOT NULL REFERENCES EkHizmet(id) ON DELETE RESTRICT,
    adet INT NOT NULL DEFAULT 1 CHECK (adet > 0),
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE KonaklamaHizmeti IS 'Konaklama süresince odaya yazılan ekstra harcamalar';

-- -----------------------------------------------------------------------------
-- 11. ÖDEME (Odeme)
-- -----------------------------------------------------------------------------
CREATE TABLE Odeme (
    id SERIAL PRIMARY KEY,
    konaklama_id INT NOT NULL REFERENCES Konaklama(id) ON DELETE RESTRICT,
    tutar NUMERIC(10, 2) NOT NULL CHECK (tutar >= 0),
    odeme_turu VARCHAR(20) NOT NULL CHECK (odeme_turu IN ('nakit', 'kart')),
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE Odeme IS 'Konaklama çıkışında tahsil edilen ödeme kayıtları';

-- -----------------------------------------------------------------------------
-- 12. TEMİZLİK KAYDI (TemizlikKaydi)
-- -----------------------------------------------------------------------------
CREATE TABLE TemizlikKaydi (
    id SERIAL PRIMARY KEY,
    oda_id INT NOT NULL REFERENCES Oda(id) ON DELETE RESTRICT,
    personel_id INT NOT NULL REFERENCES Personel(id) ON DELETE RESTRICT,
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    durum VARCHAR(30) NOT NULL DEFAULT 'temizlendi'
        CHECK (durum IN ('temizlendi', 'kontrol_bekliyor', 'bakimda', 'bakımda'))
);
COMMENT ON TABLE TemizlikKaydi IS 'Kat görevlilerinin oda temizlik ve kontrol geçmişi';

-- -----------------------------------------------------------------------------
-- 13. İŞLEM LOG (IslemLog - Tetikleyiciler Tarafından Doldurulacak)
-- -----------------------------------------------------------------------------
CREATE TABLE IslemLog (
    id SERIAL PRIMARY KEY,
    tablo_adi VARCHAR(50) NOT NULL,
    islem_turu VARCHAR(10) NOT NULL CHECK (islem_turu IN ('INSERT', 'UPDATE', 'DELETE')),
    kayit_id INT,
    eski_veri JSONB,
    yeni_veri JSONB,
    islem_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    aciklama TEXT
);
COMMENT ON TABLE IslemLog IS 'Tetikleyicilerin otomatik doldurduğu veri değişim denetim günlüğü';

-- =============================================================================
-- ŞARTNAME ZORUNLU İNDEKS TANIMLARI (Raporlama & Performans İçin)
-- =============================================================================

-- 1. Rezervasyon tarihleri indeksi (Tarih aralığı ve boş oda sorgularını hızlandırır)
CREATE INDEX idx_rezervasyon_tarihler ON Rezervasyon (giris_tarihi, cikis_tarihi);

-- 2. Çakışan rezervasyon tetikleyicisi performans indeksi
CREATE INDEX idx_rezervasyon_oda_tarih ON Rezervasyon (oda_id, giris_tarihi, cikis_tarihi, durum);

-- 3. Oda numarası indeksi
CREATE INDEX idx_oda_no ON Oda (oda_no);

-- 4. Misafir e-posta ve TC indeksi (Arama ve giriş işlemlerini hızlandırır)
CREATE INDEX idx_misafir_eposta ON Misafir (eposta);
CREATE INDEX idx_misafir_tc ON Misafir (tc_pasaport_no);

-- 5. Sezon fiyatı tarih arama indeksi
CREATE INDEX idx_sezon_fiyati_tarih ON SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi);