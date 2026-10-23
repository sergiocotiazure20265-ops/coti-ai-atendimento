# Contratos de API — COTI AI Atendimento

## 1. Abrangência e convenções

Contrato da versão funcional inicial, subordinado à constituição e a `specs/02-requirements.md`. Não contém implementação. DTOs são definições de dados; sua futura representação Java deve preferir records.

Listagem, consulta individual e diagnóstico administrativo estão formalizados neste contrato e nos requisitos complementares RC01–RC03, reconciliados pela T001. O diagnóstico é restrito à operação humana e não altera a obrigação de integração exclusiva por MCP no atendimento. A constituição referencia explicitamente este documento canônico. A reconciliação documental preserva integralmente endpoints, DTOs, schemas, permissões e erros contratados.

- REST usa JSON UTF-8, `Content-Type: application/json` e `Accept: application/json`. MCP usa envelopes JSON-RPC e regras de Streamable HTTP da seção 5; não é REST.
- Nomes JSON em camelCase, sem acentos: `titulo`, `documentoId`, `chunkId`. IDs são strings UUID; contadores são inteiros; similaridade é número JSON finito; datas são strings RFC 3339 com fuso, retornadas em UTC, como `2026-10-22T15:00:00Z`.
- Campos obrigatórios não aceitam `null`. Campos opcionais são omitidos quando desconhecidos; `null` não equivale a omissão. Exceção: `vigenciaInicio` e `vigenciaFim` nos DTOs de saída são sempre presentes e podem ser `null` para período aberto.
- Tamanhos textuais são medidos em pontos de código Unicode após normalização NFC; pergunta, título e referência de fonte recebem trim. Texto documental preserva quebras e espaços significativos. Proibir strings obrigatórias somente com espaços.
- Rejeitar propriedades desconhecidas nas entradas, chaves JSON duplicadas, tipos incorretos, números fracionários em campos inteiros e parâmetros de query desconhecidos. Não converter silenciosamente strings em números.
- Não aceitar `aprovado`, credenciais, vetores, usuário, permissões ou instruções de sistema em DTOs de entrada. Aprovação da fonte e acesso vêm de configuração/política confiável, não do texto nem de campos produzidos pelo LLM.
- Aceitar opcionalmente `X-Correlation-Id` UUID; rejeitar valor inválido com 400 e gerar nova correlação segura para esse erro. Gerar UUID quando ausente. Retornar o header em todas as respostas da aplicação e propagar correlação entre serviços. `traceparent`, quando usado, segue validação do mecanismo de tracing.
- REST não transmite SSE no MVP. Não registrar perguntas, textos, prompts completos, tokens de autenticação ou segredos em logs. Retornar `Cache-Control: no-store` para dados e erros.
- Todos os exemplos de textos, fontes, horários técnicos e identificadores são fixtures fictícias, não divulgação do catálogo real da COTI.

### 1.1 Segurança e autorização

Usar `Authorization: Bearer <token>` validado quanto a assinatura, emissor, audiência e expiração. Emissor, chaves e obtenção dos tokens serão definidos na arquitetura; não criar endpoints de autenticação nesta etapa. HTTPS é obrigatório fora do desenvolvimento local.

| Interface | Escopo obrigatório |
|---|---|
| POST /api/conhecimentos | `conhecimentos:escrever` |
| GET /api/conhecimentos e GET por id | `conhecimentos:ler` |
| POST /api/conhecimentos/diagnostico/buscar | `conhecimentos:diagnosticar` |
| MCP /mcp | `conhecimentos:pesquisar` |
| POST /api/atendimentos/perguntar | `atendimentos:perguntar` |
| GET /actuator/health | Sem token, somente status mínimo |

Ausência/token inválido resulta em 401 com `WWW-Authenticate: Bearer`; escopo insuficiente, em 403. A credencial de atendimento não deve possuir escopos de escrita, leitura administrativa ou diagnóstico da API de Conhecimento.

Na chamada MCP, usar identidade de serviço autorizada mais contexto delegado verificável do solicitante, ou token delegado cuja audiência seja a API de Conhecimento, conforme arquitetura. Não encaminhar indiscriminadamente um token de outra audiência. Sem contexto verificável, negar acesso; nunca presumir acesso irrestrito. Permissões e identidade não são argumentos da tool nem headers livres confiados por convenção. A política deve considerar identidade e escopos verificados no servidor antes de retornar texto ou metadados.

## 2. Erro JSON padronizado

### ErroResponse e ErroDetalhe

Todo erro REST produzido pela aplicação, inclusive segurança, parsing e limites HTTP, deve ter esta forma. Proxies devem preservar ou produzir o mesmo envelope quando sob controle do projeto. Ausência de resposta HTTP é tratada pelo cliente como falha de transporte.

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| erro | objeto ErroDetalhe | Sim | Único campo de primeiro nível. |
| erro.codigo | string | Sim | Código estável da tabela abaixo. |
| erro.mensagem | string, 1–500 | Sim | Mensagem segura em português; sem stack trace ou texto do provedor. |
| erro.timestamp | string date-time | Sim | Momento do erro em UTC. |
| erro.correlationId | string UUID | Sim | Igual à correlação retornada no header. |
| erro.detalhes | array de Violacao | Sim | Pode estar vazio. Nunca repetir valores rejeitados. |
| erro.atendimentoId | string UUID | Não | Presente se um atendimento já foi identificado; não existe em falhas precoces de autenticação/parsing. |
| Violacao.campo | string, 1–100 | Sim | Caminho do campo ou parâmetro; sem incluir seu conteúdo. |
| Violacao.mensagem | string, 1–200 | Sim | Descrição segura da restrição. |

