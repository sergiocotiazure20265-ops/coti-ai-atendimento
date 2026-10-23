# Plano de implementação — COTI AI Atendimento

## 1. Referências, escopo e execução

Plano derivado da leitura integral das especificações existentes: `01-constitution.md`, `02-requirements.md`, `03-architecture.md` e `06-api-contracts.md`. Na leitura inicial, este arquivo, `05-tasks.md`, `07-test-plan.md` e `08-checklist.md` estavam vazios. Também foram consultados `AGENTS.md` e as quatro skills técnicas de `skills/`.

Este documento e `05-tasks.md` são planejamento: nenhum comando de infraestrutura, compilação ou teste de aplicação abaixo foi executado nesta etapa. Arquivos e classes são previstos, não implementados. Tarefas continuam desmarcadas até haver evidência de execução e aceite.

Executar **Spec → Plan → Implement → Test → Review** em cada tarefa. Manter as versões e decisões de `03-architecture.md`: Java 21, Maven Wrapper 3.9.11, Boot 4.1.1, Spring AI 2.0.1, SDK MCP 2.0.0, JUnit 5.14.0 com bootstrap programático sem SpringExtension e PostgreSQL 16/pgvector 0.8.2. Não reabrir decisões silenciosamente por conveniência de implementação.

As oito fases têm ordem de integração. Dentro de cada fase, respeitar as dependências explícitas de `05-tasks.md`; a conclusão técnica da fase anterior é requisito adicional para iniciar implementação da seguinte. Cada fase termina em um ponto de verificação, identificado como G1–G8. Não confundir ponto de verificação técnico com aceite final de todos os requisitos envolvidos.

### 1.1 Preparação documental

T001 reconcilia explicitamente a referência de contrato na constituição para `specs/06-api-contracts.md` e registra nos requisitos a listagem, consulta e diagnóstico já solicitados, sem alterar interfaces ou decisões técnicas. A evidência e o status da execução ficam em `specs/08-checklist.md` e `specs/05-tasks.md`, sem presumir equivalência entre caminhos.

T002 preenche o plano de testes e o checklist final, com rastreabilidade RF/RNF/contratos, estratégia JUnit estabelecida na arquitetura, fixtures e evidências esperadas. Documentos vazios não equivalem a validação aprovada.

Essas tarefas não criam uma nona fase de implementação. São preparação para as oito fases abaixo; a infraestrutura sem dependência de contrato pode ser preparada antes de T001/T002, mas nenhum ponto de verificação de funcionalidade dependente do contrato pode ser aprovado sem a reconciliação correspondente.

### 1.2 Segurança, testes e incrementos incompletos

- Testes proporcionais ao comportamento acompanham cada fase. A fase 8 acrescenta regressão integrada, avaliações e revisão de segurança/observabilidade; não inaugura esses controles.
- Credenciais externas, bind local, negação por padrão, erros sanitizados e logs sem conteúdo sensível entram antes da exposição de rotas.
- Na fase 3, implementar a preparação da ingestão por portas e testes com dublês. Não publicar documento nem retornar POST 201 antes do pipeline completo da fase 4. Não criar um endpoint temporário incompatível ou publicar chunk fictício.
- Na fase 6, a consulta MCP é real e determinística, mas geração ainda é uma porta não conectada ao provedor. Testes podem controlá-la; a rota completa não fica pronta para consumidores até a fase 7. Nenhuma resposta factual de dublê deve existir no perfil normal.
- Fixtures ficam somente em testes ou ambiente de avaliação explicitamente isolado. Ausência de API key não é resolvida com segredo fictício no runtime normal nem com chamadas reais escondidas em testes comuns.
- O MVP não implementa atualização/exclusão pública, filas, retry automático, novos canais ou tools adicionais. Reprocessamento explícito de ingestão falha continua obrigatório e não amplia esse escopo.

## 2. Visão das fases e pontos de verificação

