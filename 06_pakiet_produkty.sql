-- Pakiet P_PRODUKTY - zarzadzanie produktami (panel admina)
-- Styl zgodny z reszta projektu: prefiks P_, parametry z sufiksem _in, %TYPE,
-- AS w ciele, bledy przez RAISE_APPLICATION_ERROR.
-- Uruchamiac PO 03_pakiety.sql (kolejnosc z pakietami nie ma znaczenia,
-- byle po utworzeniu tabel i triggerow).
--
-- Numery bledow (kontynuacja zakresu z 03_pakiety.sql):
--  -20010  produkt nie istnieje
--  -20011  kategoria nie istnieje
--  -20012  niepoprawne dane produktu (cena/stan ujemne)
--  -20013  niepoprawna flaga aktywny (dozwolone T/N)

CREATE OR REPLACE PACKAGE P_PRODUKTY AS

  -- dodaje nowy produkt, zwraca jego ID
  FUNCTION dodaj_produkt(nazwa_in        IN produkty.nazwa%TYPE,
                         opis_in         IN produkty.opis%TYPE,
                         cena_in         IN produkty.cena%TYPE,
                         stan_in         IN produkty.stan_magazynowy%TYPE,
                         id_kategorii_in IN produkty.id_kategorii%TYPE)
    RETURN produkty.id_produktu%TYPE;

  -- edytuje istniejacy produkt (wszystkie pola)
  PROCEDURE edytuj_produkt(id_produktu_in  IN produkty.id_produktu%TYPE,
                           nazwa_in        IN produkty.nazwa%TYPE,
                           opis_in         IN produkty.opis%TYPE,
                           cena_in         IN produkty.cena%TYPE,
                           stan_in         IN produkty.stan_magazynowy%TYPE,
                           id_kategorii_in IN produkty.id_kategorii%TYPE,
                           aktywny_in      IN produkty.aktywny%TYPE);

  -- wlacza/wylacza produkt w sklepie (T/N) - "miekkie" usuniecie
  PROCEDURE zmien_aktywnosc(id_produktu_in IN produkty.id_produktu%TYPE,
                            aktywny_in     IN produkty.aktywny%TYPE);

END P_PRODUKTY;
/

CREATE OR REPLACE PACKAGE BODY P_PRODUKTY AS

  -- prywatna walidacja wspolnych regul (kategoria, cena, stan)
  PROCEDURE sprawdz_dane(cena_in         IN produkty.cena%TYPE,
                         stan_in         IN produkty.stan_magazynowy%TYPE,
                         id_kategorii_in IN produkty.id_kategorii%TYPE)
  AS
    v_ile NUMBER;
  BEGIN
    IF cena_in < 0 OR stan_in < 0 THEN
      RAISE_APPLICATION_ERROR(-20012, 'Cena i stan magazynowy nie moga byc ujemne.');
    END IF;

    SELECT COUNT(*) INTO v_ile FROM kategorie WHERE id_kategorii = id_kategorii_in;
    IF v_ile = 0 THEN
      RAISE_APPLICATION_ERROR(-20011, 'Wybrana kategoria nie istnieje.');
    END IF;
  END sprawdz_dane;


  FUNCTION dodaj_produkt(nazwa_in        IN produkty.nazwa%TYPE,
                         opis_in         IN produkty.opis%TYPE,
                         cena_in         IN produkty.cena%TYPE,
                         stan_in         IN produkty.stan_magazynowy%TYPE,
                         id_kategorii_in IN produkty.id_kategorii%TYPE)
    RETURN produkty.id_produktu%TYPE
  AS
    v_id produkty.id_produktu%TYPE;
  BEGIN
    sprawdz_dane(cena_in, stan_in, id_kategorii_in);

    INSERT INTO produkty (nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny)
    VALUES (nazwa_in, opis_in, cena_in, stan_in, id_kategorii_in, 'T')
    RETURNING id_produktu INTO v_id;

    RETURN v_id;
  END dodaj_produkt;


  PROCEDURE edytuj_produkt(id_produktu_in  IN produkty.id_produktu%TYPE,
                           nazwa_in        IN produkty.nazwa%TYPE,
                           opis_in         IN produkty.opis%TYPE,
                           cena_in         IN produkty.cena%TYPE,
                           stan_in         IN produkty.stan_magazynowy%TYPE,
                           id_kategorii_in IN produkty.id_kategorii%TYPE,
                           aktywny_in      IN produkty.aktywny%TYPE)
  AS
  BEGIN
    IF aktywny_in NOT IN ('T','N') THEN
      RAISE_APPLICATION_ERROR(-20013, 'Flaga aktywny moze byc tylko T lub N.');
    END IF;

    sprawdz_dane(cena_in, stan_in, id_kategorii_in);

    UPDATE produkty
       SET nazwa           = nazwa_in,
           opis            = opis_in,
           cena            = cena_in,
           stan_magazynowy = stan_in,
           id_kategorii    = id_kategorii_in,
           aktywny         = aktywny_in
     WHERE id_produktu = id_produktu_in;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Produkt nie istnieje.');
    END IF;
  END edytuj_produkt;


  PROCEDURE zmien_aktywnosc(id_produktu_in IN produkty.id_produktu%TYPE,
                            aktywny_in     IN produkty.aktywny%TYPE)
  AS
  BEGIN
    IF aktywny_in NOT IN ('T','N') THEN
      RAISE_APPLICATION_ERROR(-20013, 'Flaga aktywny moze byc tylko T lub N.');
    END IF;

    UPDATE produkty SET aktywny = aktywny_in WHERE id_produktu = id_produktu_in;

    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Produkt nie istnieje.');
    END IF;
  END zmien_aktywnosc;

END P_PRODUKTY;
/

-- (opcjonalnie) jesli masz role - nadaj adminowi prawo wykonania pakietu.
-- Wrapped, zeby nie wywalalo bledu na koncie bez rol.
BEGIN
  EXECUTE IMMEDIATE 'GRANT EXECUTE ON P_PRODUKTY TO rola_admin';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