Exemplo de HTTP 400:

```json
{
  "erro": {
    "codigo": "ENTRADA_INVALIDA",
    "mensagem": "A requisição contém campos inválidos.",
    "timestamp": "2026-10-22T15:00:00Z",
    "correlationId": "10000000-0000-4000-8000-000000000001",
    "detalhes": [{"campo": "pergunta", "mensagem": "Deve conter entre 1 e 2000 caracteres e não pode ser vazia."}]
  }
}
```

### 2.1 Códigos HTTP e catálogo de erros

| HTTP | codigo | Uso |
|---|---|---|
| 400 | ENTRADA_INVALIDA | JSON, UUID, campo, query ou limite inválido. |
| 401 | NAO_AUTENTICADO | Token ausente, inválido ou expirado do chamador. |
| 403 | ACESSO_NEGADO | Escopo insuficiente ou tentativa de publicação fora da política. |
| 404 | CONHECIMENTO_NAO_ENCONTRADO | ID inexistente ou inacessível ao solicitante, sem revelar existência. |
| 404 | ROTA_NAO_ENCONTRADA | Rota REST inexistente. |
| 405 | METODO_NAO_PERMITIDO | Método REST não suportado; retornar `Allow`. |
| 406 | REPRESENTACAO_NAO_SUPORTADA | Accept incompatível. |
| 409 | FONTE_JA_CADASTRADA | Mesma fonte com conteúdo/metadados diferentes; atualização fora do MVP. |
| 409 | INGESTAO_EM_ANDAMENTO | Cadastro concorrente da mesma fonte ainda não finalizado. |
| 413 | PAYLOAD_EXCEDIDO | Corpo HTTP maior que o limite de bytes da rota. |
| 415 | MIDIA_NAO_SUPORTADA | Content-Type incompatível ou conteúdo comprimido não suportado. |
| 422 | FONTE_NAO_APROVADA | Publicador autorizado, mas origem/condições sem aprovação verificável. |
| 502 | RESPOSTA_DEPENDENCIA_INVALIDA | Schema MCP, ferramenta esperada ou resultado incompatível. |
| 502 | RESPOSTA_MODELO_INVALIDA | Saída malformada, fonte inválida ou violação detectada de fundamentação. |
| 502 | RESPOSTA_MODELO_RECUSADA | Provedor recusou a geração sem produzir resposta utilizável. |
| 503 | DEPENDENCIA_INDISPONIVEL | MCP, banco ou OpenAI indisponível, quota ou falha de credencial interna. |
| 503 | SERVICO_INDISPONIVEL | Serviço local não está pronto/saudável. |
| 504 | TEMPO_LIMITE_EXCEDIDO | Prazo da operação ou dependência esgotado. |
| 500 | ERRO_INTERNO | Erro inesperado sem exposição de detalhes internos. |

Não transformar credencial OpenAI inválida em 401 para o aluno: é falha interna de dependência, 503. Busca sem resultados não é 404/503. Conhecimento insuficiente não é erro técnico. Não criar fontes ou resposta factual em envelopes de erro.

## 3. API de Conhecimento — REST

### 3.1 POST /api/conhecimentos

Cadastrar e indexar um documento textual de origem previamente aprovada. Prazo total de 60 segundos. Corpo máximo de **1 MiB (1.048.576 bytes)** UTF-8 descomprimidos; não aceitar Content-Encoding no MVP. Além desse limite, aplicar o limite textual de 100.000 caracteres de RF01.

**CadastrarConhecimentoRequest:**

| Campo | Tipo | Obrigatório | Validação |
|---|---|---|---|
| titulo | string | Sim | 1–200 caracteres. |
| texto | string | Sim | 1–100.000 caracteres, não somente espaços. |
| fonte | string | Sim | 1–500 caracteres; referência institucional estável, não necessariamente URL. Não navegar ou baixar essa referência. |
| categoria | string enum | Sim | `CURSO`, `PROGRAMA`, `TECNOLOGIA`, `MODALIDADE`, `PRE_REQUISITO`, `INSTITUCIONAL`. |
| vigenciaInicio | string date-time | Não | Início inclusivo, se houver. |
| vigenciaFim | string date-time | Não | Fim exclusivo, posterior ao início quando ambos existirem. |

Não há mapa livre de metadados. Título/categoria/vigência são metadados declarados pelo publicador, sujeitos a verificação de aprovação. A confirmação da validade, o público autorizado e a aprovação são obtidos de política/registro confiável da fonte. Se não for possível verificá-los, não publicar. Informações temporais/comerciais sem validade confirmada não podem sustentar atendimento factual.

```json
{
  "titulo": "Documento demonstrativo — pré-requisitos",
  "texto": "Neste exemplo fictício, o programa demonstrativo exige conhecimentos básicos de programação.",
  "fonte": "fixture:programa-demonstrativo-v1",
  "categoria": "PRE_REQUISITO"
}
```

**ConhecimentoResumoResponse:** todos os campos abaixo são obrigatórios; apenas os dois campos de vigência admitem `null`.

| Campo | Tipo | Regra |
|---|---|---|
| id | string UUID | Identificador do documento, estável. |
| versao | integer ≥ 1 | 1 no cadastro inicial; não é um contador alterável pelo cliente. |
| titulo, fonte, categoria | string | Mesmas restrições da entrada. |
| status | string enum | `INDEXADO`; não expor documento parcialmente indexado. |
| quantidadeChunks | integer ≥ 1 | Quantidade efetivamente persistida. |
| criadoEm | string date-time | Momento do cadastro concluído. |
| vigenciaInicio, vigenciaFim | string date-time ou null | Limites da vigência conhecida. |
| validadeConfirmada | boolean | Confirmação obtida da política da fonte; não é inferida pelo LLM. |
| correlationId | string UUID | Correlação da operação atual, não a correlação histórica do cadastro. |

