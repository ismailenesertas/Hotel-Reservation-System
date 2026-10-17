# Hastane Otomasyonu — Varlık-İlişki Diyagramı

## ER diyagramı

```mermaid
erDiagram
    POLIKLINIK ||--o{ DOKTOR : "calistirir"
    HASTA ||--o{ MUAYENE : "muayene olur"
    POLIKLINIK ||--o{ MUAYENE : "muayene yapilan yer"
    LABORATUVAR ||--o{ TAHLIL : "tahlilleri yapar"
    HASTA ||--o{ TAHLIL_ISTEM : "tahlil yaptirir"
    DOKTOR ||--o{ TAHLIL_ISTEM : "istem olusturur"
    TAHLIL ||--o{ TAHLIL_ISTEM : "istenen tahlil"
    POLIKLINIK ||--o{ SERVIS : "servisleri bulunur"
    SERVIS ||--o{ HEMSIRE : "hemsireleri bulunur"

    POLIKLINIK {
        int poliklinik_id PK
        varchar ad
        varchar konum
    }
    DOKTOR {
        int doktor_id PK
        int poliklinik_id FK
        varchar ad
        varchar soyad
        varchar uzmanlik
    }
    HASTA {
        int hasta_id PK
        varchar tc_kimlik_no UK
        varchar ad
        varchar soyad
        date dogum_tarihi
        varchar telefon
    }
    MUAYENE {
        int muayene_id PK
        int hasta_id FK
        int poliklinik_id FK
        timestamp muayene_zamani
        text notlar
    }
    LABORATUVAR {
        int laboratuvar_id PK
        varchar ad
        varchar konum
    }
    TAHLIL {
        int tahlil_id PK
        int laboratuvar_id FK
        varchar ad
        text aciklama
    }
    TAHLIL_ISTEM {
        int istem_id PK
        int hasta_id FK
        int doktor_id FK
        int tahlil_id FK
        timestamp istem_zamani
        varchar durum
        text sonuc_notu
    }
    SERVIS {
        int servis_id PK
        int poliklinik_id FK
        varchar ad
        varchar konum
    }
    HEMSIRE {
        int hemsire_id PK
        int servis_id FK
        varchar ad
        varchar soyad
        varchar telefon
    }
```

## İlişkiler ve kardinaliteler

| İlişki | Kardinalite | Uygulama |
|---|---|---|
| Poliklinik–Doktor | 1:N | `Doktor.poliklinik_id` yabancı anahtarı |
| Hasta–Poliklinik | N:M | `Muayene` ara tablosu |
| Hasta–Tahlil | N:M | `TahlilIstem` üzerinden |
| Doktor–Tahlil | N:M | `TahlilIstem` üzerinden |
| Laboratuvar–Tahlil | 1:N | `Tahlil.laboratuvar_id` yabancı anahtarı |
| Poliklinik–Servis | 1:N | `Servis.poliklinik_id` yabancı anahtarı |
| Servis–Hemşire | 1:N | `Hemsire.servis_id` yabancı anahtarı |

### Önemli tasarım notları
1. Bir doktorun yalnızca bir polikliniğe bağlı olması, doktor tablosundaki tek `poliklinik_id` alanıyla sağlanır.
2. Bir hemşirenin yalnızca bir serviste çalışması, hemşire tablosundaki tek `servis_id` alanıyla sağlanır.
3. Her tahlil türü yalnızca bir laboratuvara bağlıdır; laboratuvar birden çok tahlil türünü gerçekleştirebilir.
4. `TahlilIstem` bir işlem/ilişki tablosudur: hangi hastaya, hangi doktor tarafından, hangi tahlilin istendiğini kaydeder. Aynı tahlilin farklı hastalar için veya aynı hastaya farklı zamanlarda tekrar istenebilmesi nedeniyle `istem_id` kullanılır.
5. Diyagramdaki çizgiler her ana kaydın sıfır veya daha fazla ilişkili kaydı olabileceğini; her ilişkili kaydın ise ilgili üst kayda bağlı olduğunu gösterir.
