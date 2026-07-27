-- Ajuste de autovacuum para tabelas de alta rotatividade / grande volume.
-- O padrao do Postgres (scale_factor 0.2 = 20%) e alto demais para tabelas
-- com dezenas de milhoes de linhas: o autovacuum so dispara depois de
-- acumular um volume enorme de tuplas mortas. Reduzido para 2% (0.02),
-- com threshold minimo, para disparar a limpeza bem mais cedo.

ALTER TABLE schema.fila_eventos SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_vacuum_threshold = 1000,
    autovacuum_analyze_scale_factor = 0.02
);

ALTER TABLE schema.eventos_recebidos SET (
    autovacuum_vacuum_scale_factor = 0.02,
    autovacuum_vacuum_threshold = 1000
);
