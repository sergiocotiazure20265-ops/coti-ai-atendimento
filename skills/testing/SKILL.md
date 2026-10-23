---
name: testing
description: Planejar, implementar e executar testes de Java, REST, MCP e RAG no COTI AI Atendimento com JUnit 5, Mockito e Testcontainers PostgreSQL/pgvector. Usar para validar comportamentos, contratos, falhas e resistência a prompt injection.
---

# Testes e critérios de aceite

## Quando utilizar

Usar ao implementar ou alterar comportamento, corrigir defeitos e validar critérios de aceite. Aplicar Spec → Plan → Implement → Test → Review; ler o `AGENTS.md`, a constituição, os requisitos, a arquitetura e os contratos. Em tarefa exclusivamente documental, validar os documentos sem criar classes Java apenas para executar testes.

## Responsabilidades

- Demonstrar comportamentos por evidências executáveis, ligando requisito, cenário, resultado esperado e teste.
- Diferenciar teste unitário, integração, contrato, fluxo completo e avaliação com modelo real.
- Relatar comandos, resultados, falhas, testes ignorados e impedimentos sem afirmar sucesso de execução inexistente.

## Passo a passo de implementação

1. Identificar os critérios de aceite afetados e montar uma matriz com caminho principal, entradas inválidas, conhecimento insuficiente, segurança e falhas de dependências. Resolver lacunas de contrato antes de inventar códigos HTTP, nomes de tools ou formatos esperados.
2. Conferir Java 21, Spring AI 2.0.1 e a versão de Spring Boot definida na arquitetura. O requisito desta skill é JUnit 5/Jupiter com Mockito. Spring Boot 4 pode gerenciar JUnit 6: não presumir que `spring-boot-starter-test` fornece JUnit 5. Exigir resolução documentada na arquitetura e comprovação da compatibilidade do conjunto, incluindo engine/launcher e plugins de teste, antes de fixar dependências; não trocar a versão solicitada silenciosamente.
3. Escrever testes unitários com JUnit Jupiter, testes parametrizados quando úteis e `MockitoExtension` para dependências. Usar mocks nas fronteiras de aplicação e evitar simular cada elo fluente do ChatClient; testar seu adaptador com um ChatModel controlado quando necessário. Verificar comportamentos, não a ordem interna irrelevante dos métodos.
4. Nos testes que precisam do contexto Spring, substituir colaboradores por `@MockitoBean` do Spring Framework, conforme suporte da stack escolhida. Não copiar `@MockBean` de exemplos antigos. Usar fixtures pequenas, relógio controlado e dados fictícios sem credenciais reais.
5. Para persistência da `api-conhecimento`, usar Testcontainers com PostgreSQL e imagem pgvector versionada, via Docker Desktop. Usar `PostgreSQLContainer` do módulo compatível e declarar compatibilidade com postgres quando exigida pela imagem substituta. Não presumir que a imagem padrão postgres contém pgvector. Executar migrações reais e conferir extensões e dimensão.
6. Conectar o contexto de integração por `@ServiceConnection` quando suportado ou por `@DynamicPropertySource`, com porta aleatória e credenciais efêmeras. Isolar dados por teste/suíte e controlar limpeza sem apagar volumes de desenvolvimento. Verificar `VectorStore.add`, `similaritySearch`, filtros, fontes, atualização e remoção com embeddings determinísticos de dimensão válida.
7. Validar HTTP REST com MockMvc na stack MVC ou WebTestClient na stack correspondente; para comunicação de rede, usar aplicação em porta aleatória. Conferir payload, validação, autenticação, autorização e erros contra OpenAPI e contrato aprovado, sem assumir que um teste de controller prova integração entre serviços.
8. Para contrato MCP, iniciar servidor e cliente reais pelo transporte Streamable HTTP e executar inicialização, negociação, `listTools` e `callTool`. Conferir schema, resultado, fontes, limites e paginação quando aplicável. Incluir parâmetros inválidos, tool desconhecida, acesso negado, erro JSON-RPC, `isError`, resposta incompatível e sucesso vazio. Um mock local da tool não satisfaz essa validação.
9. Testar falhas de dependências em dois níveis: unidade com dublês para ramificações e integração com respostas/atrasos controlados na fronteira HTTP para comprovar timeouts e retries efetivos. Cobrir MCP indisponível/lento, OpenAI com erro transitório ou credencial inválida, saída malformada/recusada, embeddings com falha e banco indisponível. Medir prazo e número de tentativas; assegurar que não surge fallback de busca fora do MCP.
10. Criar cenários de prompt injection em texto, metadados e retorno MCP: instruções para ignorar política, inventar preço, divulgar segredo fictício e executar tool não permitida. Verificar que documentos não ampliam permissões, fontes restritas não chegam ao modelo e nenhuma ferramenta fora da allowlist é executada. Teste com dublê comprova controles da aplicação, não a resistência de um LLM real.
11. Separar testes determinísticos de avaliações de geração com modelo real. Nestas, usar corpus aprovado, perguntas com e sem evidência, condições comerciais e rubrica de fundamentação/abstenção; registrar modelo e versão do prompt, sem exigir igualdade literal da resposta. Executar chamadas externas somente quando fizerem parte do escopo autorizado e com credenciais de ambiente; sua ausência deve ser relatada, não mascarada como aprovação.
12. Executar a compilação e as suítes relevantes pelo wrapper e configuração existentes. Se o projeto adotar Maven com Surefire/Failsafe configurados, usar as fases previstas para testes unitários e integração, como `test` e `verify`; não declarar integração executada só porque `test` terminou. Em outro build, seguir suas tarefas reais. Antes de testes de contêiner, conferir `docker version` e `docker info`.
13. Revisar relatórios do runner para conferir quantidade de testes executados, falhas e ignorados. Corrigir falhas, repetir o conjunto afetado e apresentar o relatório exigido pelo `AGENTS.md`. Docker indisponível ou suíte ausente significa validação pendente, não sucesso.

