# Requisitos — COTI AI Atendimento

## 1. Objetivo e referências

Automatizar respostas às dúvidas de alunos da COTI Informática sobre cursos, programas, tecnologias, modalidades, pré-requisitos e informações institucionais, usando exclusivamente evidências autorizadas. A plataforma não pode inventar valores, datas, horários, vagas ou condições comerciais.

Este documento segue `specs/01-constitution.md`, `AGENTS.md` e as skills `spring-ai`, `mcp-integration`, `rag-pgvector` e `testing`. Requisitos funcionais e não funcionais são obrigatórios no MVP, salvo exclusão explícita na seção de escopo.

`specs/03-architecture.md` define as decisões técnicas; `specs/06-api-contracts.md` é o documento canônico de rotas, payloads, autenticação, schemas, códigos HTTP e erros MCP. Os nomes de estados e campos descritos nos requisitos representam conceitos de negócio; sua representação pública deve seguir esse contrato. A T001 reconciliou a referência da constituição e registrou como RC01–RC03 as operações administrativas já solicitadas e contratadas, sem renumerar RF01–RF10 nem modificar interfaces.

## 2. Atores, responsabilidades e regras transversais

- **Publicador autorizado:** cadastra textos institucionais previamente revisados pela COTI. O MVP não inclui uma interface ou fluxo eletrônico de aprovação editorial.
- **Solicitante de atendimento:** envia uma pergunta e recebe resposta, estado do processamento e fontes permitidas. Sua permissão é determinada pela camada de segurança, não pelo texto da pergunta.
- **api-conhecimento:** recebe documentos por REST, realiza chunking, gera embeddings de documentos e consultas, persiste no PostgreSQL/pgvector e oferece pesquisa pela tool MCP `buscar_conhecimento`.
- **api-atendimentos:** recebe perguntas por REST, consulta a tool por MCP sobre Streamable HTTP e usa Spring AI/OpenAI para gerar a resposta contextualizada. Não acessa PostgreSQL/pgvector e não gera embeddings.

Uma evidência elegível deve estar completamente indexada, aprovada, autorizada para o solicitante e vigente quando possuir prazo de validade. Informação comercial ou temporal exige validade confirmada para o período perguntado; a ausência dessa confirmação não autoriza presumir atualidade. Documentos institucionais atemporais podem não ter expiração, desde que aprovados.

Considera-se conhecimento suficiente quando os trechos elegíveis cobrem a informação solicitada, respeitam seu contexto e não apresentam conflito relevante sem resolução autorizada. Score de similaridade e presença de palavras-chave, isoladamente, não comprovam suficiência. Em pergunta com partes sem suporte, o sistema pode responder às partes sustentadas, identificando explicitamente as demais limitações, sem apresentá-la como integralmente respondida.

O sistema não deve estimar preços, inferir vagas, atualizar datas por conta própria, extrapolar horários ou transportar condições de um curso, modalidade, unidade ou período para outro. Também não deve inventar cursos. Perguntas fora do domínio institucional devem receber indicação de ausência de suporte, sem usar o conhecimento geral do modelo para respondê-las.

## 3. Parâmetros de referência do MVP

Os valores abaixo são decisões iniciais de produto e operação para tornar o aceite mensurável; não são informações comerciais da COTI. Devem ser externalizados e refletidos na arquitetura, nos contratos e nos testes. Alterações exigem motivo documentado e atualização das especificações afetadas.

| Parâmetro | Referência inicial | Regra |
|---|---|---|
| Texto de documento | Até 100.000 pontos de código Unicode | Não vazio após normalização; transporte UTF-8 e limite adicional de corpo definido no contrato. |
| Pergunta | Até 2.000 pontos de código Unicode | Não vazia após remoção de espaços externos. |
| Chunk | Até 512 tokens | Tokenizador identificado e compatível com o modelo de embeddings escolhido. |
| Sobreposição | 64 tokens | Entre chunks consecutivos do mesmo documento; nunca entre documentos. |
| Resultados de busca | Padrão 5, máximo 10 | Quantidade positiva; não completar a lista com resultados irrelevantes. |
| Limiar de similaridade | Calibrado por corpus de aceite | Sem valor universal presumido; registrar métrica, valor e avaliação antes do aceite da busca. |
| Prazo total de cadastro/indexação | 60 segundos | Fluxo síncrono no MVP; expiração não pode publicar documento parcial. |
| Prazo total de atendimento | 30 segundos | Inclui consulta, validação, geração e preparação da resposta. |
| Chamada MCP | Até 10 segundos | Inclui espera pela recuperação de evidências. |
| Chamada OpenAI de chat | Até 15 segundos | Limitada também pelo tempo restante do atendimento. |
| Chamada OpenAI de embeddings | Até 5 segundos por chamada | Limitada também pelo prazo restante da operação que a originou. |
| Operação de banco | Até 3 segundos | Sem espera ilimitada por conexão ou consulta. |
| Repetições automáticas | Nenhuma no MVP | Desativar retries implícitos nos clientes e na conversão estruturada; reprocessamento explícito não pode duplicar publicação. |

