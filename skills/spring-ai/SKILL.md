---
name: spring-ai
description: Configurar OpenAI, ChatClient, prompts e respostas estruturadas com Spring AI 2.0.1 no COTI AI Atendimento. Usar em tarefas de geração e configuração de modelos; usar as skills específicas para transporte MCP e persistência vetorial.
---

# Spring AI e OpenAI

## Quando utilizar

Usar ao implementar ou revisar configuração de modelos, geração contextualizada, prompts, saída estruturada e falhas do provedor. Aplicar o fluxo Spec → Plan → Implement → Test → Review do `AGENTS.md`; ler as quatro especificações obrigatórias antes de implementar.

## Responsabilidades

- Na `api-atendimentos`, gerar respostas com OpenAI a partir de evidências obtidas exclusivamente por MCP; não acessar um VectorStore local.
- Na `api-conhecimento`, configurar o modelo OpenAI de embeddings, mantendo sua execução encapsulada nesse serviço.
- Separar configuração, adaptação do provedor, orquestração e regras de suficiência. Preservar os contratos REST/MCP aprovados.

## Passo a passo de implementação

1. Conferir a arquitetura e gerenciar módulos Spring AI pelo `org.springframework.ai:spring-ai-bom:2.0.1`. A documentação da linha 2.0.x indica Spring Boot 4.0.x/4.1.x; usar somente o patch definido na arquitetura. Registrar incompatibilidades ou versões ausentes antes de implementar.
2. Usar `spring-ai-starter-model-openai`. Vincular `spring.ai.openai.api-key` à variável `OPENAI_API_KEY`; configurar os modelos em `spring.ai.openai.chat.model` e `spring.ai.openai.embedding.model` no serviço correspondente. Em 2.0.1, preferir as propriedades sem o segmento legado `.options`. Selecionar apenas as capacidades necessárias por `spring.ai.model.chat` e `spring.ai.model.embedding`, usando `none` para desativar as indevidas. Validar a configuração efetiva na inicialização.
3. Definir limites de contexto, saída, duração e concorrência conforme o modelo aprovado; não presumir que todos os modelos aceitam os mesmos parâmetros. Usar configuração tipada e validada, sem valores secretos padrão.
4. Construir o `ChatClient` a partir do `ChatClient.Builder` injetado. Encapsular seu uso em um adaptador; não criar clientes a cada pergunta nem alterar estado compartilhado por requisição.
5. Recuperar evidências via MCP antes da geração factual. Verificar autorização, vigência e suficiência na aplicação; se faltarem evidências, retornar o estado de insuficiência previsto no contrato sem pedir ao modelo que preencha lacunas.
6. Separar política do sistema, pergunta do aluno e trechos recuperados. Usar templates com parâmetros para inserir os valores como dados, delimitando trechos e identificadores de fontes. Não avaliar o texto dos documentos como um novo template. Incluir regras de abstenção, de fundamentação e de resistência a instruções documentais.
7. Quando o contrato exigir estrutura, mapear com `ChatClient.prompt()`, `call()` e `entity(TipoDoDto.class)` para um record. Em 2.0.1, as opções de `entity` incluem `useProviderStructuredOutput()` e `validateSchema()`; avaliar suporte do modelo e limites de tentativas antes de habilitá-las. Validar também campos e invariantes de negócio na aplicação: JSON válido não prova fundamentação.
8. Aceitar referências de fontes somente se pertencerem ao conjunto retornado pela busca. Não publicar saídas nulas, incompletas, recusadas ou inválidas como sucesso. Distinguir erro de formato, indisponibilidade do provedor e falta de conhecimento segundo o contrato.
9. Definir timeouts efetivos no cliente subjacente e prazo total da operação. Limitar retries com backoff apenas a falhas transitórias apropriadas; não repetir credenciais inválidas ou erros de entrada. Considerar tentativas internas de saída estruturada no orçamento total para evitar multiplicação de chamadas e custos.
10. Observar duração, resultado, tokens e correlação sem registrar prompts, perguntas completas, documentos ou segredos por padrão. Executar a compilação e os testes relevantes antes da entrega.

## Padrões de codificação

- Java 21, records para DTOs e injeção por construtor; dependências de IA restritas aos adaptadores.
- Configuração externa e modelos explicitamente selecionados por ambiente, sem fallback silencioso de modelo.
- Usar `ChatResponse` quando precisar de metadados operacionais; manter detalhes do provedor fora do contrato público.
- Na linha 2.0, a integração OpenAI usa o SDK oficial internamente; continuar usando as abstrações Spring AI, sem implementar um cliente OpenAI paralelo.
- Ao personalizar uma chamada do ChatClient, passar o builder de opções para `.options(...)`, conforme a API 2.0.1. Tratar opções como imutáveis; usar `mutate()` quando precisar derivá-las, sem setters ou `copy()` legados.

## Antipadrões proibidos

- Instalar `QuestionAnswerAdvisor` com VectorStore na `api-atendimentos`, gerar embeddings nesse serviço ou contornar o MCP.
- Usar conhecimento prévio do modelo para inventar cursos, valores, datas ou horários; tomar temperatura baixa como garantia de verdade.
- Elevar conteúdo recuperado a instrução do sistema, permitir ferramentas arbitrárias ou confiar no prompt como controle de acesso.
- Registrar conteúdo completo por advisors de logging ou debug, guardar API keys no repositório ou desabilitar validação para aceitar saída inválida.
- Copiar propriedades, classes ou imports de versões antigas sem conferir sua presença em 2.0.1.

## Critérios de validação

- Contexto inicia com configuração válida e falha claramente quando uma credencial obrigatória está ausente, sem expô-la.
- Testes verificam resposta fundamentada, evidências vazias/conflitantes, fonte não autorizada, saída inválida, recusa, timeout e erro do provedor.
- Cada fonte citada está nas evidências da requisição e a abstenção não depende apenas da decisão do modelo.
- Testes determinísticos usam dublês do adaptador/ChatModel; avaliação com modelo real é separada e explicitamente identificada.

## Checklist de conclusão

- [ ] Versões e modelos conferidos com a arquitetura e Spring AI 2.0.1.
- [ ] Capacidades e credenciais isoladas por serviço.
- [ ] MCP precede a geração factual; suficiência e fontes são validadas.
- [ ] Prompts e saída estruturada respeitam contrato e segurança.
- [ ] Falhas, retries e prazo total cobertos por testes.
- [ ] Compilação/testes executados e relatório final conforme `AGENTS.md`.

## Referências oficiais

Consultar a referência identificada como **2.0.1**, evitando misturar exemplos de snapshots ou de outra versão: [compatibilidade e BOM](https://docs.spring.io/spring-ai/reference/getting-started.html), [OpenAI](https://docs.spring.io/spring-ai/reference/api/chat/openai-chat.html), [ChatClient](https://docs.spring.io/spring-ai/reference/api/chatclient.html), [conversores de saída](https://docs.spring.io/spring-ai/reference/api/structured-output/converters.html) e [notas de atualização](https://docs.spring.io/spring-ai/reference/upgrade-notes.html).
