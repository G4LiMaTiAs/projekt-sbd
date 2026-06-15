# Konfiguracja polaczenia z baza Oracle.
# Aplikacja laczy sie jako wlasciciel schematu (ten sam uzytkownik, w ktorym
# odpaliles projekt.sql i reszte skryptow).
# Mozna nadpisac przez zmienne srodowiskowe albo zmienic wartosci ponizej.

import os

# dane logowania do bazy
DB_USER     = os.environ.get("DB_USER", "id_116425")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "mateusz_lisowski")

# adres bazy - serwer zdalny 212.33.90.212, port 1521, SID v732
DB_DSN      = os.environ.get("DB_DSN", "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=212.33.90.212)(PORT=1521))(CONNECT_DATA=(SID=v732)))")

# klucz sesji Flaska
SECRET_KEY  = os.environ.get("SECRET_KEY", "tajny-klucz-dev-zmienic")