Os prazos são limites de execução, não uma promessa de latência média nem de disponibilidade. A arquitetura deve reservar tempo para finalização e propagação de erros e fazer chamadas respeitarem o orçamento restante. O corpus deve conter perguntas com trechos esperados, perguntas sem suporte, conflitos, fontes vencidas/restritas e tentativas de prompt injection.

## 4. Requisitos funcionais

### RF01 — Cadastrar documentos textuais via API REST

- **Identificador:** RF01.
- **Descrição:** Permitir que um publicador autorizado cadastre um documento textual na `api-conhecimento` para compor a base de conhecimento.
- **Entrada:** Título, texto, referência da fonte, metadados institucionais aplicáveis, informação de vigência quando necessária e contexto autenticado do publicador. Campos obrigatórios e seus formatos serão detalhados no contrato.
- **Processamento:** Autenticar e autorizar o publicador, validar entrada e origem aprovada, atribuir identificador e versão, executar RF02/RF03 e publicar somente após indexação completa.
- **Saída:** Identificador, versão, resultado do cadastro e quantidade de chunks indexados; em rejeição ou falha, erro explícito e identificador de correlação, sem indicar sucesso.
- **Regras de negócio:** Cadastro síncrono no MVP. Aprovação editorial deve existir antes do envio; alegações no texto não concedem aprovação ou acesso. Permissões não podem ser ampliadas por metadados arbitrários. Reenvio do mesmo conteúdo e metadados para a mesma fonte deve reutilizar o resultado ou ser identificado como duplicado, sem duplicar chunks pesquisáveis. Nova versão não é publicável parcialmente.
- **Critérios de aceite:**
  - **RF01-CA01 — Given** publicador autorizado e texto válido de fonte aprovada, **When** o cadastro e a indexação terminam, **Then** são retornados identificador e versão, e seus chunks tornam-se pesquisáveis apenas após a conclusão.
  - **RF01-CA02 — Given** texto vazio, título/fonte obrigatória ausente ou texto acima do limite, **When** o cadastro é solicitado, **Then** a entrada é rejeitada sem chamadas de embeddings nem publicação.
  - **RF01-CA03 — Given** solicitante sem permissão de publicação, **When** envia um documento, **Then** o acesso é negado e nenhum conteúdo é persistido ou enviado ao provedor.
  - **RF01-CA04 — Given** um cadastro já concluído, **When** ocorre seu reenvio idêntico, **Then** não há uma segunda cópia pesquisável do mesmo conteúdo e versão.

### RF02 — Dividir documentos em chunks com sobreposição

- **Identificador:** RF02.
- **Descrição:** Dividir cada texto validado em trechos limitados, preservando continuidade por sobreposição.
- **Entrada:** Texto normalizado, identificador/versão do documento e parâmetros de tamanho, sobreposição e tokenizador.
- **Processamento:** Tokenizar, construir janelas consecutivas com limite de tamanho e sobreposição configurados e associar posição, identificador e metadados da fonte a cada chunk.
- **Saída:** Sequência ordenada de chunks não vazios e rastreáveis à versão do documento.
- **Regras de negócio:** Exigir `0 < sobreposição < tamanho`; usar 512/64 tokens como referência inicial. O último chunk pode ser menor; documentos curtos produzem um único chunk. A operação deve avançar e terminar, sem perder conteúdo significativo ou misturar documentos. A estratégia deve considerar o limite de entrada do modelo. A implementação deve garantir sobreposição explicitamente, sem presumir que um splitter a ofereça automaticamente.
- **Critérios de aceite:**
  - **RF02-CA01 — Given** documento com 1.000 tokens e configuração 512/64, **When** o particionamento é executado, **Then** são geradas janelas de posições 0–511, 448–959 e 896–999, e as regiões sobrepostas preservam o texto correspondente.
  - **RF02-CA02 — Given** texto com até 512 tokens, **When** é dividido, **Then** resulta em um único chunk não vazio, com fonte, versão e posição preservadas.
  - **RF02-CA03 — Given** sobreposição igual ou superior ao tamanho, **When** a configuração é validada, **Then** ela é rejeitada antes da ingestão, sem laço infinito nem indexação.
  - **RF02-CA04 — Given** texto em português com acentos, títulos e condições institucionais, **When** os chunks são produzidos, **Then** não há corrupção de caracteres e o conteúdo pode ser reconstruído em ordem, descontando as sobreposições.

### RF03 — Gerar embeddings com OpenAI e persistir no pgvector

