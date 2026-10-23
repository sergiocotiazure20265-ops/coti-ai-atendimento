# COTI AI Atendimento

Plataforma de atendimento inteligente com dois microsserviços independentes. A implementação atual cobre **somente a Fase 1: infraestrutura local PostgreSQL/pgvector**. As aplicações Java, MCP e geração de respostas ainda não estão implementadas.

## Pré-requisitos

- Docker Desktop em execução, com engine Linux e Docker Compose.
- PowerShell 7 (`pwsh`) para os scripts locais.
- Porta TCP 5434 livre. Nenhuma API key OpenAI é necessária nesta fase.

Execute os comandos a partir da raiz do repositório. O acesso ao Docker deve estar disponível ao processo; em ambientes com sandbox, pode ser necessária autorização para acessar o engine.

## Inicialização local

```powershell
./scripts/init-local-env.ps1
docker compose config --quiet
docker compose pull postgres
docker compose up -d --wait --wait-timeout 90 postgres
./scripts/validate-infra.ps1 -PersistenceMode Seed
```

O primeiro comando gera três senhas criptograficamente aleatórias e distintas no `.env` ignorado pelo Git, sem imprimir valores. Ele recusa sobrescrever um arquivo existente. `.env.example` contém somente marcadores; não é uma configuração pronta para iniciar o banco. Variáveis exportadas no processo têm precedência sobre `.env`, conforme Docker Compose: evite valores antigos no terminal.

Não use `docker compose config` sem `--quiet` em logs ou relatórios: a configuração resolvida contém credenciais. Também não imprima `.env`, `docker inspect` completo ou os ambientes do contêiner. Pessoas com acesso administrativo ao Docker podem ler o ambiente dos contêineres; esta não é uma solução de cofre de produção.

## Conexão e privilégios

| Item | Valor |
|---|---|
| Host / porta local | `127.0.0.1:5434` |
| Porta no contêiner | `5432` |
| Banco | `coti_conhecimento` |
| Schema futuro de aplicação | `conhecimento` |
| Bootstrap privilegiado | `coti_bootstrap`, senha `POSTGRES_PASSWORD` |
| Migrações | `coti_migrator`, senha `DB_MIGRATION_PASSWORD` |
| Runtime de conhecimento | `coti_runtime`, senha `DB_PASSWORD` |
| Volume | `coti-ai-atendimento_postgres_data` |

As senhas vêm do ambiente privado. O runtime tem CONNECT/USAGE e receberá DML nas tabelas criadas pelo migrator no schema conhecimento; não tem CREATE, superusuário, criação de roles/bancos nem associação ao migrator. O migrator é proprietário do schema conhecimento, mas não é superusuário nem pode criar schemas arbitrários no banco. Extensões vector, hstore e uuid-ossp são instaladas pelo bootstrap. Migrações de tabelas e índice HNSW pertencem às fases posteriores.

Autenticação por senha SCRAM-SHA-256 tanto em TCP quanto em sockets locais, sem trust. O healthcheck verifica disponibilidade; a validação adicional testa autenticação e privilégios realmente.

O banco não participa da rede `servicos`. A rede `dados` é interna; somente conhecimento e banco participarão dela. A bridge `operacao_local` é exclusiva do PostgreSQL e tem masquerade de saída desabilitado. Ela é necessária no Docker Engine 29 para publicar a porta local quando o banco também está em rede interna (ADR-13). Nenhuma API deve ser ligada a essa bridge. A publicação fica somente em loopback; remova a publicação e essa bridge antes de expor a solução em rede.

## Validação reproduzível e persistência

```powershell
./scripts/validate-infra.ps1
./scripts/validate-infra.ps1 -PersistenceMode Seed
docker compose up -d --force-recreate --wait --wait-timeout 90 postgres
./scripts/validate-infra.ps1 -PersistenceMode Verify
```

- `Check` (padrão): versão/extensões, rede, volume, porta efetiva e TCP no host, SCRAM, login de ambas as roles, rejeição de senha incorreta e DDL negado com SQLSTATE 42501.
- `Seed`: realiza os checks, cria somente um schema/tabela técnica `infra_validation.persistence_marker`, grava um marcador UUID e salva sua referência em `artifacts/infra/persistence-marker.txt`, ignorado pelo Git. Não cria tabela de domínio.
- `Verify`: realiza os checks e compara o marcador persistido com a referência anterior à recriação. Também prova INSERT/UPDATE/DELETE pelo runtime em transação revertida, sem alterar o marcador.

O marcador técnico pode permanecer para futuras verificações e não participa do acervo. Nenhum modo apaga volume ou dados. Um erro produz exit code 1, com mensagem sanitizada; SQL/ambiente bruto não são impressos.

Para interromper sem remover dados:

```powershell
docker compose stop postgres
```

Não use remoção de volumes como limpeza rotineira. `docker compose up --force-recreate` recria o contêiner, mas reutiliza o volume nomeado. Se o marcador local de referência não existir, execute Seed antes de iniciar um novo teste de persistência; criar uma nova referência depois da recriação não comprova a persistência daquele evento anterior.

## Bootstrap, falhas e rotação de credenciais

O entrypoint oficial executa `infra/postgres/bootstrap/010-roles-and-extensions.sh` **apenas quando o diretório de dados está vazio**. Alterar o script ou `.env` não modifica automaticamente roles/extensões/senhas de um banco existente.

Se o bootstrap falhar, preserve o volume e investigue com acesso administrativo; não reinicialize ou apague o banco automaticamente. O validador completo detecta roles/extensões ausentes mesmo se o healthcheck simples estiver verde.

Para rotação, use uma conexão administrativa confiável e alteração interativa de senha, atualize os valores privados de ambiente e recrie os contêineres consumidores. Evite senhas em argumentos, histórico SQL ou logs. O gerador local não é ferramenta de rotação e não sobrescreve `.env`. Não conceda superusuário à aplicação para resolver erros de permissão.

## Evidência da imagem utilizada na Fase 1

| Componente | Resultado observado |
|---|---|
| Docker Desktop | 4.61.0 (219004), engine Linux |
| Engine / Compose | 29.2.1 / v5.0.2 |
| Imagem | `pgvector/pgvector:0.8.2-pg16-bookworm` |
| Digest resolvido | `pgvector/pgvector@sha256:00ba258a66dac104fd5171074a0084462a64a1369d8513f3d0a634e2f24d15bc` |
| PostgreSQL efetivo | 16.14 (Debian 16.14-1.pgdg12+1) |
| Extensão vector | 0.8.2 |

O digest identifica a imagem efetivamente validada. A tag pode receber atualização do patch PostgreSQL; um novo pull exige conferir versão/digest e repetir a validação. Para reproduzir exatamente esta execução, selecione o digest registrado em configuração de ambiente/revisão aprovada, sem inventar atualização ou alterar a major 16.

O progresso e os resultados, inclusive falhas corrigidas, ficam em [specs/08-checklist.md](specs/08-checklist.md). A próxima fase é estrutura Maven/inicialização, condicionada à conclusão da preparação documental T002 e ao aceite G1 da infraestrutura.
