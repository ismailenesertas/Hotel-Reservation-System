-- =============================================================================
-- ÖRNEK VERİ (SEED)
-- Şartname: en az 20 oda, 50 misafir, 200 rezervasyon.
--
-- Ön koşul : schema.sql ve migrate.sql uygulanmış, tablolar BOŞ olmalı.
--            Veri varsa betik hiçbir şey yapmadan hata ile durur
--            (mevcut veriyi silmez; TRUNCATE/DELETE kullanmaz).
-- Tarihler : Bugüne (CURRENT_DATE) göre üretilir: son 120 gün geçmiş konaklamalar,
--            şu an otelde kalanlar, bugün giriş/çıkış yapacaklar ve önümüzdeki
--            45 günün rezervasyonları. setseed sayesinde aynı gün çalıştırılan
--            betik aynı veriyi üretir.
-- Trigger'lar: Veri trigger'lar AÇIKKEN eklenir. Çakışma ve kapasite kuralları
--            örnek veriyi de doğrular; oda durumları check-in/out ve temizlik
--            trigger'larıyla oluşur; rezervasyon/ödeme kayıtları IslemLog'a düşer.
-- Kullanıcı hesapları: parola hash'i gerektirdiği için backend (auth) aşamasında
--            ayrı olarak oluşturulur.
-- Tek transaction: herhangi bir adım hata verirse hiçbir veri eklenmez.
-- =============================================================================
\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM Oda) OR EXISTS (SELECT 1 FROM Misafir)
       OR EXISTS (SELECT 1 FROM Rezervasyon) OR EXISTS (SELECT 1 FROM OdaTipi) THEN
        RAISE EXCEPTION 'Seed yalnızca boş veritabanında çalışır: tablolarda veri var, hiçbir şey eklenmedi.';
    END IF;
END $$;

SELECT setseed(0.42);   -- tekrarlanabilir rastgelelik

-- -----------------------------------------------------------------------------
-- Oda tipleri ve odalar (4 kat x 5 oda = 20 oda; her katta 3 standart, 1 deluxe, 1 suit)
-- -----------------------------------------------------------------------------
INSERT INTO OdaTipi (tip_adi, kapasite, aciklama, temel_fiyat) VALUES
    ('standart', 2, 'Çift kişilik standart oda',            1500),
    ('deluxe',   3, 'Geniş, şehir manzaralı oda',          2500),
    ('suit',     4, 'Oturma salonlu, deniz manzaralı suit', 4000);

INSERT INTO Oda (oda_no, kat, oda_tipi_id)
SELECT (kat * 100 + sira)::text,
       kat,
       (SELECT id FROM OdaTipi
         WHERE tip_adi = CASE WHEN sira <= 3 THEN 'standart' WHEN sira = 4 THEN 'deluxe' ELSE 'suit' END)
FROM generate_series(1, 4) AS kat, generate_series(1, 5) AS sira
ORDER BY kat, sira;

-- -----------------------------------------------------------------------------
-- Sezon fiyatları: geçen yıl, bu yıl ve gelecek yıl; her yıl 3 dönem
-- (Ocak-Mayıs normal, Haziran-Eylül yaz +%40, Ekim-Aralık kış -%10)
-- -----------------------------------------------------------------------------
INSERT INTO SezonFiyati (oda_tipi_id, baslangic_tarihi, bitis_tarihi, gecelik_fiyat)
SELECT ot.id, d.baslangic, d.bitis, round(ot.temel_fiyat * d.carpan)
FROM OdaTipi ot
CROSS JOIN generate_series(EXTRACT(YEAR FROM CURRENT_DATE)::int - 1,
                           EXTRACT(YEAR FROM CURRENT_DATE)::int + 1) AS y
CROSS JOIN LATERAL (VALUES
    (make_date(y, 1, 1),  make_date(y, 5, 31),  1.00),
    (make_date(y, 6, 1),  make_date(y, 9, 30),  1.40),
    (make_date(y, 10, 1), make_date(y, 12, 31), 0.90)
) AS d(baslangic, bitis, carpan)
ORDER BY ot.id, d.baslangic;

-- -----------------------------------------------------------------------------
-- Personel ve ek hizmetler
-- -----------------------------------------------------------------------------
INSERT INTO Personel (ad, soyad, gorev, ise_giris_tarihi) VALUES
    ('Elif',   'Yılmaz', 'yonetici',      '2019-03-01'),
    ('Burak',  'Demir',  'yonetici',      '2020-06-15'),
    ('Selin',  'Kaya',   'resepsiyon',    '2021-02-01'),
    ('Emre',   'Çelik',  'resepsiyon',    '2022-04-11'),
    ('Deniz',  'Şahin',  'resepsiyon',    '2023-09-18'),
    ('Ayten',  'Arslan', 'kat_gorevlisi', '2020-01-06'),
    ('Murat',  'Koç',    'kat_gorevlisi', '2021-07-19'),
    ('Hülya',  'Aydın',  'kat_gorevlisi', '2024-03-04');