- **Identificador:** RF03.
- **Descrição:** Gerar representações vetoriais dos chunks e armazená-las junto aos textos e metadados na `api-conhecimento`.
- **Entrada:** Chunks de RF02, metadados de origem, modelo de embeddings e configuração de dimensão aprovada.
- **Processamento:** Solicitar embeddings OpenAI por Spring AI, persistir com PgVectorStore e controlar conclusão da indexação e publicação do documento.
- **Saída:** Chunks indexados, identificadores persistentes e estado final de sucesso ou falha da indexação.
- **Regras de negócio:** Modelo e dimensão devem ser consistentes entre indexação e consulta. Não publicar lote parcial; se uma etapa falhar, qualquer artefato intermediário permanece inelegível à busca. Reprocessamento não deve duplicar chunks. Troca incompatível de modelo exige reindexação planejada. Banco, credenciais e embeddings pertencem exclusivamente à `api-conhecimento`.
- **Critérios de aceite:**
  - **RF03-CA01 — Given** chunks válidos e dependências disponíveis, **When** a indexação conclui, **Then** cada chunk possui texto, vetor da dimensão configurada e metadados recuperáveis no PostgreSQL/pgvector.
  - **RF03-CA02 — Given** falha OpenAI ou de persistência após parte do processamento, **When** a operação termina, **Then** não há publicação parcial e RF01 não retorna sucesso.
  - **RF03-CA03 — Given** vetor de dimensão incompatível, **When** a persistência é tentada, **Then** ocorre falha explícita e o documento não se torna elegível para pesquisa.
  - **RF03-CA04 — Given** reinício do serviço após indexação concluída, **When** uma busca válida é executada, **Then** os dados persistidos continuam disponíveis sem reingestão obrigatória.

### RF04 — Consultar documentos por similaridade semântica

- **Identificador:** RF04.
- **Descrição:** Recuperar trechos relevantes de documentos elegíveis para uma pergunta textual.
- **Entrada:** Pergunta, quantidade de resultados solicitada dentro do limite, filtros permitidos e contexto de autorização confiável.
- **Processamento:** Validar parâmetros, gerar embedding da consulta na `api-conhecimento`, realizar similaritySearch, aplicar critérios de autorização/vigência e selecionar resultados pelo limiar calibrado.
- **Saída:** Até a quantidade solicitada de trechos elegíveis, com score, fonte, identificadores, versão e metadados permitidos; lista vazia quando não houver correspondências elegíveis.
- **Regras de negócio:** Não expor busca REST alternativa para consumo pela `api-atendimentos`. Não executar expressões de filtro arbitrárias recebidas do usuário. Não reduzir silenciosamente o limiar para forçar resultados. Nenhum texto ou metadado restrito pode ser retornado. Similaridade não garante suficiência da resposta.
- **Critérios de aceite:**
  - **RF04-CA01 — Given** corpus de aceite com pergunta e trechos esperados, **When** ocorre busca por uma paráfrase sem os termos literais do documento, **Then** pelo menos um trecho esperado aparece dentro do limite configurado, com metadados rastreáveis.
  - **RF04-CA02 — Given** pergunta sem correspondência acima do limiar, **When** a busca conclui sem falhas, **Then** retorna lista vazia e sucesso de pesquisa, sem trechos inventados.
  - **RF04-CA03 — Given** documentos relevantes vencidos, não aprovados ou fora da permissão, **When** são buscados, **Then** seus trechos e metadados não são expostos.
  - **RF04-CA04 — Given** limite inválido ou filtro não permitido, **When** a pesquisa é solicitada, **Then** ela é rejeitada antes de gerar embeddings ou consultar o banco.

### RF05 — Disponibilizar ferramenta MCP buscar_conhecimento

- **Identificador:** RF05.
- **Descrição:** Expor a recuperação semântica da `api-conhecimento` como tool MCP chamada exatamente `buscar_conhecimento`.
- **Entrada:** Inicialização/descoberta MCP ou chamada autenticada da tool com pergunta e parâmetros de pesquisa contratados.
- **Processamento:** Negociar o protocolo, disponibilizar schemas, validar argumentos, autorizar a operação e executar RF04 por Streamable HTTP.
- **Saída:** Descrição e schemas na descoberta; na execução, evidências estruturadas ou erro MCP explícito, conforme contrato.
- **Regras de negócio:** Não expor tools adicionais no MVP sem requisito aprovado. A tool retorna evidências, não uma resposta final elaborada por LLM. Registro de ferramenta e autenticação não substituem autorização das fontes. A fronteira MCP não deve vazar stack traces, SQL ou credenciais.
- **Critérios de aceite:**
  - **RF05-CA01 — Given** cliente MCP autorizado e servidor disponível, **When** inicializa e descobre ferramentas, **Then** encontra `buscar_conhecimento` com schema compatível com o contrato.
  - **RF05-CA02 — Given** parâmetros válidos, **When** a tool é executada por Streamable HTTP, **Then** retorna o resultado estruturado de RF04 sem usar transporte stdio ou REST proprietário.
  - **RF05-CA03 — Given** parâmetros inválidos ou tool desconhecida, **When** ocorre a chamada, **Then** há erro compatível com o protocolo e nenhuma pesquisa indevida.
  - **RF05-CA04 — Given** cliente não autorizado, **When** tenta descobrir ou executar a tool protegida, **Then** o acesso é negado sem revelar o acervo.

### RF06 — Receber perguntas na API de Atendimentos

