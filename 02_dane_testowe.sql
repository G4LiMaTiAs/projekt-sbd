-- Dane testowe do sklepu
-- Uruchamiac PO projekt.sql, a PRZED 03/04 (zeby triggery audytowe nie liczyly seedu).
-- ID wpisujemy jawnie, na koncu dociagamy sekwencje.
-- Hasla: wszyscy klienci = "haslo123", pracownik = "praca123", admin = "admin123"
-- (w bazie trzymamy tylko hash bcrypt).

-- czyszczenie danych zeby skrypt byl idempotentny
DELETE FROM recenzje;
DELETE FROM platnosci;
DELETE FROM pozycje_zamowienia;
DELETE FROM zamowienia;
DELETE FROM produkty;
DELETE FROM kategorie;
DELETE FROM klienci;
DELETE FROM log_operacji;
COMMIT;


-- KATEGORIE (najpierw glowne, potem podkategorie - przez FK na rodzica)
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (1, 'Elektronika', 'Sprzet elektroniczny', NULL);
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (6, 'Dom', 'Artykuly do domu', NULL);
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (2, 'Laptopy', 'Komputery przenosne', 1);
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (3, 'Smartfony', 'Telefony komorkowe', 1);
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (4, 'Audio', 'Sluchawki i glosniki', 1);
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (5, 'Akcesoria', 'Akcesoria komputerowe', 1);
INSERT INTO kategorie (id_kategorii, nazwa, opis, id_rodzica) VALUES (7, 'AGD', 'Sprzet AGD', 6);


-- KLIENCI (haslo_hash = bcrypt). Klient id=5 jest nieaktywny. id 6 pracownik, id 7 admin.
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (1, 'anna.kowalska@example.com', '$2b$12$Q6.qf0sBaPzgCF.sTpNfNOmPPFMt4hpiids5j92aQ8uyZOEA5i1/q', 'Anna', 'Kowalska', '600100200', 'ul. Kwiatowa 5', 'Warszawa', '00-001', 'T', 'KLIENT');
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (2, 'piotr.nowak@example.com', '$2b$12$Q6.qf0sBaPzgCF.sTpNfNOmPPFMt4hpiids5j92aQ8uyZOEA5i1/q', 'Piotr', 'Nowak', '600300400', 'ul. Lesna 12', 'Krakow', '30-100', 'T', 'KLIENT');
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (3, 'kasia.wisniewska@example.com', '$2b$12$Q6.qf0sBaPzgCF.sTpNfNOmPPFMt4hpiids5j92aQ8uyZOEA5i1/q', 'Katarzyna', 'Wisniewska', '600500600', 'ul. Polna 8', 'Poznan', '60-001', 'T', 'KLIENT');
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (4, 'marek.zielinski@example.com', '$2b$12$Q6.qf0sBaPzgCF.sTpNfNOmPPFMt4hpiids5j92aQ8uyZOEA5i1/q', 'Marek', 'Zielinski', '600700800', 'ul. Dluga 3', 'Gdansk', '80-001', 'T', 'KLIENT');
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (5, 'ola.dabrowska@example.com', '$2b$12$Q6.qf0sBaPzgCF.sTpNfNOmPPFMt4hpiids5j92aQ8uyZOEA5i1/q', 'Aleksandra', 'Dabrowska', '600900100', 'ul. Krotka 1', 'Lodz', '90-001', 'N', 'KLIENT');
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (6, 'pracownik@techsklep.pl', '$2b$12$pcMBy1.J0nTHfVpX7epAO.URb0hk9e91rQ/X2Ztjc/m8SbZGF3wUq', 'Jan', 'Pracowniczy', '500100100', NULL, 'Warszawa', '00-002', 'T', 'PRACOWNIK');
INSERT INTO klienci (id_klienta, email, haslo_hash, imie, nazwisko, telefon, adres_ulica, adres_miasto, adres_kod, aktywny, rola)
VALUES (7, 'admin@techsklep.pl', '$2b$12$.EoAClQeyc81nP9oEmzBDuIg4fC3.1K2dgY4EyPnHAsbw.df.8uNy', 'Admin', 'Sklepu', '500200200', NULL, 'Warszawa', '00-003', 'T', 'ADMIN');


