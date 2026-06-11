# Warstwa dostepu do bazy - python-oracledb (tryb thin, bez Instant Client).
# Operacje zapisujace ida przez pakiety PL/SQL (bez ORM).
# Odczyty to zwykle SELECT-y (czesto z widokow).

import oracledb
import config

_pool = None  # pula polaczen tworzona przy pierwszym uzyciu


def _get_pool():
    global _pool
    if _pool is None:
        _pool = oracledb.create_pool(
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            dsn=config.DB_DSN,
            min=1, max=4, increment=1,
        )
    return _pool


def polaczenie():
    return _get_pool().acquire()


def _wiersze_na_slowniki(cursor):
    # zamienia wynik kursora na liste slownikow {kolumna_malymi: wartosc}
    kolumny = [c[0].lower() for c in cursor.description]
    return [dict(zip(kolumny, w)) for w in cursor.fetchall()]


def _data(d):
    return d.strftime("%Y-%m-%d") if d else ""


def czysty_blad(e):
    # wyciaga czytelny komunikat z bledu Oracle (np. ORA-20003: brak na stanie)
    try:
        msg = e.args[0].message
    except Exception:
        msg = str(e)
    # ucinamy prefix "ORA-20003: " zostawiajac sam tekst
    if "ORA-" in msg and ":" in msg:
        return msg.split(":", 1)[1].strip().split("\n")[0]
    return msg


# ---------------- ODCZYTY ----------------

def lista_kategorii():
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("SELECT id_kategorii, nazwa, id_rodzica FROM kategorie ORDER BY id_kategorii")
        return _wiersze_na_slowniki(cur)


def lista_produktow():
    # katalog - tylko aktywne (z widoku v_katalog)
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii
                         FROM v_katalog ORDER BY nazwa""")
        wiersze = _wiersze_na_slowniki(cur)
    for w in wiersze:
        w["opis"] = w["opis"] or ""
        w["aktywny"] = "T"
    return wiersze


def produkt(pid):
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_produktu, nazwa, opis, cena, stan_magazynowy, id_kategorii, aktywny
                         FROM produkty WHERE id_produktu = :1""", [pid])
        w = _wiersze_na_slowniki(cur)
    if not w:
        return None
    w = w[0]
    w["opis"] = w["opis"] or ""
    return w


def kategoria(kid):
    for k in lista_kategorii():
        if k["id_kategorii"] == kid:
            return k
    return None


def recenzje_produktu(pid):
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT k.imie AS imie_klienta, r.ocena, r.tresc, r.data_dodania
                         FROM recenzje r JOIN klienci k ON k.id_klienta = r.id_klienta
                        WHERE r.id_produktu = :1 ORDER BY r.data_dodania DESC""", [pid])
        wiersze = _wiersze_na_slowniki(cur)
    for w in wiersze:
        w["data_dodania"] = _data(w["data_dodania"])
        w["tresc"] = w["tresc"] or ""
    return wiersze


def uzytkownik_po_emailu(email):
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_klienta, email, haslo_hash, imie, nazwisko, rola, aktywny
                         FROM klienci WHERE LOWER(email) = LOWER(:1)""", [email])
        w = _wiersze_na_slowniki(cur)
    return w[0] if w else None


def zamowienia_klienta(id_klienta):
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_zamowienia, data_zamowienia, status, suma, adres_dostawy
                         FROM zamowienia WHERE id_klienta = :1
                        ORDER BY data_zamowienia DESC""", [id_klienta])
        zam = _wiersze_na_slowniki(cur)
        for z in zam:
            z["data_zamowienia"] = _data(z["data_zamowienia"])
            cur.execute("""SELECT p.nazwa, poz.ilosc, poz.cena_jednostkowa
                             FROM pozycje_zamowienia poz
                             JOIN produkty p ON p.id_produktu = poz.id_produktu
                            WHERE poz.id_zamowienia = :1""", [z["id_zamowienia"]])
            z["pozycje"] = _wiersze_na_slowniki(cur)
    return zam


def wszystkie_zamowienia():
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_zamowienia, klient, data_zamowienia, status, suma
                         FROM v_zamowienia_pelne ORDER BY data_zamowienia DESC""")
        zam = _wiersze_na_slowniki(cur)
    for z in zam:
        z["data_zamowienia"] = _data(z["data_zamowienia"])
    return zam


def wszystkie_produkty():
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_produktu, nazwa, cena, stan_magazynowy, id_kategorii, aktywny
                         FROM produkty ORDER BY id_produktu""")
        return _wiersze_na_slowniki(cur)


def logi():
    with polaczenie() as con:
        cur = con.cursor()
        cur.execute("""SELECT id_logu, uzytkownik, operacja, nazwa_tabeli, id_rekordu,
                              TO_CHAR(data_op,'YYYY-MM-DD HH24:MI:SS') AS data_op, szczegoly
                         FROM log_operacji ORDER BY id_logu DESC""")
        return _wiersze_na_slowniki(cur)


# ---------------- ZAPISY (przez pakiety PL/SQL) ----------------

def rejestruj_klienta(email, haslo_hash, imie, nazwisko, telefon, ulica, miasto, kod):
    with polaczenie() as con:
        cur = con.cursor()
        v_id = cur.callfunc("P_KLIENCI.rejestruj", oracledb.NUMBER,
                            [email, haslo_hash, imie, nazwisko, telefon, ulica, miasto, kod])
        con.commit()
        return int(v_id)


def zloz_zamowienie(id_klienta, adres, pozycje, metoda):
    # pozycje: lista (id_produktu, ilosc). Tworzy zamowienie, dodaje pozycje, oplaca.
    with polaczenie() as con:
        cur = con.cursor()
        v_zam = cur.callfunc("P_ZAMOWIENIA.zloz_zamowienie", oracledb.NUMBER,
                             [id_klienta, adres])
        for id_prod, ilosc in pozycje:
            cur.callproc("P_ZAMOWIENIA.dodaj_pozycje", [int(v_zam), id_prod, ilosc])
        cur.callproc("P_ZAMOWIENIA.dodaj_platnosc", [int(v_zam), metoda])
        con.commit()
        return int(v_zam)


def zmien_status(id_zamowienia, nowy_status):
    with polaczenie() as con:
        cur = con.cursor()
        cur.callproc("P_ZAMOWIENIA.zmien_status", [id_zamowienia, nowy_status])
        con.commit()
