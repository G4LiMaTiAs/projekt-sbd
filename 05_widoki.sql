-- 05_widoki.sql
-- WERSJA AWARYJNA pliku 05_role.sql dla konta BEZ przywilejow CREATE ROLE / CREATE USER.
-- Tworzy WYLACZNIE widoki potrzebne aplikacji. Pomija role i uzytkownikow.
-- Uruchamiac PO 04_triggery.sql, jako wlasciciel schematu.
--
-- Model rol (rola_klient/pracownik/admin + uzytkownicy app_*) z oryginalnego
-- 05_role.sql wymaga przywilejow CREATE ROLE i CREATE USER, ktorych to konto
-- nie posiada. Rozroznienie rol w aplikacji opiera sie na kolumnie KLIENCI.rola.

-- katalog dla klienta - tylko aktywne produkty + nazwa kategorii
CREATE OR REPLACE VIEW v_katalog AS
SELECT p.id_produktu,
       p.nazwa,
       p.opis,
       p.cena,
       p.stan_magazynowy,
       k.nazwa AS kategoria,
       p.id_kategorii
  FROM produkty p
  JOIN kategorie k ON k.id_kategorii = p.id_kategorii
 WHERE p.aktywny = 'T';

-- zamowienia z danymi klienta - dla personelu
CREATE OR REPLACE VIEW v_zamowienia_pelne AS
SELECT z.id_zamowienia,
       z.data_zamowienia,
       z.status,
       z.suma,
       z.adres_dostawy,
       k.id_klienta,
       k.imie || ' ' || k.nazwisko AS klient
  FROM zamowienia z
  JOIN klienci k ON k.id_klienta = z.id_klienta;
