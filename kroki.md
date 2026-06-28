# Kroki prezentacji projektu PPV (PostgreSQL HA)

## Architektura

```
warszawa1 (MASTER, :5432)  ──┬──▶ haproxy_write (:5432) ──▶ aplikacja (zapis)
                             │
warszawa2 (STANDBY 1)       ├──▶ haproxy_read  (:5433) ──▶ aplikacja (odczyt)
warszawa3 (STANDBY 2)       │
krakow_dr (DR / BACKUP)     ┘    watchdog ──▶ failover na krakow_dr
backup_agent                     (pełny, różnicowy, WAL)
pgadmin                          http://localhost:5050
stats read:                      http://localhost:8405/haproxy?stats (admin:admin123)
stats write:                     http://localhost:8404/haproxy?stats (admin:admin123)
```

---

## 1. Uruchomienie środowiska

```bash
# Buduje obrazy i uruchamia wszystkie kontenery w tle
docker compose up -d --build

# Sprawdzenie stanu kontenerów (wszystkie powinny być "running")
docker compose ps
```

---

## 2. Weryfikacja replikacji

```bash
# Status replikacji na masterze — widać podłączone standbys
docker exec -u postgres -it warszawa1_master psql -U postgres -c "SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn FROM pg_stat_replication;"

# Potwierdzenie, że standby jest w trybie hot_standby
docker exec -u postgres -it warszawa2_read1 psql -U postgres -c "SELECT pg_is_in_recovery();"
docker exec -u postgres -it warszawa3_read2 psql -U postgres -c "SELECT pg_is_in_recovery();"

# Krakow DR — też standby (z restore_command dla WAL)
docker exec -u postgres -it krakow_dr psql -U postgres -c "SELECT pg_is_in_recovery();"
```

---

## 3. Wstawianie i odczyt danych (replikacja działa)

```bash
# Wstaw event przez mastera (haproxy_write 172.20.0.6:5432)
docker exec -it klient psql -h 172.20.0.6 -p 5432 -U postgres -d ppv_db -c "INSERT INTO streaming.events(title, event_date, price) VALUES ('Finał PPV 2026', '2026-07-01 20:00', 49.99);"

# Odczytaj z repliki przez haproxy_read (172.20.0.7:5433)
docker exec -it klient psql -h 172.20.0.7 -p 5433 -U postgres -d ppv_db -c "SELECT * FROM streaming.events;"
```

---

## 4. Load balancing odczytu (round-robin)

```bash
# Każde kolejne zapytanie trafia na inny węzeł (warszawa2 / warszawa3)
for i in 1 2 3 4; do docker exec -it klient psql -h 172.20.0.7 -p 5433 -U postgres -d ppv_db -c "SELECT inet_server_addr();" 2>/dev/null; done
```

---

## 5. Uprawnienia ról

```bash
# operator1 — może SELECT na events/channels, INSERT na orders, NIE może dotknąć payments
docker exec -e PGPASSWORD=Operator123! -it klient psql -h 172.20.0.6 -p 5432 -U operator1 -d ppv_db -c "SELECT * FROM streaming.events;"
docker exec -e PGPASSWORD=Operator123! -it klient psql -h 172.20.0.6 -p 5432 -U operator1 -d ppv_db -c "SELECT * FROM billing.payments;"
# ↑ powyższe powinno zwrócić: ERROR: permission denied
```

---

## 6. Symulacja failoveru (awaria mastera)

```bash
# Zatrzymaj mastera
docker compose stop warszawa1

# Watchdog wykryje awarię i wypromuje krakow_dr — obserwuj logi
docker logs -f watchdog

# Po promocji — zapis idzie teraz do krakow_dr przez haproxy_write
docker exec -it klient psql -h 172.20.0.6 -p 5432 -U postgres -d ppv_db -c "INSERT INTO streaming.events(title, event_date, price) VALUES ('Powrót po awarii', '2026-08-01 18:00', 29.99);"

# Weryfikacja — krakow_dr jest teraz masterem
docker exec -u postgres -it krakow_dr psql -U postgres -c "SELECT pg_is_in_recovery();"
# Powinno zwrócić: f (false)
```

---

## 7. Przywrócenie mastera

```bash
# Uruchom ponownie warszawa1
docker compose start warszawa1

# Sprawdź logi — nie jest już masterem, haproxy_write nadal wskazuje na krakow_dr
docker logs warszawa1_master --tail 30
```

---

## 8. Backupy

```bash
# Lista wykonanych backupów pełnych (niedzielny, pg_basebackup)
docker exec -it backup_agent ls -lh /backups/full/

# Lista backupów różnicowych (pg_dump, codziennie 03:00)
docker exec -it backup_agent ls -lh /backups/diff/

# Lista zarchiwizowanych logów WAL (codziennie 04:00)
docker exec -it backup_agent ls -lh /backups/logs/

# Ręczne wywołanie backupu pełnego bez czekania na cron
docker exec -it backup_agent bash /backup/full_backup.sh
```

---

## 9. PgAdmin (GUI)

```
URL:   http://localhost:5050
Email: admin@ppv.com
Hasło: admin123
```

Serwery są wstępnie skonfigurowane w `pgadmin/servers.json`.

---

## 10. Zatrzymanie i czyszczenie

```bash
# Zatrzymaj wszystkie kontenery
docker compose down

# Zatrzymaj i usuń wolumeny (reset danych)
docker compose down -v
```