- **Identificador:** RF06.
- **Descrição:** Receber perguntas textuais por REST na `api-atendimentos` e iniciar um atendimento independente.
- **Entrada:** Pergunta e contexto do solicitante conforme a política de acesso; identificador de correlação opcional, validado quando fornecido.
- **Processamento:** Validar autenticação/autorização e entrada, estabelecer identificador do atendimento e correlação, executar RF07–RF10 dentro do prazo total.
- **Saída:** Resposta de atendimento ou resultado de erro/insuficiência, com identificador e correlação, conforme contrato.
- **Regras de negócio:** Perguntas são independentes no MVP, sem memória conversacional implícita. Não persistir histórico de perguntas por padrão. Uma pergunta não altera permissões ou configurações. Rejeitar entradas inválidas antes de chamar MCP ou OpenAI.
- **Critérios de aceite:**
  - **RF06-CA01 — Given** solicitante autorizado e pergunta válida, **When** envia a requisição, **Then** o fluxo recebe identificador rastreável e consulta o conhecimento antes de gerar fatos.
  - **RF06-CA02 — Given** pergunta ausente, somente espaços ou maior que 2.000 pontos de código, **When** a requisição é recebida, **Then** é rejeitada sem chamadas externas de pesquisa ou geração.
  - **RF06-CA03 — Given** duas perguntas de solicitantes distintos, **When** são processadas, **Then** não compartilham contexto recuperado, permissões ou memória de conversa.

### RF07 — Consultar a ferramenta MCP da API de Conhecimento

- **Identificador:** RF07.
- **Descrição:** A `api-atendimentos` deve executar `buscar_conhecimento` exclusivamente pelo cliente MCP.
- **Entrada:** Pergunta validada, identidade/permissões confiáveis, correlação e orçamento de tempo restante.
- **Processamento:** Usar conexão MCP inicializada, verificar disponibilidade/schema da tool, enviar parâmetros permitidos, executar a chamada e validar o resultado antes de construir contexto.
- **Saída:** Evidências estruturadas validadas, resultado vazio ou classificação explícita da falha.
- **Regras de negócio:** A recuperação deve ocorrer em todo atendimento factual válido. Não deixar essa obrigação exclusivamente à decisão de tool calling do modelo. Permissões não podem ser derivadas de argumentos produzidos pelo LLM. Não usar cache de respostas, busca local, REST alternativo ou acesso direto ao banco como fallback no MVP.
- **Critérios de aceite:**
  - **RF07-CA01 — Given** conexão válida e tool contratada, **When** uma pergunta é processada, **Then** a chamada observável a `buscar_conhecimento` ocorre por MCP e sua correlação é preservada.
  - **RF07-CA02 — Given** servidor indisponível, tool ausente ou schema incompatível, **When** o atendimento tenta pesquisar, **Then** retorna falha técnica e não consulta banco nem gera resposta factual sem evidência.
  - **RF07-CA03 — Given** HTTP bem-sucedido com erro JSON-RPC, `isError` ou payload inválido, **When** o cliente interpreta a resposta, **Then** identifica falha e não a confunde com busca vazia válida.

### RF08 — Construir contexto RAG e gerar resposta com OpenAI

- **Identificador:** RF08.
- **Descrição:** Gerar resposta em português com Spring AI/OpenAI a partir dos trechos elegíveis recuperados por MCP.
- **Entrada:** Pergunta validada, evidências com fontes, política de resposta e configuração do modelo de chat.
- **Processamento:** Avaliar suficiência, delimitar evidências como dados, construir contexto dentro do orçamento do modelo, gerar resposta e validar estrutura, referências e regras de negócio antes da entrega.
- **Saída:** Resposta fundamentada ou indicação explícita de insuficiência/falha; nunca saída bruta inválida apresentada como sucesso.
- **Regras de negócio:** Não usar conhecimento prévio do LLM para completar fatos institucionais ausentes. Preservar qualificadores da fonte; não inventar valores, datas, horários, vagas, cursos ou condições comerciais. Não executar instruções de documentos. Se a redução de contexto retirar evidências essenciais, reconhecer insuficiência. Dados sem suporte não podem aparecer como afirmações, mesmo em resposta parcialmente sustentada.
- **Critérios de aceite:**
  - **RF08-CA01 — Given** evidências suficientes sobre conteúdo e pré-requisitos de um curso, **When** a resposta é gerada, **Then** suas afirmações correspondem aos trechos e preservam modalidade e condições aplicáveis.
  - **RF08-CA02 — Given** documento com programa do curso, mas sem preço, data, horário ou vagas confirmados, **When** esses dados são perguntados, **Then** o sistema declara a limitação sem estimá-los ou importar condições de outro curso.
  - **RF08-CA03 — Given** trecho contendo “ignore as regras”, preço fictício imposto como instrução ou pedido de divulgação de segredo, **When** compõe o contexto, **Then** não modifica políticas, não executa ações e não fornece a informação ordenada sem evidência factual válida.
  - **RF08-CA04 — Given** saída do modelo com formato inválido, fonte inexistente ou afirmação sem suporte identificada na validação, **When** a aplicação prepara a resposta, **Then** a saída é rejeitada e tratada explicitamente, sem entregar o conteúdo inválido como sucesso.

### RF09 — Devolver fontes, identificadores e metadados utilizados

