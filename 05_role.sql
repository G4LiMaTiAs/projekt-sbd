-- Role, uzytkownicy, uprawnienia i widoki
-- Bezpieczenstwo realizujemy zgodnie z wykladem: przez ROLE + WIDOKI
-- (bez kontekstow/VPD - tego nie bylo na zajeciach).
--
-- UWAGA: ten skrypt, jak pozostale, uruchamiamy jako WLASCICIEL SCHEMATU
-- (zeby widoki i granty dotyczyly naszych tabel). Wlasciciel musi miec
-- przywileje systemowe CREATE ROLE i CREATE USER. Jesli ich nie ma, DBA
-- nadaje je jednorazowo:
--     GRANT CREATE ROLE, CREATE USER TO <twoj_uzytkownik>;
-- Alternatywnie mozna zakomentowac sekcje "UZYTKOWNICY" na dole -
-- same role i widoki wystarcza do pokazania modelu uprawnien.
--
-- Aplikacja Flask laczy sie jako wlasciciel schematu (jedno polaczenie),
-- a rozroznienie klient/pracownik/admin w aplikacji opiera sie na kolumnie
-- KLIENCI.rola. Role i uzytkownicy ponizej pokazuja model uprawnien w bazie
-- (mozna je zademonstrowac logujac sie w SQL Developer jako app_klient itd.).
-- Uruchamiac PO 04_triggery.sql.


-- ========================================================================
-- WIDOKI (warstwa dostepu / ukrycia danych)
-- ========================================================================

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


-- ========================================================================
-- SPRZATANIE (zeby skrypt byl idempotentny) - kazdy DROP w osobnym bloku,
-- bledy ignorujemy (gdy obiekt jeszcze nie istnieje)
-- ========================================================================
BEGIN EXECUTE IMMEDIATE 'DROP USER app_klient CASCADE';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER app_pracownik CASCADE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP USER app_admin CASCADE';     EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE rola_klient';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE rola_pracownik'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE rola_admin';     EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- ========================================================================
-- ROLE
-- ========================================================================
CREATE ROLE rola_klient;
CREATE ROLE rola_pracownik;
CREATE ROLE rola_admin;


-- ----- uprawnienia roli KLIENT -----
-- klient widzi tylko katalog (aktywne produkty), kategorie i recenzje,
-- a operacje wykonuje wylacznie przez pakiety (bez ORM)
GRANT SELECT ON v_katalog  TO rola_klient;
GRANT SELECT ON kategorie  TO rola_klient;
GRANT SELECT ON recenzje   TO rola_klient;
GRANT EXECUTE ON P_ZAMOWIENIA TO rola_klient;
GRANT EXECUTE ON P_KLIENCI    TO rola_klient;

-- ----- uprawnienia roli PRACOWNIK -----
-- pracownik ma wszystko co klient + obsluga zamowien i podglad produktow
GRANT rola_klient TO rola_pracownik;
GRANT SELECT, UPDATE ON produkty            TO rola_pracownik;
GRANT SELECT ON zamowienia                  TO rola_pracownik;
GRANT SELECT ON pozycje_zamowienia          TO rola_pracownik;
GRANT SELECT ON platnosci                   TO rola_pracownik;
GRANT SELECT ON klienci                     TO rola_pracownik;
GRANT SELECT ON v_zamowienia_pelne          TO rola_pracownik;

-- ----- uprawnienia roli ADMIN -----
-- admin ma wszystko co pracownik + zarzadzanie produktami/kategoriami,
-- kontami klientow i podglad logu operacji
GRANT rola_pracownik TO rola_admin;
GRANT INSERT, UPDATE, DELETE ON produkty   TO rola_admin;
GRANT INSERT, UPDATE, DELETE ON kategorie  TO rola_admin;
GRANT UPDATE, DELETE ON klienci            TO rola_admin;
GRANT SELECT ON log_operacji               TO rola_admin;


-- ========================================================================
-- UZYTKOWNICY (wymaga uprawnien DBA - patrz uwaga na gorze pliku)
-- Kazdy uzytkownik dostaje prawo logowania i jedna role.
-- ========================================================================
CREATE USER app_klient    IDENTIFIED BY klient123;
CREATE USER app_pracownik IDENTIFIED BY prac123;
CREATE USER app_admin     IDENTIFIED BY admin123;

GRANT CREATE SESSION TO app_klient;
GRANT CREATE SESSION TO app_pracownik;
GRANT CREATE SESSION TO app_admin;

GRANT rola_klient    TO app_klient;
GRANT rola_pracownik TO app_pracownik;
GRANT rola_admin     TO app_admin;