| Fase | Tarefas | Dependências | Resultado verificável |
|---|---|---|---|
| 1 — Infraestrutura | T003–T009 | Docker Desktop disponível | G1: banco 16/pgvector, roles, volume, rede e porta 5434 verificados. |
| 2 — Maven e inicialização | T010–T021 | G1, T001 e T002 | G2: dois builds/processos independentes e infraestrutura de testes funcionando. |
| 3 — Persistência e preparação da ingestão | T022–T029 | G2 | G3: modelo/repositórios/política de fontes e consultas administrativas corretos. |
| 4 — Chunking e embeddings | T030–T038 | G3 | G4: POST indexa e publica atomicamente com vetores 1536. |
| 5 — Busca e MCP Server | T039–T048 | G4 | G5: busca filtrada e tool MCP real conformes; corpus preparado. |
| 6 — MCP Client e atendimento | T049–T058 | G5 | G6: cliente real, delegação e pesquisa determinística testados, geração ainda não habilitada ao consumidor. |
| 7 — OpenAI e contexto RAG | T059–T069 | G6 | G7: atendimento completo com limites, fontes e falhas explícitas. |
| 8 — Validação final | T070–T080 | G7 | G8: RF/RNF aceitos com evidências, avaliação semântica e operação local documentadas. |

Dependência principal: G1 → G2 → G3 → G4 → G5 → G6 → G7 → G8. Não iniciar uma fase apenas porque o código da anterior foi escrito: conferir seus testes e critérios de saída.

## 3. Convenções de arquivos e comandos

Nos arquivos previstos, **K** significa `api-conhecimento/src/main/java/br/com/cotiinformatica/conhecimento`; **A** significa `api-atendimentos/src/main/java/br/com/cotiinformatica/atendimentos`. Recursos e testes ficam nos diretórios de cada módulo definidos na arquitetura. Classes com o mesmo papel em ambos os serviços são implementações locais, sem biblioteca Java compartilhada de domínio ou contrato.

Comandos são destinados ao PowerShell na raiz do repositório **depois que os arquivos e scripts correspondentes existirem**. Os scripts listados serão criados pelas tarefas indicadas. Não executá-los antecipadamente e concluir sucesso por inexistência de testes. Usar variáveis de ambiente para credenciais, sem valores em linha de comando ou saída.

- `docker compose config --quiet` valida configuração sem imprimir segredos interpolados. Não publicar saída de `docker compose config` completo.
- `scripts/validate-infra.ps1` é previsto para T007: verifica banco, extensões, roles, bind e persistência de um marcador técnico descartável, usando autenticação por ambiente sem imprimir senhas.
- Maven `verify` deve executar compilação, Surefire `*Test` e Failsafe `*IT`, conferindo contagens e skips. Builds por `-f` comprovam independência do outro módulo.
- `scripts/verify-e2e.ps1` será criado em T074 e `scripts/verify-reports.ps1` em T075. Perfil `ai-evaluation` será criado em T077 e ficará desativado por padrão.
- Não executar `docker compose down -v`, apagar volumes persistentes ou imprimir logs completos para diagnosticar. Falta de Docker ou credenciais implica pendência explícita, não aprovação nem substituição por H2.

## Fase 1 — Infraestrutura Docker e PostgreSQL/pgvector

**Objetivo:** disponibilizar banco persistente local reproduzível, isolado e autenticado antes de qualquer aplicação.

**Dependências:** Docker Desktop em modo contêiner Linux, engine e Compose acessíveis, porta 5434 livre, permissão de pull e variáveis locais preparadas. T003 verifica o ambiente; T001/T002 não bloqueiam a criação da infraestrutura isolada.

