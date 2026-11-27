-- =============================================================================
-- ÖRNEK VERİ (SEED) TUTARLILIK KONTROLÜ
-- Ön koşul: seed.sql yüklenmiş olmalı. (run_all.sql'e dahil değildir; çünkü
--           run_all boş veritabanında da çalışabilmelidir.)
-- Yalnızca okuma yapar; ROLLBACK ile biter.
-- =============================================================================

BEGIN;
\ir _yardimci.sql

-- Şartname miktarları
SELECT pg_temp.esit_bekle('En az 20 oda',         $q$SELECT (count(*) >= 20)::text  FROM Oda$q$,         'true');
SELECT pg_temp.esit_bekle('En az 50 misafir',     $q$SELECT (count(*) >= 50)::text  FROM Misafir$q$,     'true');
SELECT pg_temp.esit_bekle('En az 200 rezervasyon', $q$SELECT (count(*) >= 200)::text FROM Rezervasyon$q$, 'true');

-- İş kuralları veride korunuyor
SELECT pg_temp.esit_bekle('Aynı odada çakışan aktif rezervasyon yok',
    $q$SELECT count(*)::text FROM Rezervasyon a JOIN Rezervasyon b
         ON a.oda_id = b.oda_id AND a.id < b.id
        AND a.durum <> 'iptal' AND b.durum <> 'iptal'
        AND daterange(a.giris_tarihi, a.cikis_tarihi) && daterange(b.giris_tarihi, b.cikis_tarihi)$q$, '0');
SELECT pg_temp.esit_bekle('Kapasiteyi aşan rezervasyon yok',
    $q$SELECT count(*)::text FROM Rezervasyon r JOIN Oda o ON o.id = r.oda_id
        JOIN OdaTipi ot ON ot.id = o.oda_tipi_id WHERE r.kisi_sayisi > ot.kapasite$q$, '0');
SELECT pg_temp.esit_bekle('Sezon fiyatları çakışmıyor',
    $q$SELECT count(*)::text FROM SezonFiyati a JOIN SezonFiyati b
         ON a.oda_tipi_id = b.oda_tipi_id AND a.id < b.id
        AND daterange(a.baslangic_tarihi, a.bitis_tarihi, '[]') && daterange(b.baslangic_tarihi, b.bitis_tarihi, '[]')$q$, '0');

-- Yaşam döngüsü tutarlılığı
SELECT pg_temp.esit_bekle('Her tamamlanan rezervasyonun kapalı konaklaması ve ödemesi var',
    $q$SELECT count(*)::text FROM Rezervasyon r
        LEFT JOIN Konaklama k ON k.rezervasyon_id = r.id
        LEFT JOIN Odeme o ON o.konaklama_id = k.id
       WHERE r.durum = 'tamamlandi' AND (k.gercek_cikis_zamani IS NULL OR o.id IS NULL)$q$, '0');
SELECT pg_temp.esit_bekle('İptal edilenlerin konaklaması yok',
    $q$SELECT count(*)::text FROM Rezervasyon r JOIN Konaklama k ON k.rezervasyon_id = r.id WHERE r.durum = 'iptal'$q$, '0');
SELECT pg_temp.esit_bekle('Açık konaklaması olan odalar = dolu odalar',
    $q$SELECT (
         (SELECT array_agg(DISTINCT r.oda_id ORDER BY r.oda_id) FROM Konaklama k
            JOIN Rezervasyon r ON r.id = k.rezervasyon_id WHERE k.gercek_cikis_zamani IS NULL)
         IS NOT DISTINCT FROM
         (SELECT array_agg(id ORDER BY id) FROM Oda WHERE durum = 'dolu'))::text$q$, 'true');
SELECT pg_temp.esit_bekle('Ödeme tutarı = sezon fiyatlı geceler + ek hizmetler',
    $q$SELECT count(*)::text FROM Odeme od
        JOIN Konaklama k   ON k.id = od.konaklama_id
        JOIN Rezervasyon r ON r.id = k.rezervasyon_id
        JOIN Oda o         ON o.id = r.oda_id
        JOIN OdaTipi ot    ON ot.id = o.oda_tipi_id
       WHERE od.tutar <> (
             (SELECT sum(COALESCE((SELECT sf.gecelik_fiyat FROM SezonFiyati sf
                                    WHERE sf.oda_tipi_id = o.oda_tipi_id
                                      AND g::date BETWEEN sf.baslangic_tarihi AND sf.bitis_tarihi), ot.temel_fiyat))
                FROM generate_series(r.giris_tarihi, r.cikis_tarihi - 1, interval '1 day') g)
           + (SELECT COALESCE(sum(kh.adet * eh.birim_fiyat), 0) FROM KonaklamaHizmeti kh
                JOIN EkHizmet eh ON eh.id = kh.hizmet_id WHERE kh.konaklama_id = k.id))$q$, '0');

-- View'lar veriyle dolu
SELECT pg_temp.esit_bekle('Bugün giriş yapacak misafir var',
    $q$SELECT (count(*) > 0)::text FROM vw_bugun_giris_cikis WHERE hareket = 'giris'$q$, 'true');
SELECT pg_temp.esit_bekle('Bugün çıkış yapacak misafir var',
    $q$SELECT (count(*) > 0)::text FROM vw_bugun_giris_cikis WHERE hareket = 'cikis'$q$, 'true');
SELECT pg_temp.esit_bekle('Oda durumu view''ı 20 odayı listeliyor',
    $q$SELECT count(*)::text FROM vw_oda_durumu$q$, (SELECT count(*)::text FROM Oda));
SELECT pg_temp.esit_bekle('IslemLog trigger ile dolmuş (en az rezervasyon + ödeme sayısı kadar INSERT)',
    $q$SELECT (count(*) >= (SELECT count(*) FROM Rezervasyon) + (SELECT count(*) FROM Odeme))::text
         FROM IslemLog WHERE islem_turu = 'INSERT'$q$, 'true');

\echo 'ÖRNEK VERİ KONTROLLERİ GEÇTİ'
ROLLBACK;
