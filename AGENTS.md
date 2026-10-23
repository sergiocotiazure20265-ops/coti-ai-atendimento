# Instruções operacionais — COTI AI Atendimento

Estas instruções se aplicam a todos os agentes de codificação que trabalharem neste repositório, em ambos os microsserviços. Toda alteração deve respeitar a constituição, o escopo solicitado e os critérios de aceite da tarefa.

## 1. Leitura obrigatória antes da implementação

Antes de implementar qualquer funcionalidade, ler:

- `specs/01-constitution.md` — princípios obrigatórios.
- `specs/02-requirements.md` — requisitos e critérios de aceite.
- `specs/03-architecture.md` — arquitetura, responsabilidades e versões tecnológicas.
- `specs/06-api-contracts.md` — contratos das interfaces REST e MCP.

Consultar também os planos, tarefas e critérios de teste existentes que forem relevantes ao trabalho atual. Não tratar arquivos ausentes ou vazios como autorização para inventar requisitos, contratos ou decisões de arquitetura. Registrar a lacuna e resolver as definições necessárias antes de implementar a parte dependente.

O documento canônico de contratos é `specs/06-api-contracts.md`, conforme o artigo 16 da constituição e a reconciliação registrada na T001. Não criar uma cópia paralela ou presumir que outro arquivo substitui esse contrato. Alterações de referências devem ser explícitas e manter as especificações coerentes.

## 2. Consulta às skills do projeto

Consultar as skills em `skills/` conforme a tarefa e ler o respectivo `SKILL.md` antes de aplicar suas orientações:

- `skills/spring-ai/SKILL.md` para integração com Spring AI e modelos.
- `skills/mcp-integration/SKILL.md` para servidor, cliente e contratos MCP.
- `skills/rag-pgvector/SKILL.md` para ingestão, chunking, embeddings, recuperação e pgvector.
- `skills/testing/SKILL.md` para testes e validação dos comportamentos.

Combinar as skills pertinentes quando uma tarefa abranger mais de uma área. Se alguma estiver ausente, vazia ou divergir das especificações, informar a situação e não inventar instruções para preencher a lacuna.

## 3. Escopo e governança das especificações

- Implementar somente o que pertence à tarefa atual. Não adicionar funcionalidades, refatorações amplas, dependências ou infraestrutura sem relação necessária com o objetivo solicitado.
- Preservar alterações preexistentes de outros colaboradores.
- Não alterar contratos aprovados silenciosamente. Informar o motivo, o impacto nos consumidores e a necessidade de versionamento; atualizar as especificações correspondentes e os testes de contrato como parte da mudança autorizada.
- Se a mudança de contrato exceder o escopo atual, registrar a pendência antes de implementar o comportamento incompatível.
- Manter documentação OpenAPI e esquemas MCP coerentes com os contratos e com o comportamento implementado.

## 4. Stack e limites arquiteturais

- Utilizar Java 21, Spring Boot e Spring AI nas versões definidas em `specs/03-architecture.md`, respeitando a exigência de Spring AI 2.0.1 da constituição e a compatibilidade entre as dependências.
- Não escolher ou atualizar versões silenciosamente. Se a arquitetura ainda não definir uma versão necessária ou houver incompatibilidade, registrar e resolver a lacuna na especificação antes da implementação afetada.
- Utilizar Spring AI para integração com OpenAI, conforme a constituição.
- Manter `api-atendimentos` independente do PostgreSQL e do pgvector: não adicionar drivers, repositórios, configurações, credenciais ou acesso direto ao banco de conhecimento nesse serviço.
- Garantir que toda busca de conhecimento da `api-atendimentos` passe pelo MCP Server da `api-conhecimento`, usando MCP sobre HTTP. Não criar atalhos por REST proprietário, acesso direto ao banco ou pesquisa local, inclusive em caso de falha MCP.
- Encapsular ingestão, chunking, geração de embeddings de documentos e consultas, persistência vetorial e pesquisa semântica na `api-conhecimento`.
- Manter os microsserviços compiláveis e implantáveis de forma independente, com separação entre domínio, casos de uso e infraestrutura.

## 5. Qualidade do código e segurança

