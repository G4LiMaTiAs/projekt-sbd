# TechSklep - aplikacja kliencka (Flask)

Front sklepu internetowego do projektu zaliczeniowego z PL/SQL.
Laczy sie z baza Oracle przez `python-oracledb` (warstwa `db.py`);
operacje zapisujace ida przez pakiety PL/SQL (bez ORM).

## Uruchomienie

Najpierw baza (skrypty SQL wg README w katalogu glownym), potem:

```bash
cd app
pip install -r requirements.txt
python app.py
```

Dane polaczenia ustawiamy w `config.py`. Aplikacja startuje na http://127.0.0.1:5000

## Konta testowe

| rola      | email                       | haslo     |
|-----------|-----------------------------|-----------|
| klient    | anna.kowalska@example.com   | haslo123  |
| pracownik | pracownik@techsklep.pl      | praca123  |
| admin     | admin@techsklep.pl          | admin123  |

## Co jest

- Strona glowna, katalog z filtrem kategorii
- Strona produktu z recenzjami
- Koszyk (w sesji) + finalizacja zamowienia (pakiet P_ZAMOWIENIA)
- Logowanie (bcrypt) / rejestracja (pakiet P_KLIENCI) / wylogowanie
- Panel pracownika/admina: produkty, zamowienia (zmiana statusu), log operacji
- Kontrola dostepu wg roli (KLIENT / PRACOWNIK / ADMIN)
