# Diagram zwiazkow encji (ERD)

Diagram w skladni Mermaid - renderuje sie w VS Code (z rozszerzeniem Mermaid),
na GitHubie oraz w wielu edytorach Markdown.

```mermaid
erDiagram
    KLIENCI ||--o{ ZAMOWIENIA : sklada
    KLIENCI ||--o{ RECENZJE : pisze
    KATEGORIE ||--o{ KATEGORIE : "rodzic-dziecko"
    KATEGORIE ||--o{ PRODUKTY : zawiera
    PRODUKTY ||--o{ POZYCJE_ZAMOWIENIA : "jest w"
    PRODUKTY ||--o{ RECENZJE : oceniany
    ZAMOWIENIA ||--o{ POZYCJE_ZAMOWIENIA : ma
    ZAMOWIENIA ||--o{ PLATNOSCI : oplacane

    KLIENCI {
        number id_klienta PK
        varchar2 email UK
        varchar2 haslo_hash
        varchar2 imie
        varchar2 nazwisko
        char aktywny
        varchar2 rola
    }
    KATEGORIE {
        number id_kategorii PK
        varchar2 nazwa UK
        number id_rodzica FK
    }
    PRODUKTY {
        number id_produktu PK
        varchar2 nazwa
        number cena
        number stan_magazynowy
        number id_kategorii FK
        char aktywny
    }
    ZAMOWIENIA {
        number id_zamowienia PK
        number id_klienta FK
        date data_zamowienia
        varchar2 status
        number suma
    }
    POZYCJE_ZAMOWIENIA {
        number id_pozycji PK
        number id_zamowienia FK
        number id_produktu FK
        number ilosc
        number cena_jednostkowa
    }
    PLATNOSCI {
        number id_platnosci PK
        number id_zamowienia FK
        number kwota
        varchar2 metoda
        varchar2 status
    }
    RECENZJE {
        number id_recenzji PK
        number id_produktu FK
        number id_klienta FK
        number ocena
        varchar2 tresc
    }
    LOG_OPERACJI {
        number id_logu PK
        varchar2 uzytkownik
        varchar2 operacja
        varchar2 nazwa_tabeli
        number id_rekordu
        timestamp data_op
    }
```

LOG_OPERACJI nie ma kluczy obcych - jest wypelniany przez triggery audytowe
i przechowuje historie operacji na pozostalych tabelach.