- **Identificador:** RF09.
- **Descrição:** Permitir ao consumidor rastrear as evidências usadas na elaboração da resposta.
- **Entrada:** Resposta candidata, conjunto efetivamente usado no contexto e metadados autorizados da recuperação.
- **Processamento:** Associar citações aos trechos de suporte, conferir sua presença no conjunto recuperado, eliminar referências duplicadas e remover metadados internos/restritos.
- **Saída:** Identificador do atendimento e correlação; para cada fonte utilizada, identificadores de documento e chunk, versão, título, referência de origem e metadados permitidos de relevância/vigência. URL não é obrigatória se a fonte possuir outra referência institucional válida.
- **Regras de negócio:** Não criar URLs, títulos ou identificadores pelo modelo. Distinguir fontes utilizadas de documentos apenas recuperados. Não devolver vetores, credenciais, permissões internas ou conteúdo não autorizado. Resposta factual deve possuir pelo menos uma fonte válida; todas as suas afirmações factuais devem ter suporte identificável. Ausência de evidência tem fontes utilizadas vazias; falhas técnicas não devem oferecer fontes como justificativa de uma resposta inexistente.
- **Critérios de aceite:**
  - **RF09-CA01 — Given** resposta sustentada por dois chunks da mesma fonte, **When** os metadados são devolvidos, **Then** é possível identificar ambos os chunks e a versão exata, sem duplicar a descrição da fonte desnecessariamente.
  - **RF09-CA02 — Given** identificador citado que não pertence às evidências recuperadas, **When** ocorre validação, **Then** a resposta não é publicada como fundamentada.
  - **RF09-CA03 — Given** busca sem evidências ou falha antes da geração, **When** o resultado é devolvido, **Then** não há fontes utilizadas inventadas e o atendimento mantém seu identificador de correlação.

### RF10 — Tratar ausência de evidência ou falhas de dependências

- **Identificador:** RF10.
- **Descrição:** Dar retorno explícito, compreensível e tecnicamente distinguível quando não for possível responder com segurança.
- **Entrada:** Resultado vazio, evidências insuficientes/conflitantes, falhas MCP, banco ou OpenAI, expiração de prazo, recusa do modelo ou saída inválida.
- **Processamento:** Classificar o resultado, impedir geração indevida, selecionar mensagem segura e registrar diagnóstico técnico correlacionado sem conteúdo sensível.
- **Saída:** Estado conceitual de respondido, parcialmente respondido com limitações, conhecimento insuficiente, dependência indisponível, tempo esgotado ou resposta do modelo inválida/recusada. O contrato definirá sua representação pública e os códigos de erro.
- **Regras de negócio:** Busca vazia válida é diferente de falha de pesquisa. Não afirmar que a COTI não oferece algo apenas por ausência de registro. Sem evidências elegíveis, devolver mensagem determinística sem chamar o modelo de chat para inventar uma resposta. Conflitos não podem ser resolvidos por preferência arbitrária do modelo. Pode solicitar esclarecimento; canal humano só pode ser indicado se estiver na base autorizada. Não retornar stack traces ou segredo na mensagem pública.
- **Critérios de aceite:**
  - **RF10-CA01 — Given** pesquisa concluída sem evidências, **When** o atendimento finaliza, **Then** informa conhecimento insuficiente, não chama o chat e não conclui que o serviço ou curso inexiste.
  - **RF10-CA02 — Given** documentos conflitantes e nenhuma regra autorizada de precedência, **When** a pergunta é avaliada, **Then** o sistema informa a limitação sem selecionar um preço, horário ou condição como verdadeiro.
  - **RF10-CA03 — Given** timeout ou indisponibilidade MCP, OpenAI ou banco, **When** a operação falha, **Then** há resultado técnico distinguível da ausência de conhecimento, correlação e nenhuma tentativa de contornar MCP.
  - **RF10-CA04 — Given** instrução de encaminhamento humano sem fonte autorizada, **When** o sistema não sabe responder, **Then** não inventa telefone, email, URL ou horário de atendimento.

## 4.1 Requisitos complementares de administração e diagnóstico

RC01–RC03 explicitam operações já definidas em `specs/06-api-contracts.md`, seções 3.2–3.4, e contempladas na arquitetura e no plano. Seu registro na T001 corrige a falta de cobertura nos requisitos; não introduz novos endpoints, acesso de atendimento por REST ou gestão de atualização/exclusão documental.

### RC01 — Listar conhecimentos para administração