**Arquivos previstos:** `compose.yaml`, `.env.example` sem segredos, `.gitignore`, `infra/postgres/bootstrap/` para roles/extensões, `scripts/validate-infra.ps1`, instruções operacionais em `README.md` e evidência do digest/patch da imagem. O Compose nesta fase contém somente PostgreSQL e declara as redes previstas; não referencia Dockerfiles de aplicações ainda inexistentes.

**Classes esperadas:** nenhuma classe Java. Bootstrap/script não cria tabelas de domínio ou migrações que pertencem às fases 3/4.

**Critérios de aceite — G1 (T009):**

- Imagem `pgvector/pgvector:0.8.2-pg16-bookworm` resolvida e digest registrado, PostgreSQL major 16 e extensão vector 0.8.2 confirmados; hstore/uuid-ossp disponíveis.
- Host em `127.0.0.1:5434` para porta interna 5432, banco `coti_conhecimento`, volume nomeado persistente e rede `dados` interna; bridge exclusiva `operacao_local` conforme ADR-13, sem participação das APIs e sem exposição na LAN. Validar conexão TCP efetiva, não apenas declaração de portas.
- Bootstrap administrativo separado do runtime; role runtime sem superusuário/DDL e senha externa, sem modo trust. Mudança de senha em `.env` não é apresentada como rotação automática de volume já inicializado.
- Recriar somente o contêiner preserva o marcador/dados; script verifica permissões sem revelar credenciais. Nenhuma imagem/app Java é exigida para validar esta fase.

**Comandos de validação previstos:**

```powershell
docker version
docker info
docker compose version
docker compose config --quiet
docker compose pull postgres
docker compose up -d postgres
docker compose ps postgres
docker image inspect pgvector/pgvector:0.8.2-pg16-bookworm --format '{{index .RepoDigests 0}}'
./scripts/validate-infra.ps1
```

**Riscos técnicos:** engine indisponível, proxy impedindo pull, conflito na porta, extensão não habilitada apesar de instalada, bootstrap que roda somente em volume novo, credenciais impressas, permissões excessivas e perda de dados por limpeza de volume. Tratar sem apagar banco existente ou trocar a imagem silenciosamente.

## Fase 2 — Estrutura Maven e inicialização dos dois microsserviços

**Objetivo:** criar dois projetos executáveis independentes, portas 8081/8082 e base de qualidade/configuração segura para as próximas fases.

**Dependências:** G1, T001 e T002. JDK 21 instalado, acesso aos artefatos Maven e material local de validação JWT fornecido fora do repositório. Serviços de IA ainda não implementados permanecem desabilitados explicitamente, sem exigir conexão real nos testes de bootstrap.

**Arquivos previstos:** POM raiz e POMs dos dois módulos, Wrapper e `.mvn/wrapper/`, classes principais, perfis `application*.yaml`, testes de bootstrap, configuração de segurança/parsing/erro/logging, dois Dockerfiles e extensão do Compose para aplicativos em perfil próprio. Migrações de domínio e funcionalidades ainda não entram nesta fase.

**Classes esperadas:** `ApiConhecimentoApplication`, `ApiAtendimentosApplication`, `SecurityConfig`, `JwtProperties`, `ApiExceptionHandler`, `ErroResponse`, `ErroDetalhe`, `Violacao`, `CorrelationFilter`, `UnicodeCodePointValidator`, `HealthResponseAdapter` e configuração OpenAPI, conforme pertinência por módulo. `ApplicationBootstrapTest` e `ApplicationBootstrapIT` comprovam a estrutura.

**Critérios de aceite — G2 (T021):**