INSERT INTO EkHizmet (hizmet_adi, birim_fiyat) VALUES
    ('Kahvaltı',     250),
    ('Spa',          900),
    ('Otopark',      150),
    ('Oda Servisi',  400),
    ('Çamaşırhane',  200);

-- -----------------------------------------------------------------------------
-- 50 misafir (ad/soyad listelerinden üretilir; iletişim bilgileri sahte)
-- -----------------------------------------------------------------------------
INSERT INTO Misafir (ad, soyad, tc_pasaport_no, telefon, eposta, dogum_tarihi)
SELECT
    (ARRAY['Ahmet','Ayşe','Mehmet','Fatma','Mustafa','Zeynep','Ali','Emine','Hüseyin','Hatice',
           'İbrahim','Merve','Hasan','Elif','Yusuf','Büşra','Ömer','Esra','Can','Gizem',
           'Kerem','Ece','Onur','Derya','Serkan'])[1 + (i - 1) % 25],
    (ARRAY['Yıldız','Öztürk','Aydın','Özdemir','Arslan','Doğan','Kılıç','Aslan','Çetin','Kara',
           'Koç','Kurt','Özkan','Şimşek','Polat','Erdoğan','Güneş','Tekin','Acar','Bulut'])[1 + (i * 7) % 20],
    (10000000000 + i * 7919)::text,                       -- 11 haneli sahte kimlik no
    '0532' || lpad(i::text, 7, '0'),
    'misafir' || lpad(i::text, 2, '0') || '@example.com',
    DATE '1960-01-01' + floor(random() * 15000)::int
FROM generate_series(1, 50) AS i;

-- -----------------------------------------------------------------------------
-- Rezervasyonlar, konaklamalar, ek hizmetler, ödemeler ve temizlik kayıtları
-- Her oda için zaman çizelgesi ileri doğru yürünür; konaklamalar arka arkaya
-- dizildiği için aynı odada çakışma oluşmaz (oluşursa trigger 005 durdurur).
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    bugun       date := CURRENT_DATE;
    oda         RECORD;
    cur         date;
    s           date;     -- giriş
    e           date;     -- çıkış
    gece        int;
    v_durum     text;
    rez_id      int;
    kon_id      int;
    oda_tutari  numeric;
    hizmet_tutari numeric;
    resepsiyon  int[];
    kat_gorevli int[];
