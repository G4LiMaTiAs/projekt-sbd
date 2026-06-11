-- Triggery - kontrola magazynu i audyt
-- Uruchamiac PO 03_pakiety.sql.
-- Triggery audytowe pisza do INNEJ tabeli (log_operacji), wiec nie ma problemu
-- z mutating table. Bledy zglaszamy przez RAISE_APPLICATION_ERROR.


-- ========================================================================
-- 1. KONTROLA STANU MAGAZYNOWEGO
-- przy dodaniu/zmianie pozycji sprawdzamy czy starczy towaru
-- ========================================================================
CREATE OR REPLACE TRIGGER trg_pozycje_stan
BEFORE INSERT OR UPDATE ON pozycje_zamowienia
FOR EACH ROW
DECLARE
  v_stan produkty.stan_magazynowy%TYPE;
BEGIN
  SELECT stan_magazynowy INTO v_stan
    FROM produkty WHERE id_produktu = :NEW.id_produktu;

  IF :NEW.ilosc > v_stan THEN
    RAISE_APPLICATION_ERROR(-20003,
      'Brak wystarczajacej ilosci na stanie (dostepne: ' || v_stan || ').');
  END IF;
END;
/


-- ========================================================================
-- 2. AUTOMATYCZNE ZMNIEJSZENIE STANU PO OPLACENIU
-- gdy zamowienie zmienia status na OPLACONE - zdejmujemy towar z magazynu,
-- gdy anulowane po oplaceniu - przywracamy towar
-- ========================================================================
CREATE OR REPLACE TRIGGER trg_zam_magazyn
AFTER UPDATE OF status ON zamowienia
FOR EACH ROW
DECLARE
  v_stan produkty.stan_magazynowy%TYPE;
BEGIN
  -- oplacenie -> zdejmij stan
  IF :NEW.status = 'OPLACONE' AND :OLD.status <> 'OPLACONE' THEN
    FOR poz IN (SELECT id_produktu, ilosc FROM pozycje_zamowienia
                 WHERE id_zamowienia = :NEW.id_zamowienia) LOOP
      -- kontrola zeby nie zejsc ponizej zera (czytelny blad zamiast ORA-02290)
      SELECT stan_magazynowy INTO v_stan FROM produkty WHERE id_produktu = poz.id_produktu;
      IF v_stan < poz.ilosc THEN
        RAISE_APPLICATION_ERROR(-20003,
          'Brak wystarczajacej ilosci na stanie przy oplacaniu (produkt ' || poz.id_produktu || ').');
      END IF;
      UPDATE produkty
         SET stan_magazynowy = stan_magazynowy - poz.ilosc
       WHERE id_produktu = poz.id_produktu;
    END LOOP;

  -- anulowanie oplaconego -> zwroc stan
  ELSIF :NEW.status = 'ANULOWANE' AND :OLD.status = 'OPLACONE' THEN
    FOR poz IN (SELECT id_produktu, ilosc FROM pozycje_zamowienia
                 WHERE id_zamowienia = :NEW.id_zamowienia) LOOP
      UPDATE produkty
         SET stan_magazynowy = stan_magazynowy + poz.ilosc
       WHERE id_produktu = poz.id_produktu;
    END LOOP;
  END IF;
END;
/


-- ========================================================================
-- 3. TRIGGERY AUDYTOWE -> LOG_OPERACJI
-- jeden trigger na tabele, obsluguje INSERT/UPDATE/DELETE
-- ========================================================================

CREATE OR REPLACE TRIGGER trg_log_klienci
AFTER INSERT OR UPDATE OR DELETE ON klienci
FOR EACH ROW
DECLARE
  v_op  log_operacji.operacja%TYPE;
  v_id  log_operacji.id_rekordu%TYPE;