**201 Created**, com `Location: /api/conhecimentos/{id}`, somente após indexação e publicação completas:

```json
{
  "id": "20000000-0000-4000-8000-000000000001",
  "versao": 1,
  "titulo": "Documento demonstrativo — pré-requisitos",
  "fonte": "fixture:programa-demonstrativo-v1",
  "categoria": "PRE_REQUISITO",
  "status": "INDEXADO",
  "quantidadeChunks": 1,
  "criadoEm": "2026-10-22T15:00:00Z",
  "vigenciaInicio": null,
  "vigenciaFim": null,
  "validadeConfirmada": true,
  "correlationId": "10000000-0000-4000-8000-000000000001"
}
```

Deduplicar pela fonte normalizada mais conteúdo/metadados normalizados. Reenvio idêntico concluído retorna **200 OK** com o mesmo ID/versão, nova correlação e sem duplicar chunks. Conteúdo diferente para a mesma fonte retorna 409; não implementar atualização implícita. Cadastros concorrentes não podem publicar duplicatas. Falha/timeout retorna erro e impede publicação parcial ou tardia da operação expirada. Novo envio após falha deve permitir reprocessamento seguro, sem duplicidade.

Erros: 400, 401, 403, 406, 409, 413, 415, 422, 503, 504 e 500 conforme seção 2.

### 3.2 GET /api/conhecimentos

Listagem administrativa paginada de documentos indexados acessíveis ao chamador; não realiza busca semântica, não gera embeddings e não retorna texto completo ou vetores.

| Query | Tipo | Obrigatório | Regra |
|---|---|---|---|
| pagina | integer ≥ 0 | Não | Padrão 0. |
| tamanho | integer 1–100 | Não | Padrão 20. |
| categoria | enum de categoria | Não | Filtro exato, autorizado. |

Ordenação fixa por `criadoEm DESC, id ASC`. Aplicar autorização antes da contagem/paginação; documentos inacessíveis não entram nos totais. Vigência vencida pode ser visível ao administrador autorizado, mas não habilita uso no RAG. Não há snapshot garantido entre páginas sob cadastros concorrentes.

**PaginaConhecimentosResponse, HTTP 200:** `itens` é array de ConhecimentoResumoResponse; `pagina`, `tamanho`, `totalElementos` e `totalPaginas` são inteiros não negativos, com tamanho positivo. `correlationId` é UUID obrigatório. Página além do total retorna itens vazios, preservando os totais reais. Sem itens, totalPaginas é 0.

Exemplo de `GET /api/conhecimentos?pagina=0&tamanho=20` sem documentos visíveis:

```json
{
  "itens": [],
  "pagina": 0,
  "tamanho": 20,
  "totalElementos": 0,
  "totalPaginas": 0,
  "correlationId": "10000000-0000-4000-8000-000000000001"
}
```

Erros: 400, 401, 403, 406, 503, 504 e 500. Operações de banco limitadas a 3 segundos.

### 3.3 GET /api/conhecimentos/{id}

`id` obrigatório, UUID válido. Exige leitura administrativa e autorização sobre o documento. Responde **200 OK** com **ConhecimentoDetalheResponse**: todos os campos de ConhecimentoResumoResponse mais `texto` obrigatório, string de 1–100.000 caracteres. Não retorna embeddings, chunks internos, permissões ou credenciais.

```json
{
  "id": "20000000-0000-4000-8000-000000000001",
  "versao": 1,
  "titulo": "Documento demonstrativo — pré-requisitos",
  "texto": "Neste exemplo fictício, o programa demonstrativo exige conhecimentos básicos de programação.",
  "fonte": "fixture:programa-demonstrativo-v1",
  "categoria": "PRE_REQUISITO",
  "status": "INDEXADO",
  "quantidadeChunks": 1,
  "criadoEm": "2026-10-22T15:00:00Z",
  "vigenciaInicio": null,
  "vigenciaFim": null,
  "validadeConfirmada": true,
  "correlationId": "10000000-0000-4000-8000-000000000001"
}
```

ID inválido: 400. Inexistente, ainda não publicado ou fora da permissão documental: 404 com a mesma mensagem segura. Escopo geral de leitura ausente: 403. Demais erros: 401, 406, 503, 504 e 500.

### 3.4 POST /api/conhecimentos/diagnostico/buscar

Diagnóstico administrativo autenticado, preferencialmente em rede de operação. Não pode ser usado pela identidade da `api-atendimentos` nem ser seu fallback. Executa o mesmo caso de uso semântico e os mesmos filtros de elegibilidade da tool, preservando aprovação, autorização e vigência. Retorno não é um envelope MCP.

**BuscarConhecimentoRequest:** `pergunta` string obrigatória de 1–2.000 caracteres, não somente espaços; `limite` inteiro opcional de 1 a 10, padrão 5. Não aceitar filtros livres ou dados de identidade no corpo. Máximo de **16 KiB (16.384 bytes)** UTF-8 no corpo. Prazo total de 10 segundos.

```json
{"pergunta": "Quais são os pré-requisitos do programa demonstrativo?", "limite": 5}
```

HTTP 200 usa **BuscaConhecimentoResponse**, definido na seção 4; seu exemplo de sucesso e o de busca vazia valem integralmente para esta rota. Falhas REST usam ErroResponse, não `resultado: ERRO` de MCP. Erros: 400, 401, 403, 406, 413, 415, 503, 504 e 500.

