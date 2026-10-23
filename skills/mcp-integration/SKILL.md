---
name: mcp-integration
description: Implementar e validar MCP Server e MCP Client com Spring AI 2.0.1 e Streamable HTTP entre api-conhecimento e api-atendimentos. Usar para descoberta, execução de tools, segurança, timeouts e contratos MCP.
---

# Integração MCP sobre Streamable HTTP

## Quando utilizar

Usar em mudanças no servidor MCP de conhecimento, cliente de atendimento, descoberta, execução ou tratamento de falhas de tools. Seguir Spec → Plan → Implement → Test → Review e ler `AGENTS.md` e as quatro especificações obrigatórias. Não inventar nomes, parâmetros ou resultados enquanto os contratos estiverem vazios ou divergentes.

## Responsabilidades

- Expor pesquisa semântica na `api-conhecimento` e consumi-la exclusivamente por MCP na `api-atendimentos`.
- Preservar autenticação, autorização documental, validação, rastreabilidade e isolamento dos serviços.
- Devolver evidências e metadados contratados; a tool não deve elaborar a resposta final ao aluno.

## Passo a passo de implementação

1. Conferir BOM Spring AI 2.0.1, stack web e modelo de execução definidos na arquitetura. Escolher SYNC ou ASYNC coerente com a aplicação; não bloquear event loops com JDBC ou chamadas síncronas.
2. No servidor, usar `spring-ai-starter-mcp-server-webmvc` ou a alternativa `spring-ai-starter-mcp-server-webflux`, conforme a arquitetura, com `spring.ai.mcp.server.protocol=STREAMABLE`. Configurar o caminho por `spring.ai.mcp.server.streamable-http.mcp-endpoint` segundo o contrato; não transformar a rota em um controller REST proprietário.
3. Expor apenas a tool aprovada. Uma opção suportada é registrar `ToolCallbackProvider` com `ToolCallback`s de métodos `@Tool`, convertidos pelo starter para MCP; conferir os schemas gerados e evitar registro duplicado por scanners ou providers. Não expor automaticamente todos os beans ou ferramentas disponíveis.
4. Descrever parâmetros e resultado sem ambiguidade. Validar pergunta não vazia, limites de tamanho, limites de resultados e filtros permitidos antes de gerar embeddings. Aplicar autorização na camada de aplicação: schema gerado ou anotação não substitui validação de negócio. Identidade e permissões vêm do contexto autenticado, nunca de argumentos controlados pelo modelo.
5. Proteger o endpoint HTTP: os starters não aplicam autenticação/autorização automaticamente. Implementar a fronteira de segurança definida no contrato, validar origem quando aplicável e usar HTTPS fora do ambiente local. Filtrar documentos por permissão antes de retornar os trechos.
6. No consumidor, usar `spring-ai-starter-mcp-client` ou `spring-ai-starter-mcp-client-webflux` conforme a arquitetura. Configurar `spring.ai.mcp.client.streamable-http.connections.<nome>.url` com a URL base e `.endpoint` com o caminho contratado, evitando duplicar `/mcp`. Externalizar URL e credenciais; não transportar tokens na URL.
7. Inicializar o cliente, negociar capacidades e descobrir tools por `listTools()`. Usar `McpSyncClient` ou `McpAsyncClient` gerenciados pela integração; conferir nome e schema contra o contrato e tratar paginação quando presente.
8. Invocar a pesquisa por `callTool` com `McpSchema.CallToolRequest` e argumentos aprovados. Preferir orquestração explícita para garantir recuperação antes da resposta factual. Se integrar callbacks ao ChatClient, aplicar allowlist e verificar que a recuperação ocorreu; a escolha do modelo de não chamar uma tool não autoriza responder sem evidência.
9. Validar o resultado antes de usá-lo: formato, tipos, limites, fontes e sinalização de erro. Distinguir erro HTTP/transporte, erro JSON-RPC, resultado de tool com `isError`, payload incompatível e busca bem-sucedida sem trechos. Não mapear todos esses casos para lista vazia.
10. Configurar `spring.ai.mcp.client.request-timeout`, prazo total do atendimento e limites de conexão conforme a stack. Limitar retries de pesquisa a falhas transitórias e ao orçamento total; não repetir erro de schema, autenticação ou autorização. Encerrar clientes e sessões pelo ciclo de vida gerenciado.
11. Propagar correlação conforme contrato e segurança; observar descoberta, chamada, latência e categoria de falha sem logar argumentos completos. Validar o fluxo real HTTP com a skill de testes.

## Padrões de codificação

- Encapsular SDK MCP no adaptador; manter DTOs em records e injeção por construtor.
- Versionar schema e normalizar erros na fronteira, preservando detalhes suficientes para diagnóstico interno sem expor segredos.
- Autorizar filtros no servidor e impor limites próprios mesmo quando o cliente já validar parâmetros.
- Configurar Streamable HTTP explicitamente; seu uso de SSE para streaming não equivale ao transporte legado HTTP/SSE.

## Antipadrões proibidos

- Transportes stdio ou SSE legado, pesquisa REST paralela, acesso direto ao PostgreSQL e fallback local de conhecimento.
- Considerar descoberta uma autorização para executar qualquer tool ou confiar em instruções contidas no resultado.
- Tratar HTTP 200 como sucesso de negócio sem conferir o resultado MCP.
- Publicar o MCP sem fronteira de segurança, confiar no campo de usuário enviado pelo LLM ou compartilhar credenciais do banco com atendimento.
- Usar chamadas a métodos locais como única evidência de que o contrato MCP funciona.

## Critérios de validação

- Cliente e servidor reais negociam o protocolo, descobrem a tool e executam a pesquisa por Streamable HTTP.
- Schema, autenticação, filtros, fontes e erros correspondem ao contrato aprovado.
- Testes cobrem argumento inválido, tool desconhecida, acesso negado, timeout, resposta malformada, `isError` e resultado vazio.
- Indisponibilidade não provoca acesso alternativo ao banco nem geração de fatos sem evidências.

## Checklist de conclusão

- [ ] Contrato e nomes de tools conferidos; divergência de caminhos das specs resolvida quando necessária.
- [ ] Starters 2.0.1 e Streamable HTTP configurados para a stack escolhida.
- [ ] Segurança, parâmetros e autorização de fontes verificados no servidor.
- [ ] Descoberta, execução, timeouts e erros testados pelo transporte real.
- [ ] Atendimento permanece sem dependências PostgreSQL/pgvector.
- [ ] Compilação/testes e relato final registrados conforme `AGENTS.md`.

## Referências oficiais

Usar as páginas identificadas como **2.0.1**: [servidor e segurança](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-server-boot-starter-docs.html), [servidor Streamable HTTP](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-streamable-http-server-boot-starter-docs.html) e [cliente MCP](https://docs.spring.io/spring-ai/reference/api/mcp/mcp-client-boot-starter-docs.html). Conferir as assinaturas do SDK na versão transitiva gerenciada pelo BOM antes de escrever imports ou construir mensagens.
