-- Projekt zaliczeniowy - sklep internetowy
-- schemat bazy: tabele, sekwencje, constrainty

-- sprzatanie zeby mozna bylo odpalic skrypt drugi raz bez bledow
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name IN
            ('LOG_OPERACJI','RECENZJE','PLATNOSCI','POZYCJE_ZAMOWIENIA',
             'ZAMOWIENIA','PRODUKTY','KATEGORIE','KLIENCI'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
  END LOOP;

  FOR s IN (SELECT sequence_name FROM user_sequences WHERE sequence_name IN
            ('SEQ_KLIENCI','SEQ_KATEGORIE','SEQ_PRODUKTY','SEQ_ZAMOWIENIA',
             'SEQ_POZYCJE','SEQ_PLATNOSCI','SEQ_RECENZJE','SEQ_LOG'))
  LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/


-- sekwencje do generowania ID
CREATE SEQUENCE seq_klienci    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_kategorie  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_produkty   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_zamowienia START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_pozycje    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_platnosci  START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_recenzje   START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_log        START WITH 1 INCREMENT BY 1 NOCACHE;


-- klienci sklepu
CREATE TABLE klienci (
  id_klienta        NUMBER(10)        NOT NULL,
  email             VARCHAR2(100)     NOT NULL,
  haslo_hash        VARCHAR2(255)     NOT NULL,  -- nie trzymamy hasla na czysto
  imie              VARCHAR2(50)      NOT NULL,
  nazwisko          VARCHAR2(50)      NOT NULL,
  telefon           VARCHAR2(20),
  adres_ulica       VARCHAR2(150),
  adres_miasto      VARCHAR2(80),
  adres_kod         VARCHAR2(10),
  data_rejestracji  DATE              DEFAULT SYSDATE NOT NULL,
  aktywny           CHAR(1)           DEFAULT 'T' NOT NULL,  -- T/N zamiast kasowania
  rola              VARCHAR2(20)      DEFAULT 'KLIENT' NOT NULL,  -- KLIENT/PRACOWNIK/ADMIN

  CONSTRAINT pk_klienci         PRIMARY KEY (id_klienta),
  CONSTRAINT uk_klienci_email   UNIQUE (email),
  CONSTRAINT ck_klienci_aktywny CHECK (aktywny IN ('T','N')),
  CONSTRAINT ck_klienci_rola    CHECK (rola IN ('KLIENT','PRACOWNIK','ADMIN')),
  CONSTRAINT ck_klienci_email   CHECK (email LIKE '%_@_%._%')  -- prosta walidacja maila
);


-- kategorie produktow, moga miec rodzica (drzewo)
CREATE TABLE kategorie (
  id_kategorii  NUMBER(10)    NOT NULL,
  nazwa         VARCHAR2(80)  NOT NULL,
  opis          VARCHAR2(500),
  id_rodzica    NUMBER(10),   -- NULL = kategoria glowna

  CONSTRAINT pk_kategorie       PRIMARY KEY (id_kategorii),
  CONSTRAINT uk_kategorie_nazwa UNIQUE (nazwa),
  CONSTRAINT fk_kategorie_rodzic FOREIGN KEY (id_rodzica)
    REFERENCES kategorie (id_kategorii)
);


-- produkty w sklepie
CREATE TABLE produkty (
  id_produktu       NUMBER(10)        NOT NULL,
  nazwa             VARCHAR2(150)     NOT NULL,
  opis              VARCHAR2(2000),
  cena              NUMBER(10,2)      NOT NULL,
  stan_magazynowy   NUMBER(10)        DEFAULT 0 NOT NULL,
  id_kategorii      NUMBER(10)        NOT NULL,
  aktywny           CHAR(1)           DEFAULT 'T' NOT NULL,  -- N = ukryty w sklepie
  data_dodania      DATE              DEFAULT SYSDATE NOT NULL,

  CONSTRAINT pk_produkty           PRIMARY KEY (id_produktu),
  CONSTRAINT fk_produkty_kategoria FOREIGN KEY (id_kategorii)
    REFERENCES kategorie (id_kategorii),
  CONSTRAINT ck_produkty_cena      CHECK (cena >= 0),
  CONSTRAINT ck_produkty_stan      CHECK (stan_magazynowy >= 0),
  CONSTRAINT ck_produkty_aktywny   CHECK (aktywny IN ('T','N'))
);


-- zamowienia klientow
CREATE TABLE zamowienia (
  id_zamowienia     NUMBER(10)        NOT NULL,
  id_klienta        NUMBER(10)        NOT NULL,
  data_zamowienia   DATE              DEFAULT SYSDATE NOT NULL,
  status            VARCHAR2(20)      DEFAULT 'NOWE' NOT NULL,
  suma              NUMBER(12,2)      DEFAULT 0 NOT NULL,  -- liczona triggerem/procedura
  adres_dostawy     VARCHAR2(300),

  CONSTRAINT pk_zamowienia         PRIMARY KEY (id_zamowienia),
  CONSTRAINT fk_zamowienia_klient  FOREIGN KEY (id_klienta)
    REFERENCES klienci (id_klienta),
  -- mozliwe statusy: NOWE -> OPLACONE -> WYSLANE -> DOSTARCZONE, albo ANULOWANE
  CONSTRAINT ck_zamowienia_status  CHECK (status IN
    ('NOWE','OPLACONE','WYSLANE','DOSTARCZONE','ANULOWANE')),
  CONSTRAINT ck_zamowienia_suma    CHECK (suma >= 0)
);


-- pozycje zamowienia (czyli koszyk)
-- cene kopiujemy z produktu zeby zmiana ceny pozniej nie zepsula historii
CREATE TABLE pozycje_zamowienia (
  id_pozycji        NUMBER(10)        NOT NULL,
  id_zamowienia     NUMBER(10)        NOT NULL,
  id_produktu       NUMBER(10)        NOT NULL,
  ilosc             NUMBER(6)         NOT NULL,
  cena_jednostkowa  NUMBER(10,2)      NOT NULL,

  CONSTRAINT pk_pozycje            PRIMARY KEY (id_pozycji),
  CONSTRAINT fk_pozycje_zamowienie FOREIGN KEY (id_zamowienia)
    REFERENCES zamowienia (id_zamowienia) ON DELETE CASCADE,
  CONSTRAINT fk_pozycje_produkt    FOREIGN KEY (id_produktu)
    REFERENCES produkty (id_produktu),
  CONSTRAINT ck_pozycje_ilosc      CHECK (ilosc > 0),
  CONSTRAINT ck_pozycje_cena       CHECK (cena_jednostkowa >= 0),
  -- ten sam produkt nie moze byc dwa razy w tym samym zamowieniu
  CONSTRAINT uk_pozycje_unik       UNIQUE (id_zamowienia, id_produktu)
);


-- platnosci
CREATE TABLE platnosci (
  id_platnosci      NUMBER(10)        NOT NULL,
  id_zamowienia     NUMBER(10)        NOT NULL,
  kwota             NUMBER(12,2)      NOT NULL,
  metoda            VARCHAR2(20)      NOT NULL,
  status            VARCHAR2(20)      DEFAULT 'OCZEKUJACA' NOT NULL,
  data_platnosci    DATE              DEFAULT SYSDATE NOT NULL,

  CONSTRAINT pk_platnosci          PRIMARY KEY (id_platnosci),
  CONSTRAINT fk_platnosci_zam      FOREIGN KEY (id_zamowienia)
    REFERENCES zamowienia (id_zamowienia),
  CONSTRAINT ck_platnosci_metoda   CHECK (metoda IN ('KARTA','PRZELEW','BLIK','POBRANIE')),
  CONSTRAINT ck_platnosci_status   CHECK (status IN ('OCZEKUJACA','ZREALIZOWANA','ODRZUCONA','ZWROCONA')),
  CONSTRAINT ck_platnosci_kwota    CHECK (kwota > 0)
);


-- recenzje produktow - jeden klient moze ocenic dany produkt tylko raz
CREATE TABLE recenzje (
  id_recenzji   NUMBER(10)        NOT NULL,
  id_produktu   NUMBER(10)        NOT NULL,
  id_klienta    NUMBER(10)        NOT NULL,
  ocena         NUMBER(1)         NOT NULL,  -- 1-5 gwiazdek
  tresc         VARCHAR2(1000),
  data_dodania  DATE              DEFAULT SYSDATE NOT NULL,

  CONSTRAINT pk_recenzje           PRIMARY KEY (id_recenzji),
  CONSTRAINT fk_recenzje_produkt   FOREIGN KEY (id_produktu)
    REFERENCES produkty (id_produktu) ON DELETE CASCADE,
  CONSTRAINT fk_recenzje_klient    FOREIGN KEY (id_klienta)
    REFERENCES klienci (id_klienta),
  CONSTRAINT ck_recenzje_ocena     CHECK (ocena BETWEEN 1 AND 5),
  CONSTRAINT uk_recenzje_unik      UNIQUE (id_produktu, id_klienta)
);


-- log do audytu - bedzie zapelniany triggerami
CREATE TABLE log_operacji (
  id_logu       NUMBER(10)        NOT NULL,
  uzytkownik    VARCHAR2(50)      DEFAULT USER NOT NULL,
  operacja      VARCHAR2(10)      NOT NULL,
  nazwa_tabeli  VARCHAR2(30)      NOT NULL,
  id_rekordu    NUMBER(10),
  data_op       TIMESTAMP         DEFAULT SYSTIMESTAMP NOT NULL,
  szczegoly     VARCHAR2(500),

  CONSTRAINT pk_log              PRIMARY KEY (id_logu),
  CONSTRAINT ck_log_operacja     CHECK (operacja IN ('INSERT','UPDATE','DELETE'))
);


-- indeksy na klucze obce i kolumny po ktorych czesto bedziemy szukac
CREATE INDEX idx_produkty_kategoria   ON produkty (id_kategorii);
CREATE INDEX idx_zamowienia_klient    ON zamowienia (id_klienta);
CREATE INDEX idx_zamowienia_status    ON zamowienia (status);
CREATE INDEX idx_pozycje_zamowienie   ON pozycje_zamowienia (id_zamowienia);
CREATE INDEX idx_pozycje_produkt      ON pozycje_zamowienia (id_produktu);
CREATE INDEX idx_platnosci_zamowienie ON platnosci (id_zamowienia);
CREATE INDEX idx_recenzje_produkt     ON recenzje (id_produktu);
CREATE INDEX idx_log_tabela           ON log_operacji (nazwa_tabeli, data_op);


-- triggery podstawiajace ID z sekwencji (zeby nie trzeba bylo go podawac w insercie)
CREATE OR REPLACE TRIGGER trg_klienci_bi
BEFORE INSERT ON klienci FOR EACH ROW
BEGIN
  IF :NEW.id_klienta IS NULL THEN
    :NEW.id_klienta := seq_klienci.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_kategorie_bi
BEFORE INSERT ON kategorie FOR EACH ROW
BEGIN
  IF :NEW.id_kategorii IS NULL THEN
    :NEW.id_kategorii := seq_kategorie.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_produkty_bi
BEFORE INSERT ON produkty FOR EACH ROW
BEGIN
  IF :NEW.id_produktu IS NULL THEN
    :NEW.id_produktu := seq_produkty.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_zamowienia_bi
BEFORE INSERT ON zamowienia FOR EACH ROW
BEGIN
  IF :NEW.id_zamowienia IS NULL THEN
    :NEW.id_zamowienia := seq_zamowienia.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_pozycje_bi
BEFORE INSERT ON pozycje_zamowienia FOR EACH ROW
BEGIN
  IF :NEW.id_pozycji IS NULL THEN
    :NEW.id_pozycji := seq_pozycje.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_platnosci_bi
BEFORE INSERT ON platnosci FOR EACH ROW
BEGIN
  IF :NEW.id_platnosci IS NULL THEN
    :NEW.id_platnosci := seq_platnosci.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_recenzje_bi
BEFORE INSERT ON recenzje FOR EACH ROW
BEGIN
  IF :NEW.id_recenzji IS NULL THEN
    :NEW.id_recenzji := seq_recenzje.NEXTVAL;
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_log_bi
BEFORE INSERT ON log_operacji FOR EACH ROW
BEGIN
  IF :NEW.id_logu IS NULL THEN
    :NEW.id_logu := seq_log.NEXTVAL;
  END IF;
END;
/

COMMIT;