## Padrões de codificação

- Organizar cenários em preparação, ação e verificação; nomes devem explicar a regra observável.
- Preferir records nas fixtures de DTOs e construir os objetos testados por construtor.
- Usar recursos efêmeros, portas dinâmicas, prazos limitados e espera por condição em vez de sleeps arbitrários.
- Testar ausência de API keys, informações sensíveis e perguntas completas nos logs com marcadores fictícios.
- Verificar também que o build da `api-atendimentos` não contém dependências PostgreSQL/pgvector nem exige banco para iniciar seus testes de aplicação.

## Antipadrões proibidos

- Afirmar aprovação sem executar, ignorar testes obrigatórios silenciosamente ou remover uma asserção para esconder defeito.
- Usar H2 para comprovar comportamento pgvector, substituir a integração MCP inteira por mock ou depender de serviços pessoais em testes determinísticos.
- Usar respostas de LLM como único oráculo, contar JSON válido como evidência factual ou aprovar segurança apenas porque o prompt contém uma instrução defensiva.
- Fazer a suíte exigir API key real por padrão, chamar provedores sem controle de escopo ou registrar prompts completos nos relatórios.
- Criar testes que apenas reproduzem a implementação sem verificar uma regra ou risco real.

## Critérios de validação

- Cada comportamento alterado tem cenários observáveis de sucesso e falha ligados ao aceite.
- Integrações PostgreSQL/pgvector e MCP são executadas contra componentes reais apropriados; geração e embeddings podem ser controlados para determinismo.
- Falhas técnicas são distintas de ausência de conhecimento; limites de acesso e abstenção têm evidências.
- Relatórios comprovam execução das suítes relevantes e deixam explícitas as limitações das avaliações de IA.

## Checklist de conclusão

- [ ] Matriz requisito → critério → cenário → teste conferida.
- [ ] Compatibilidade JUnit 5/Spring Boot e dependências de teste resolvida na arquitetura.
- [ ] Unitários, HTTP, contratos MCP e integração pgvector pertinentes executados.
- [ ] Falhas, prompt injection e proteção de logs avaliados.
- [ ] Avaliações com modelo real identificadas separadamente, quando executadas.
- [ ] Compilação e resultados do runner conferidos; pendências e próxima tarefa relatadas.

## Referências oficiais

[JUnit 5](https://docs.junit.org/5.14.0/user-guide/), [testes Spring Boot 4](https://docs.spring.io/spring-boot/4.0/reference/testing/index.html), [MockitoBean](https://docs.spring.io/spring-framework/reference/testing/annotations/integration-spring/annotation-mockitobean.html) e [Testcontainers PostgreSQL](https://java.testcontainers.org/modules/databases/postgres/). Para os componentes Spring AI, consultar as referências **2.0.1** vinculadas nas outras três skills e confirmar as assinaturas da versão de Testcontainers gerenciada pelo build.
