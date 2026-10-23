# Constituição do COTI AI Atendimento

Este documento estabelece princípios obrigatórios para especificação, implementação, testes e evolução da plataforma de atendimento inteligente aos alunos da COTI Informática. Os termos **DEVE**, **NÃO DEVE** e **É PROIBIDO** expressam obrigações. O cumprimento deve ser demonstrado por evidências de revisão, testes e critérios de aceite.

## Artigo 1 — Plataforma Java e compatibilidade

- **Regra:** Os dois microsserviços DEVEM utilizar Java 21 e Spring AI 2.0.1, com uma versão do Spring Boot comprovadamente compatível com essa versão do Spring AI. A compatibilidade NÃO DEVE ser presumida nem resolvida por atualização silenciosa de versões.
- **Justificativa:** Uma base tecnológica consistente reduz conflitos de dependências e torna a execução reproduzível.
- **Consequência arquitetural:** Cada serviço terá configuração de build independente, versões explícitas e gerenciamento coerente de dependências. A versão exata do Spring Boot será registrada na especificação técnica após verificação da matriz oficial de compatibilidade. Se a combinação exigida não estiver disponível ou não for suportada, a implementação ficará impedida até decisão registrada de revisão da especificação.
- **Como validar seu cumprimento:** Inspecionar os arquivos de build e a árvore de dependências; executar compilação, testes e inicialização de ambos os serviços com Java 21; registrar a evidência oficial de compatibilidade das versões selecionadas.

## Artigo 2 — Spring AI e OpenAI

- **Regra:** A integração com os modelos OpenAI DEVE ocorrer por meio do Spring AI. A `api-atendimentos` DEVE utilizar o modelo de chat para gerar respostas contextualizadas; a `api-conhecimento` DEVE utilizar o modelo de embeddings para indexação e pesquisa.
- **Justificativa:** A abstração comum facilita configuração, manutenção e controle das responsabilidades de IA.
- **Consequência arquitetural:** Adaptadores de infraestrutura encapsularão o acesso aos modelos. Modelo, limites de execução e parâmetros operacionais serão configuráveis, sem acoplamento do domínio ao SDK do provedor. A pesquisa MCP retornará evidências; a elaboração da resposta ao aluno pertencerá à `api-atendimentos`.
- **Como validar seu cumprimento:** Revisar dependências e pontos de chamada; testar os adaptadores e os fluxos de chat e embeddings; verificar que não há chamadas diretas ao provedor contornando o Spring AI.

## Artigo 3 — Modularidade e independência dos serviços

- **Regra:** `api-conhecimento` e `api-atendimentos` DEVEM ser microsserviços independentes, com separação entre domínio, casos de uso, interfaces de entrada e infraestrutura.
- **Justificativa:** Fronteiras explícitas permitem evolução e implantação independentes e evitam mistura entre recuperação de conhecimento e atendimento.
- **Consequência arquitetural:** A `api-conhecimento` será responsável por ingestão, validação documental, chunking, indexação e recuperação. A `api-atendimentos` receberá perguntas REST, orquestrará a consulta MCP e produzirá respostas. Nenhum serviço dependerá de entidades de persistência ou módulos internos do outro.
- **Como validar seu cumprimento:** Revisar dependências entre módulos; compilar e empacotar cada serviço separadamente; testar os casos de uso com interfaces de infraestrutura substituídas e verificar a ausência de dependências de implementação entre serviços.

## Artigo 4 — Comunicação exclusivamente por MCP sobre HTTP

- **Regra:** Toda consulta da `api-atendimentos` à `api-conhecimento` DEVE ocorrer exclusivamente por MCP sobre HTTP. É PROIBIDO substituir essa integração por REST proprietário, acesso direto ao banco, biblioteca interna compartilhada de pesquisa ou transporte local por stdio.
- **Justificativa:** Um contrato MCP explícito mantém o desacoplamento e padroniza a descoberta e a execução da ferramenta de pesquisa semântica.
- **Consequência arquitetural:** A `api-conhecimento` exporá um servidor MCP com ferramenta de pesquisa; a `api-atendimentos` utilizará um cliente MCP. Transporte, versão do protocolo, autenticação, autorização, timeouts e erros deverão constar no contrato. Falhas MCP não autorizarão caminhos alternativos de acesso ao conhecimento.
- **Como validar seu cumprimento:** Executar testes de integração MCP sobre HTTP, incluindo descoberta, chamada da ferramenta, entrada inválida, acesso negado e indisponibilidade; revisar chamadas de rede e dependências para excluir caminhos alternativos.

