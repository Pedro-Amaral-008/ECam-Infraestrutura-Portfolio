
# --- Exemplo de integracao com plataforma de observabilidade central ---
# Ao final da execucao, reporta o resultado (sucesso/falha) via HTTP POST
# para um painel de monitoramento central, que exibe status e dispara
# alerta (ex: Telegram) automaticamente em caso de falha, com cooldown.
#
# curl -s -X POST http://<host-monitoramento>:8000/backups/registrar \
#   -H "x-api-key: <chave>" \
#   -H "Content-Type: application/json" \
#   -d "{
#     \"job_name\": \"Backup <servico>\",
#     \"instance\": \"<instancia>\",
#     \"backup_type\": \"Dump PostgreSQL\",
#     \"status\": \"$STATUS\",
#     \"executado_em\": \"$(date +%Y-%m-%dT%H:%M:%S)\"
#   }"
