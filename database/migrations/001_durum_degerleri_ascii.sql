-- =============================================================================
-- MIGRATION 001: Durum / rol değerlerini tek (ASCII) yazıma indirme
--
-- Sorun : Baseline şemada (schema.sql) aynı anlam iki farklı değerle saklanabiliyordu
--         ('bos' ve 'boş', 'yonetici' ve 'yönetici' ...). Bu durum sorgularda ve
--         tetikleyicilerde tutarsızlığa yol açar (WHERE durum = 'bos' 'boş'u bulmaz).
-- Çözüm : Her değer için tek, ASCII yazım. Ekranda Türkçe etiketle gösterilir.
--
-- Sıra  : Önce eski CHECK kısıtları kaldırılır, sonra mevcut veri yeni yazıma
--         dönüştürülür, en son yeni CHECK kısıtları eklenir.
-- Tekrar çalıştırılabilir (idempotent) ve tek transaction içindedir: herhangi bir
-- adım hata verirse hiçbir değişiklik kalıcı olmaz.
-- =============================================================================

BEGIN;

-- 1) Eski kısıtları kaldır
ALTER TABLE Oda           DROP CONSTRAINT IF EXISTS oda_durum_check;
ALTER TABLE Personel      DROP CONSTRAINT IF EXISTS personel_gorev_check;
ALTER TABLE Kullanici     DROP CONSTRAINT IF EXISTS kullanici_rol_check;
ALTER TABLE Kullanici     DROP CONSTRAINT IF EXISTS chk_kullanici_iliski;
ALTER TABLE Rezervasyon   DROP CONSTRAINT IF EXISTS rezervasyon_durum_check;
ALTER TABLE TemizlikKaydi DROP CONSTRAINT IF EXISTS temizlikkaydi_durum_check;

-- 2) Mevcut veriyi yeni yazıma dönüştür
UPDATE Oda SET durum = 'bos'     WHERE durum = 'boş';
UPDATE Oda SET durum = 'bakimda' WHERE durum = 'bakımda';

UPDATE Personel SET gorev = 'kat_gorevlisi' WHERE gorev IN ('kat gorevlisi', 'kat görevlisi');
UPDATE Personel SET gorev = 'yonetici'      WHERE gorev = 'yönetici';

UPDATE Kullanici SET rol = 'yonetici' WHERE rol = 'yönetici';

UPDATE Rezervasyon SET durum = 'onayli'     WHERE durum = 'onaylı';
UPDATE Rezervasyon SET durum = 'tamamlandi' WHERE durum = 'tamamlandı';

UPDATE TemizlikKaydi SET durum = 'bakimda' WHERE durum = 'bakımda';

-- 3) Yeni kısıtları ekle (aynı adlarla)
ALTER TABLE Oda ADD CONSTRAINT oda_durum_check
    CHECK (durum IN ('bos', 'dolu', 'temizlikte', 'bakimda'));

ALTER TABLE Personel ADD CONSTRAINT personel_gorev_check
    CHECK (gorev IN ('resepsiyon', 'kat_gorevlisi', 'yonetici'));

ALTER TABLE Kullanici ADD CONSTRAINT kullanici_rol_check
    CHECK (rol IN ('misafir', 'resepsiyon', 'yonetici'));

-- Rol ile bağlı kayıt tutarlılığı:
--  misafir            -> yalnızca misafir_id dolu
--  resepsiyon/yonetici -> yalnızca personel_id dolu
--  yonetici           -> hiçbir kayda bağlı olmayan sistem yöneticisi de olabilir
ALTER TABLE Kullanici ADD CONSTRAINT chk_kullanici_iliski CHECK (
    (rol = 'misafir' AND misafir_id IS NOT NULL AND personel_id IS NULL) OR
    (rol IN ('resepsiyon', 'yonetici') AND personel_id IS NOT NULL AND misafir_id IS NULL) OR
    (rol = 'yonetici' AND personel_id IS NULL AND misafir_id IS NULL)
);

ALTER TABLE Rezervasyon ADD CONSTRAINT rezervasyon_durum_check
    CHECK (durum IN ('beklemede', 'onayli', 'iptal', 'tamamlandi'));

ALTER TABLE TemizlikKaydi ADD CONSTRAINT temizlikkaydi_durum_check
    CHECK (durum IN ('temizlendi', 'kontrol_bekliyor', 'bakimda'));

COMMIT;