BEGIN
    SELECT array_agg(id ORDER BY id) INTO resepsiyon  FROM Personel WHERE gorev = 'resepsiyon';
    SELECT array_agg(id ORDER BY id) INTO kat_gorevli FROM Personel WHERE gorev = 'kat_gorevlisi';

    FOR oda IN
        SELECT o.id, o.oda_tipi_id, ot.kapasite, ot.temel_fiyat,
               row_number() OVER (ORDER BY o.oda_no) AS sira
        FROM Oda o JOIN OdaTipi ot ON ot.id = o.oda_tipi_id
        ORDER BY o.oda_no
    LOOP
        cur := bugun - 120;

        WHILE cur < bugun + 45 LOOP
            s    := cur + floor(random() * 5)::int;      -- 0-4 gün boşluk
            gece := 1 + floor(random() * 6)::int;        -- 1-6 gece
            e    := s + gece;

            -- Bugünü kesen konaklamaları bazı odalarda hizala (bugünün giriş/çıkış listesi dolu olsun)
            IF s < bugun AND e > bugun THEN
                IF oda.sira % 5 = 0 THEN
                    e := bugun;                          -- bugün çıkış yapacak
                ELSIF oda.sira % 5 = 1 THEN
                    s := bugun; e := bugun + gece;       -- bugün giriş yapacak
                END IF;
            END IF;

            -- Durum: geçmiş / otelde / bugün giriş / gelecek
            IF e < bugun THEN
                v_durum := CASE WHEN random() < 0.12 THEN 'iptal' ELSE 'tamamlandi' END;
            ELSIF s < bugun THEN
                v_durum := 'onayli';                     -- şu an otelde (check-in yapılmış)
            ELSIF s = bugun THEN
                v_durum := 'onayli';                     -- bugün gelecek (check-in bekliyor)
            ELSE
                v_durum := CASE WHEN random() < 0.08 THEN 'iptal'
                                WHEN random() < 0.55 THEN 'onayli'
                                ELSE 'beklemede' END;
            END IF;

            INSERT INTO Rezervasyon (misafir_id, oda_id, giris_tarihi, cikis_tarihi, kisi_sayisi, durum, olusturma_tarihi)
            -- Misafir: bu tarihlerde başka aktif konaklaması olmayan rastgele biri
            -- (kural değildir, örnek verinin gerçekçi olması içindir)
            VALUES ((SELECT m.id FROM Misafir m
                      WHERE NOT EXISTS (
                            SELECT 1 FROM Rezervasyon x
                            WHERE x.misafir_id = m.id AND x.durum <> 'iptal'
                              AND daterange(x.giris_tarihi, x.cikis_tarihi) && daterange(s, e))
                      ORDER BY random() LIMIT 1),
                    oda.id, s, e,
                    1 + floor(random() * oda.kapasite)::int,
                    v_durum,
                    s - (1 + floor(random() * 30)::int))
            RETURNING id INTO rez_id;

            -- Check-in yapılmış konaklamalar: tamamlanan ve şu an otelde olanlar
            IF v_durum = 'tamamlandi' OR (v_durum = 'onayli' AND s < bugun) THEN
                INSERT INTO Konaklama (rezervasyon_id, gercek_giris_zamani, islemi_yapan_personel_id)
                VALUES (rez_id,
                        s + time '14:00' + random() * interval '4 hours',
                        resepsiyon[1 + floor(random() * array_length(resepsiyon, 1))::int])
                RETURNING id INTO kon_id;                 -- trigger 007: oda 'dolu'

                -- Ek hizmetler (bugünden önceki günlerde)
                INSERT INTO KonaklamaHizmeti (konaklama_id, hizmet_id, adet, tarih)
                SELECT kon_id, h.id, 1 + floor(random() * 3)::int,
                       s + time '09:00' + floor(random() * LEAST(gece, GREATEST(bugun - s, 1)))::int * interval '1 day'
                FROM EkHizmet h
                WHERE random() < 0.35;

                IF v_durum = 'tamamlandi' THEN
                    -- Check-out: trigger 007 oda 'temizlikte'
                    UPDATE Konaklama
                    SET gercek_cikis_zamani = e + time '10:00' + random() * interval '2 hours'
                    WHERE id = kon_id;

                    -- Ödeme = her gecenin sezon fiyatı (yoksa temel fiyat) + ek hizmetler
                    SELECT sum(COALESCE(
                               (SELECT sf.gecelik_fiyat FROM SezonFiyati sf
                                 WHERE sf.oda_tipi_id = oda.oda_tipi_id
                                   AND g::date BETWEEN sf.baslangic_tarihi AND sf.bitis_tarihi),
                               oda.temel_fiyat))
                    INTO oda_tutari
                    FROM generate_series(s, e - 1, interval '1 day') AS g;

                    SELECT COALESCE(sum(kh.adet * eh.birim_fiyat), 0) INTO hizmet_tutari
                    FROM KonaklamaHizmeti kh JOIN EkHizmet eh ON eh.id = kh.hizmet_id
                    WHERE kh.konaklama_id = kon_id;

                    INSERT INTO Odeme (konaklama_id, tutar, odeme_turu, tarih)
                    VALUES (kon_id, oda_tutari + hizmet_tutari,
                            CASE WHEN random() < 0.6 THEN 'kart' ELSE 'nakit' END,
                            e + time '11:00');

                    -- Temizlik: trigger 008 oda 'bos'. Dün/bugün boşalan bazı odalar
                    -- henüz temizlenmemiş kalır (oda durumu 'temizlikte').
                    IF NOT (e >= bugun - 1 AND oda.sira % 3 = 0) THEN
                        INSERT INTO TemizlikKaydi (oda_id, personel_id, tarih, durum)
                        VALUES (oda.id,
                                kat_gorevli[1 + floor(random() * array_length(kat_gorevli, 1))::int],
                                e + time '13:00', 'temizlendi');
                    END IF;
                END IF;
            END IF;

            cur := e;
        END LOOP;
    END LOOP;

    -- Bir oda bakımda (şu an boş olan en yüksek numaralı oda)
    INSERT INTO TemizlikKaydi (oda_id, personel_id, tarih, durum)
    SELECT id, kat_gorevli[1], now(), 'bakimda'
    FROM Oda WHERE durum = 'bos' ORDER BY oda_no DESC LIMIT 1;   -- trigger 008: oda 'bakimda'
END $$;

-- -----------------------------------------------------------------------------
-- Özet
-- -----------------------------------------------------------------------------
SELECT 'oda_tipi'   AS tablo, count(*) FROM OdaTipi
UNION ALL SELECT 'oda',            count(*) FROM Oda
UNION ALL SELECT 'sezon_fiyati',   count(*) FROM SezonFiyati
UNION ALL SELECT 'personel',       count(*) FROM Personel
UNION ALL SELECT 'ek_hizmet',      count(*) FROM EkHizmet
UNION ALL SELECT 'misafir',        count(*) FROM Misafir
UNION ALL SELECT 'rezervasyon',    count(*) FROM Rezervasyon
UNION ALL SELECT 'konaklama',      count(*) FROM Konaklama
UNION ALL SELECT 'konaklama_hizmeti', count(*) FROM KonaklamaHizmeti
UNION ALL SELECT 'odeme',          count(*) FROM Odeme
UNION ALL SELECT 'temizlik_kaydi', count(*) FROM TemizlikKaydi
UNION ALL SELECT 'islem_log',      count(*) FROM IslemLog;

COMMIT;
