#!/bin/bash
# Manutencao semanal de VACUUM nas tabelas de maior volume/rotatividade.
# Agendado via cron, em horario de baixo uso.
# Motivado por diagnostico de I/O: autovacuum nunca havia rodado na tabela
# de fila de eventos, acumulando centenas de milhares de tuplas mortas
# e derrubando o armazenamento para 100% de utilizacao (iowait ~98%).

LOG=/var/log/app-vacuum.log

docker exec app-db psql -U appuser -d appdb -c "VACUUM (VERBOSE, ANALYZE) schema.fila_eventos;" >> "$LOG" 2>&1
docker exec app-db psql -U appuser -d appdb -c "VACUUM (VERBOSE, ANALYZE) schema.eventos_recebidos;" >> "$LOG" 2>&1
docker exec app-db psql -U appuser -d appdb -c "VACUUM (VERBOSE, ANALYZE) schema.tabela_grande_1;" >> "$LOG" 2>&1
docker exec app-db psql -U appuser -d appdb -c "VACUUM (VERBOSE, ANALYZE) schema.tabela_grande_2;" >> "$LOG" 2>&1
