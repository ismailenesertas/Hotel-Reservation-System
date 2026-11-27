-- =============================================================================
-- MIGRATION 004: Aynı oda tipi için sezon fiyatı dönemleri çakışamaz (TRIGGER)
--
-- Neden : Toplam tutar "her gecenin o geceye ait sezon fiyatı" ile hesaplanır.
--         Aynı gece için iki sezon fiyatı olursa hangisinin kullanılacağı belirsizdir.
-- Kural : Aynı oda tipinin iki dönemi tek bir günde bile kesişemez.
--         Dönemler kapalı aralıktır: [baslangic_tarihi, bitis_tarihi]
--         (bitiş günü de sezona dahildir), örn. 1-10 Haziran ile 10-20 Haziran çakışır.
-- Eşzamanlılık: Kontrol öncesi ilgili OdaTipi satırı FOR UPDATE ile kilitlenir;
--         aynı oda tipine aynı anda gelen iki ekleme sırayla değerlendirilir.
-- Not   : fn_sezon_cakisma_kontrol bir trigger FONKSİYONUDUR (RETURNS trigger).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_sezon_cakisma_kontrol()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    cakisan_id INT;
BEGIN
    -- Geçersiz aralık (bitiş < başlangıç): BEFORE trigger CHECK'ten önce çalışır.
    -- daterange() burada kendi hatasını verirdi; değerlendirmeyi anlamlı hata
    -- mesajı veren chk_sezon_tarih kısıtına bırakıyoruz.
    IF NEW.bitis_tarihi < NEW.baslangic_tarihi THEN
        RETURN NEW;
    END IF;

    -- Aynı oda tipine yapılan eşzamanlı eklemeleri sıraya sok
    PERFORM 1 FROM OdaTipi WHERE id = NEW.oda_tipi_id FOR UPDATE;

    SELECT s.id INTO cakisan_id
    FROM SezonFiyati s
    WHERE s.oda_tipi_id = NEW.oda_tipi_id
      AND s.id <> NEW.id                       -- güncellemede kaydın kendisi hariç
      AND daterange(s.baslangic_tarihi, s.bitis_tarihi, '[]')
       && daterange(NEW.baslangic_tarihi, NEW.bitis_tarihi, '[]')   -- && : kesişiyor mu?
    LIMIT 1;

    IF cakisan_id IS NOT NULL THEN
        RAISE EXCEPTION 'Sezon fiyatı çakışması: oda tipi % için % - % dönemi, #% numaralı sezon fiyatıyla kesişiyor',
            NEW.oda_tipi_id, NEW.baslangic_tarihi, NEW.bitis_tarihi, cakisan_id
            USING ERRCODE = 'exclusion_violation';   -- SQLSTATE 23P01
    END IF;

    RETURN NEW;   -- BEFORE trigger: NEW döndürülürse işlem devam eder
END;
$$;

DROP TRIGGER IF EXISTS trg_sezon_cakisma ON SezonFiyati;
CREATE TRIGGER trg_sezon_cakisma
    BEFORE INSERT OR UPDATE OF oda_tipi_id, baslangic_tarihi, bitis_tarihi
    ON SezonFiyati
    FOR EACH ROW
    EXECUTE FUNCTION fn_sezon_cakisma_kontrol();

COMMIT;