## 4. DTOs da recuperação semântica

### 4.1 TrechoConhecimento

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| chunkId | string UUID | Sim | Identificador estável do chunk. |
| texto | string, 1–12.000 caracteres | Sim | Chunk completo; também limitado a 512 tokens de embeddings segundo RF02. Não truncar condições. |
| documentoId | string UUID | Sim | Documento original. |
| versaoDocumento | integer ≥ 1 | Sim | Versão exata da evidência. |
| titulo | string, 1–200 | Sim | Copiado dos metadados aprovados. |
| fonte | string, 1–500 | Sim | Referência original; não criada pelo modelo. |
| categoria | enum de categoria | Sim | Mesmo domínio do cadastro. |
| similaridade | number finito, -1 a 1 | Não | Similaridade de cosseno, maior é melhor; não é probabilidade. Omitir se indisponível. |
| vigenciaInicio | string date-time ou null | Sim | Início inclusivo conhecido. |
| vigenciaFim | string date-time ou null | Sim | Fim exclusivo conhecido. |
| validadeConfirmada | boolean | Sim | Copiado da política confiável de fonte. |

Contrato inicial de score: similaridade de cosseno; a arquitetura deve selecionar a distância correspondente e registrar sua conversão quando a biblioteca retornar distância. Não publicar distância bruta com o nome similaridade, nem aplicar uma conversão universal a outras métricas. Limiar é configuração interna calibrada, não parâmetro da tool. Resultado pode omitir score, mas o servidor deve continuar aplicando a política de relevância internamente.

Se um chunk não couber no limite de caracteres, a configuração de ingestão deve ser corrigida antes da publicação; não descartá-lo silenciosamente na recuperação. Resposta de busca tem limite de **1 MiB** em bytes JSON UTF-8. Estouro ou inconsistência interna é falha, não lista vazia nem truncamento silencioso.

### 4.2 BuscaConhecimentoResponse

`resultado` obrigatório, constante `SUCESSO`; `trechos` obrigatório, array de TrechoConhecimento, de 0 até `limite` efetivo (máximo 10); `correlationId` UUID obrigatório. Chunks sem duplicação de ID, ordenados por relevância decrescente; empate por documentoId/chunkId. Quando score não for exposto, preservar a ordem calculada pelo servidor. Não incluir a pergunta original, vetores ou contagem de documentos restritos.

```json
{
  "resultado": "SUCESSO",
  "trechos": [
    {
      "chunkId": "30000000-0000-4000-8000-000000000001",
      "texto": "Neste exemplo fictício, o programa demonstrativo exige conhecimentos básicos de programação.",
      "documentoId": "20000000-0000-4000-8000-000000000001",
      "versaoDocumento": 1,
      "titulo": "Documento demonstrativo — pré-requisitos",
      "fonte": "fixture:programa-demonstrativo-v1",
      "categoria": "PRE_REQUISITO",
      "similaridade": 0.91,
      "vigenciaInicio": null,
      "vigenciaFim": null,
      "validadeConfirmada": true
    }
  ],
  "correlationId": "10000000-0000-4000-8000-000000000001"
}
```

Busca concluída sem evidências elegíveis, HTTP REST 200 ou resultado MCP sem erro:

```json
{
  "resultado": "SUCESSO",
  "trechos": [],
  "correlationId": "10000000-0000-4000-8000-000000000001"
}
```

## 5. API de Conhecimento — MCP verdadeiro

### 5.1 Transporte e ciclo de vida

Endpoint único **`/mcp`**, via **Streamable HTTP**, com Spring AI 2.0.1 e SDK MCP gerenciado por seu BOM. Não criar `POST /mcp/buscar_conhecimento`, nem chamar a rota administrativa fingindo ser MCP.

Adotar revisão de protocolo **2025-06-18**, ou revisão posterior mutuamente suportada que preserve estes schemas e semântica. A arquitetura deve fixar a revisão efetivamente testada. Incompatibilidade impede uso; não fazer downgrade para stdio ou transporte HTTP/SSE legado.

Inicializar por `initialize`, receber capacidades de tools e concluir com `notifications/initialized`; só então usar `tools/list` e `tools/call`. Processar paginação da descoberta. O corpo é JSON-RPC 2.0. Exemplos abaixo mostram o corpo lógico, inclusive quando transportado em evento SSE.

Headers: Authorization e correlação da seção 1, `Content-Type: application/json`, `Accept: application/json, text/event-stream`; após negociação, `MCP-Protocol-Version` com a revisão acordada. Se o servidor emitir `Mcp-Session-Id`, reutilizá-lo e encerrá-lo pelo cliente gerenciado; sessão não substitui autenticação. Validar Origin contra allowlist quando presente e rejeitar origem não autorizada. Ausência de Origin em cliente de serviço não dispensa token.

POST envia mensagens JSON-RPC. Requisições recebem resposta JSON ou SSE; notificações aceitas recebem 202 sem corpo. GET na mesma rota admite stream SSE, ou 405 se esse modo opcional não for oferecido. DELETE pode encerrar sessão, ou retornar 405 quando não suportado. Essas respostas de controle não usam DTOs REST de negócio.

Regras de transporte seguem a [especificação Streamable HTTP](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports); negociação segue o [ciclo de vida MCP](https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle). Segurança HTTP pode produzir 401/403 antes do processamento JSON-RPC, com ErroResponse quando houver corpo gerado pela aplicação. Erros de protocolo devem manter seu envelope nativo.

### 5.2 Nome, entrada e descoberta