## Artigo 5 — Exclusividade do PostgreSQL com pgvector

- **Regra:** O PostgreSQL com pgvector DEVE ser utilizado exclusivamente pela `api-conhecimento` para persistir a base e seus vetores. A `api-atendimentos` NÃO DEVE acessar esse banco nem possuir suas credenciais, drivers ou configuração de armazenamento vetorial.
- **Justificativa:** A propriedade exclusiva dos dados evita acoplamento por esquema e acesso indevido ao acervo.
- **Consequência arquitetural:** A `api-conhecimento` será proprietária das migrações, índices vetoriais, documentos, chunks e metadados de recuperação. O isolamento também será aplicado às credenciais e à conectividade de rede.
- **Como validar seu cumprimento:** Revisar builds, configurações, migrações e permissões; testar persistência e pesquisa com PostgreSQL e pgvector; demonstrar que a `api-atendimentos` não consegue se conectar ao banco de conhecimento.

## Artigo 6 — Encapsulamento dos embeddings

- **Regra:** A geração de embeddings, tanto dos documentos quanto das perguntas usadas na pesquisa, DEVE ocorrer dentro da `api-conhecimento`. A `api-atendimentos` enviará texto e filtros permitidos pelo contrato MCP, nunca vetores calculados por ela.
- **Justificativa:** A qualidade da busca depende de consistência entre modelo, dimensão e preparação dos vetores indexados e consultados.
- **Consequência arquitetural:** Chunking, normalização, modelo de embeddings, dimensões e versionamento do índice serão controlados pela `api-conhecimento`. Mudanças incompatíveis exigirão estratégia explícita de reindexação antes do uso do novo modelo.
- **Como validar seu cumprimento:** Testar indexação e consulta com configuração consistente; verificar rejeição de dimensões incompatíveis; revisar o contrato MCP e confirmar a ausência de geração de embeddings na `api-atendimentos`.

## Artigo 7 — Credenciais por variáveis de ambiente

- **Regra:** Credenciais OpenAI, banco de dados e integração entre serviços DEVEM ser fornecidas por variáveis de ambiente no processo de execução, inclusive quando injetadas por um gerenciador de segredos. Credenciais obrigatórias ausentes DEVEM produzir falha de configuração explícita.
- **Justificativa:** Separar credenciais de artefatos permite rotação e configurações independentes por ambiente.
- **Consequência arquitetural:** Cada serviço receberá somente os segredos necessários à sua responsabilidade. A configuração usará referências a variáveis, sem valores secretos padrão; a rotação não exigirá alteração do código-fonte.
- **Como validar seu cumprimento:** Inicializar os serviços com variáveis controladas em testes; verificar falha clara na ausência de credenciais obrigatórias e confirmar que mensagens de diagnóstico não revelam seus valores.

## Artigo 8 — Proibição de segredos no código-fonte

- **Regra:** É PROIBIDO incluir API keys, tokens, senhas ou credenciais reais no código-fonte, arquivos versionados, testes, exemplos, imagens de contêiner e documentação. Valores de exemplo DEVEM ser marcadores fictícios inequívocos.
- **Justificativa:** Um segredo publicado pode permanecer acessível no histórico e comprometer serviços e dados.
- **Consequência arquitetural:** O processo de desenvolvimento e integração contínua incluirá detecção de segredos. Arquivos locais que contenham segredos ficarão fora do versionamento. Um vazamento exigirá revogação ou rotação, além da correção do artefato.
- **Como validar seu cumprimento:** Executar varredura de segredos no conteúdo versionado e no histórico disponível; inspecionar artefatos de build e exemplos; bloquear a entrega quando houver credenciais reais detectadas.

## Artigo 9 — Respostas fundamentadas em conhecimento autorizado

