# Migração de Sistema de Telemetria Veicular — Cloud → Self-Hosted

**Portfólio técnico** documentando a migração de um sistema de monitoramento de frota via câmeras veiculares (GPS, heartbeat, alarmes) de uma plataforma cloud (PaaS) para infraestrutura própria (self-hosted), com Docker.

> Este repositório é uma versão sanitizada para fins de demonstração. Não contém código-fonte de aplicação, credenciais, endereços de rede reais ou qualquer informação identificável de terceiros.

## Contexto do projeto

Sistema de produção com histórico de dados relevante (banco de dados na casa de centenas de GB em tamanho bruto) rodando em uma plataforma cloud, migrado para um servidor físico próprio — parte de uma iniciativa maior de trazer a infraestrutura de TI para dentro de casa, reduzindo custo recorrente e ganhando controle operacional.

## Desafios técnicos enfrentados e soluções

### 1. Provisionamento de servidor do zero, sem conectividade inicial
- Rede Wi-Fi configurada via Netplan em um ambiente sem acesso à internet
- Dependência de pacote (`wpasupplicant`) resolvida via instalação offline por pendrive, incluindo resolução de dependência transitiva (`libpcsclite1`)

### 2. Armazenamento redundante e escalável
- Configuração de **RAID 0** via `mdadm`, unindo dois discos físicos em um único volume lógico, para acomodar volume de dados de produção sem comprometer o disco de sistema (NVMe)
- Estratégia de separação: disco de sistema para SO/aplicação, RAID para dados de alto volume

### 3. Migração de banco de dados de grande porte
- `pg_dump`/`pg_restore` de um banco PostgreSQL com dado bruto na casa de ~200GB, via proxy de rede pública
- Identificação e tratamento de timeout de conexão em transferências de longa duração (parâmetros `keepalives`)
- Execução resiliente de processos de longa duração via `tmux`, protegendo contra interrupção por queda de sessão remota
- Identificação de tabelas com acúmulo de dados históricos sem rotina de limpeza (uma única tabela de fila de eventos representava mais de 1/3 do volume total do banco)

### 4. Containerização
- Dockerfile multi-stage (build de frontend + runtime de backend Node.js)
- Orquestração via Docker Compose (aplicação + PostgreSQL)
- Gerenciamento de logs com rotação, para evitar crescimento descontrolado de disco

### 5. Planejamento de corte de produção (cutover)
- Estratégia de virada com sistema fornecedor externo (webhook) apontando para o novo ambiente
- Plano de reconciliação de dados para o intervalo entre a última cópia de dados e o corte efetivo

## Stack

- Ubuntu Server 24.04 LTS
- Docker + Docker Compose
- PostgreSQL 17
- Node.js 20 (Express + React/Vite)
- RAID 0 (mdadm)

## Estrutura

```
infra/
  Dockerfile
  docker-compose.example.yml
```

