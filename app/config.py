# Konfiguracja polaczenia z baza Oracle.
# Aplikacja laczy sie jako wlasciciel schematu (ten sam uzytkownik, w ktorym
# odpaliles projekt.sql i reszte skryptow).
# Mozna nadpisac przez zmienne srodowiskowe albo zmienic wartosci ponizej.

import os

# dane logowania do bazy - ZMIEN na swoje
DB_USER     = os.environ.get("DB_USER", "sklep")          # np. twoj uzytkownik schematu
DB_PASSWORD = os.environ.get("DB_PASSWORD", "sklep")      # haslo do bazy

# DSN: host:port/service_name  (typowo dla Oracle 19c XE -> XEPDB1)
DB_DSN      = os.environ.get("DB_DSN", "localhost:1521/XEPDB1")

# klucz sesji Flaska
SECRET_KEY  = os.environ.get("SECRET_KEY", "tajny-klucz-dev-zmienic")