- **Identificador:** RC01.
- **Descrição:** Permitir listagem administrativa paginada dos documentos indexados acessíveis ao solicitante por `GET /api/conhecimentos`.
- **Entrada:** Contexto autenticado com escopo `conhecimentos:ler`; parâmetros opcionais `pagina` (inteiro ≥ 0, padrão 0), `tamanho` (inteiro de 1 a 100, padrão 20) e `categoria` do domínio contratado.
- **Processamento:** Validar escopo e parâmetros, aplicar autorização antes de contar/paginar e ordenar por criadoEm decrescente e id crescente, conforme o contrato.
- **Saída:** HTTP 200 com resumos, página, tamanho, totais e correlação; erros padronizados conforme o contrato.
- **Regras de negócio:** Não gerar embeddings nem realizar busca semântica. Não devolver texto completo, vetores ou metadados restritos. Documento parcial não entra na listagem. Vigência vencida pode ser visível ao administrador autorizado, sem habilitar seu uso no RAG. Totais não revelam documentos fora da permissão.
- **Critérios de aceite:**
  - **RC01-CA01 — Given** documentos indexados acessíveis e parâmetros válidos, **When** a listagem é solicitada, **Then** retorna resumos na ordenação contratada, com paginação e totais calculados apenas sobre o conjunto autorizado.
  - **RC01-CA02 — Given** nenhum documento visível ou página além do total, **When** ocorre a consulta, **Then** retorna HTTP 200 com itens vazios e totais coerentes, sem chamar embeddings.
  - **RC01-CA03 — Given** tamanho fora de 1–100, página negativa ou parâmetro desconhecido, **When** a requisição é validada, **Then** retorna HTTP 400 com erro padronizado.
  - **RC01-CA04 — Given** solicitante sem autenticação ou sem escopo de leitura, **When** tenta listar, **Then** recebe respectivamente 401 ou 403, sem acesso ao acervo.

### RC02 — Consultar um conhecimento para administração

- **Identificador:** RC02.
- **Descrição:** Permitir consulta administrativa individual por `GET /api/conhecimentos/{id}`.
- **Entrada:** UUID obrigatório e contexto autenticado com escopo `conhecimentos:ler`, sujeito à autorização documental.
- **Processamento:** Validar UUID e permissão, consultar somente documento publicado e montar o detalhe contratado.
- **Saída:** HTTP 200 com resumo, texto integral e correlação; 400 para ID inválido; 404 seguro para inexistente, não publicado ou inacessível; demais erros conforme o contrato.
- **Regras de negócio:** Não devolver embeddings, chunks internos, credenciais ou permissões. Ausência de escopo geral resulta em 403; restrição documental resulta no mesmo 404 usado para documento inexistente, sem revelar sua existência.
- **Critérios de aceite:**
  - **RC02-CA01 — Given** documento indexado e autorizado, **When** seu UUID é consultado, **Then** retorna HTTP 200 com versão, texto e metadados contratados, sem vetores.
  - **RC02-CA02 — Given** documento inexistente, parcial ou fora da permissão, **When** o UUID é consultado por solicitante com escopo de leitura, **Then** retorna o mesmo código/mensagem segura de 404, sem conteúdo documental.
  - **RC02-CA03 — Given** ID que não é UUID válido, **When** a entrada é validada, **Then** retorna HTTP 400, sem consulta desnecessária ao banco.

### RC03 — Diagnosticar busca semântica administrativamente

- **Identificador:** RC03.
- **Descrição:** Disponibilizar `POST /api/conhecimentos/diagnostico/buscar` exclusivamente para diagnóstico administrativo; o consumidor de atendimento continua usando apenas MCP.
- **Entrada:** Contexto autenticado com escopo `conhecimentos:diagnosticar`; `pergunta` obrigatória de 1–2.000 pontos de código, não vazia; `limite` inteiro opcional de 1 a 10, padrão 5. Corpo até 16 KiB, sem filtros livres ou identidade no payload.
- **Processamento:** Validar segurança e entrada, executar o mesmo caso de uso de RF04 com aprovação, autorização e vigência e produzir resposta REST, sem envelope JSON-RPC.
- **Saída:** HTTP 200 com BuscaConhecimentoResponse e trechos ou lista vazia; falhas e timeouts por erro REST padronizado conforme o contrato.
- **Regras de negócio:** Prazo total de 10 segundos, com limites internos e retries zero já definidos. A identidade da api-atendimentos não recebe permissão para esta rota. Não registrar a pergunta completa por padrão e não contornar filtros para fins de diagnóstico. O endpoint não substitui nem emula a tool buscar_conhecimento.
- **Critérios de aceite:**
  - **RC03-CA01 — Given** operador autorizado e pergunta válida, **When** executa o diagnóstico, **Then** recebe evidências no formato REST contratado, com os mesmos filtros de elegibilidade de RF04.
  - **RC03-CA02 — Given** identidade do atendimento sem escopo de diagnóstico, **When** tenta chamar a rota, **Then** recebe 403 e não há pesquisa nem fallback do fluxo de atendimento para REST.
  - **RC03-CA03 — Given** limite inválido, propriedade desconhecida ou payload excedido, **When** a requisição é recebida, **Then** retorna 400 ou 413 conforme o contrato, antes de embeddings/pesquisa.
  - **RC03-CA04 — Given** pesquisa válida sem trechos, falha de dependência ou timeout, **When** a operação termina, **Then** distingue respectivamente 200 com lista vazia, 503 e 504, sem expor erros internos ou confundir o resultado com MCP.

## 5. Requisitos não funcionais

### RNF01 — Segurança

