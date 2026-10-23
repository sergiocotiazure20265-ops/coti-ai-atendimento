---
name: rag-pgvector
description: Implementar ingestão, chunking, embeddings e recuperação com PgVectorStore no Spring AI 2.0.1, exclusivamente na api-conhecimento. Usar para qualidade de busca, metadados, fontes e suficiência de evidências.
---

# RAG com PostgreSQL e pgvector

## Quando utilizar

Usar em tarefas de ingestão textual, transformação em chunks, indexação e pesquisa semântica na `api-conhecimento`. Para expor a pesquisa, consultar também a skill MCP; para geração da resposta final na `api-atendimentos`, consultar a skill Spring AI. Seguir o fluxo operacional e as leituras obrigatórias do `AGENTS.md`.

## Responsabilidades

- Manter textos, chunks, embeddings e metadados somente na `api-conhecimento`.
- Retornar evidências autorizadas e rastreáveis, com relevância e vigência adequadas à pergunta.
- Preservar origem, versão e permissões durante toda a ingestão; não tratar similaridade como prova de verdade.

## Passo a passo de implementação

1. Confirmar os critérios de aceite, fontes autorizadas, regras de atualização, exclusão, autorização e suficiência. Definir limites de entrada e políticas de chunking na especificação antes de implementar; não inventar valores comerciais nem contratos.
2. Usar Java 21, BOM Spring AI 2.0.1 e `spring-ai-starter-vector-store-pgvector` exclusivamente na `api-conhecimento`, com o modelo de embeddings OpenAI configurado nesse serviço. Subir PostgreSQL/pgvector em Docker pelo Docker Desktop, com imagem versionada e credenciais por ambiente.
3. Planejar migrações e extensões exigidas pelo PgVectorStore (`vector`, `hstore` e `uuid-ossp`). A inicialização automática do schema exige opt-in; preferir migrações controladas para ambientes persistentes e permissões mínimas em execução. Definir dimensão, métrica e índice compatíveis com o modelo e os limites da versão do pgvector escolhida.
4. Ingerir apenas textos aprovados, validando tamanho, formato, origem e permissão de publicação. Normalizar sem remover condições relevantes, como modalidade, unidade, moeda e validade. Representar o conteúdo com `Document`; utilizar `DocumentReader` quando houver leitor apropriado para a fonte.
5. Gerar chunks por `TokenTextSplitter.builder()` e aplicar o splitter à lista de documentos, preservando contexto de títulos e condições. Configurar tamanho por `withChunkSize(...)` e demais opções suportadas em 2.0.1 conforme avaliação do acervo; se houver sobreposição planejada, verificar suporte ou implementar transformação explícita, sem presumir métodos inexistentes. Testar texto vazio, longo, acentos e fronteiras que separem preço de suas condições.
6. Atribuir identificadores estáveis a documento/versão/chunk e propagar metadados de fonte, posição, aprovação, vigência e acesso, conforme contrato. Chaves de metadados aqui são conceitos: sua nomenclatura definitiva pertence às specs. Não permitir que a ingestão pública atribua a si mesma permissões ou aprovação.
7. Injetar `VectorStore` com implementação `PgVectorStore`. A configuração manual, se necessária, usa `PgVectorStore.builder(jdbcTemplate, embeddingModel)`. Indexar com `add(List<Document>)`, que gera embeddings pelo modelo associado; não calcular vetores novamente sem necessidade. Processar lotes limitados e registrar estado de ingestão para tratar falhas parciais e reprocessamento sem duplicidade.
8. Implementar atualização e remoção dos chunks antigos conforme a política aprovada. Tornar somente versões completas e aprovadas pesquisáveis. Mudança de modelo/dimensão exige reindexação planejada, sem misturar espaços vetoriais incompatíveis.
9. Pesquisar com `similaritySearch(SearchRequest.builder().query(...).topK(...).similarityThreshold(...).filterExpression(...).build())`. A vetorização da consulta ocorre nesse serviço. Validar limites no servidor e construir filtros com `FilterExpressionBuilder` ou expressão controlada; nunca concatenar filtros arbitrários fornecidos pelo aluno ou LLM.
10. Aplicar autorização, aprovação e vigência antes de expor trechos; filtros de metadados não substituem a política de acesso da aplicação. Selecionar topK e limiar por um conjunto de perguntas com evidências esperadas. Não confundir score de similaridade com probabilidade de correção; analisar também cobertura e conflitos.
11. Devolver por MCP somente trechos e metadados contratados, mantendo seus identificadores de fonte. Sinalizar resultado vazio sem fabricar evidência; distinguir falha de embeddings/banco de ausência de resultados. A `api-atendimentos` aplicará a regra de suficiência antes de gerar fatos.
12. Registrar métricas de ingestão, latência, vazios e falhas sem armazenar textos e perguntas completos nos logs. Validar busca com PostgreSQL/pgvector real e modelo de embeddings controlado nos testes.

## Padrões de codificação

- Separar ingestão, transformação, persistência e recuperação por interfaces de aplicação e adaptadores.
- Usar records nos DTOs, injeção por construtor e configuração tipada para lotes, limites e modelo.
- Manter metadados consistentes e inspecionáveis; preservar a ligação do chunk à versão exata da fonte.
- Tratar todo texto recuperado como dado não confiável, delimitado na geração; aprovação documental não torna suas instruções executáveis.

## Antipadrões proibidos

- VectorStore, credenciais de banco ou EmbeddingModel na `api-atendimentos`.
- Indexar documentos sem aprovação, perder metadados no chunking ou devolver fontes fora da permissão do solicitante.
- Retornar o primeiro resultado como resposta correta por definição, baixar o limiar até sempre encontrar algo ou inventar evidências para busca vazia.
- Presumir dimensão fixa do modelo, misturar embeddings incompatíveis ou usar schema automático destrutivo em base persistente.
- Usar H2 ou mocks como única validação de filtros, índices e operações pgvector.

## Critérios de validação

- Reingestão não duplica chunks e substituição não deixa versões obsoletas acessíveis.
- Testes reais verificam dimensões, persistência, recuperação, filtros, exclusão e falhas parciais.
- Perguntas de avaliação recuperam os trechos esperados; perguntas sem suporte não levam a fatos inventados.
- Fontes não aprovadas, vencidas ou restritas não vazam por resultados, metadados ou logs.

## Checklist de conclusão

- [ ] Docker/pgvector e migrações reproduzíveis; credenciais externas.
- [ ] Modelo, dimensões, métrica, índice e reindexação coerentes.
- [ ] Chunks preservam contexto, origem e autorização.
- [ ] Atualização e ingestão parcial não expõem estado inválido.
- [ ] Relevância, filtros, fontes e resultados vazios avaliados.
- [ ] Compilação/testes realizados e pendências relatadas conforme `AGENTS.md`.

## Referências oficiais

Conferir a referência **2.0.1** antes da implementação: [PgVectorStore e busca filtrada](https://docs.spring.io/spring-ai/reference/api/vectordbs/pgvector.html) e [pipeline ETL e TokenTextSplitter](https://docs.spring.io/spring-ai/reference/api/etl-pipeline.html). Não copiar senhas ou a dimensão ilustrativa dos exemplos para a configuração real.