Nome exato: **`buscar_conhecimento`**. Operação somente leitura; não altera documentos nem gera resposta final ao aluno. Não requer aprovação humana por chamada, pois é pesquisa autorizada sem mutação; os controles de acesso são obrigatórios.

**inputSchema obrigatório**, anunciado no resultado de `tools/list`:

```json
{
  "type": "object",
  "properties": {
    "pergunta": {"type": "string", "minLength": 1, "maxLength": 2000, "pattern": "\\S", "description": "Pergunta textual sobre informações institucionais autorizadas."},
    "limite": {"type": "integer", "minimum": 1, "maximum": 10, "default": 5}
  },
  "required": ["pergunta"],
  "additionalProperties": false
}
```

O servidor deve aplicar o padrão 5 quando `limite` for omitido: `default` no schema não preenche o valor automaticamente. `null`, 0, 11, 2.5 e `"5"` são inválidos. Validar tamanho novamente após a normalização. Identidade/permissões não podem aparecer em `arguments`.

Descoberta é feita por esta requisição, não por GET REST:

```json
{"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}}
```

O resultado deve conter `tools` com uma entrada de `name: buscar_conhecimento`, descrição da pesquisa, `inputSchema` acima e `outputSchema` da seção seguinte. O MVP não anuncia outras tools; não emitir `nextCursor` quando não houver outra página.

### 5.3 outputSchema obrigatório

`structuredContent` deve obedecer ao schema abaixo. Ele admite sucesso e erro operacional para que erros da tool também tenham estrutura validável. `content`/`isError` são campos do envelope MCP, não deste objeto. Strings obrigatórias também obedecem à regra transversal de não serem somente espaços; validar formatos UUID/date-time na aplicação, não apenas por anotação de schema.

```json
{
  "type": "object",
  "properties": {
    "resultado": {"enum": ["SUCESSO", "ERRO"]},
    "trechos": {"type": "array", "maxItems": 10, "items": {"$ref": "#/$defs/Trecho"}},
    "correlationId": {"type": "string", "format": "uuid"},
    "erro": {"$ref": "#/$defs/Erro"}
  },
  "required": ["resultado", "trechos", "correlationId"],
  "additionalProperties": false,
  "oneOf": [
    {"properties": {"resultado": {"const": "SUCESSO"}}, "not": {"required": ["erro"]}},
    {"properties": {"resultado": {"const": "ERRO"}, "trechos": {"maxItems": 0}}, "required": ["erro"]}
  ],
  "$defs": {
    "Trecho": {
      "type": "object",
      "properties": {
        "chunkId": {"type": "string", "format": "uuid"},
        "texto": {"type": "string", "minLength": 1, "maxLength": 12000},
        "documentoId": {"type": "string", "format": "uuid"},
        "versaoDocumento": {"type": "integer", "minimum": 1},
        "titulo": {"type": "string", "minLength": 1, "maxLength": 200},
        "fonte": {"type": "string", "minLength": 1, "maxLength": 500},
        "categoria": {"enum": ["CURSO", "PROGRAMA", "TECNOLOGIA", "MODALIDADE", "PRE_REQUISITO", "INSTITUCIONAL"]},
        "similaridade": {"type": "number", "minimum": -1, "maximum": 1},
        "vigenciaInicio": {"type": ["string", "null"], "format": "date-time"},
        "vigenciaFim": {"type": ["string", "null"], "format": "date-time"},
        "validadeConfirmada": {"type": "boolean"}
      },
      "required": ["chunkId", "texto", "documentoId", "versaoDocumento", "titulo", "fonte", "categoria", "vigenciaInicio", "vigenciaFim", "validadeConfirmada"],
      "additionalProperties": false
    },
    "Erro": {
      "type": "object",
      "properties": {
        "codigo": {"enum": ["ENTRADA_INVALIDA", "ACESSO_NEGADO", "DEPENDENCIA_INDISPONIVEL", "TEMPO_LIMITE_EXCEDIDO", "ERRO_INTERNO"]},
        "mensagem": {"type": "string", "minLength": 1, "maxLength": 500},
        "timestamp": {"type": "string", "format": "date-time"},
        "correlationId": {"type": "string", "format": "uuid"},
        "detalhes": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {"campo": {"type": "string", "minLength": 1, "maxLength": 100}, "mensagem": {"type": "string", "minLength": 1, "maxLength": 200}},
            "required": ["campo", "mensagem"],
            "additionalProperties": false
          }
        }
      },
      "required": ["codigo", "mensagem", "timestamp", "correlationId", "detalhes"],
      "additionalProperties": false
    }
  }
}
```

Além do schema, impor `trechos.length <= limite efetivo`, unicidade de chunkId, vigência, coerência de versão/fonte e correlação idêntica no objeto e no erro. O outputSchema é declarado integralmente na descoberta; não usar referências a definições que o cliente não consiga resolver.

### 5.4 Execução e resultado MCP

Exemplo após inicialização:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "buscar_conhecimento",
    "arguments": {"pergunta": "Quais são os pré-requisitos do programa demonstrativo?", "limite": 5}
  }
}
```

O `result.structuredContent` de sucesso é exatamente BuscaConhecimentoResponse, inclusive os trechos do exemplo da seção 4.2. Usar `isError: false`. Por compatibilidade, `content` contém um bloco `text` com a serialização JSON do mesmo objeto; o consumidor utiliza e valida structuredContent, sem tratar texto livre como evidência substituta. Se ambos existirem e divergirem, rejeitar a resposta.

Exemplo completo de execução válida sem correspondências:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "isError": false,
    "structuredContent": {
      "resultado": "SUCESSO",
      "trechos": [],
      "correlationId": "10000000-0000-4000-8000-000000000001"
    },
    "content": [{"type": "text", "text": "{\"resultado\":\"SUCESSO\",\"trechos\":[],\"correlationId\":\"10000000-0000-4000-8000-000000000001\"}"}]
  }
}
```

