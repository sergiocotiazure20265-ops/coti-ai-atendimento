# Checklist e registro de execução — COTI AI Atendimento

## Estado atual — 2026-10-22

| Item | Status | Evidência / pendência |
|---|---|---|
| T001 — Reconciliação documental | Concluída e validada | Registro histórico abaixo, preservado. |
| T002 — Plano de testes e checklist completo | Pendente | `specs/07-test-plan.md` permanece vazio; falta matriz completa RF/RNF/RC/contratos e evidências por fase. |
| Fase 1 — Docker e PostgreSQL/pgvector, T003–T009 | Concluída e validada — G1 | Seed/Verify aprovados, contêiner recriado com marcador preservado; registro abaixo. |
| Fase 2 — Maven e inicialização, T010–T021 | Não iniciada | G1 concluído; aguarda T002 antes de iniciar. |
| Fase 3 — Persistência, T022–T029 | Não iniciada | Depende de G2. |
| Fase 4 — Chunking/embeddings, T030–T038 | Não iniciada | Depende de G3. |
| Fase 5 — Busca/MCP Server, T039–T048 | Não iniciada | Depende de G4. |
| Fase 6 — MCP Client/atendimento, T049–T058 | Não iniciada | Depende de G5. |
| Fase 7 — Chat/RAG, T059–T069 | Não iniciada | Depende de G6. |
| Fase 8 — Validação final, T070–T080 | Não iniciada | Depende de G7. |

**Progresso:** 8 de 80 tarefas concluídas (T001 e T003–T009); G1 aprovado, G2–G8 pendentes. Os registros de execução documentam T001 e Fase 1; não representam a implementação da matriz/checklist completa prevista na T002.

## Execução T001 — Reconciliar referências e escopo documental

**Data:** 2026-10-22, referência America/Sao_Paulo.

**Seleção:** primeira tarefa pendente do backlog, sem dependências. Foi executada somente T001 para respeitar a instrução de uma TASK por interação. A preparação documental não é uma nona fase; antecede as funcionalidades dependentes dos contratos. T002 e T003–T080 não foram executadas.

### Resultado e justificativa

- Corrigido o artigo 16 da constituição para o contrato canônico existente, `specs/06-api-contracts.md`, com motivo explícito da reconciliação.
- Registrados RC01 (listagem), RC02 (consulta individual) e RC03 (diagnóstico), com 11 critérios Given/When/Then, refletindo exclusivamente as operações já solicitadas e contratadas. RF01–RF10 e RNF01–RNF09 mantiveram sua numeração.
- Atualizadas as notas de referência/status em AGENTS.md, arquitetura, plano e introdução do contrato para eliminar a indicação desatualizada de divergência pendente.
- Preservados os corpos técnicos da arquitetura e do contrato, inclusive endpoints, DTOs, schemas, permissões, erros, limites, versões e diagramas. A alteração da arquitetura limita-se às notas documentais de reconciliação; nenhuma decisão técnica foi alterada.
- Registrado o status no backlog e mantidas todas as outras tarefas desmarcadas. Nenhum arquivo Java, POM, script persistente, contêiner ou serviço foi criado nesta tarefa.

### Arquivos criados

Nenhum. Todos os arquivos alterados já existiam, inclusive este checklist, que estava vazio.

### Arquivos modificados

| Arquivo | Alteração |
|---|---|
| `AGENTS.md` | Referência canônica explícita, sem divergência desatualizada. |
| `specs/01-constitution.md` | Caminho do artigo 16 corrigido e motivo registrado. |
| `specs/02-requirements.md` | RC01–RC03, critérios de aceite, inclusão no MVP e referências reconciliadas. |
| `specs/03-architecture.md` | Somente notas introdutória/final sobre o estado da reconciliação. |
| `specs/04-plan.md` | Referência da preparação e orientação de consulta ao progresso atual. |
| `specs/05-tasks.md` | T001 marcada, ligação à evidência e texto de retomada atualizado. |
| `specs/06-api-contracts.md` | Somente nota introdutória de reconciliação. |
| `specs/08-checklist.md` | Registro desta execução, resultados e pendências. |

### Comandos e verificações executados

| Execução | Resultado |
|---|---|
| `Get-Content` / `Get-Item` | Leitura das instruções, especificações e skill de testes; identificação das tarefas e dos documentos vazios. |
| `rg -n` | Localização de referências e notas de pendência a reconciliar. |
| `python -` com pathlib/hashlib | Snapshot de integridade anterior às alterações e comparação posterior dos documentos. |
| `python -` com json/jsonschema | Parsing de 20 exemplos JSON e validação dos dois schemas; exemplos estruturados MCP verificados contra o schema e texto espelhado. |
| `python -` com verificações documentais | Referência legada eliminada das instruções/specs; arquivo canônico existente; 10 RF, 9 RNF, 3 RC e 11 critérios complementares; cercas Markdown e whitespace conferidos. |
| Comparação SHA-256 | Corpo técnico do contrato a partir de segurança e corpo técnico da arquitetura entre stack e nota final idênticos ao snapshot; todos os blocos JSON do contrato idênticos. |
| `git diff --check` | Concluído sem erros; como os documentos já estavam não rastreados no Git, a checagem explícita de whitespace em Python complementou essa verificação. |
| `git status --short` | Alterações preexistentes não rastreadas de AGENTS.md/skills/specs preservadas, sem staging ou commit. |