- Boot 4.1.1, AI BOM 2.0.1 e release 21 resolvidos; JUnit 5.14.0/API/launcher coerentes, integração por bootstrap programático sem SpringExtension. Smoke tests têm contagem positiva.
- Cada POM produz JAR sem compilar o outro serviço; atendimento não contém driver PostgreSQL, JDBC/DataSource ou PgVectorStore.
- Processos locais sobem em 8081/8082 com perfis válidos, health mínimo sem chamadas pagas, logs estruturados/correlação e segurança deny-by-default. Nenhuma rota funcional incompleta é anunciada como pronta.
- Testes exercitam configuração ausente, 401/403 e erros padronizados. Imagens separadas construídas pelo Docker Desktop, sem credenciais embutidas.
- Quando starters de IA/MCP forem adicionados posteriormente, o build deve revalidar a árvore transitiva e manter o isolamento. O perfil de teste pode injetar adaptadores controlados; o perfil normal não fornece respostas fictícias.

**Comandos de validação previstos:**

```powershell
java -version
./mvnw.cmd --version
./mvnw.cmd help:effective-pom
./mvnw.cmd -f api-conhecimento/pom.xml dependency:tree
./mvnw.cmd -f api-atendimentos/pom.xml dependency:tree
./mvnw.cmd -f api-conhecimento/pom.xml verify
./mvnw.cmd -f api-atendimentos/pom.xml verify
docker compose config --quiet
docker compose --profile apps build api-conhecimento api-atendimentos
```

Asserções HTTP de bootstrap e saúde pertencem aos testes, que iniciam/encerram os processos em portas aleatórias. Para conferir 8081/8082, iniciar as imagens com ambiente local válido; não presumir serviços iniciados apenas pelo comando build.

**Riscos técnicos:** resolução de artefatos/versões, auto-configuração inesperada de modelos/banco, mistura Jupiter 5/6, uso indevido de @SpringBootTest, herança de dependências de conhecimento no atendimento, diferenças Jackson 3 e bind localhost errado dentro de contêiner.

## Fase 3 — Persistência e ingestão de conhecimento

**Objetivo:** implementar domínio, persistência documental, autorização da fonte e preparação segura de ingestão; disponibilizar leitura administrativa contratada. Concluir o POST depende da fase 4.

**Dependências:** G2; política de fontes confiável e fixtures aprovadas para testes; credenciais administrativas/runtime separadas. Consultar skills rag-pgvector e testing.

**Arquivos previstos:** K `domain/model/`, `domain/policy/`, `application/port/`, `application/service/` e `infrastructure/persistence/`; migrações `V1__documentos.sql` e `V2__operacoes_ingestao.sql`; registro de fontes somente leitura por ambiente; DTOs/GETs administrativos e testes JDBC/HTTP nos diretórios do módulo.

**Classes esperadas:** `Documento`, `OperacaoIngestao`, `EstadoIngestao`, `Categoria`, `DocumentoRepository`, `OperacaoIngestaoRepository`, adaptadores JDBC, `PoliticaFontesAdapter`, `PrepararIngestaoService`, `ConsultarConhecimentoService`, `Deadline`, `ConhecimentoController` para GETs e records de consulta/listagem.

**Critérios de aceite — G3 (T029):**

- Flyway aplica estruturas, unicidade da fonte/hash e controle de tentativa em PostgreSQL real; runtime sem DDL. Operações de banco respeitam 3 segundos, incluindo aquisição da conexão.
- Fonte não aprovada/digest divergente é rejeitado antes de embeddings; registro ausente/inválido falha com diagnóstico seguro, registro vazio válido inicia sem acervo.
- Reserva concorrente, deduplicação, estados PROCESSANDO/FALHOU/EXPIRADO e deadline testados. Nenhum documento parcial aparece como INDEXADO.
- GETs por ID/listagem seguem autorização, 404 seguro, ordenação e paginação do contrato; fixtures INDEXADO são criadas apenas no ambiente de teste.
- Pipeline ainda incompleto permanece atrás de porta interna. Testes com dublês não comprovam RF01/RF03 completos nem autorizam POST 201 prematuro.

**Comandos de validação previstos:**

```powershell
docker info
./scripts/validate-infra.ps1
./mvnw.cmd -f api-conhecimento/pom.xml verify
```