### 5.5 Erros MCP e mapeamento

Não substituir os envelopes JSON-RPC por ErroResponse. O formato padronizado ErroDetalhe é reutilizado em `error.data.erro` nos erros de protocolo gerados pela aplicação, ou em `structuredContent.erro` nos erros operacionais da tool. Erros internos do SDK devem preservar códigos nativos e ser sanitizados; nunca depender da mensagem textual para classificá-los.

| Camada | Representação | Interpretação no atendimento |
|---|---|---|
| Segurança HTTP | 401/403 antes de JSON-RPC | Credencial de serviço/delegação inválida: 503 ao aluno; não reutilizar o status como autenticação inválida do aluno. |
| JSON-RPC | -32700 parse, -32600 requisição inválida, -32601 método ausente, -32602 parâmetros/tool desconhecida | 502 RESPOSTA_DEPENDENCIA_INVALIDA quando originado pela integração interna. |
| Execução da tool | result.isError=true e structuredContent.resultado=ERRO | Mapear codigo sem usar o campo HTTP como único indicador. |
| Rede/servidor indisponível | Sem resposta, conexão recusada ou HTTP 5xx | 503; se expirou o prazo, 504. |
| Payload/schema inconsistente | HTTP 200 ou evento SSE com resultado incompatível | 502, nunca lista vazia. |
| Sucesso vazio | isError=false, resultado=SUCESSO e trechos=[] | 200 CONHECIMENTO_INSUFICIENTE, sem chamar chat. |

Argumentos de execução inválidos são reportados com `isError: true` e codigo `ENTRADA_INVALIDA`; envelope `tools/call` inválido é -32602. Método desconhecido é -32601; nome de tool desconhecido em `tools/call` é -32602. `id` deve corresponder ao pedido e pode ser `null` em erro de parsing sem ID identificável. Não enviar simultaneamente `result` e `error`.

Exemplo de erro de protocolo, HTTP normalmente 200 quando a requisição JSON-RPC foi aceita para processamento:

```json
{
  "jsonrpc": "2.0",
  "id": 4,
  "error": {
    "code": -32602,
    "message": "Ferramenta desconhecida.",
    "data": {
      "erro": {
        "codigo": "ENTRADA_INVALIDA",
        "mensagem": "Ferramenta desconhecida.",
        "timestamp": "2026-10-22T15:00:00Z",
        "correlationId": "10000000-0000-4000-8000-000000000001",
        "detalhes": []
      }
    }
  }
}
```

