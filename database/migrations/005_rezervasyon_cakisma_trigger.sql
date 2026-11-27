-- =============================================================================
-- MIGRATION 005: Çakışan tarihli rezervasyonu engelleyen TRIGGER
-- (Şartname: Zorunlu Trigger 1 - sistemin en önemli iş kuralı)
--
-- Kural : Aynı oda, tarihleri kesişen iki AKTİF rezervasyona sahip olamaz.
--         Aktif = durumu 'iptal' olmayan rezervasyon.
--         Tarihler yarı açık aralıktır: [giris_tarihi, cikis_tarihi)
--         -> çıkış günü dahil değildir; bir misafirin çıktığı gün aynı odaya
--            yeni misafir girebilir (otelcilikteki gerçek kullanım).
-- Ne zaman: INSERT'te ve oda/tarih/durum değiştiren UPDATE'te çalışır.
--         Böylece iptal edilmiş bir rezervasyonu çakışan tarihte yeniden
--         aktif yapmak da engellenir.
-- Eşzamanlılık: Kontrol öncesi Oda satırı FOR UPDATE ile kilitlenir. Aynı odaya
--         aynı anda gelen iki istek sırayla değerlendirilir; ikinci istek ilkinin
--         sonucunu görür. (Kilit olmasaydı ikisi de "çakışma yok" görüp
--         kaydedilebilirdi.)
-- Not   : fn_rezervasyon_cakisma_kontrol bir trigger FONKSİYONUDUR (RETURNS trigger).
-- Tekrar çalıştırılabilir ve tek transaction içindedir.
-- =============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION fn_rezervasyon_cakisma_kontrol()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    cakisan RECORD;
BEGIN
    -- İptal edilen rezervasyon odayı bloke etmez; kontrole gerek yok
    IF NEW.durum = 'iptal' THEN
        RETURN NEW;
    END IF;

    -- Geçersiz aralık (çıkış <= giriş): BEFORE trigger CHECK'ten önce çalışır;
    -- değerlendirmeyi anlamlı hata veren chk_rezervasyon_tarih kısıtına bırak.
    IF NEW.cikis_tarihi <= NEW.giris_tarihi THEN
        RETURN NEW;
    END IF;

    -- Aynı odaya yapılan eşzamanlı rezervasyonları sıraya sok
    PERFORM 1 FROM Oda WHERE id = NEW.oda_id FOR UPDATE;

    SELECT r.id, r.giris_tarihi, r.cikis_tarihi INTO cakisan
    FROM Rezervasyon r
    WHERE r.oda_id = NEW.oda_id
      AND r.id <> NEW.id                         -- güncellemede kaydın kendisi hariç
      AND r.durum <> 'iptal'
      AND daterange(r.giris_tarihi, r.cikis_tarihi, '[)')
       && daterange(NEW.giris_tarihi, NEW.cikis_tarihi, '[)')
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Rezervasyon çakışması: oda % için % - % tarihleri, #% numaralı rezervasyonla (% - %) çakışıyor',
            NEW.oda_id, NEW.giris_tarihi, NEW.cikis_tarihi,
            cakisan.id, cakisan.giris_tarihi, cakisan.cikis_tarihi
            USING ERRCODE = 'exclusion_violation';   -- SQLSTATE 23P01 (API: 409 Conflict)
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rezervasyon_cakisma ON Rezervasyon;
CREATE TRIGGER trg_rezervasyon_cakisma
    BEFORE INSERT OR UPDATE OF oda_id, giris_tarihi, cikis_tarihi, durum
    ON Rezervasyon
    FOR EACH ROW
    EXECUTE FUNCTION fn_rezervasyon_cakisma_kontrol();

COMMIT;