- Autenticar e autorizar publicação e acesso às interfaces conforme a política a definir nos contratos. Impor autorização documental na `api-conhecimento` antes de retornar evidências. Somente conteúdo elegível pode ser enviado ao modelo de chat.
- Usar HTTPS fora do ambiente local, privilégios mínimos no banco e credenciais distintas por responsabilidade. Não versionar segredos nem incorporá-los a imagens. Minimizar informações pessoais transmitidas aos provedores.
- **Aceite — Given** solicitante sem permissão e documentos restritos, **When** tenta cadastrar, pesquisar ou atender usando tais fontes, **Then** as operações indevidas são negadas e não há vazamento por resposta, metadados, logs ou contexto enviado ao chat.

### RNF02 — Observabilidade e rastreabilidade

- Produzir logs estruturados, métricas e traces correlacionando REST, MCP, embeddings, banco e chat. Observar duração, resultados vazios, erros, timeouts e uso de tokens quando informado pelo provedor.
- Não registrar API keys, informações sensíveis, documentos, prompts ou perguntas completas por padrão. Preferir identificadores de atendimento, fonte, versão e categoria de falha; evitar dados pessoais em labels de métricas.
- **Aceite — Given** atendimento bem-sucedido e falha controlada, **When** a telemetria é inspecionada, **Then** é possível seguir cada operação entre serviços e identificar sua categoria de resultado sem encontrar marcadores sensíveis das fixtures.

### RNF03 — Manutenibilidade e documentação

- Usar Java 21, Spring AI 2.0.1 e Spring Boot compatível, com versões exatas definidas na arquitetura. Separar domínio, casos de uso e adaptadores; preferir records para DTOs e injeção por construtor.
- Seguir Spec → Plan → Implement → Test → Review. Manter OpenAPI para REST e schemas MCP atualizados. Mudanças em contratos exigem motivo, análise de impacto e atualização das specs.
- **Aceite — Given** alteração de comportamento, **When** é revisada, **Then** possui requisito/critério relacionado, contrato correspondente atualizado quando necessário e evidência de compilação independente dos serviços afetados.

### RNF04 — Tempo limite das integrações

- Aplicar os limites da seção 3 também a espera por conexão, leitura e execução; cancelar trabalho pendente quando possível. Nenhuma chamada ou fila pode esperar indefinidamente. Não iniciar etapa cujo orçamento necessário exceda o prazo restante.
- Desabilitar repetições automáticas no MVP, inclusive nas camadas internas dos SDKs e validação de saída estruturada. Expiração deve impedir publicação tardia de documento incompleto ou resposta após encerramento da operação.
- **Aceite — Given** dependência que atrasa além de seu limite configurado, **When** a operação é executada, **Then** a aplicação produz timeout dentro do orçamento total, com tolerância de medição previamente registrada no ambiente de teste, e não faz nova tentativa automática.

### RNF05 — Validação de entrada e limites de recursos

- Validar campos obrigatórios, tamanho, tipos, filtros permitidos, topK, configuração de chunks e metadados antes de efeitos externos. Não executar expressões enviadas pelo solicitante como SQL, filtros livres, templates ou instruções de sistema.
- Definir também limites de payload HTTP, lotes de embeddings e contexto de geração na arquitetura/contratos, respeitando os modelos selecionados; rejeitar excesso explicitamente, sem truncar silenciosamente perguntas ou condições comerciais.
- **Aceite — Given** entrada acima do limite, filtro não permitido ou configuração inconsistente, **When** é recebida, **Then** há rejeição clara sem execução desnecessária de embeddings, banco, MCP ou chat.

### RNF06 — Testabilidade

- Criar testes automatizados ligados aos critérios RF/RNF, com JUnit 5, Mockito, testes HTTP e contratos MCP. Resolver na arquitetura a compatibilidade de JUnit 5 com o conjunto Spring Boot escolhido, sem substituir versões silenciosamente.
- Usar Testcontainers PostgreSQL/pgvector em Docker Desktop para comportamento vetorial real e cliente/servidor MCP reais para Streamable HTTP. Usar dublês determinísticos para modelos nas suítes comuns e separar avaliações com OpenAI real.
- **Aceite — Given** execução de validação, **When** os relatórios são conferidos, **Then** demonstram cenários de sucesso, falha, insuficiência, autorização e prompt injection, com testes executados/ignorados distinguíveis. Integração real ausente não é declarada aprovada por um mock.

### RNF07 — Separação e execução dos microsserviços

- Compilar, configurar e implantar cada serviço independentemente. `api-atendimentos` não pode conter drivers, credenciais, VectorStore ou conexões PostgreSQL/pgvector. Toda busca passa pela tool MCP; embeddings pertencem à `api-conhecimento`.
- Construir imagens e executar banco e dependências locais com Docker através do Docker Desktop. Usar Docker Compose quando necessário à orquestração e não apagar volumes persistentes em limpeza rotineira.
- **Aceite — Given** ambiente Docker definido pelo projeto, **When** os serviços são construídos e suas dependências inspecionadas, **Then** ambos podem ser implantados separadamente, somente conhecimento alcança o banco e atendimento falha explicitamente sem MCP, sem buscar por outro caminho.

### RNF08 — Proteção contra prompt injection