Exemplo de falha operacional da tool, HTTP 200 não significa sucesso da pesquisa:

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "isError": true,
    "structuredContent": {
      "resultado": "ERRO",
      "trechos": [],
      "correlationId": "10000000-0000-4000-8000-000000000001",
      "erro": {
        "codigo": "DEPENDENCIA_INDISPONIVEL",
        "mensagem": "Não foi possível concluir a pesquisa neste momento.",
        "timestamp": "2026-10-22T15:00:00Z",
        "correlationId": "10000000-0000-4000-8000-000000000001",
        "detalhes": []
      }
    },
    "content": [{"type": "text", "text": "{\"resultado\":\"ERRO\",\"trechos\":[],\"correlationId\":\"10000000-0000-4000-8000-000000000001\",\"erro\":{\"codigo\":\"DEPENDENCIA_INDISPONIVEL\",\"mensagem\":\"Não foi possível concluir a pesquisa neste momento.\",\"timestamp\":\"2026-10-22T15:00:00Z\",\"correlationId\":\"10000000-0000-4000-8000-000000000001\",\"detalhes\":[]}}"}]
  }
}
```

Na tool, `TEMPO_LIMITE_EXCEDIDO` resulta em HTTP REST 504 no atendimento; `DEPENDENCIA_INDISPONIVEL`/`ERRO_INTERNO` do servidor remoto resultam em 503; `ENTRADA_INVALIDA`/`ACESSO_NEGADO` inesperados na execução interna resultam em 502, sem divulgar detalhes documentais. Validação do próprio aluno ocorre antes do MCP e retorna 400/401/403 localmente. Erros de tool com structuredContent continuam sujeitos ao outputSchema e não podem conter evidências parciais.

Referência para `tools/list`, `tools/call`, `outputSchema`, `structuredContent` e distinção dos erros: [especificação MCP de tools](https://modelcontextprotocol.io/specification/2025-06-18/server/tools).

## 6. API de Atendimentos — REST

### 6.1 POST /api/atendimentos/perguntar

**PerguntarRequest:** somente `pergunta`, string obrigatória de 1–2.000 caracteres, após normalização/trim e não somente espaços. Limite de corpo **16 KiB**, sem compressão. Não aceitar contexto, fontes, prompt, modelo, identidade ou filtros no payload. Prazo total de 30 segundos.

```json
{"pergunta": "Quais são os pré-requisitos do programa demonstrativo?"}
```

**AtendimentoResponse, HTTP 200:**

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| atendimentoId | string UUID | Sim | Identificador da requisição, sem exigir histórico persistente. |
| correlationId | string UUID | Sim | Correlação propagada ao MCP. |
| status | string enum | Sim | `RESPONDIDO`, `PARCIALMENTE_RESPONDIDO`, `CONHECIMENTO_INSUFICIENTE`. |
| resposta | string, 1–4.000 caracteres | Sim | Texto seguro em português; não conter citações/URLs inventadas. |
| fontes | array de FonteUtilizada, máximo 10 | Sim | Somente fontes efetivamente utilizadas; vazio na insuficiência total. |
| limitacoes | array de string, máximo 10 | Sim | Cada item 1–500 caracteres; vazio apenas quando não há limitação. |

**FonteUtilizada:** `documentoId` UUID, `versaoDocumento` inteiro ≥1, `titulo`, `fonte`, `categoria`, `vigenciaInicio`, `vigenciaFim`, `validadeConfirmada` conforme TrechoConhecimento, todos obrigatórios. Acrescentar `trechos`, array obrigatório de 1–10 objetos com `chunkId` UUID obrigatório e `similaridade` opcional (-1 a 1). Agrupar por documentoId/versaoDocumento; não repetir descrição do documento para cada chunk. Não devolver o texto integral nem embeddings neste DTO. Todos os metadados são copiados da recuperação, não gerados pelo LLM.

```json
{
  "atendimentoId": "40000000-0000-4000-8000-000000000001",
  "correlationId": "10000000-0000-4000-8000-000000000001",
  "status": "RESPONDIDO",
  "resposta": "No exemplo demonstrativo, são necessários conhecimentos básicos de programação.",
  "fontes": [
    {
      "documentoId": "20000000-0000-4000-8000-000000000001",
      "versaoDocumento": 1,
      "titulo": "Documento demonstrativo — pré-requisitos",
      "fonte": "fixture:programa-demonstrativo-v1",
      "categoria": "PRE_REQUISITO",
      "vigenciaInicio": null,
      "vigenciaFim": null,
      "validadeConfirmada": true,
      "trechos": [{"chunkId": "30000000-0000-4000-8000-000000000001", "similaridade": 0.91}]
    }
  ],
  "limitacoes": []
}
```

Invariantes: RESPONDIDO exige fontes não vazias e limitacoes vazias; PARCIALMENTE_RESPONDIDO exige fontes e limitacoes não vazias; CONHECIMENTO_INSUFICIENTE exige fontes vazias e limitacoes não vazias. Parcial só quando partes independentes da pergunta tiverem suporte; não usar o estado para entregar suposições. Texto de limitação deve distinguir conflito, falta de informação ou impossibilidade de manter contexto suficiente, sem expor conteúdo restrito.

Exemplo de busca vazia, sem chamada ao modelo de chat:

```json
{
  "atendimentoId": "40000000-0000-4000-8000-000000000001",
  "correlationId": "10000000-0000-4000-8000-000000000001",
  "status": "CONHECIMENTO_INSUFICIENTE",
  "resposta": "Não encontrei informações autorizadas suficientes para responder à sua pergunta.",
  "fontes": [],
  "limitacoes": ["A pesquisa não retornou evidências elegíveis."]
}
```

Erros: 400, 401, 403, 406, 413, 415, 502, 503, 504 e 500, sempre ErroResponse. Falhas técnicas não retornam AtendimentoResponse com status de insuficiência. A recusa ou saída inválida do modelo não produz fontes/resposta parcialmente elaboradas no erro.

Exemplo de HTTP 504, aplicável também à expiração do prazo total:

```json
{
  "erro": {
    "codigo": "TEMPO_LIMITE_EXCEDIDO",
    "mensagem": "Não foi possível concluir o atendimento dentro do tempo limite.",
    "timestamp": "2026-10-22T15:00:30Z",
    "correlationId": "10000000-0000-4000-8000-000000000001",
    "atendimentoId": "40000000-0000-4000-8000-000000000001",
    "detalhes": []
  }
}
```

### 6.2 GET /actuator/health

Sem corpo nem query. Endpoint mínimo de saúde da `api-atendimentos`, sem detalhes de componentes, variáveis, banco, tokens, modelos ou URLs internas. Não deve executar pesquisa nem chamada paga à OpenAI por probe. Não configura indicador de PostgreSQL na API de Atendimentos.

**HealthResponse, HTTP 200**, campo obrigatório `status`, constante `UP`:

```json
{"status": "UP"}
```

Se a aplicação estiver de pé mas não saudável/pronta, retornar **503**, ErroResponse com codigo `SERVICO_INDISPONIVEL` e mensagem segura. Este contrato exige padronizar a resposta negativa do Actuator na futura implementação; não assumir que seu corpo padrão já é ErroResponse. Serviço parado pode não responder, condição distinta de JSON 503. Demais erros de aplicação usam a seção 2.

## 7. Transformação de resultados MCP em contexto RAG

1. Validar a entrada REST e chamar `buscar_conhecimento` com pergunta e limite padrão 5. Garantir pesquisa explícita antes da resposta factual; não deixar a decisão obrigatória exclusivamente ao modelo. Não usar o diagnóstico REST, os GETs administrativos ou PostgreSQL/pgvector como atalho.
2. Conferir envelope MCP, isError, schema, limites, IDs, versões, metadados e correlação. Resposta incompatível resulta em 502; não converter falha em ausência de conhecimento. Remover duplicação de chunks por ID e rejeitar conflito de metadados para o mesmo documento/versão.
3. O servidor de conhecimento já aplica aprovação, autorização e vigência; atendimento verifica coerência dos metadados recebidos e não amplia permissões. Para dados comerciais/temporais, exigir validade confirmada e evidência aplicável ao período/unidade/modalidade perguntados. Similaridade não basta para confirmar fatos. Se a evidência for vazia ou manifestamente insuficiente, responder deterministicamente sem chamar chat.
4. Construir um bloco de evidências delimitado como **dados não confiáveis**, preservando ordem de relevância e chunks inteiros. Serializar objetos com chunkId, documentoId, versão, título, fonte, categoria, vigência e texto por serializador seguro; não interpolar documentos como templates ou instruções do sistema. Metadados também são dados, não comandos.
5. Limitar o bloco completo de evidências a **12.000 pontos de código Unicode**, incluindo metadados, delimitadores e escape JSON do bloco efetivamente enviado ao modelo. Limitar também a **4.000 tokens do modelo de chat**. Aplicar o menor orçamento disponível. A contagem em caracteres não substitui a tokenização do modelo.
6. Reservar até **1.500 tokens de saída**, além das instruções fixas e da pergunta completa; contar o prompt final com sua sobrecarga de mensagens e assegurar que entrada + reserva de saída cabe na janela do modelo configurado. Modelos/configurações incapazes de cumprir os limites devem ser rejeitados na inicialização. Não truncar a pergunta ou aumentar silenciosamente o limite.
7. Selecionar chunks completos por ordem determinística até o orçamento, sem cortar uma condição comercial no meio. Não adicionar chunk que não caiba; outros só podem ser usados se preservarem suporte suficiente. Se o corte retirar informação essencial ou deixar conflito sem resolução, retornar insuficiência ou parcial com limitação explícita. Se nenhum chunk couber, não chamar chat. Excesso de resposta MCP sobre o limite de transporte é 502; excesso de evidências válidas sobre o orçamento RAG é seleção com reavaliação de suficiência, não falha de rede.
8. Enviar política fixa de fundamentação/abstenção, pergunta em mensagem de usuário e evidências como dados separados. Proibir obediência a instruções documentais, divulgação de segredos e execução de ferramentas fora da allowlist. Não transmitir credenciais ou permissões internas ao LLM.
9. Solicitar resposta estruturada interna com `resposta`, `chunkIdsUtilizados` (UUIDs), `limitacoes` e status entre os três valores públicos. Esses campos internos não são um novo endpoint. O modelo não fornece título, URL, fonte, categoria ou versão da resposta pública. Validar estrutura, limites e suporte identificável de cada afirmação; uma declaração do próprio modelo ou referência existente não prova veracidade.
10. Aceitar apenas chunkIds pertencentes aos trechos efetivamente incluídos no contexto desta requisição. Gerar FonteUtilizada pela aplicação, agrupando os registros originais recuperados. Não listar automaticamente todos os resultados como utilizados nem aceitar citação a trecho excluído do contexto. Referência inválida ou violação detectada de fundamentação resulta em 502 RESPOSTA_MODELO_INVALIDA, sem repassar a saída inválida.
11. Validar as invariantes de status/fontes/limitações. Sem suporte suficiente, não inventar valores, datas, horários, vagas ou condições, nem afirmar inexistência de curso. Canal humano só pode aparecer se seu contato estiver sustentado nas evidências autorizadas. Não salvar memória ou histórico de perguntas por padrão.

## 8. Prazos, falhas e consistência

| Operação | Limite máximo |
|---|---|
| Cadastro/indexação síncrona | 60 s totais |
| Atendimento | 30 s totais |
| Pesquisa MCP ou diagnóstico REST | 10 s totais |
| OpenAI chat | 15 s por chamada |
| OpenAI embeddings | 5 s por chamada |
| Banco, incluindo espera por conexão | 3 s por operação |

Toda etapa usa o menor entre o seu limite e o orçamento restante da operação superior, reservando margem para responder. Sem orçamento, não iniciar etapa seguinte. Nenhuma repetição automática no MVP, incluindo SDK, reconexão com reexecução e validação de saída estruturada. Inicialização/descoberta no caminho do atendimento também consome seu prazo; preferir ciclo de vida gerenciado sem criar conexão para cada pergunta.

Timeout retorna 504 REST ou erro de tool classificado, sem resposta factual parcial. Cancelar trabalho pendente quando suportado; proteger publicação com estado de operação para impedir sucesso tardio após timeout de indexação. Desconexão deixa o resultado desconhecido para o cliente: ao reenviar cadastro, deduplicar; não publicar uma segunda cópia. O sistema não promete execução exactly-once na rede.

MCP indisponível, falha de embeddings/banco, recusa de geração, erro de formato e conhecimento insuficiente permanecem categorias distintas. A API de Atendimentos nunca tenta acessar a base vetorial e nunca consulta conhecimento em endpoint REST, inclusive durante incidentes.

## 9. Validação contratual exigida antes da implementação ser aceita

- OpenAPI deve refletir rotas REST, DTOs, segurança, exemplos, limites e todos os códigos aplicáveis; não documentar a tool como se fosse uma rota REST de pesquisa.
- Descoberta MCP deve anunciar schemas resolvíveis; testes reais de Streamable HTTP verificam inicialização, listagem, execução, structuredContent, erro JSON-RPC, isError, busca vazia, autorização e timeout.
- Testes REST devem verificar paginação/autorização, deduplicação de cadastro, consulta 404 sem vazamento, padrão de erros e health sem detalhes. Diagnóstico deve negar acesso à identidade de atendimento.
- Testes de RAG devem conferir limites em caracteres e tokens, chunks excluídos, citações desconhecidas, agrupamento de fontes, perda de condições por redução de contexto, prompt injection e ausência de fatos comerciais inventados.
- Modelos/tokenizadores, versão exata do Boot e SDK, mecanismo de delegação de identidade, aprovação das fontes e limiar de relevância devem ser detalhados em `specs/03-architecture.md` antes da implementação dependente. O contrato não constitui evidência de execução desses testes.