Conferir relatórios de testes de migração, repositório, política de fonte e GETs. Testcontainers usa banco efêmero; não aplica fixtures de teste no volume de desenvolvimento.

**Riscos técnicos:** longa transação durante dependência externa, corrida de unicidade/reserva, normalização/hash inconsistentes, leak por totais da paginação e bootstrap de extensões confundido com migração de tabelas.

## Fase 4 — Chunking e geração de embeddings

**Objetivo:** completar a ingestão REST síncrona com chunks 512/64, OpenAI embeddings e publicação atômica em pgvector.

**Dependências:** G3, EmbeddingModel OpenAI configurado somente em conhecimento, API key externa para execução real; dublês determinísticos nos testes comuns. Consultar skills spring-ai, rag-pgvector e testing.

**Arquivos previstos:** migração `V3__vector_store_hnsw.sql`, K `infrastructure/ai/`, `infrastructure/config/`, `application/service/`, adaptador de indexação em `infrastructure/persistence/`, POST/records de cadastro em `controller/`, testes unitários de chunking e integração de ingestão/timeout/reinício.

**Classes esperadas:** `Chunk`, `ChunkingService`, `TokenWindowChunker`, `EmbeddingConfig`, `PgVectorConfig`, `PgVectorKnowledgeAdapter`, `IndexarConhecimentoService`, `PublicarConhecimentoService`, `CadastrarConhecimentoService`, `CadastrarConhecimentoRequest` e respostas contratadas.

**Critérios de aceite — G4 (T038):**

- text-embedding-3-small/1536, CL100K_BASE e HNSW/vector_cosine_ops configurados e testados; inicialização automática de schema desabilitada.
- Janelas 512/64 com avanço 448, IDs/metadados preservados e reconstrução Unicode sem corrupção; cenário de 1.000 tokens cumpre RF02-CA01.
- Lotes limitados a 16 chunks/8.192 tokens; embeddings não são calculados duas vezes. Sem chamada OpenAI segurando transação/lock de banco.
- POST retorna 201/200/409 corretos; aprovação, input inválido e falta de permissão impedem chamada paga. Falha parcial/timeout não publica e reenvio explícito não duplica.
- Publicação atômica condicionada a estado/deadline/proprietário; teste prova ausência de commit lógico tardio. Cadastro até 60 s, embeddings até 5 s/chamada, banco até 3 s, retries zero.

**Comandos de validação previstos:**

```powershell
./mvnw.cmd -f api-conhecimento/pom.xml verify
./mvnw.cmd -f api-conhecimento/pom.xml dependency:tree
docker compose --profile apps build api-conhecimento
```

Fluxos de integração usam PgVectorStore/banco reais e EmbeddingModel controlado. Registrar à parte qualquer smoke com OpenAI real autorizado; ele não substitui os testes de falhas controladas.

**Riscos técnicos:** API de splitter sem overlap, fronteiras de tokens corrompendo Unicode, dimensões incompatíveis, custo/quota/latência de embeddings, estado parcial exposto e deadline sem proteção de publicação.

## Fase 5 — Busca vetorial e MCP Server

**Objetivo:** executar pesquisa elegível e disponibilizá-la pela tool verdadeira buscar_conhecimento, com diagnóstico administrativo separado.

**Dependências:** G4, esquema do contrato, contexto autenticado/público, filtros de aprovação/estado/vigência e corpus de pesquisa. Consultar skills mcp-integration, rag-pgvector e testing.

**Arquivos previstos:** K `application/service/BuscarConhecimentoService`, política de elegibilidade, adaptador de busca PgVectorStore, DTOs de evidências, controller de diagnóstico, adaptador/configuração MCP e schemas contratados, fixtures e `McpServerContractIT`.

**Classes esperadas:** `BuscarConhecimentoService`, `PoliticaElegibilidade`, `BuscaConhecimentoRequest`, `TrechoConhecimento`, `BuscaConhecimentoResponse`, `DiagnosticoConhecimentoController`, `ConhecimentoMcpServerAdapter`, `McpServerConfig` e tradutor de erro de tool.

