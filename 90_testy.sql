-- Testy logiki PL/SQL
-- Uruchamiac PO 04 (i ewentualnie 05). Najlepiej w SQL Developer jako skrypt (F5).
-- Na koncu ROLLBACK - testy nie zmieniaja trwale danych.

SET SERVEROUTPUT ON;

-- ========================================================================
-- TEST 1: zloz zamowienie -> dodaj pozycje -> oplac -> stan ma spasc
-- ========================================================================
DECLARE
  v_zam   zamowienia.id_zamowienia%TYPE;
  v_przed produkty.stan_magazynowy%TYPE;
  v_po    produkty.stan_magazynowy%TYPE;
BEGIN
  SELECT stan_magazynowy INTO v_przed FROM produkty WHERE id_produktu = 7;

  v_zam := P_ZAMOWIENIA.zloz_zamowienie(1, 'ul. Testowa 1, Warszawa');
  P_ZAMOWIENIA.dodaj_pozycje(v_zam, 7, 2);   -- 2 sztuki produktu 7
  P_ZAMOWIENIA.dodaj_platnosc(v_zam, 'KARTA'); -- status OPLACONE -> trigger zdejmuje stan

  SELECT stan_magazynowy INTO v_po FROM produkty WHERE id_produktu = 7;

  IF v_po = v_przed - 2 THEN
    DBMS_OUTPUT.PUT_LINE('TEST 1 OK: stan ' || v_przed || ' -> ' || v_po || ' (spadl o 2)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('TEST 1 BLAD: stan ' || v_przed || ' -> ' || v_po);
  END IF;

  -- TEST 2: anuluj oplacone -> stan ma wrocic
  P_ZAMOWIENIA.anuluj_zamowienie(v_zam);
  SELECT stan_magazynowy INTO v_po FROM produkty WHERE id_produktu = 7;
  IF v_po = v_przed THEN
    DBMS_OUTPUT.PUT_LINE('TEST 2 OK: po anulowaniu stan wrocil do ' || v_po);
  ELSE
    DBMS_OUTPUT.PUT_LINE('TEST 2 BLAD: stan po anulowaniu = ' || v_po);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TEST 1/2 BLAD: ' || SQLERRM);
END;
/


-- ========================================================================
-- TEST 3: proba dodania wiecej niz na stanie -> wyjatek -20003
-- ========================================================================
DECLARE
  v_zam zamowienia.id_zamowienia%TYPE;
BEGIN
  v_zam := P_ZAMOWIENIA.zloz_zamowienie(1, 'ul. Testowa 2');
  P_ZAMOWIENIA.dodaj_pozycje(v_zam, 7, 99999);  -- za duzo
  DBMS_OUTPUT.PUT_LINE('TEST 3 BLAD: nie zglosil wyjatku');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20003 THEN
      DBMS_OUTPUT.PUT_LINE('TEST 3 OK: zgloszono wyjatek braku na stanie (' || SQLERRM || ')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('TEST 3 BLAD: inny wyjatek: ' || SQLERRM);
    END IF;
END;
/


-- ========================================================================
-- TEST 4: niedozwolona zmiana statusu (NOWE -> DOSTARCZONE) -> wyjatek -20004
-- ========================================================================
DECLARE
  v_zam zamowienia.id_zamowienia%TYPE;
BEGIN
  v_zam := P_ZAMOWIENIA.zloz_zamowienie(1, 'ul. Testowa 3');
  P_ZAMOWIENIA.zmien_status(v_zam, 'DOSTARCZONE');  -- z NOWE nie wolno
  DBMS_OUTPUT.PUT_LINE('TEST 4 BLAD: nie zglosil wyjatku');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20004 THEN
      DBMS_OUTPUT.PUT_LINE('TEST 4 OK: zablokowano zla zmiane statusu (' || SQLERRM || ')');
    ELSE
      DBMS_OUTPUT.PUT_LINE('TEST 4 BLAD: inny wyjatek: ' || SQLERRM);
    END IF;
END;
/


-- ========================================================================
-- TEST 5: czy trigger audytowy faktycznie dopisuje wpis do LOG_OPERACJI
-- (porownanie liczby wpisow przed i po operacji UPDATE)
-- ========================================================================
DECLARE
  v_przed NUMBER;
  v_po    NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_przed FROM log_operacji;
  -- dowolny UPDATE na produkcie uruchamia trigger trg_log_produkty
  UPDATE produkty SET stan_magazynowy = stan_magazynowy WHERE id_produktu = 7;
  SELECT COUNT(*) INTO v_po FROM log_operacji;

  IF v_po > v_przed THEN
    DBMS_OUTPUT.PUT_LINE('TEST 5 OK: trigger audytowy dopisal wpis (' || v_przed || ' -> ' || v_po || ')');
  ELSE
    DBMS_OUTPUT.PUT_LINE('TEST 5 BLAD: log nie urosl po operacji');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('TEST 5 BLAD: ' || SQLERRM);
END;
/


-- cofamy zmiany testowe
ROLLBACK;
