-- =============================================================================
-- ORTAK TEST YARDIMCILARI
-- Test dosyaları bu dosyayı BEGIN'den sonra "\ir _yardimci.sql" ile yükler.
-- pg_temp şemasındaki fonksiyonlar yalnızca o oturumda vardır ve test sonundaki
-- ROLLBACK ile birlikte kaybolur.
-- =============================================================================

-- Verilen SQL'in belirtilen SQLSTATE hata koduyla REDDEDİLMESİNİ bekler.
-- 23514 check_violation, 23505 unique_violation,
-- 23503 foreign_key_violation, 23502 not_null_violation, P0001 raise_exception
CREATE FUNCTION pg_temp.hata_bekle(p_aciklama text, p_sqlstate text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    calisti boolean := false;
BEGIN
    BEGIN
        EXECUTE p_sql;
        calisti := true;
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE <> p_sqlstate THEN
            RAISE EXCEPTION 'BAŞARISIZ: % -> beklenen hata %, gelen % (%)',
                p_aciklama, p_sqlstate, SQLSTATE, SQLERRM;
        END IF;
        RAISE NOTICE 'GEÇTİ   : % (reddedildi: %)', p_aciklama, SQLSTATE;
    END;
    IF calisti THEN
        RAISE EXCEPTION 'BAŞARISIZ: % -> hata bekleniyordu ama sorgu çalıştı', p_aciklama;
    END IF;
END $$;

-- Verilen SQL'in HATASIZ çalışmasını bekler (geçerli veri kabul edilmeli).
CREATE FUNCTION pg_temp.basari_bekle(p_aciklama text, p_sql text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE p_sql;
    RAISE NOTICE 'GEÇTİ   : % (kabul edildi)', p_aciklama;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'BAŞARISIZ: % -> kabul edilmeliydi ama hata verdi: % (%)',
        p_aciklama, SQLSTATE, SQLERRM;
END $$;

-- Verilen sorgunun sonucunun beklenen değere eşit olmasını bekler.
CREATE FUNCTION pg_temp.esit_bekle(p_aciklama text, p_sorgu text, p_beklenen text)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    gelen text;
BEGIN
    EXECUTE p_sorgu INTO gelen;
    IF gelen IS DISTINCT FROM p_beklenen THEN
        RAISE EXCEPTION 'BAŞARISIZ: % -> beklenen "%", gelen "%"', p_aciklama, p_beklenen, gelen;
    END IF;
    RAISE NOTICE 'GEÇTİ   : % (= %)', p_aciklama, gelen;
END $$;