**Critérios de aceite — G5 (T048):**

- SimilaritySearch gera embedding da pergunta na API de Conhecimento, retorna até limite (padrão 5/máximo 10) e não expõe restritos/vencidos/parciais. Similaridade é cosseno, não distância/probabilidade.
- `/mcp` negocia o protocolo e oferece somente buscar_conhecimento, inputSchema/outputSchema completos, structuredContent, isError e text espelhado coerentes. A busca vetorial ocorre antes de responder à tool.
- `initialize`, descoberta e execução são testadas com cliente real Streamable HTTP. Não basta chamar método Java ou controller de diagnóstico.
- Erro JSON-RPC, erro operacional, schema inválido, vazio e timeout permanecem distintos. Endpoint de diagnóstico exige escopo próprio e nega a identidade do atendimento.
- Corpus com evidências esperadas está pronto. Baseline 0,75 permite desenvolvimento técnico; **calibração semântica final em T077 é necessária para aceite do MVP**, sem bloquear desenvolvimento das próximas camadas com fixtures controladas.

**Comandos de validação previstos:**

```powershell
./mvnw.cmd -f api-conhecimento/pom.xml verify
docker compose --profile apps build api-conhecimento
```

O teste de contrato inicia servidor/cliente reais e valida chamadas, headers, origens e limites. Requisição curl ao diagnóstico REST não é evidência de funcionamento MCP.

**Riscos técnicos:** SDK/negociação incompatíveis, @Tool sem outputSchema requerido, registro duplicado de tool, autorização apenas após topK, score convertido duas vezes, body HTTP 200 confundido com sucesso e erros internos vazando dados.

## Fase 6 — MCP Client e API de Atendimentos

**Objetivo:** receber perguntas e recuperar evidências deterministicamente por MCP, com delegação e isolamento entre requisições, preparando a porta de geração.

**Dependências:** G5; base de aplicação/segurança da fase 2; chave de delegação local externa e verificador correspondente em conhecimento. Consultar skills mcp-integration e testing.

**Arquivos previstos:** A `infrastructure/mcp/`, `infrastructure/security/`, `application/port/`, `application/service/`, `controller/dto/`, configuração MCP e testes de rede/contrato/concorrência; integração do emissor de delegação com o verificador K.

**Classes esperadas:** `ConhecimentoMcpClientAdapter`, `McpClientConfig`, `DelegacaoJwtService`, `McpRequestContext`, `McpResultValidator`, `ConhecimentoGateway`, `GeracaoRespostaPort`, `PerguntarService`, `AtendimentoController`, `PerguntarRequest`, `AtendimentoResponse` e tradutor de falhas MCP.

**Critérios de aceite — G6 (T058):**

- Pergunta validada antes da rede; chamada explícita a buscar_conhecimento antecede a porta de geração. Client SYNC, callbacks automáticos desabilitados, sem tool-choice probabilístico.
- Token delegado restringe audiência/ator/escopo/grupos/expiração; headers por requisição não vazam entre usuários/sessões. Diagnóstico/admin/banco inacessíveis à identidade do atendimento.
- Schema/correlação/structuredContent/isError validados; vazio gera insuficiência sem chamar geração; falhas se tornam 502/503/504, nunca vazio fictício.
- Testes demonstram cliente real, prazo MCP 10 s e atendimento 30 s. A aplicação não depende de PostgreSQL nem gera embeddings.
- Controller/serviço podem ser testados com GeracaoRespostaPort controlada; **resposta factual completa e prontidão do endpoint para consumidor ficam pendentes de G7**. Não habilitar dublê no perfil normal, não retornar texto de placeholder como resposta válida.

**Comandos de validação previstos:**

