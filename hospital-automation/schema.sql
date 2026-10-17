-- Hastane Otomasyonu: veritabani semasi
-- PostgreSQL uyumludur. Bu betik yalnizca tablo ve kisitlari olusturur.

CREATE TABLE Poliklinik (
    poliklinik_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ad VARCHAR(100) NOT NULL UNIQUE,
    konum VARCHAR(150)
);

CREATE TABLE Doktor (
    doktor_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    poliklinik_id INTEGER NOT NULL,
    ad VARCHAR(60) NOT NULL,
    soyad VARCHAR(60) NOT NULL,
    uzmanlik VARCHAR(100),
    telefon VARCHAR(20),
    CONSTRAINT fk_doktor_poliklinik
        FOREIGN KEY (poliklinik_id) REFERENCES Poliklinik(poliklinik_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Hasta (
    hasta_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tc_kimlik_no CHAR(11) UNIQUE,
    ad VARCHAR(60) NOT NULL,
    soyad VARCHAR(60) NOT NULL,
    dogum_tarihi DATE,
    telefon VARCHAR(20)
);

CREATE TABLE Muayene (
    muayene_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hasta_id INTEGER NOT NULL,
    poliklinik_id INTEGER NOT NULL,
    muayene_zamani TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notlar TEXT,
    CONSTRAINT fk_muayene_hasta
        FOREIGN KEY (hasta_id) REFERENCES Hasta(hasta_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_muayene_poliklinik
        FOREIGN KEY (poliklinik_id) REFERENCES Poliklinik(poliklinik_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Laboratuvar (
    laboratuvar_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ad VARCHAR(100) NOT NULL UNIQUE,
    konum VARCHAR(150),
    telefon VARCHAR(20)
);

CREATE TABLE Tahlil (
    tahlil_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    laboratuvar_id INTEGER NOT NULL,
    ad VARCHAR(100) NOT NULL,
    aciklama TEXT,
    CONSTRAINT fk_tahlil_laboratuvar
        FOREIGN KEY (laboratuvar_id) REFERENCES Laboratuvar(laboratuvar_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_tahlil_laboratuvar_ad UNIQUE (laboratuvar_id, ad)
);

CREATE TABLE TahlilIstem (
    istem_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hasta_id INTEGER NOT NULL,
    doktor_id INTEGER NOT NULL,
    tahlil_id INTEGER NOT NULL,
    istem_zamani TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    durum VARCHAR(20) NOT NULL DEFAULT 'Bekliyor',
    sonuc_notu TEXT,
    CONSTRAINT ck_tahlil_istem_durum
        CHECK (durum IN ('Bekliyor', 'Alindi', 'Tamamlandi', 'Iptal')),
    CONSTRAINT fk_istem_hasta
        FOREIGN KEY (hasta_id) REFERENCES Hasta(hasta_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_istem_doktor
        FOREIGN KEY (doktor_id) REFERENCES Doktor(doktor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_istem_tahlil
        FOREIGN KEY (tahlil_id) REFERENCES Tahlil(tahlil_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE Servis (
    servis_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    poliklinik_id INTEGER NOT NULL,
    ad VARCHAR(100) NOT NULL,
    konum VARCHAR(150),
    CONSTRAINT fk_servis_poliklinik
        FOREIGN KEY (poliklinik_id) REFERENCES Poliklinik(poliklinik_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_servis_poliklinik_ad UNIQUE (poliklinik_id, ad)
);

CREATE TABLE Hemsire (
    hemsire_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    servis_id INTEGER NOT NULL,
    ad VARCHAR(60) NOT NULL,
    soyad VARCHAR(60) NOT NULL,
    telefon VARCHAR(20),
    CONSTRAINT fk_hemsire_servis
        FOREIGN KEY (servis_id) REFERENCES Servis(servis_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- Sik kullanilan yabanci anahtar alanlari icin indeksler
CREATE INDEX idx_doktor_poliklinik ON Doktor(poliklinik_id);
CREATE INDEX idx_muayene_hasta ON Muayene(hasta_id);
CREATE INDEX idx_muayene_poliklinik ON Muayene(poliklinik_id);
CREATE INDEX idx_tahlil_laboratuvar ON Tahlil(laboratuvar_id);
CREATE INDEX idx_istem_hasta ON TahlilIstem(hasta_id);
CREATE INDEX idx_istem_doktor ON TahlilIstem(doktor_id);
CREATE INDEX idx_istem_tahlil ON TahlilIstem(tahlil_id);
CREATE INDEX idx_servis_poliklinik ON Servis(poliklinik_id);
CREATE INDEX idx_hemsire_servis ON Hemsire(servis_id);
