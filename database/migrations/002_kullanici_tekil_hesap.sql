-- =============================================================================
-- MIGRATION 002: Her misafir ve personel için en fazla bir kullanıcı hesabı
--
-- Sorun : Kullanici.misafir_id ve Kullanici.personel_id UNIQUE değildi; aynı
--         misafire/personele birden fazla giriş hesabı açılabiliyordu
--         (ilişki fiilen 1:N oluyordu).
-- Çözüm : İki sütuna UNIQUE kısıtı -> ilişki 1:0..1 olur.
--         PostgreSQL'de UNIQUE sütunda birden fazla NULL'a izin verilir; bu yüzden
--         misafir_id'si NULL olan personel hesapları birbirini engellemez.
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

ALTER TABLE Kullanici DROP CONSTRAINT IF EXISTS uq_kullanici_misafir;
ALTER TABLE Kullanici ADD CONSTRAINT uq_kullanici_misafir UNIQUE (misafir_id);

ALTER TABLE Kullanici DROP CONSTRAINT IF EXISTS uq_kullanici_personel;
ALTER TABLE Kullanici ADD CONSTRAINT uq_kullanici_personel UNIQUE (personel_id);

COMMIT;