```powershell
./mvnw.cmd -f api-atendimentos/pom.xml dependency:tree
./mvnw.cmd -f api-atendimentos/pom.xml verify
docker compose --profile apps build api-atendimentos
```

Testes de integração do módulo iniciam servidor MCP de teste real/controlado, sem dependência Maven do JAR de conhecimento; contrato do produtor já é verificado em G5. Fluxo dos dois JARs reais será validado em T074.

**Riscos técnicos:** token de audiência errada encaminhado ao serviço, mutable headers globais, perda de contexto em threads do SDK, sessão assumida como autorização, tool ausente e classificação de 401 interno como erro do aluno.

## Fase 7 — Integração com OpenAI e montagem do contexto RAG

**Objetivo:** completar a geração contextualizada e a resposta pública fundamentada com fontes reconstruídas pela aplicação.

**Dependências:** G6; modelo de chat, tokenizador, janela e suporte a saída estruturada registrados por ambiente; API key externa para execução real. Consultar skills spring-ai e testing.

**Arquivos previstos:** A `infrastructure/ai/`, `infrastructure/config/`, `domain/policy/`, `application/service/`, `resources/prompts/`, registros de capacidades sem segredos e testes de contexto/saída/fundamentação.

**Classes esperadas:** `ChatModelProperties`, `ModelCapabilitiesRegistry`, `ChatClientConfig`, `ContextoRagBuilder`, `ChatTokenCounter`, `PoliticaSuficiencia`, `RespostaGerada`, `OpenAiRespostaAdapter`, `ValidadorResposta`, `MontadorFontes` e integração final de `PerguntarService`.

**Critérios de aceite — G7 (T069):**

- OPENAI_CHAT_MODEL obrigatório, configuração validada sem fallback; embeddings desabilitados no atendimento. ChatClient encapsulado, sem VectorStore ou tools automáticas.
- Contexto com chunks inteiros, até 12.000 pontos de código/4.000 tokens, reserva de 1.500 tokens de saída e prompt total dentro da janela do modelo. Não truncar pergunta/condições para forçar sucesso.
- Saída estruturada validada, resposta até 4.000 caracteres, fontes derivadas somente dos chunkIds incluídos; agrupamento por documento/versão e invariantes de status obedecidos.
- Vazio/conflito/insuficiência manifesta não chama chat; limitações explícitas nas partes sem suporte. Não inventar cursos, valores, datas, horários, vagas ou contatos.
- Recusa, formato/fonte inválida, falha e timeout do modelo são erros explícitos; zero retry. Endpoint completo é habilitado/pronto somente com os adaptadores reais configurados.

**Comandos de validação previstos:**

```powershell
./mvnw.cmd -f api-atendimentos/pom.xml verify
./mvnw.cmd verify
docker compose --profile apps build api-conhecimento api-atendimentos
```

Testes de sequência provam MCP antes de geração; testes de limites/falhas não dependem de resposta real variável. Avaliação semântica com OpenAI real fica explicitamente separada em T077.

**Riscos técnicos:** tokenizador incorreto, overhead de prompt ignorado, score tomado como verdade, validação estruturada disparando retries ocultos, citações existentes sem suporte factual e prompts/retornos de tool contendo instruções maliciosas.

## Fase 8 — Testes, segurança e observabilidade

**Objetivo:** consolidar testes reais entre processos, revisar controles transversais e demonstrar aceite do MVP local, sem declarar prontidão de produção/rede automaticamente.

**Dependências:** G7; Docker Desktop, scripts/harness de teste, corpus e modelos autorizados para avaliação, recursos de ambiente e credenciais externas. Segurança de publicação em rede requer as medidas adicionais da arquitetura.

**Arquivos previstos:** testes de regressão e falhas nos dois módulos; `scripts/verify-e2e.ps1`, `scripts/verify-reports.ps1`, configuração de CI, métricas/tracing, arquivos de evidência sem conteúdo sensível, `README.md`, `specs/07-test-plan.md` e `specs/08-checklist.md` atualizados em suas tarefas próprias.