**Compilação e testes da aplicação:** não aplicáveis a T001, exclusivamente documental; Maven, JUnit, Docker e OpenAI não foram executados. Validação documental não comprova compilação, funcionamento das APIs ou qualidade de IA. O relatório não apresenta esses testes como aprovados.

### Pendências e retomada

- Próxima tarefa na ordem: **T002 — detalhar plano de testes e checklist completo**, agora com T001 concluída. Manter este registro e acrescentar os critérios de aceite restantes sem reclassificar testes planejados como executados.
- Próxima fase de implementação: **Fase 1**, iniciando em **T003**, ainda pendente; nenhuma infraestrutura foi criada ou verificada nesta interação.
- T002 deve abranger também RC01–RC03, além de RF/RNF e contratos. Calibração de relevância, integração real e aceite do MVP continuam nas tarefas futuras.
- Não avançar para Maven/funcionalidades antes dos pontos de verificação e das dependências definidos em `specs/04-plan.md` e `specs/05-tasks.md`.

## Execução Fase 1 — T003–T009 — 2026-10-22

**Resultado:** fase concluída; G1 aprovado. Apenas infraestrutura PostgreSQL/pgvector foi implementada, sem iniciar a fase 2 ou criar classes Java/POMs. T002 é preparação documental independente e permanece pendente, conforme a permissão explícita do plano para executar a fase 1 antes dela. A regra atual do usuário é uma fase por interação; a seleção de tarefa única do registro T001 é histórica.

### Tarefas e evidências

| Tarefa | Resultado validado |
|---|---|
| T003 | Docker Desktop 4.61.0 (219004), Engine 29.2.1 Linux, Compose v5.0.2; zero listeners em 5434 antes da criação; pull da imagem definida confirmou acesso ao registry. |
| T004 | `.env.example` sem valores reais, `.gitignore`, senhas locais criptográficas distintas no `.env` ignorado. Gerador recusou sobrescrita e preservou o hash do arquivo; nenhum valor impresso. |
| T005 | `compose.yaml` validado com config --quiet; somente serviço postgres, volume nomeado, bind local e redes segregadas. Ajuste necessário da publicação documentado na ADR-13. |
| T006 | Bootstrap executado em volume novo, SCRAM sem trust, extensões vector/hstore/uuid-ossp e roles separadas; nenhum objeto de domínio criado. Sintaxe bash validada no contêiner. |
| T007 | Script PowerShell validado por parser e execução real. Check/Seed/Verify verificam estado, rede, TCP, roles e persistência; engine inacessível produz exit code 1. Diagnostics brutos não são impressos. |
| T008 | Contêiner saudável com PostgreSQL 16.14 (Debian 16.14-1.pgdg12+1), vector 0.8.2. Digest `pgvector/pgvector@sha256:00ba258a66dac104fd5171074a0084462a64a1369d8513f3d0a634e2f24d15bc` registrado no README. |
| T009 | Seed aprovado; contêiner recriado com ID diferente, mesmo volume; Verify aprovado com marcador idêntico. Runtime autentica, faz DML em transação revertida e recebe SQLSTATE 42501 ao tentar CREATE TABLE. |

O volume persistente `coti-ai-atendimento_postgres_data` foi preservado. O serviço permanece saudável em `127.0.0.1:5434` ao término; nenhum volume foi apagado. O marcador pertence ao schema técnico infra_validation e não é uma tabela do acervo/aplicação.

### Arquivos criados nesta fase

- `.gitattributes`: preserva finais LF dos scripts de bootstrap e demais fontes textuais.
- `.env.example`: nomes das variáveis e marcadores de configuração.
- `compose.yaml`: PostgreSQL, volume, redes, healthcheck e bind.
- `infra/postgres/bootstrap/010-roles-and-extensions.sh`: extensões/roles/permissões iniciais.
- `scripts/init-local-env.ps1`: geração local sem sobrescrita nem impressão de senhas.
- `scripts/validate-infra.ps1`: verificações de infraestrutura e persistência.
- **Locais, ignorados pelo Git:** `.env` com valores privados e `artifacts/infra/persistence-marker.txt` com a referência técnica para comparação. Não publicar seus conteúdos.

### Arquivos modificados nesta fase

- `.gitignore`: acrescenta proteção para ambiente privado, chaves e artefatos locais, preservando as exclusões Java existentes.
- `README.md`: instruções reproduzíveis, contas, persistência, bootstrap/rotação, riscos de logs e digest real.
- `specs/03-architecture.md`: ADR-13 e adaptação necessária de topologia local, justificada por falha observada; demais decisões mantidas.
- `specs/04-plan.md`: critério G1 atualizado para verificar porta efetiva e bridge de operação local da ADR-13.
- `specs/05-tasks.md`: T003–T009 marcadas e referência da evidência G1; ajuste da descrição de rede de T005 para ADR-13.
- `specs/08-checklist.md`: status atual e este registro, mantendo o histórico T001.