-- PRODUKTY (produkt 4 i 11 maja stan 0; produkt 11 jest nieaktywny)
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (1, 'Laptop Lenovo IdeaPad 3', '15.6 cala, Ryzen 5, 16GB RAM, 512GB SSD.', 2499.00, 12, 2, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (2, 'Laptop Dell Inspiron 15', 'Intel Core i5, 8GB RAM, 256GB SSD.', 2899.00, 5, 2, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (3, 'Smartfon Samsung Galaxy A55', '6.6 cala AMOLED, 128GB, aparat 50MP.', 1599.00, 20, 3, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (4, 'Smartfon Xiaomi Redmi Note 13', 'Bateria 5000mAh, 256GB pamieci.', 999.00, 0, 3, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (5, 'Sluchawki Sony WH-1000XM5', 'Bezprzewodowe, redukcja szumow ANC.', 1399.00, 8, 4, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (6, 'Sluchawki JBL Tune 510BT', 'Bezprzewodowe nauszne, do 40h grania.', 169.00, 34, 4, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (7, 'Mysz Logitech MX Master 3S', 'Ergonomiczna mysz bezprzewodowa.', 449.00, 15, 5, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (8, 'Klawiatura mechaniczna Keychron K8', 'Switche brazowe, podswietlenie, USB-C.', 399.00, 9, 5, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (9, 'Ekspres do kawy DeLonghi', 'Cisnieniowy, automatyczny spieniacz mleka.', 1199.00, 6, 7, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (10, 'Odkurzacz Xiaomi Mi Vacuum', 'Bezprzewodowy, moc ssania 120AW.', 899.00, 3, 7, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (11, 'Monitor Dell 27 cali', 'IPS, Full HD, 75Hz. Model wycofany.', 699.00, 0, 5, 'N');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (12, 'Tablet Samsung Galaxy Tab A9', '10.1 cala, 64GB, do multimediow.', 749.00, 11, 1, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (13, 'Powerbank Anker 20000mAh', 'Szybkie ladowanie, 2x USB.', 159.00, 40, 5, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (14, 'Smartwatch Xiaomi Watch', 'Pomiar tetna, GPS, do 14 dni baterii.', 299.00, 18, 1, 'T');
INSERT INTO produkty (id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny) VALUES (15, 'Glosnik JBL Charge 5', 'Bezprzewodowy, wodoodporny, 20h grania.', 599.00, 7, 4, 'T');


-- ZAMOWIENIA (wszystkie 5 statusow). Suma wpisana recznie - zgodna z pozycjami.
INSERT INTO zamowienia (id_zamowienia, id_klienta, data_zamowienia, status, suma, adres_dostawy)
VALUES (1, 1, DATE '2026-05-02', 'DOSTARCZONE', 2668.00, 'ul. Kwiatowa 5, 00-001 Warszawa');
INSERT INTO zamowienia (id_zamowienia, id_klienta, data_zamowienia, status, suma, adres_dostawy)
VALUES (2, 1, DATE '2026-05-28', 'WYSLANE', 1599.00, 'ul. Kwiatowa 5, 00-001 Warszawa');
INSERT INTO zamowienia (id_zamowienia, id_klienta, data_zamowienia, status, suma, adres_dostawy)
VALUES (3, 2, DATE '2026-06-01', 'OPLACONE', 449.00, 'ul. Lesna 12, 30-100 Krakow');
INSERT INTO zamowienia (id_zamowienia, id_klienta, data_zamowienia, status, suma, adres_dostawy)
VALUES (4, 2, DATE '2026-06-03', 'NOWE', 399.00, 'ul. Lesna 12, 30-100 Krakow');
INSERT INTO zamowienia (id_zamowienia, id_klienta, data_zamowienia, status, suma, adres_dostawy)
VALUES (5, 1, DATE '2026-05-20', 'ANULOWANE', 169.00, 'ul. Kwiatowa 5, 00-001 Warszawa');


-- POZYCJE ZAMOWIENIA (cena_jednostkowa skopiowana z produktu)
INSERT INTO pozycje_zamowienia (id_pozycji, id_zamowienia, id_produktu, ilosc, cena_jednostkowa) VALUES (1, 1, 1, 1, 2499.00);
INSERT INTO pozycje_zamowienia (id_pozycji, id_zamowienia, id_produktu, ilosc, cena_jednostkowa) VALUES (2, 1, 6, 1, 169.00);
INSERT INTO pozycje_zamowienia (id_pozycji, id_zamowienia, id_produktu, ilosc, cena_jednostkowa) VALUES (3, 2, 3, 1, 1599.00);
INSERT INTO pozycje_zamowienia (id_pozycji, id_zamowienia, id_produktu, ilosc, cena_jednostkowa) VALUES (4, 3, 7, 1, 449.00);
INSERT INTO pozycje_zamowienia (id_pozycji, id_zamowienia, id_produktu, ilosc, cena_jednostkowa) VALUES (5, 4, 8, 1, 399.00);
INSERT INTO pozycje_zamowienia (id_pozycji, id_zamowienia, id_produktu, ilosc, cena_jednostkowa) VALUES (6, 5, 6, 1, 169.00);


-- PLATNOSCI (tylko dla oplaconych/wyslanych/dostarczonych; zam 5 zwrocona)
INSERT INTO platnosci (id_platnosci, id_zamowienia, kwota, metoda, status, data_platnosci) VALUES (1, 1, 2668.00, 'KARTA', 'ZREALIZOWANA', DATE '2026-05-02');
INSERT INTO platnosci (id_platnosci, id_zamowienia, kwota, metoda, status, data_platnosci) VALUES (2, 2, 1599.00, 'PRZELEW', 'ZREALIZOWANA', DATE '2026-05-28');
INSERT INTO platnosci (id_platnosci, id_zamowienia, kwota, metoda, status, data_platnosci) VALUES (3, 3, 449.00, 'BLIK', 'ZREALIZOWANA', DATE '2026-06-01');
INSERT INTO platnosci (id_platnosci, id_zamowienia, kwota, metoda, status, data_platnosci) VALUES (4, 5, 169.00, 'POBRANIE', 'ZWROCONA', DATE '2026-05-21');


-- RECENZJE (tylko klienci ktorzy kupili; UNIQUE produkt+klient)
INSERT INTO recenzje (id_recenzji, id_produktu, id_klienta, ocena, tresc, data_dodania) VALUES (1, 1, 1, 5, 'Super laptop, szybko dziala, polecam do studiowania.', DATE '2026-05-10');
INSERT INTO recenzje (id_recenzji, id_produktu, id_klienta, ocena, tresc, data_dodania) VALUES (2, 6, 1, 4, 'Dobre sluchawki za te pieniadze.', DATE '2026-05-11');
INSERT INTO recenzje (id_recenzji, id_produktu, id_klienta, ocena, tresc, data_dodania) VALUES (3, 3, 1, 5, 'Telefon bardzo dobry, ladny ekran.', DATE '2026-05-29');
INSERT INTO recenzje (id_recenzji, id_produktu, id_klienta, ocena, tresc, data_dodania) VALUES (4, 7, 2, 5, 'Najlepsza mysz jaka mialem.', DATE '2026-06-02');


-- kilka wpisow do logu, zeby panel admina nie byl pusty na starcie
-- (wlasciwe wpisy beda dokladane automatycznie przez triggery z 04)
INSERT INTO log_operacji (id_logu, uzytkownik, operacja, nazwa_tabeli, id_rekordu, szczegoly) VALUES (1, USER, 'INSERT', 'PRODUKTY', 12, 'Dodano produkt: Tablet Samsung Galaxy Tab A9');
INSERT INTO log_operacji (id_logu, uzytkownik, operacja, nazwa_tabeli, id_rekordu, szczegoly) VALUES (2, USER, 'UPDATE', 'PRODUKTY', 11, 'Produkt wycofany (aktywny = N)');

COMMIT;


-- dociagniecie sekwencji powyzej najwiekszego wstawionego ID,
-- zeby aplikacja generowala kolejne ID bez kolizji
DECLARE
  PROCEDURE dobij(p_seq IN VARCHAR2, p_tab IN VARCHAR2, p_col IN VARCHAR2) IS
    v_max NUMBER;
    v_cur NUMBER;
  BEGIN
    EXECUTE IMMEDIATE 'SELECT NVL(MAX('||p_col||'),0) FROM '||p_tab INTO v_max;
    LOOP
      EXECUTE IMMEDIATE 'SELECT '||p_seq||'.NEXTVAL FROM dual' INTO v_cur;
      EXIT WHEN v_cur >= v_max;
    END LOOP;
  END;
BEGIN
  dobij('seq_klienci',   'klienci',            'id_klienta');
  dobij('seq_kategorie', 'kategorie',          'id_kategorii');
  dobij('seq_produkty',  'produkty',           'id_produktu');
  dobij('seq_zamowienia','zamowienia',         'id_zamowienia');
  dobij('seq_pozycje',   'pozycje_zamowienia', 'id_pozycji');
  dobij('seq_platnosci', 'platnosci',          'id_platnosci');
  dobij('seq_recenzje',  'recenzje',           'id_recenzji');
  dobij('seq_log',       'log_operacji',       'id_logu');
END;
/

COMMIT;