**Classes esperadas:** testes de delegação/concorrência/prompt injection, `DeadlineIT`, `DependencyFailureIT`, `HealthContractIT`, componentes de tracing/observação necessários e suites de avaliação. Nenhum terceiro microsserviço ou módulo compartilhado de runtime.

**Critérios de aceite — G8 (T080):**

- RF01–RF10, RNF01–RNF09 e operações adicionais do contrato têm cenário/teste/evidência rastreável. Nenhum teste obrigatório ignorado ou suíte vazia contabilizado como aprovação.
- Harness externo inicia dois JARs/processos e dependências isoladas depois de construir ambos, confirma cadastro → tool MCP real → chat controlado → fontes e falhas. Não adiciona dependência Maven de um serviço no outro.
- Limites/zero retry comprovados com atrasos na fronteira de rede; concorrência 1 ingestão/4 pesquisas/4 atendimentos e isolamento entre solicitantes testados.
- JWT, escopos, grupos, CORS/Origin, aprovação de fontes, logs e visibilidade de endpoints revisados. Prompt injection e fatos comerciais sem evidência produzem abstenção segura ou erro apropriado.
- Telemetria estruturada correlaciona REST/MCP/embeddings/banco/chat sem conteúdo sensível, com métricas de duração/vazios/falhas/tokens. Health não causa chamada paga e respeita 200/503 padronizado.
- Corpus avaliado com OpenAI real no perfil autorizado, limiar final registrado e fundamentação/abstenção avaliadas independentemente. Se não executado, **aceite semântico permanece pendente**.
- Documentação operacional contempla boot, variáveis, rotação, persistência, diagnóstico e condições prévias para rede; imagens reconstruídas e ambiente local validado sem apagar dados existentes.

**Comandos de validação previstos:**

```powershell
docker version
docker info
docker compose config --quiet
./mvnw.cmd -f api-conhecimento/pom.xml verify
./mvnw.cmd -f api-atendimentos/pom.xml verify
./mvnw.cmd verify
./scripts/verify-reports.ps1
./scripts/verify-e2e.ps1
docker compose --profile apps build api-conhecimento api-atendimentos
```

Somente quando o perfil de avaliação existir e a execução externa estiver autorizada/configurada:

```powershell
./mvnw.cmd -P ai-evaluation verify
```

Esse perfil não entra por padrão na CI determinística. Testes com dublês não são apresentados como avaliação do modelo real. Scripts devem encerrar somente processos/recursos de teste que criaram e preservar volumes locais.

**Riscos técnicos:** testes comuns consumindo quota, corpus enviesado, instabilidade de saídas, harness confundindo JAR antigo com build atual, segredo em relatório/CI, testes skipped mascarados, probe acionando dependências pagas e declaração de segurança produtiva baseada apenas no cenário local.

## 4. Primeira implementação recomendada

**Lote inicial recomendado: T001–T009**, respeitando a ordem/dependências de `05-tasks.md`: preparação documental e infraestrutura Docker isolada, sem Java. Para infraestrutura estrita, T003 pode começar imediatamente; T004–T009 seguem sua cadeia e não dependem de classes, POMs, MCP ou OpenAI.

Após G1 e T001/T002, **T010–T021** podem formar o segundo lote, ou extensão explícita do primeiro caso o escopo solicitado inclua inicializar os dois serviços. Não avançar automaticamente além do lote autorizado. Nenhuma tarefa de persistência funcional, embeddings, MCP ou geração é necessária para entregar G1/G2.

Não iniciar T022+ antes de G2. Este plano não comprova execução: consultar os checkboxes atuais em `specs/05-tasks.md` e suas evidências em `specs/08-checklist.md`, sem presumir pré-requisitos operacionais aprovados a partir do planejamento.
