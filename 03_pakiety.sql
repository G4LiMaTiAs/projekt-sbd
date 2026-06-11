-- Pakiety PL/SQL - logika sklepu
-- Styl wg wykladu: prefiks P_, parametry z sufiksem _IN, %TYPE, AS zamiast IS,
-- bledy zglaszane przez RAISE_APPLICATION_ERROR (numery z zakresu -20000..-20999).
-- Uruchamiac PO 02_dane_testowe.sql.

-- Numery bledow uzywane w projekcie:
--  -20001  klient nie istnieje lub jest nieaktywny
--  -20002  produkt nie istnieje lub jest nieaktywny
--  -20003  brak wystarczajacej ilosci na stanie
--  -20004  niedozwolona zmiana statusu
--  -20005  zamowienie nie istnieje
--  -20006  email juz zajety (rejestracja)


-- ========================================================================
-- PAKIET P_ZAMOWIENIA - skladanie i obsluga zamowien
-- ========================================================================
CREATE OR REPLACE PACKAGE P_ZAMOWIENIA AS

  -- tworzy nowe (puste) zamowienie w statusie NOWE, zwraca jego ID
  FUNCTION zloz_zamowienie(id_klienta_in IN klienci.id_klienta%TYPE,
                           adres_in      IN zamowienia.adres_dostawy%TYPE)
    RETURN zamowienia.id_zamowienia%TYPE;

  -- dodaje pozycje do zamowienia (kopiuje cene z produktu)
  PROCEDURE dodaj_pozycje(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE,
                          id_produktu_in   IN produkty.id_produktu%TYPE,
                          ilosc_in         IN pozycje_zamowienia.ilosc%TYPE);

  -- zwraca sume zamowienia (suma ilosc * cena_jednostkowa)
  FUNCTION oblicz_sume_zamowienia(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE)
    RETURN NUMBER;

  -- przelicza i zapisuje kolumne suma w zamowieniu
  PROCEDURE przelicz_sume(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE);

  -- zmienia status zamowienia z kontrola dozwolonych przejsc
  PROCEDURE zmien_status(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE,
                         nowy_status_in   IN zamowienia.status%TYPE);

  -- anuluje zamowienie (tylko ze statusu NOWE lub OPLACONE)
  PROCEDURE anuluj_zamowienie(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE);

  -- rejestruje platnosc i ustawia zamowienie na OPLACONE
  PROCEDURE dodaj_platnosc(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE,
                           metoda_in        IN platnosci.metoda%TYPE);

END P_ZAMOWIENIA;
/

CREATE OR REPLACE PACKAGE BODY P_ZAMOWIENIA AS

  FUNCTION zloz_zamowienie(id_klienta_in IN klienci.id_klienta%TYPE,
                           adres_in      IN zamowienia.adres_dostawy%TYPE)
    RETURN zamowienia.id_zamowienia%TYPE
  AS
    v_aktywny  klienci.aktywny%TYPE;
    v_id       zamowienia.id_zamowienia%TYPE;
  BEGIN
    -- sprawdzenie czy klient istnieje i jest aktywny
    BEGIN
      SELECT aktywny INTO v_aktywny FROM klienci WHERE id_klienta = id_klienta_in;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Klient nie istnieje.');
    END;

    IF v_aktywny = 'N' THEN
      RAISE_APPLICATION_ERROR(-20001, 'Klient jest nieaktywny.');
    END IF;

    INSERT INTO zamowienia (id_klienta, status, suma, adres_dostawy)
    VALUES (id_klienta_in, 'NOWE', 0, adres_in)
    RETURNING id_zamowienia INTO v_id;

    RETURN v_id;
  END zloz_zamowienie;


  PROCEDURE dodaj_pozycje(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE,
                          id_produktu_in   IN produkty.id_produktu%TYPE,
                          ilosc_in         IN pozycje_zamowienia.ilosc%TYPE)
  AS
    v_aktywny produkty.aktywny%TYPE;
    v_cena    produkty.cena%TYPE;
    v_stan    produkty.stan_magazynowy%TYPE;
  BEGIN
    -- pobranie danych produktu
    BEGIN
      SELECT aktywny, cena, stan_magazynowy
        INTO v_aktywny, v_cena, v_stan
        FROM produkty WHERE id_produktu = id_produktu_in;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20002, 'Produkt nie istnieje.');
    END;

    IF v_aktywny = 'N' THEN
      RAISE_APPLICATION_ERROR(-20002, 'Produkt jest nieaktywny.');
    END IF;

    IF ilosc_in > v_stan THEN
      RAISE_APPLICATION_ERROR(-20003, 'Brak wystarczajacej ilosci na stanie (dostepne: ' || v_stan || ').');
    END IF;

    -- jesli produkt jest juz w zamowieniu - zwiekszamy ilosc, inaczej dodajemy
    UPDATE pozycje_zamowienia
       SET ilosc = ilosc + ilosc_in
     WHERE id_zamowienia = id_zamowienia_in
       AND id_produktu   = id_produktu_in;

    IF SQL%ROWCOUNT = 0 THEN
      INSERT INTO pozycje_zamowienia (id_zamowienia, id_produktu, ilosc, cena_jednostkowa)
      VALUES (id_zamowienia_in, id_produktu_in, ilosc_in, v_cena);
    END IF;

    przelicz_sume(id_zamowienia_in);
  END dodaj_pozycje;


  FUNCTION oblicz_sume_zamowienia(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE)
    RETURN NUMBER
  AS
    v_suma NUMBER := 0;
  BEGIN
    SELECT NVL(SUM(ilosc * cena_jednostkowa), 0)
      INTO v_suma
      FROM pozycje_zamowienia
     WHERE id_zamowienia = id_zamowienia_in;
    RETURN v_suma;
  END oblicz_sume_zamowienia;


  PROCEDURE przelicz_sume(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE)
  AS
  BEGIN
    UPDATE zamowienia
       SET suma = oblicz_sume_zamowienia(id_zamowienia_in)
     WHERE id_zamowienia = id_zamowienia_in;
  END przelicz_sume;


  PROCEDURE zmien_status(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE,
                         nowy_status_in   IN zamowienia.status%TYPE)
  AS
    v_obecny zamowienia.status%TYPE;
    v_ok     BOOLEAN := FALSE;
  BEGIN
    BEGIN
      SELECT status INTO v_obecny FROM zamowienia WHERE id_zamowienia = id_zamowienia_in;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20005, 'Zamowienie nie istnieje.');
    END;

    -- dozwolone przejscia statusow
    IF    v_obecny = 'NOWE'     AND nowy_status_in IN ('OPLACONE','ANULOWANE') THEN v_ok := TRUE;
    ELSIF v_obecny = 'OPLACONE' AND nowy_status_in IN ('WYSLANE','ANULOWANE')  THEN v_ok := TRUE;
    ELSIF v_obecny = 'WYSLANE'  AND nowy_status_in = 'DOSTARCZONE'             THEN v_ok := TRUE;
    END IF;

    IF NOT v_ok THEN
      RAISE_APPLICATION_ERROR(-20004, 'Niedozwolona zmiana statusu: ' || v_obecny || ' -> ' || nowy_status_in);
    END IF;

    UPDATE zamowienia SET status = nowy_status_in WHERE id_zamowienia = id_zamowienia_in;
  END zmien_status;


  PROCEDURE anuluj_zamowienie(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE)
  AS
  BEGIN
    -- korzysta z walidacji w zmien_status (z NOWE/OPLACONE mozna anulowac)
    zmien_status(id_zamowienia_in, 'ANULOWANE');
  END anuluj_zamowienie;


  PROCEDURE dodaj_platnosc(id_zamowienia_in IN zamowienia.id_zamowienia%TYPE,
                           metoda_in        IN platnosci.metoda%TYPE)
  AS
    v_suma zamowienia.suma%TYPE;
  BEGIN
    SELECT suma INTO v_suma FROM zamowienia WHERE id_zamowienia = id_zamowienia_in;

    INSERT INTO platnosci (id_zamowienia, kwota, metoda, status)
    VALUES (id_zamowienia_in, v_suma, metoda_in, 'ZREALIZOWANA');

    -- zmiana statusu na OPLACONE uruchomi trigger zdejmujacy stan magazynowy
    zmien_status(id_zamowienia_in, 'OPLACONE');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20005, 'Zamowienie nie istnieje.');
  END dodaj_platnosc;