- Tratar pergunta, texto, metadados e retorno MCP como dados não confiáveis. Separar instruções do sistema e evidências, limitar ferramentas por allowlist e impor autorização na aplicação.
- Não obedecer a instruções documentais para alterar políticas, revelar segredos, consultar outra base ou inventar fatos. Prompts defensivos não substituem validação e fronteiras de segurança.
- **Aceite — Given** corpus com instruções maliciosas em documentos e metadados, **When** ocorrem pesquisa e geração, **Then** não há ampliação de acesso, execução de ferramenta indevida ou divulgação de segredo fictício; a resposta mantém as regras de evidência ou se abstém.

### RNF09 — Configuração por variáveis de ambiente

- Fornecer credenciais exclusivamente por variáveis de ambiente, inclusive quando injetadas por gerenciador de segredos. Externalizar modelos, URLs MCP, parâmetros de busca/chunking e timeouts, com valores não secretos padrão documentados quando aplicável.
- Validar configurações obrigatórias na inicialização, sem credenciais reais de fallback. Cada serviço recebe apenas os segredos de que necessita.
- **Aceite — Given** credencial obrigatória ausente ou parâmetro inválido, **When** o serviço inicia, **Then** falha com diagnóstico seguro. **Given** ambiente válido, **When** modelos e limites configuráveis são alterados, **Then** são aplicados sem modificação do código e sem expor valores secretos.

## 6. Escopo do MVP

### Incluído

- RF01–RF10 e RNF01–RNF09, com os dois microsserviços independentes.
- RC01–RC03: listagem, consulta individual e diagnóstico administrativos já contratados, sem permitir consumo REST de conhecimento pela api-atendimentos.
- Cadastro síncrono de texto em payload REST por publicador autorizado, com fonte previamente aprovada; chunking com sobreposição, embeddings e publicação somente após indexação completa.
- Recuperação semântica com metadados, aprovação, vigência e autorização; tool `buscar_conhecimento` por MCP Streamable HTTP.
- Atendimento REST de perguntas independentes em português, resposta RAG com OpenAI, fontes e estados explícitos de insuficiência ou falha.
- Controles de segurança, configuração externa, telemetria mínima, OpenAPI, schemas MCP e testes de aceite automatizados.
- Execução reproduzível com Docker Desktop e banco PostgreSQL/pgvector. Corpus de aceite fictício ou institucional aprovado, sem credenciais reais versionadas.

### Fora do escopo

- Frontend, aplicativo móvel, WhatsApp, email, voz ou integrações com redes sociais.
- Upload/processamento de PDF, Word, imagens, OCR, áudio ou vídeo; crawler e navegação automática por URLs. A referência de origem não autoriza baixar conteúdo remoto.
- Workflow eletrônico de aprovação editorial, portal administrativo e gestão completa de versões/exclusão por interfaces dedicadas. Permanecem obrigatórios identificação de versão, deduplicação e impedimento de exposição parcial; evolução do acervo exigirá tarefa e contrato próprios.
- Filas, ingestão assíncrona, reprocessamento automático e retries automáticos; busca híbrida, reranking avançado e fine-tuning.
- Memória de conversa, histórico persistente de atendimentos, personalização por perfil acadêmico e consultas a dados pessoais do aluno.
- Matrícula, pagamento, reserva de vagas, descontos negociados, cálculo de preços, emissão de propostas ou alteração de dados institucionais por uma conversa.
- Integração em tempo real com ERP, CRM, calendários ou sistemas comerciais. O MVP não pode confirmar disponibilidade atual a partir de documento sem validade suficiente.
- Ferramentas MCP além de `buscar_conhecimento`, pesquisa alternativa por REST ou banco, múltiplos provedores de IA e fallback de modelo.
- Transferência automática para atendente humano, SSO corporativo completo, alta disponibilidade e escala produtiva com SLA contratado. Sua exclusão não dispensa autenticação, autorização, limites de execução e indicação de canais humanos apenas quando documentados.

## 7. Condições para avançar e concluir o MVP

Antes da implementação correspondente, conferir e detalhar os parâmetros de ambiente previstos na arquitetura e nos contratos: versões e bibliotecas, modelos/dimensões/tokenizador, política de acesso e aprovação das fontes, schemas, rotas, erros, limites de payload/lotes/contexto e orçamento de execução. A referência canônica do contrato foi reconciliada na T001; sua existência não substitui a validação de compatibilidade nem o aceite de implementação.

Antes do aceite da busca e do atendimento, registrar o corpus, a métrica/limiar de relevância e os resultados esperados, incluindo paráfrases, perguntas sem suporte e fatos comerciais ausentes. Todos os cenários obrigatórios deste documento devem ser aprovados no ambiente de teste definido; avaliações de fundamentação não podem depender apenas de o próprio modelo declarar que acertou.

O MVP somente será considerado concluído com evidências dos critérios de aceite aplicáveis, compilação e testes relevantes executados, contratos/documentação coerentes e pendências obrigatórias resolvidas. Resultados de testes devem ser relatados conforme `AGENTS.md`; esta especificação, por si só, não comprova implementação ou execução desses testes.