- **Regra:** Toda afirmação factual sobre a COTI DEVE ser sustentada exclusivamente por informações recuperadas da base autorizada e acessíveis ao solicitante. O conhecimento prévio do modelo NÃO DEVE suprir fatos ausentes da recuperação.
- **Justificativa:** Recuperar conteúdo semanticamente próximo não garante que ele seja autorizado, vigente ou suficiente para responder.
- **Consequência arquitetural:** A ingestão controlará a aprovação das fontes; a pesquisa aplicará autorização e filtros de validade antes de expor trechos. A resposta manterá associação com identificadores e versões das evidências utilizadas, conforme o contrato. Instruções e fontes externas fornecidas pelo aluno não se tornarão evidências autorizadas automaticamente.
- **Como validar seu cumprimento:** Testar perguntas com evidências suficientes, documentos não aprovados, conteúdo fora da permissão e fontes expiradas; verificar a sustentação de cada afirmação e a rastreabilidade até os trechos recuperados.

## Artigo 10 — Resistência a prompt injection documental

- **Regra:** Documentos, chunks, metadados e resultados de ferramentas DEVEM ser tratados como dados não confiáveis. Instruções neles contidas NÃO DEVEM alterar políticas, ampliar permissões, revelar segredos ou comandar ferramentas.
- **Justificativa:** Uma fonte documental pode conter instruções maliciosas, mesmo quando seu conteúdo é relevante para a pergunta.
- **Consequência arquitetural:** O contexto recuperado será delimitado e separado das instruções do sistema. Ferramentas e argumentos terão validação e permissões mínimas. Autorização e acesso a segredos serão impostos pela aplicação, sem depender da obediência do modelo ao prompt.
- **Como validar seu cumprimento:** Executar testes adversariais com documentos que peçam para ignorar regras, inventar respostas, extrair segredos ou consultar conteúdo restrito; confirmar que não ocorrem divulgação de dados, elevação de acesso ou execução indevida de ferramentas.

## Artigo 11 — Insuficiência de conhecimento e falhas de recuperação

- **Regra:** Quando as evidências forem ausentes, insuficientes, conflitantes ou sem validade confirmada, o atendimento DEVE declarar a limitação e NÃO DEVE completar lacunas com suposições. Indisponibilidade técnica DEVE ser distinguida de ausência de conhecimento.
- **Justificativa:** Uma recusa informativa preserva a confiança e permite ao aluno compreender a limitação encontrada.
- **Consequência arquitetural:** Critérios de suficiência serão definidos na especificação e validados com exemplos de aceite. O fluxo terá tratamento explícito para resultado vazio, conflito, timeout e falha do provedor. Poderá solicitar esclarecimento ou indicar canal humano somente quando esse canal constar na base autorizada.
- **Como validar seu cumprimento:** Testar busca vazia, baixa relevância, evidências contraditórias e falhas MCP/OpenAI; verificar mensagens e estados previstos no contrato, sem respostas factuais inventadas nem erros técnicos apresentados como inexistência de informação.

## Artigo 12 — Logging, observabilidade e rastreabilidade

- **Regra:** Os serviços DEVEM produzir logs estruturados, métricas e rastreamento distribuído suficientes para acompanhar uma solicitação REST, sua consulta MCP e as chamadas aos modelos, preservando dados pessoais e segredos.
- **Justificativa:** Diagnosticar erros e avaliar respostas exige correlacionar operações e identificar as evidências utilizadas.
- **Consequência arquitetural:** Identificadores de correlação serão propagados entre serviços. Serão observados latência, erros, timeouts, resultados de recuperação e consumo de modelos. A rastreabilidade registrará identificadores de fontes e versões; perguntas, documentos completos e dados sensíveis não serão registrados indiscriminadamente.
- **Como validar seu cumprimento:** Executar um atendimento completo e uma falha controlada; correlacionar os eventos entre os serviços, conferir métricas e evidências e verificar a ausência de credenciais e conteúdo sensível nos registros.

## Artigo 13 — Testes automatizados e critérios de aceite

