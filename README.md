# Sklep internetowy TechSklep - projekt zaliczeniowy (PL/SQL + Flask)

Baza danych sklepu internetowego w Oracle 19c wraz z aplikacja kliencka we Flasku.
Cala logika biznesowa jest po stronie bazy (pakiety, triggery, role), aplikacja
komunikuje sie z baza przez wywolania pakietow PL/SQL (bez ORM).

## Stos technologiczny

- Oracle Database 19c + SQL Developer
- PL/SQL: pakiety, triggery, role, widoki, sekwencje
- Python + Flask + python-oracledb (tryb thin)
- Bootstrap 5 (z CDN)
- Hasla hashowane bcryptem

## Struktura plikow

```
projekt.sql            - schemat: tabele, sekwencje, constrainty, triggery ID
02_dane_testowe.sql    - dane przykladowe (klienci, produkty, zamowienia...)
03_pakiety.sql         - pakiety P_ZAMOWIENIA, P_KLIENCI + wyjatki
04_triggery.sql        - kontrola stanu, zdejmowanie po oplaceniu, audyt do logu
05_role.sql            - role, uzytkownicy, uprawnienia, widoki
90_testy.sql           - testy logiki (DBMS_OUTPUT)
ERD.md                 - diagram zwiazkow encji
app/                   - aplikacja Flask
PLAN_SQL.md            - plan/checklista czesci bazodanowej
```

## Uruchomienie bazy (SQL Developer)

Skrypty odpalamy w kolejnosci, jako uzytkownik bedacy wlascicielem schematu:

1. `projekt.sql`
2. `02_dane_testowe.sql`
3. `03_pakiety.sql`
4. `04_triggery.sql`
5. `05_role.sql`  - uruchamiaj jako wlasciciel schematu. Wymaga przywilejow
   CREATE ROLE i CREATE USER. Jesli ich nie masz, DBA nadaje je raz:
   `GRANT CREATE ROLE, CREATE USER TO <twoj_uzytkownik>;`
   albo zakomentuj sekcje "UZYTKOWNICY" (same role + widoki tez sa wystarczajace)
6. (opcjonalnie) `90_testy.sql` - sprawdzenie czy logika dziala

## Uruchomienie aplikacji

```bash
cd app
pip install -r requirements.txt
```

Ustaw dane polaczenia w `app/config.py` (DB_USER, DB_PASSWORD, DB_DSN),
domyslnie `localhost:1521/XEPDB1`. Potem:

```bash
python app.py
```

Aplikacja startuje na http://127.0.0.1:5000

## Konta testowe

| rola      | email                       | haslo     |
|-----------|-----------------------------|-----------|
| klient    | anna.kowalska@example.com   | haslo123  |
| pracownik | pracownik@techsklep.pl      | praca123  |
| admin     | admin@techsklep.pl          | admin123  |

## Role i uprawnienia (model bezpieczenstwa)

- **rola_klient** - przeglada katalog (widok `v_katalog`), kupuje przez pakiet
  `P_ZAMOWIENIA`, zaklada konto przez `P_KLIENCI`.
- **rola_pracownik** - to co klient + podglad wszystkich zamowien i zmiana ich
  statusow, podglad produktow.
- **rola_admin** - to co pracownik + zarzadzanie produktami/kategoriami, kontami
  klientow i podglad logu operacji.

Bezpieczenstwo realizowane przez role + widoki (zgodnie z materialami z wykladu).

## Co demonstruje projekt

- Schemat znormalizowany z nazwanymi constraintami (PK/FK/UK/CHECK) i indeksami
- Pakiety PL/SQL z funkcjami, procedurami i obsluga wyjatkow
- Triggery: kontrola magazynu, automatyczne zdejmowanie stanu po oplaceniu, audyt
- Rozne role uzytkownikow z roznymi uprawnieniami
- Aplikacja webowa rozmawiajaca z baza wylacznie przez pakiety (bez ORM)