END P_ZAMOWIENIA;
/


-- ========================================================================
-- PAKIET P_KLIENCI - rejestracja klientow
-- ========================================================================
CREATE OR REPLACE PACKAGE P_KLIENCI AS

  -- rejestruje nowego klienta; haslo przychodzi juz zahaszowane (bcrypt) z aplikacji
  FUNCTION rejestruj(email_in      IN klienci.email%TYPE,
                     haslo_hash_in IN klienci.haslo_hash%TYPE,
                     imie_in       IN klienci.imie%TYPE,
                     nazwisko_in   IN klienci.nazwisko%TYPE,
                     telefon_in    IN klienci.telefon%TYPE DEFAULT NULL,
                     ulica_in      IN klienci.adres_ulica%TYPE DEFAULT NULL,
                     miasto_in     IN klienci.adres_miasto%TYPE DEFAULT NULL,
                     kod_in        IN klienci.adres_kod%TYPE DEFAULT NULL)
    RETURN klienci.id_klienta%TYPE;

END P_KLIENCI;
/

CREATE OR REPLACE PACKAGE BODY P_KLIENCI AS

  FUNCTION rejestruj(email_in      IN klienci.email%TYPE,
                     haslo_hash_in IN klienci.haslo_hash%TYPE,
                     imie_in       IN klienci.imie%TYPE,
                     nazwisko_in   IN klienci.nazwisko%TYPE,
                     telefon_in    IN klienci.telefon%TYPE DEFAULT NULL,
                     ulica_in      IN klienci.adres_ulica%TYPE DEFAULT NULL,
                     miasto_in     IN klienci.adres_miasto%TYPE DEFAULT NULL,
                     kod_in        IN klienci.adres_kod%TYPE DEFAULT NULL)
    RETURN klienci.id_klienta%TYPE
  AS
    v_ile NUMBER;
    v_id  klienci.id_klienta%TYPE;
  BEGIN
    SELECT COUNT(*) INTO v_ile FROM klienci WHERE LOWER(email) = LOWER(email_in);
    IF v_ile > 0 THEN
      RAISE_APPLICATION_ERROR(-20006, 'Email jest juz zajety.');
    END IF;

    INSERT INTO klienci (email, haslo_hash, imie, nazwisko, telefon,
                         adres_ulica, adres_miasto, adres_kod, rola)
    VALUES (email_in, haslo_hash_in, imie_in, nazwisko_in, telefon_in,
            ulica_in, miasto_in, kod_in, 'KLIENT')
    RETURNING id_klienta INTO v_id;

    RETURN v_id;
  END rejestruj;

END P_KLIENCI;
/