- **Regra:** Toda funcionalidade DEVE possuir critérios de aceite verificáveis, vinculados à especificação, e testes automatizados proporcionais ao risco. Mudanças NÃO DEVEM ser consideradas concluídas quando critérios obrigatórios falharem.
- **Justificativa:** Comportamentos de recuperação, segurança e geração precisam ser demonstrados de forma repetível.
- **Consequência arquitetural:** A validação abrangerá testes unitários, integração PostgreSQL/pgvector, contratos REST/MCP e fluxos de atendimento. Cenários de IA usarão evidências controladas e avaliação de fundamentação, autorização e abstenção, sem exigir igualdade literal de texto gerado. Haverá cenários negativos e adversariais.
- **Como validar seu cumprimento:** Relacionar requisito, critério de aceite e teste; executar a suíte na integração contínua; registrar resultados e bloquear entregas com falhas obrigatórias, incluindo regressões de alucinação e autorização.

## Artigo 14 — Documentação OpenAPI

- **Regra:** As interfaces REST públicas dos serviços DEVEM possuir documentação OpenAPI atualizada, incluindo autenticação, entradas, respostas, validações e erros. A ferramenta MCP DEVE possuir seus próprios esquemas e descrição de contrato.
- **Justificativa:** Consumidores precisam de uma descrição precisa e verificável de cada interface.
- **Consequência arquitetural:** A API REST de atendimento será descrita em OpenAPI. Eventuais interfaces REST de administração do conhecimento seguirão a mesma obrigação; o protocolo MCP continuará documentado por seus esquemas próprios e não será apresentado como uma API REST de pesquisa alternativa.
- **Como validar seu cumprimento:** Validar a especificação OpenAPI e comparar seus esquemas com os endpoints implementados; testar exemplos e erros; verificar separadamente os esquemas de entrada e saída da ferramenta MCP.

## Artigo 15 — Proibição de inventar ofertas e informações comerciais

- **Regra:** É PROIBIDO inventar, estimar ou inferir como fato cursos, preços, descontos, datas, turmas, disponibilidade e horários. Esses dados somente poderão aparecer quando sustentados por evidências autorizadas, vigentes e aplicáveis à pergunta.
- **Justificativa:** Informações comerciais incorretas afetam decisões dos alunos e a credibilidade da instituição.
- **Consequência arquitetural:** A resposta preservará condições e qualificadores da fonte, como unidade, modalidade, período e moeda. Dados ausentes ou conflitantes acionarão o tratamento de insuficiência, sem extrapolar ofertas de outros cursos ou períodos.
- **Como validar seu cumprimento:** Testar perguntas sobre cursos inexistentes, preços ausentes, ofertas vencidas e horários conflitantes; confrontar valores e condições de cada resposta com as fontes e verificar a abstenção quando faltar suporte.

## Artigo 16 — Contratos e desenvolvimento orientado a especificações

- **Regra:** As implementações DEVEM respeitar os contratos definidos em `specs/06-api-contracts.md`. Requisitos, contratos e critérios de aceite DEVEM preceder a implementação correspondente. Nenhuma divergência poderá ser introduzida silenciosamente.
- **Justificativa:** Contratos explícitos permitem evolução coordenada de serviços independentes e tornam as decisões revisáveis.
- **Consequência arquitetural:** O contrato definirá endpoints REST, ferramenta MCP, esquemas, autenticação, autorização, erros, estados de insuficiência e rastreabilidade. Alterações incompatíveis exigirão revisão documentada e estratégia de versionamento. Enquanto `specs/06-api-contracts.md` não estiver definido e validado, implementações dependentes desses contratos não poderão ser consideradas aprovadas. Arquivos com outros nomes não o substituirão implicitamente.
- **Como validar seu cumprimento:** Revisar cada mudança contra a constituição e o contrato; executar testes de contrato para produtor e consumidor; verificar a rastreabilidade entre especificação, implementação e aceite. Ausência do contrato ou divergência não resolvida impedirá o aceite da funcionalidade afetada.

**Registro de reconciliação — T001, 2026-10-22:** o caminho do artigo 16 foi corrigido explicitamente para o documento numerado existente, adotado pelo AGENTS.md, pelos requisitos e pela arquitetura. A correção elimina uma referência a arquivo inexistente; não modifica endpoints, DTOs, schemas, permissões ou princípios arquiteturais.