### Comandos/testes executados e resultados

| Execução | Resultado |
|---|---|
| `docker version`, `docker info`, `docker compose version` | Engine Linux e versões confirmados. A primeira tentativa dentro do sandbox não acessou configuração/pipe; execução autorizada fora do sandbox funcionou, sem mudança global no Docker. |
| Consulta de listeners com `Get-NetTCPConnection` | Porta 5434 livre antes da implementação. |
| `docker pull pgvector/pgvector:0.8.2-pg16-bookworm` | Imagem obtida; digest real registrado. |
| `./scripts/init-local-env.ps1` | `.env` criado sem imprimir valores; segunda execução recusada e hash preservado. |
| `git check-ignore .env artifacts/infra/persistence-marker.txt` | Ambos ignorados. |
| Parser PowerShell / parser YAML Python | Sintaxe dos dois scripts e Compose conferida, finais LF e único serviço postgres verificados. |
| `docker compose config --quiet` | Configuração válida, sem imprimir ambiente resolvido. |
| `docker compose up -d --wait --wait-timeout 90 postgres` | Contêiner criado e saudável; bootstrap executado no volume novo. |
| Inspeção filtrada de portas/redes/volume e teste TCP | Detectou falha da rede exclusivamente interna; após ADR-13, porta efetiva 127.0.0.1:5434 e conexão real confirmadas. Nenhuma inspeção completa com ambiente secreto foi impressa. |
| `docker compose exec -T postgres bash -n /docker-entrypoint-initdb.d/010-roles-and-extensions.sh` | Sintaxe bash aprovada. |
| `./scripts/validate-infra.ps1 -PersistenceMode Seed` | Versão/extensões, SCRAM sem trust, rede, porta/TCP, volume/bootstrap read-only, logins, privilégios mínimos, senha incorreta e DDL negado aprovados; marcador gravado. |
| `docker compose up -d --force-recreate --wait --wait-timeout 90 postgres` | Somente contêiner recriado, ID alterado e volume reutilizado. |
| `./scripts/validate-infra.ps1 -PersistenceMode Verify` | Todas as verificações repetidas com sucesso; marcador anterior preservado e DML runtime comprovado com rollback. |
| Validador em processo com DOCKER_HOST inacessível | Exit code 1 esperado, sem falso positivo; variáveis do processo restauradas. |
| Verificação dos logs PostgreSQL em memória | Nenhuma das três credenciais locais presente; conteúdo dos logs/segredos não exibido. |
| `docker compose ps postgres` | Saudável, `127.0.0.1:5434->5432/tcp`. |
| Auditoria final Python e `git diff --check` | 80 IDs únicos e somente T001/T003–T009 concluídas; exclusões Java originais preservadas; 12 arquivos públicos revisados sem as credenciais locais, erros de encoding ou whitespace; nenhum Java/POM criado. Diff sem erros, com aviso de normalização LF/CRLF em `.gitignore`. |

**Compilação/testes Java:** não aplicáveis à fase 1; não há projetos Java/Maven implementados. Nenhum teste JUnit, Testcontainers ou OpenAI foi apresentado como executado. A validação de banco nesta fase foi realizada diretamente contra PostgreSQL/pgvector em Docker.

### Falhas encontradas e corrigidas

1. **Publicação da porta com somente rede interna:** a primeira validação encontrou NetworkSettings.Ports vazio apesar de HostConfig.PortBindings declarar 5434; o host recusou conexão. Mantida dados interna e adicionada bridge exclusiva operacao_local com masquerade desabilitado, sem conectar PostgreSQL a servicos. ADR-13/critério G1 e teste TCP efetivo registram a necessidade. Não houve troca de versão/engine ou desativação de autenticação. Referências técnicas na arquitetura.
2. **Criação de schema técnico pelo migrator:** Seed inicialmente falhou porque o migrator não possui CREATE no banco, por desenho de privilégio mínimo. Ajustado o validador para o bootstrap criar somente o schema técnico e o migrator criar sua tabela. Nenhum privilégio adicional foi concedido ao migrator/runtime. Seed e Verify passaram depois da correção.

### Pendências e próxima fase

- Nenhuma pendência obrigatória de G1. A adaptação de rede é local e deve ser removida juntamente com a publicação 5434 antes de expor em rede.
- **T002 permanece pendente**: plano de testes/checklist completo, incluindo RF/RNF/RC/contratos. A execução da infraestrutura não conclui essa preparação.
- **Próxima fase: Fase 2 — estrutura Maven e inicialização dos dois microsserviços**, somente após T002; G1 já está aprovado. Nenhuma tarefa T010+ foi iniciada.
- Repetir a validação se a tag resolver outro digest/patch, houver rotação de credenciais ou mudança de configuração. Não regenerar `.env` nem apagar volumes para contornar divergências de autenticação.