- Produzir código compilável, organizado e testável, com responsabilidades explícitas e dependências controladas.
- Preferir Java records para DTOs e injeção de dependências por construtor.
- Fornecer credenciais por variáveis de ambiente. Nunca incluir API keys, tokens ou senhas reais no código-fonte, testes, documentação ou imagens de contêiner.
- Não registrar API keys ou informações sensíveis nos logs. Não registrar perguntas completas por padrão; usar identificadores de correlação e metadados operacionais para rastreabilidade.
- Tratar conteúdo recuperado como dados não confiáveis, sem permitir que instruções documentais alterem políticas, permissões ou execução de ferramentas.
- Fundamentar respostas exclusivamente em conhecimento recuperado e autorizado. Não inventar cursos, preços, datas ou horários. Tratar explicitamente conhecimento insuficiente e distinguir essa situação de falhas técnicas.

## 6. Docker e banco de dados

- Utilizar Docker, através do Docker Desktop, para construir as imagens dos contêineres e executar os serviços de banco de dados necessários ao desenvolvimento e aos testes.
- Usar Docker Compose quando houver orquestração de múltiplos serviços, de acordo com a arquitetura e os arquivos do projeto.
- Executar PostgreSQL com pgvector em contêiner sob responsabilidade exclusiva da `api-conhecimento`, com credenciais externas à imagem e ao código versionado.
- Antes de executar comandos dependentes de contêineres, verificar se o Docker Desktop e seu engine estão disponíveis. Usar os comandos de build e inicialização definidos pelo projeto.
- Não apagar volumes ou dados persistentes como parte de limpeza rotineira sem autorização para essa exclusão.
- Se Docker Desktop ou outro pré-requisito estiver indisponível, informar o impedimento e quais validações não puderam ser executadas. Não substituir silenciosamente a infraestrutura especificada.

## 7. Fluxo operacional: Spec → Plan → Implement → Test → Review

1. **Spec:** Ler os quatro documentos obrigatórios e as skills pertinentes. Identificar requisitos, contratos, critérios de aceite, restrições e lacunas da tarefa. Resolver definições que bloqueiem a implementação sem ampliar o escopo por iniciativa própria.
2. **Plan:** Definir os arquivos e módulos afetados, os passos da alteração, as dependências necessárias e os comandos de compilação e teste. Relacionar a validação planejada aos critérios de aceite.
3. **Implement:** Executar apenas as mudanças previstas para a tarefa, respeitando as fronteiras dos serviços, os contratos e as práticas de código e segurança. Atualizar especificações quando a mudança autorizada exigir.
4. **Test:** Criar ou atualizar testes para os comportamentos implementados. Antes de concluir uma tarefa de implementação, executar a compilação e os testes relevantes dos serviços afetados, incluindo integração e contratos quando aplicáveis. Utilizar os wrappers e comandos existentes no projeto e a infraestrutura Docker prevista. Registrar resultados reais e limitações.
5. **Review:** Revisar as alterações contra escopo, constituição, arquitetura, contratos e critérios de aceite. Verificar ausência de segredos, acessos indevidos ao banco e caminhos de busca que contornem MCP. Corrigir problemas encontrados e repetir as verificações afetadas antes de apresentar o resultado.

Em tarefas exclusivamente documentais, revisar conteúdo, referências e estrutura; informar que compilação e testes da aplicação não se aplicam quando não houver alteração executável. Não criar código ou infraestrutura apenas para validar documentação.

## 8. Evidências de execução e relato final

Não afirmar que a compilação ou os testes passaram sem tê-los executado e conferido os resultados. Diferenciar verificações aprovadas, falhas, testes não executados e validações não aplicáveis. Informar impedimentos e não apresentar um critério obrigatório pendente como concluído.

Ao terminar cada interação, apresentar:

- **Arquivos criados:** caminhos dos arquivos criados na interação, ou “nenhum”.
- **Arquivos modificados:** caminhos dos arquivos existentes alterados na interação, ou “nenhum”.
- **Comandos executados:** comandos efetivamente executados e seus resultados relevantes; não listar comandos apenas sugeridos como executados.
- **Testes realizados:** verificações executadas, seus resultados e o que não foi executado ou não se aplica.
- **Pendências:** lacunas, falhas, impedimentos e critérios ainda não atendidos, ou “nenhuma”.
- **Próxima tarefa recomendada:** uma ação concreta alinhada às especificações e ao estágio atual do projeto, sem executá-la automaticamente fora do escopo solicitado.
