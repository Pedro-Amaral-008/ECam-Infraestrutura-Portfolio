# Migracao de Sistema de Telemetria — Cloud para Self-Hosted

Portfolio tecnico documentando a migracao de um sistema de monitoramento de frota via cameras veiculares (GPS, heartbeat, alarmes) de uma plataforma cloud (PaaS) para infraestrutura fisica propria (self-hosted), com Docker.

> Versao sanitizada para fins de demonstracao. Nao contem codigo-fonte de aplicacao, credenciais, enderecos de rede reais ou qualquer informacao identificavel de terceiros.

## Objetivo

Reduzir custo recorrente de infraestrutura em nuvem e trazer controle operacional total sobre sistemas internos criticos, migrando-os para servidores fisicos proprios.

## Contexto e escopo

De um conjunto de multiplos sistemas internos hospedados em cloud, o de **maior custo de manutencao** foi priorizado como piloto do processo de migracao — validando a estrategia completa (dump/restore de banco de grande porte, containerizacao, armazenamento redundante) antes de replicar para os demais sistemas, que aguardam a aquisicao de um servidor dedicado de maior capacidade.

## Arquitetura

```
Fornecedor externo (cameras / telemetria)
        |
        v  webhook HTTPS
   Reverse Proxy (Caddy, TLS)
        |
        v
   App (Node.js / Express)
     - API REST
     - Painel web (React)
     - Workers internos (fila de ingestao, motor de alertas)
        |
        v
   PostgreSQL 17
        |
        v
   RAID 0 (mdadm) — volume de dados
```

Toda a stack roda em containers Docker, com o armazenamento dividido entre dois discos com propósitos distintos:

| Disco | Conteúdo |
|---|---|
| Disco de sistema (NVMe) | Sistema operacional, Docker Engine, imagens de container, aplicação |
| RAID 0 (discos mecânicos) | Volume de dados do PostgreSQL — todo o banco de produção |

Essa separação foi uma decisão tomada **durante** a migração, não planejada desde o início: o volume do banco estava inicialmente no disco de sistema (comportamento padrão do Docker), mas o restore de um banco de grande porte colocou em risco o espaço livre disponível ali, compartilhado com SO e imagens. A solução foi realocar o volume de dados para o RAID, isolando o crescimento do banco do disco de sistema.

## Desafios tecnicos enfrentados e solucoes

**Provisionamento sem conectividade inicial**
Configuracao de rede Wi-Fi via Netplan em um ambiente sem acesso a internet no momento da instalacao. Resolucao de dependencia de pacote (`wpasupplicant` + dependencia transitiva) via instalacao offline por pendrive.

**Armazenamento de grande volume**
Configuracao de RAID 0 via `mdadm`, unindo dois discos fisicos em um unico volume logico, para acomodar dados de producao sem comprometer o disco de sistema (NVMe, capacidade limitada). Expansao de volume logico (LVM) para liberar espaco alocado nao utilizado.

**Migracao de banco de dados de grande porte**
`pg_dump`/`pg_restore` de um banco de producao com dado bruto na casa de ~200GB, via proxy de rede publica. Identificacao e correcao de timeout de conexao em transferencias de longa duracao (parametros de keepalive). Execucao resiliente de processos de dezenas de horas via `tmux`, protegendo contra interrupcao por queda de sessao remota.

**Deteccao de anomalia de dados**
Identificacao de uma unica tabela de fila de eventos, sem rotina de limpeza, responsavel por mais de um terco do volume total do banco de origem — achado relevante para o planejamento de retencao de dados no novo ambiente.

**Adaptacao de estrategia em tempo real**
Durante o restore, deteccao de que o volume de dados excedia a capacidade do disco de sistema (ver secao Arquitetura). Migracao da estrategia de armazenamento (bind mount para RAID) em pleno andamento do processo, sem perder o progresso ja realizado.

**Containerizacao**
Dockerfile multi-stage (build de frontend + runtime de backend Node.js). Orquestracao via Docker Compose. Gerenciamento de logs com rotacao, para evitar crescimento descontrolado de disco.

**Planejamento de corte de producao**
Estrategia de virada com sistema fornecedor externo (webhook) apontando para o novo ambiente. Plano de reconciliacao de dados para o intervalo entre a ultima copia de dados e o corte efetivo.

**Exposição pública e HTTPS**
Diagnóstico e contorno de defeito físico na porta Ethernet onboard do servidor, resolvido via adaptador USB-Ethernet com IP estático. Configuração de NAT (port forward) em firewall com múltiplas WANs. Registro DNS público apontando para o IP público. Certificado TLS automático via Caddy + Let's Encrypt. Diagnóstico e correção de NAT hairpin/loopback — cenário em que o acesso ao domínio público falha apenas quando originado de dentro da própria rede — resolvido via Split DNS no resolver do firewall, fazendo o mesmo domínio resolver para IP interno de dentro da rede e IP público de fora.

**Recuperação de incidente sem perda de dados**
Durante o transporte físico do servidor, o array RAID perdeu a assinatura (superblock) em um dos discos, levando o boot a modo de emergência. Recuperação via recriação do array com os mesmos parâmetros originais (nível, número de discos, tamanho de chunk, ordem dos discos), preservando o mapeamento físico dos dados. Validação pós-recuperação por contagem de registros no banco restaurado, conferida contra o volume original.


**Diagnóstico e correção de performance pós-produção**
Após a virada de produção, identificado via `iostat` um `%iowait` de até 98% e utilização de disco em 100%, mesmo com CPU e RAM ociosas — um padrão clássico de gargalo de I/O mascarado como "servidor lento". Causa raiz: o autovacuum do PostgreSQL nunca havia executado na tabela de maior volume (fila de eventos), acumulando centenas de milhares de tuplas mortas. Correção: VACUUM manual para liberar o acúmulo existente, seguido de ajuste dos parâmetros de autovacuum (reduzindo o scale factor de 20% para 2%) nas tabelas de maior rotatividade, e agendamento de manutenção preventiva semanal. Resultado: iowait caiu de 98% para ~15%, utilização de disco de 100% para ~35-40%.

## Stack

| Tecnologia | Funcao |
|---|---|
| Ubuntu Server 24.04 LTS | Sistema operacional do servidor |
| Docker / Docker Compose | Orquestracao dos containers |
| PostgreSQL 17 | Banco de dados da aplicacao |
| Node.js 20 (Express) | Backend / API REST |
| React + Vite | Painel web |
| mdadm (RAID 0) | Armazenamento de dados de producao |
| Caddy | Reverse proxy / TLS |
| tmux | Execucao resiliente de processos de longa duracao |

## Estrutura

```
infra/
  Dockerfile
  docker-compose.example.yml
  Caddyfile.example
scripts/
  vacuum-maintenance.sh
  tune-autovacuum.sql
```

## Roadmap

- [x] Provisionamento do servidor (rede, Docker, RAID)
- [x] Containerizacao da aplicacao
- [x] Migracao de dados de producao (dump/restore)
- [x] HTTPS com dominio proprio (proxy reverso, TLS automatico, Split DNS)
- [x] Recuperacao de incidente de RAID sem perda de dados
- [x] Corte de producao (virada do webhook do fornecedor externo)
- [x] Diagnostico e correcao de performance (I/O, autovacuum)
- [ ] Reconciliacao de dados do periodo de transicao
- [ ] Migracao dos demais sistemas, apos aquisicao de servidor dedicado
