# TechSklep - aplikacja kliencka sklepu internetowego (Flask)
# Laczy sie z baza Oracle przez warstwe db.py.
# Operacje zapisujace ida przez pakiety PL/SQL (bez ORM), hasla sprawdzane bcryptem.

from functools import wraps
import bcrypt
from flask import (Flask, render_template, request, redirect, url_for,
                   session, flash)

import config
import db

app = Flask(__name__)
app.secret_key = config.SECRET_KEY


# --- kontrola dostepu ---

def wymaga_logowania(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if "uzytkownik" not in session:
            flash("Musisz sie zalogowac.", "warning")
            return redirect(url_for("logowanie"))
        return f(*args, **kwargs)
    return wrapper


def wymaga_personelu(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        u = session.get("uzytkownik")
        if not u or u["rola"] not in ("PRACOWNIK", "ADMIN"):
            flash("Brak uprawnien do tej sekcji.", "danger")
            return redirect(url_for("index"))
        return f(*args, **kwargs)
    return wrapper


@app.context_processor
def wstrzyknij_koszyk():
    koszyk = session.get("koszyk", {})
    return {"koszyk_liczba": sum(koszyk.values())}


# --- strona glowna ---

@app.route("/")
def index():
    polecane = db.lista_produktow()[:4]
    return render_template("index.html", polecane=polecane, kategorie=db.lista_kategorii())


# --- katalog ---

@app.route("/katalog")
def katalog():
    id_kat = request.args.get("kategoria", type=int)

    produkty = db.lista_produktow()
    if id_kat:
        produkty = [p for p in produkty if p["id_kategorii"] == id_kat]

    wybrana = db.kategoria(id_kat) if id_kat else None
    return render_template("katalog.html", produkty=produkty,
                           kategorie=db.lista_kategorii(), wybrana=wybrana)


# --- szczegoly produktu ---

@app.route("/produkt/<int:pid>")
def produkt(pid):
    p = db.produkt(pid)
    if not p:
        flash("Nie znaleziono produktu.", "danger")
        return redirect(url_for("katalog"))
    recenzje = db.recenzje_produktu(pid)
    srednia = round(sum(r["ocena"] for r in recenzje) / len(recenzje), 1) if recenzje else None
    return render_template("produkt.html", p=p, recenzje=recenzje,
                           srednia=srednia, kategoria=db.kategoria(p["id_kategorii"]))


# --- koszyk ---

@app.route("/koszyk")
def koszyk():
    pozycje, suma = _pozycje_koszyka()
    return render_template("koszyk.html", pozycje=pozycje, suma=suma)


def _pozycje_koszyka():
    koszyk = session.get("koszyk", {})
    pozycje, suma = [], 0
    for pid_str, ilosc in koszyk.items():
        p = db.produkt(int(pid_str))
        if p:
            wartosc = p["cena"] * ilosc
            suma += wartosc
            pozycje.append({"produkt": p, "ilosc": ilosc, "wartosc": wartosc})
    return pozycje, suma


@app.route("/koszyk/dodaj/<int:pid>", methods=["POST"])
def koszyk_dodaj(pid):
    p = db.produkt(pid)
    if not p or p["aktywny"] != "T":
        flash("Nie mozna dodac tego produktu.", "danger")
        return redirect(url_for("katalog"))
    if p["stan_magazynowy"] <= 0:
        flash("Produkt niedostepny (brak na stanie).", "warning")
        return redirect(url_for("produkt", pid=pid))

    koszyk = session.get("koszyk", {})
    koszyk[str(pid)] = koszyk.get(str(pid), 0) + 1
    session["koszyk"] = koszyk
    flash(f"Dodano do koszyka: {p['nazwa']}", "success")
    return redirect(request.referrer or url_for("katalog"))


@app.route("/koszyk/usun/<int:pid>", methods=["POST"])
def koszyk_usun(pid):
    koszyk = session.get("koszyk", {})
    koszyk.pop(str(pid), None)
    session["koszyk"] = koszyk
    flash("Usunieto z koszyka.", "info")
    return redirect(url_for("koszyk"))


# --- finalizacja zamowienia ---

@app.route("/zamowienie", methods=["GET", "POST"])
@wymaga_logowania
def zamowienie():
    koszyk = session.get("koszyk", {})
    if not koszyk:
        flash("Koszyk jest pusty.", "warning")
        return redirect(url_for("katalog"))

    pozycje, suma = _pozycje_koszyka()

    if request.method == "POST":
        adres = f"{request.form.get('ulica','')}, {request.form.get('kod','')} {request.form.get('miasto','')}"
        metoda = request.form.get("metoda", "KARTA")
        lista = [(int(pid), il) for pid, il in koszyk.items()]
        try:
            v_zam = db.zloz_zamowienie(session["uzytkownik"]["id_klienta"], adres, lista, metoda)
            session["koszyk"] = {}
            flash(f"Zamowienie #{v_zam} zostalo zlozone i oplacone!", "success")
            return redirect(url_for("moje_zamowienia"))
        except Exception as e:
            flash("Nie udalo sie zlozyc zamowienia: " + db.czysty_blad(e), "danger")

    return render_template("zamowienie.html", pozycje=pozycje, suma=suma,
                           metody=["KARTA", "PRZELEW", "BLIK", "POBRANIE"])


# --- moje zamowienia ---

@app.route("/moje-zamowienia")
@wymaga_logowania
def moje_zamowienia():
    zamowienia = db.zamowienia_klienta(session["uzytkownik"]["id_klienta"])
    # przepisanie pozycji na slownik {id_zamowienia: [pozycje]} pod istniejacy szablon
    pozycje = {z["id_zamowienia"]: z["pozycje"] for z in zamowienia}
    return render_template("moje_zamowienia.html", zamowienia=zamowienia, pozycje=pozycje)


# --- logowanie / rejestracja ---

@app.route("/logowanie", methods=["GET", "POST"])
def logowanie():
    if request.method == "POST":
        email = request.form.get("email", "")
        haslo = request.form.get("haslo", "")
        u = db.uzytkownik_po_emailu(email)
        if u and u["aktywny"] == "T" and bcrypt.checkpw(haslo.encode(), u["haslo_hash"].encode()):
            session["uzytkownik"] = {"id_klienta": u["id_klienta"], "email": u["email"],
                                     "imie": u["imie"], "nazwisko": u["nazwisko"], "rola": u["rola"]}
            flash(f"Witaj, {u['imie']}!", "success")
            if u["rola"] in ("PRACOWNIK", "ADMIN"):
                return redirect(url_for("admin_panel"))
            return redirect(url_for("index"))
        flash("Bledny email lub haslo (albo konto nieaktywne).", "danger")
    return render_template("login.html")


@app.route("/rejestracja", methods=["GET", "POST"])
def rejestracja():
    if request.method == "POST":
        haslo = request.form.get("haslo", "")
        haslo2 = request.form.get("haslo2", "")
        if haslo != haslo2:
            flash("Hasla nie sa takie same.", "danger")
            return render_template("rejestracja.html")
        haslo_hash = bcrypt.hashpw(haslo.encode(), bcrypt.gensalt()).decode()
        try:
            db.rejestruj_klienta(request.form.get("email"), haslo_hash,
                                 request.form.get("imie"), request.form.get("nazwisko"),
                                 request.form.get("telefon"), request.form.get("ulica"),
                                 request.form.get("miasto"), request.form.get("kod"))
            flash("Konto zalozone! Mozesz sie zalogowac.", "success")
            return redirect(url_for("logowanie"))
        except Exception as e:
            flash("Nie udalo sie zarejestrowac: " + db.czysty_blad(e), "danger")
    return render_template("rejestracja.html")


@app.route("/wyloguj")
def wyloguj():
    session.pop("uzytkownik", None)
    flash("Wylogowano.", "info")
    return redirect(url_for("index"))


# --- PANEL ADMINA / PRACOWNIKA ---

@app.route("/admin")
@wymaga_personelu
def admin_panel():
    zam = db.wszystkie_zamowienia()
    return render_template("admin/panel.html", ostatnie=zam[:5])


@app.route("/admin/produkty")
@wymaga_personelu
def admin_produkty():
    return render_template("admin/produkty.html", produkty=db.wszystkie_produkty(),
                           kategorie=db.lista_kategorii())


@app.route("/admin/zamowienia")
@wymaga_personelu
def admin_zamowienia():
    return render_template("admin/zamowienia.html", zamowienia=db.wszystkie_zamowienia(),
                           statusy=["NOWE", "OPLACONE", "WYSLANE", "DOSTARCZONE", "ANULOWANE"])


@app.route("/admin/zamowienia/<int:zid>/status", methods=["POST"])
@wymaga_personelu
def admin_zmien_status(zid):
    nowy = request.form.get("status")
    try:
        db.zmien_status(zid, nowy)
        flash(f"Zmieniono status zamowienia #{zid} na {nowy}.", "success")
    except Exception as e:
        flash("Nie udalo sie zmienic statusu: " + db.czysty_blad(e), "danger")
    return redirect(url_for("admin_zamowienia"))


@app.route("/admin/logi")
@wymaga_personelu
def admin_logi():
    return render_template("admin/logi.html", logi=db.logi())


if __name__ == "__main__":
    app.run(debug=True, port=5000)