BEGIN
  IF INSERTING THEN v_op := 'INSERT'; v_id := :NEW.id_klienta;
  ELSIF UPDATING THEN v_op := 'UPDATE'; v_id := :NEW.id_klienta;
  ELSE v_op := 'DELETE'; v_id := :OLD.id_klienta;
  END IF;

  INSERT INTO log_operacji (operacja, nazwa_tabeli, id_rekordu, szczegoly)
  VALUES (v_op, 'KLIENCI', v_id, 'Operacja na koncie klienta');
END;
/

CREATE OR REPLACE TRIGGER trg_log_produkty
AFTER INSERT OR UPDATE OR DELETE ON produkty
FOR EACH ROW
DECLARE
  v_op  log_operacji.operacja%TYPE;
  v_id  log_operacji.id_rekordu%TYPE;
  v_szc log_operacji.szczegoly%TYPE;
BEGIN
  IF INSERTING THEN
    v_op := 'INSERT'; v_id := :NEW.id_produktu;
    v_szc := 'Dodano produkt: ' || :NEW.nazwa;
  ELSIF UPDATING THEN
    v_op := 'UPDATE'; v_id := :NEW.id_produktu;
    v_szc := 'Zmiana produktu: ' || :NEW.nazwa || ' (stan: ' || :NEW.stan_magazynowy || ')';
  ELSE
    v_op := 'DELETE'; v_id := :OLD.id_produktu;
    v_szc := 'Usunieto produkt: ' || :OLD.nazwa;
  END IF;

  INSERT INTO log_operacji (operacja, nazwa_tabeli, id_rekordu, szczegoly)
  VALUES (v_op, 'PRODUKTY', v_id, v_szc);
END;
/

CREATE OR REPLACE TRIGGER trg_log_zamowienia
AFTER INSERT OR UPDATE OR DELETE ON zamowienia
FOR EACH ROW
DECLARE
  v_op  log_operacji.operacja%TYPE;
  v_id  log_operacji.id_rekordu%TYPE;
  v_szc log_operacji.szczegoly%TYPE;
BEGIN
  IF INSERTING THEN
    v_op := 'INSERT'; v_id := :NEW.id_zamowienia;
    v_szc := 'Nowe zamowienie klienta id=' || :NEW.id_klienta;
  ELSIF UPDATING THEN
    v_op := 'UPDATE'; v_id := :NEW.id_zamowienia;
    v_szc := 'Zmiana statusu: ' || :OLD.status || ' -> ' || :NEW.status;
  ELSE
    v_op := 'DELETE'; v_id := :OLD.id_zamowienia;
    v_szc := 'Usunieto zamowienie id=' || :OLD.id_zamowienia;
  END IF;

  INSERT INTO log_operacji (operacja, nazwa_tabeli, id_rekordu, szczegoly)
  VALUES (v_op, 'ZAMOWIENIA', v_id, v_szc);
END;
/

CREATE OR REPLACE TRIGGER trg_log_platnosci
AFTER INSERT OR UPDATE OR DELETE ON platnosci
FOR EACH ROW
DECLARE
  v_op  log_operacji.operacja%TYPE;
  v_id  log_operacji.id_rekordu%TYPE;
  v_szc log_operacji.szczegoly%TYPE;
BEGIN
  IF INSERTING THEN
    v_op := 'INSERT'; v_id := :NEW.id_platnosci;
    v_szc := 'Platnosc ' || :NEW.metoda || ' kwota ' || :NEW.kwota;
  ELSIF UPDATING THEN
    v_op := 'UPDATE'; v_id := :NEW.id_platnosci;
    v_szc := 'Zmiana statusu platnosci -> ' || :NEW.status;
  ELSE
    v_op := 'DELETE'; v_id := :OLD.id_platnosci;
    v_szc := 'Usunieto platnosc id=' || :OLD.id_platnosci;
  END IF;

  INSERT INTO log_operacji (operacja, nazwa_tabeli, id_rekordu, szczegoly)
  VALUES (v_op, 'PLATNOSCI', v_id, v_szc);
END;
/
