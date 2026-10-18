# Decisões arquiteturais

Registro das decisões técnicas do projeto e seus motivos. O diário conta o processo;
aqui fica só a decisão final. Serve de base para Materiais e Métodos.

Revisado em 16/10/2026: coloquei as decisões em ordem de número, corrigi a numeração
repetida (eram três "DA-31"), troquei o bloco "Ainda em aberto" pelas decisões já
resolvidas e corrigi trechos escritos antes da execução (DA-10, DA-15, DA-16).
Atualizado em 17/10/2026: DA-36 (prints usados na monografia).



## DA-01 — Fonte de dados (16/08/2026)

**Decisão:** usar os Informes Mensais e Trimestrais Estruturados de FII, publicados pela CVM
no portal de Dados Abertos.

A ideia original era usar dados contratuais da empresa onde trabalho, com contratos e
recebíveis em nível individual. Ficou de fora por confidencialidade comercial e por conta da
LGPD, já que contratos de locação costumam ter fiadores e contatos que são pessoa física.

Isso trouxe uma vantagem: com dados públicos, qualquer pessoa consegue reproduzir o estudo
inteiro.

Correção (16/10/2026): a versão anterior dizia que os dados "são auditados por órgão
regulador". Não é correto. Os valores do informe são declarados pelo administrador do
fundo (Instrução CVM 472, art. 39) e publicados pela CVM, que não calcula nem audita os
percentuais. Por isso as regras de qualidade são necessárias.

A limitação é que a granularidade é por imóvel e por trimestre, não por contrato. Análise de
renovação contratual, inadimplência por locatário e vencimento individual ficam de fora e
entram como trabalhos futuros.

Atualização (16/10/2026): os informes mensais foram baixados, mas não são usados no
pipeline, porque não contêm área nem vacância. A fonte efetiva é o informe trimestral
(tabelas `geral` e `imovel`).



## DA-02 — Arquitetura em camadas (17/08/2026)

**Decisão:** Bronze, Silver e Gold, mais uma área de quarentena.

Bronze guarda o arquivo original, sem alteração, como veio da fonte. Se eu errar o tratamento,
reprocesso a partir dela sem perder nada.

Silver guarda o dado limpo e tipado, mantendo a granularidade original.

Gold guarda o dado agregado, pronto para consumo e para o BI.

Quarentena isola os registros que falharem nas regras de qualidade. A ideia é medir e
reportar a taxa de rejeição, não descartar em silêncio.

A mesma estrutura é criada local e replicada na nuvem, com os mesmos nomes de pasta.



## DA-03 — Ambiente isolado (18/08/2026)

**Decisão:** ambiente virtual `venv` por projeto, com as versões registradas em
`requirements.txt`.

Evita conflito de versão com outros projetos da máquina, e o arquivo de versões permite
recriar o ambiente exato, que é o critério de reprodutibilidade que a banca pode cobrar.

Bibliotecas: pandas, pyarrow (Parquet), duckdb (SQL local), scikit-learn, matplotlib,
seaborn, ipykernel e openpyxl.



## DA-04 — O que vai para o Git (27/08/2026)

**Decisão:** versionar código, documentação e configuração. Dados, modelos e o `.venv` ficam
de fora, via `.gitignore`.

Git não foi feito para arquivo binário grande. E excluir a pasta `dados` é medida de
segurança: se um dia entrarem dados da empresa, a política já impede que subam para
repositório, mesmo sendo privado.

Branch única (`main`), por ser trabalho de um autor só.

Atualização (16/10/2026): o arquivo `.pbix` do dashboard também fica fora do
versionamento, porque contém cópia dos dados importados (DA-34).



## DA-05 — Formato de arquivo (27/08/2026)

**Decisão:** manter o formato original na Bronze (ZIP com CSV) e usar Parquet da Silver em
diante.

Parquet é colunar, então a consulta lê só as colunas que precisa. Comprime melhor que CSV e
carrega o esquema de tipos dentro do próprio arquivo, sem precisar inferir a cada leitura.
É o formato nativo do S3/Athena e também do OneLake, as duas opções de nuvem que eu tinha
na época (a escolhida foi a AWS, DA-11).



## DA-06 — Recorte temporal (27/08/2026)

**Decisão:** informes trimestrais de 2020 a 2026.

A tabela `imovel` é trimestral, ou seja, 4 observações por ano. Três anos dariam uns 12
pontos, pouco demais para série temporal. Sete anos dão uns 26.

Incluir 2020–2022 traz o período de pandemia, quando o setor logístico teve expansão atípica
com o e-commerce. Em vez de problema, vira assunto de análise.

Atualização (16/10/2026): a série final tem 26 trimestres (2020-T1 a 2026-T2); 2026
tem apenas os dois primeiros trimestres. A afirmação sobre expansão do setor na
pandemia é motivação do recorte e só entra na monografia com fonte verificada.



## DA-07 — Seleção dos fundos logísticos (29/08/2026)

**Decisão:** filtrar `Segmento_Atuacao == 'Logística'` na tabela `geral` do informe
trimestral.

É critério objetivo, definido pela própria CVM no cadastro do fundo. Elimina a seleção manual
de CNPJ e o risco de viés na escolha da amostra.

Fundos "Multicategoria" e "Híbrido" ficam de fora. Podem ter parte logística no portfólio,
mas trariam fundos que talvez sejam minoritariamente logísticos. O recorte prioriza pureza de
segmento.

No informe de 2025 o filtro retornou 299 registros e 100 CNPJs distintos.



## DA-08 — Identificação dos fundos por CNPJ (29/08/2026)

**Decisão:** identificar e contar fundos pelo campo `CNPJ_Fundo_Classe`, nunca pelo nome.

O campo `Tipo_Fundo_Classe` assume "Fundo" ou "Classe". Fundos com classes de cotas geram
mais de uma linha para o mesmo CNPJ, e os nomes divergem entre elas. Contar por nome geraria
dupla contagem; contar por CNPJ preserva a entidade.

Atualização (16/10/2026): a regra atua na tabela `geral` (seleção e contagem de fundos).
Na tabela `imovel` não houve deduplicação: zero duplicatas exatas e nenhum informe com
mais de uma versão (ver diário, notebook 02).



## DA-09 — Particionamento (03/09/2026)

**Decisão:** Bronze fica em estrutura plana, com o ano no nome do arquivo. O particionamento
físico no padrão `ano=AAAA/` começa na Silver, em Parquet.

O particionamento reduz custo porque o motor de consulta ignora as pastas fora do filtro
(*partition pruning*). Mas isso só funciona em formato que o motor consegue ler direto.
Athena e o endpoint SQL do Fabric não abrem ZIP: a Bronze é lida uma vez na ingestão e nunca
é consultada. Particioná-la não economizaria nada.



## DA-10 — O que este trabalho entrega (revisado em 17/09/2026; atualizado em 16/10/2026)

Revisão após feedback do Prof. Luiz Sérgio (14/09/2026).

O Percentual_Vacancia já vem informado por imóvel: é declarado pelo administrador do
fundo no informe trimestral e publicado pela CVM, que não o calcula. E a arquitetura
medalhão é padrão de mercado consolidado, não é algo a propor.

A contribuição central do trabalho é o **feature engineering** (engenharia de atributos):
as decisões de tratamento e as variáveis derivadas que transformam o dado publicado pela CVM em
base analítica utilizável. Em concreto, conforme executado:

- derivação da ocupação a partir da vacância, dado que Percentual_Locado tem 97,7% de nulos
- conversão de percentual para área absoluta em m², o que permite somar imóveis
  de tamanhos diferentes
- consolidação por segmento e por fundo com ponderação por área (indicador que não existe na fonte)
- regras de qualidade e critérios de quarentena (faixa de vacância, plausibilidade de área),
  com motivo registrado
- distinção entre recorte de escopo e quarentena
- seleção anual dos fundos, para evitar viés de sobrevivência
- harmonização de esquema entre os arquivos anuais
- alinhamento temporal dos informes por ano e trimestre
- identificação dos fundos por CNPJ em razão do desdobramento Fundo/Classe

Correção (16/10/2026): a versão anterior desta decisão citava "campos numéricos entregues
como texto". A execução mostrou que o CSV usa ponto decimal e os campos são lidos como
número; `nvarchar` é o tipo no banco da CVM, não no arquivo publicado.

O pipeline medalhão é o **meio** que viabiliza esse tratamento em escala e de forma
reprodutível, não o fim do trabalho.

Vocabulário: usar "implementar um pipeline" e não "propor uma arquitetura".



## DA-11 — Plataforma de nuvem: AWS (AWS Academy Learner Lab)

**Decisão:** a migração usa o AWS Academy Learner Lab, com S3 para armazenamento
das camadas (mesma estrutura de pastas do ambiente local), Glue Data Catalog
para o registro das tabelas e Athena para as consultas SQL. Cada tabela Gold
fica em uma pasta própria no S3. A Silver e a Gold são enviadas já processadas;
o ambiente local permanece como fonte de verdade.

**Motivo:** acesso disponível sem depender de autorização para uso do tenant
corporativo exigido pelo Microsoft Fabric; custo coberto pelos créditos do
ambiente acadêmico; o SQL do Athena é próximo ao do DuckDB usado na Gold
(DA-23). Limitações: sessões com tempo limitado, credenciais temporárias e
ambiente vinculado ao curso, o que exige registrar evidências (prints) da
migração.



## DA-12 — Fundos com segmento nulo

**Decisão:** registros da tabela `geral` com `Segmento_Atuacao` nulo ficam fora da
amostra, como efeito direto do filtro por igualdade exata com "Logística" (DA-07).

**Motivo:** sem segmento declarado no cadastro, não há base objetiva para classificar o
fundo como logístico. Incluí-lo exigiria classificação manual, o que a DA-07 evita.
(Registrada formalmente em 16/10/2026; a regra já estava aplicada no notebook 02.)



## DA-13 — Método de projeção da série

**Decisão:** a projeção da vacância ponderada usa média móvel de 4 trimestres,
escolhida entre três métodos simples (ingênuo, média móvel de 4 trimestres e
tendência linear) por holdout temporal: treino nos 22 primeiros trimestres
(2020-T1 a 2025-T2), teste nos 4 últimos (2025-T3 a 2026-T2), critério MAE.
A projeção final é recalculada com a série inteira, para horizonte de 4
trimestres, e apresentada com faixa de ± MAE do teste.

**Motivo:** com 26 pontos e uma ruptura de composição em 2025-T4, métodos
complexos não se justificam. MAE no teste: média móvel 3,57 pontos, tendência
linear 3,73, ingênuo 3,75; a diferença entre eles (0,18 ponto) é pequena, e o
erro de todos é dominado pela ruptura. A média móvel foi preferida também por
não prolongar a tendência de queda aprendida até 2025-T2, contrariada pelos
dados seguintes. A projeção tem caráter indicativo.

(Esta decisão estava registrada por engano como "DA-31"; renumerada em 16/10/2026.)



## DA-14 — Indicador de ocupação (10/09/2026)

**Decisão:** usar Percentual_Vacancia como indicador único e derivar a ocupação como
1 - vacância. Percentual_Locado não é utilizado.

**Motivo:** o campo Percentual_Locado tem 97,7% de nulos na amostra analisada,
inviabilizando qualquer análise sobre ele. Como ocupação e vacância são
complementares, nenhuma informação se perde. Perde-se apenas a possibilidade de validação
cruzada entre os dois campos, que é substituída por regras de faixa (vacância entre
0 e 1) e de plausibilidade de área.

Complemento (01/10/2026): o Anexo 39-II da Instrução CVM nº 571/2015 prevê a coluna
"% locado" apenas para imóveis para renda em construção (item 1.1.2.2.1); para imóveis
para renda acabados, o formulário prevê "% de vacância" (item 1.1.2.1.1). A alta
proporção de nulos em Percentual_Locado é compatível com o desenho do formulário,
e não com falha de preenchimento.



## DA-15 — Incorporação de Ballou (2006) (18/09/2026)

**Decisão:** incorporar Ballou (2006), publicado na revista Produção. Não é a obra citada na V0
(Ballou, 1993, livro), mas é verificável e cumpre função equivalente.

Uso: definição de logística via CSCMP (Introdução), peso econômico da cadeia de
suprimentos (1.1), e fundamentação da vacância financeira via a discussão sobre
ótica de receita versus custo (2.1).

Descartados: Assis et al. (2018) e Faria et al. (2018), porque tratam de transporte, não
de armazenagem; trazê-los afastaria o texto do tema central.

CNT: o PDF anexado é a Agenda Institucional 2022, que NÃO contém a afirmação sobre
redução de 25% dos custos citada na V0. O dado provavelmente está na Pesquisa CNT
de Rodovias. Citação permanece fora até verificação.

Restam 6 citações da V0 não recuperadas: CNT, Santiago (2019), Faria (2018),
Lima et al. (2021), Gagliardi et al. (2018), Rajendran e Jayakrishnan (2022).
Nenhuma entra na monografia sem verificação.



## DA-16 — Regras de qualidade para a coluna Area

**Decisão:** registros com Area = 0 ou Area > 1.000.000 m² vão para a quarentena.

Regra de domínio: área zero não existe fisicamente.

Regra de plausibilidade: o limite de 1.000.000 m² fica no vão entre o percentil 99
da distribuição observada (552.080 m²) e o primeiro valor suspeito identificado
(1.512.456 m²). O corte é justificado pelo próprio dado.

Registros suspeitos não são corrigidos, apenas isolados. Corrigir exigiria supor o
valor verdadeiro, o que introduziria informação não sustentada pela fonte.

Situação (16/10/2026): a regra de consistência temporal (variação brusca de área do
mesmo imóvel entre trimestres), prevista como pendente, não foi implementada, porque a
CVM não fornece identificador único de imóvel. Fica registrada como limitação.



## DA-17 — Seleção de fundos por ano (evita viés de sobrevivência)

**Decisão:** a lista de fundos logísticos é obtida da tabela geral de cada ano, e não
de uma lista fixa extraída de um único ano.

**Motivo:** fundos são criados, liquidados ou mudam de segmento ao longo do período.
Usar a lista de 2025 para os anos anteriores excluiria fundos encerrados antes de
2025, que tendem a ser os de pior desempenho, produzindo viés de sobrevivência
e uma série histórica de vacância artificialmente favorável.



## DA-18 — Harmonização de esquema entre anos

**Decisão:** dentro da função de carga, as colunas CNPJ_Fundo e Nome_Fundo são
renomeadas para CNPJ_Fundo_Classe e Nome_Fundo_Classe, em todos os anos.

**Motivo:** o arquivo de 2020 usa nomes de coluna diferentes dos anos de 2021 a 2026.
Padroniza-se para o nome atual porque é o esquema vigente da fonte. A renomeação é
aplicada a todos os anos, sem condicional por ano, pois não produz efeito onde a
coluna antiga não existe. A regra fica genérica e não depende de caso especial.

Complemento (16/10/2026): a página do conjunto de dados na CVM informa que os arquivos
dos últimos cinco anos são atualizados semanalmente e que o histórico anterior permanece
no repositório fora dessa política. Isso é compatível com o arquivo de 2020 manter o
esquema antigo, mas a causa exata da diferença de nomes não é declarada pela CVM.



## DA-19 — Recorte de escopo pela classe do imóvel

**Decisão:** o estudo considera apenas registros com Classe = "Imóveis para renda
acabados" (5.737 de 6.192 registros, 92,7%).

**Motivo:** vacância pressupõe imóvel pronto e destinado a aluguel. Imóveis em
construção ainda não podem ter inquilino; imóveis para venda não são alugados.

Os registros excluídos por escopo não vão para a quarentena: são válidos, mas fora
do objeto. A quarentena fica reservada a registros suspeitos, para que a taxa de
rejeição reflita problemas reais de qualidade.



## DA-20 — Regras de qualidade e registro de motivo

**Decisão:** cinco regras aplicadas aos registros no escopo: área ausente, área zero,
área acima de 1.000.000 m², vacância ausente, vacância fora da faixa 0 a 1. Cada
registro rejeitado recebe na coluna motivo_quarentena o código de todas as regras
que violou.

**Motivo:** vacância ausente impede o registro de contribuir para o indicador central;
mantê-lo apenas na soma das áreas tornaria a ponderação inconsistente. O motivo
registrado torna a quarentena auditável e permite reportar a rejeição por causa.



## DA-21 — Variáveis derivadas na Silver

**Decisão:** derivar na Silver Taxa_Ocupacao = 1 − Percentual_Vacancia,
Area_Vaga_m2 = Area × Percentual_Vacancia, Area_Locada_m2 = Area × Taxa_Ocupacao e o
Trimestre extraído de Data_Referencia. A Silver fica com 17 colunas.

**Motivo:** a ocupação sai por complementaridade porque Percentual_Locado não serve (DA-14).
Passar de percentual para m² é o que permite somar imóveis de tamanhos diferentes. Ficaram
de fora as colunas de construção e venda (classes fora do escopo), Percentual_Locado (97,7%
de vazios) e o texto livre de características.



## DA-22 — Gravação idempotente da Silver

**Decisão:** a pasta de destino é apagada antes de cada gravação.

**Motivo:** a gravação particionada acrescenta arquivos às partições existentes; sem a
limpeza, reexecutar o notebook duplicaria os dados. A Silver é sempre reconstruível a partir da Bronze.



## DA-23 — Agregações da Gold em SQL (DuckDB)

**Decisão:** as tabelas da Gold são produzidas por consultas SQL executadas no DuckDB sobre os
arquivos Parquet da Silver, expostos como view com reconstrução da partição por ano.

**Motivo:** o SQL é portável, e a mesma consulta roda com alterações mínimas no Amazon
Athena ou no endpoint SQL do Microsoft Fabric na fase de migração.

Indicador central: vacancia_ponderada = SUM(Area_Vaga_m2) / SUM(Area), por
trimestre. A média simples dos percentuais é calculada apenas para comparação.



## DA-24 — Alinhamento temporal na Gold

**Decisão:** as agregações da Gold agrupam por ano e trimestre, e não pela data de
referência exata. Quando um fundo apresenta mais de uma data de referência no
mesmo trimestre, apenas os registros da data mais recente são considerados.

**Motivo:** fundos informam a data de referência de formas diferentes (último dia
útil ou último dia do calendário, como 2022-12-30 e 2022-12-31), o que
partia o mesmo trimestre em várias linhas (35 em vez de 26) e criava um falso
período (2025-09-01, com 33% de vacância). A verificação identificou um fundo
(13.012.312/0001-67) com duas datas no 1º trimestre de 2023 (31/01 e 31/03).
Como o informe descreve a posição no fechamento do período, a data mais recente
substitui a anterior; sem essa regra, o fundo seria contado duas vezes no
trimestre. O descarte ocorre só na agregação; a Silver permanece inalterada.



## DA-25 — Regra de alinhamento temporal centralizada em view

**Decisão:** a regra da DA-24 (data mais recente de cada fundo no trimestre) foi
transformada na view imoveis_trimestre, criada no notebook 03 a partir da view
silver_imoveis. As tabelas Gold por fundo e seguintes leem dessa view.

**Motivo:** evitar que a mesma regra fique escrita em várias consultas; se ela
mudar, a alteração acontece em um único ponto. A view foi validada contra a
Gold 1: 5.606 registros nos dois casos.



## DA-26 — Identificação do fundo na Gold por CNPJ

**Decisão:** a Gold por fundo identifica cada fundo apenas pelo CNPJ_Fundo_Classe,
sem o nome.

**Motivo:** o nome não está na Silver (fica na tabela geral da Bronze), e trazê-lo
exigiria alterar o notebook 02. O CNPJ é o identificador estável adotado desde
a DA-08; nomes podem ser consultados pontualmente na análise, quando necessário.



## DA-27 — Gold de evolução do mercado não criada

**Decisão:** a tabela Gold prevista para a evolução do mercado (quantidade de
fundos, registros e área total por trimestre) não foi criada como arquivo
separado.

**Motivo:** essas três medidas já estão na Gold do segmento
(vacancia_segmento_trimestral: qtd_fundos, qtd_registros, area_total_m2).
Uma tabela à parte duplicaria dados e documentação sem acrescentar informação.



## DA-28 — Padrão das figuras da análise

**Decisão:** as figuras são salvas em monografia/figuras/ como PNG a 300 dpi, com
nome no formato figNN_descricao.png, sem título dentro da imagem e com eixo Y
iniciando em zero. Conversões de escala (vacância em %, área em milhões de m²)
são feitas apenas no gráfico; a Gold mantém vacância na escala 0 a 1 e área em m².

**Motivo:** o título da figura fica no texto da monografia, conforme a ABNT, e não
deve aparecer duplicado. O eixo a partir de zero evita exagero visual das
oscilações. Manter uma única escala nas camadas evita conversão dupla no
consumo (por exemplo, o formato de porcentagem do Power BI multiplicaria por
100 um valor já convertido).



## DA-29 — Decomposição da variação da área vaga por presença na amostra

**Decisão:** variações relevantes da área vaga do segmento entre dois trimestres
são decompostas em três parcelas, conforme a presença de cada fundo: fundos
que entraram, fundos que saíram e fundos presentes nos dois trimestres. Fundo
ausente em um trimestre conta como área vaga zero naquele trimestre.

**Motivo:** como a seleção de fundos é anual (DA-17), a composição da amostra muda
ao longo do tempo, e a quantidade de fundos pode permanecer igual mesmo com
entradas e saídas (2025-T3 e 2025-T4: 55 fundos, com 4 entradas e 4 saídas).
A decomposição separa mudança de amostra de variação real de ocupação. As três
parcelas somam exatamente a variação do segmento na Gold do segmento.



## DA-30 — Distribuição da vacância por faixas no nível do imóvel

**Decisão:** a distribuição da vacância é analisada na Silver (nível imóvel ×
trimestre), classificando cada registro em cinco faixas: 0% (locado), até 10%,
10% a 50%, 50% a 100% e 100% (vago). Os percentuais são calculados por ano
sobre o número de registros. A regra da DA-24 não é reaplicada nesta análise.

**Motivo:** um histograma simples seria dominado pela concentração em zero; faixas
com significado de negócio tornam a cauda legível. A Gold não serve porque é
agregada por trimestre e por fundo. A única duplicidade temporal da Silver
(Pilkington, 2023-T1, vacância 0) representa 1 registro em 5.607, efeito
desprezível nos percentuais; reaplicar a regra aqui duplicaria a lógica
centralizada na view imoveis_trimestre (DA-25). Limitação: os percentuais são
de registros, não de imóveis distintos, porque a CVM não fornece
identificador único de imóvel.



## DA-31 — Registro das camadas no Athena e validação da migração

**Decisão:** Silver, Gold e Quarentena foram registradas no Glue Data Catalog como
tabelas externas, criadas por DDL no Athena (src/athena/01_criar_tabelas.sql),
no banco tcc_galpoes. A Silver é particionada por ano, com partições
registradas por MSCK REPAIR TABLE. A quarentena é registrada apenas com as
colunas de auditoria. A validação (src/athena/02_validacao.sql) compara
contagens com o ambiente local e recalcula a Gold do segmento no Athena a
partir da Silver, com a regra da DA-24.

**Motivo:** DDL explícita e versionada no repositório garante rastreabilidade e
controle dos tipos, obtidos do esquema real dos Parquet, sem depender de
inferência automática por crawler. O recálculo da Gold no Athena comprova a
portabilidade do SQL (DA-23) e a equivalência entre o ambiente local e a
nuvem.



## DA-32 — Componentes da AWS utilizados e descartados

**Decisão:** na nuvem, são usados o S3 (armazenamento das camadas), o Glue Data
Catalog (metadados das tabelas) e o Athena (consultas SQL). Não são usados o
Glue Crawler, os jobs de ETL do Glue nem o Amazon QuickSight. O dashboard é
construído no Power BI, conectado ao Athena por driver ODBC, em modo de
importação.

**Motivo:** o processamento das camadas já é feito e validado localmente (pandas
e DuckDB), e o volume (5.607 registros na Silver) não justifica jobs de ETL
em escala, que consomem créditos por tempo de execução. O crawler foi
substituído por DDL explícita e versionada (DA-31). O QuickSight conectaria
ao Athena sem driver, mas exige assinatura com cobrança por usuário,
incompatível com o crédito disponível; o Power BI já era o entregável definido
no projeto.



## DA-33 — Transformação Silver → Gold executada na nuvem

**Decisão:** a etapa Silver → Gold foi executada no Athena: a regra de
alinhamento temporal (DA-24) foi criada como a view tcc_galpoes.imoveis_trimestre,
e as Gold do segmento e por fundo foram geradas por CTAS (CREATE TABLE AS
SELECT) em Parquet, em s3://tcc-galpoes-leandro-2026/gold_nuvem/, como as
tabelas gold_vacancia_segmento_trimestral_nuvem e
gold_vacancia_fundo_trimestral_nuvem (script src/athena/03_gold_na_nuvem.sql).
A etapa Bronze → Silver e a projeção permanecem locais.

**Motivo:** o SQL da Gold já era portável e validado (DA-23, DA-31), o que
permitiu executar uma etapa de transformação do pipeline na nuvem com baixo
custo. A Gold gerada na nuvem fica em pasta separada da Gold enviada do
ambiente local, para permitir a comparação linha a linha. Bronze → Silver
permanece local porque o Athena não lê arquivos ZIP nem executa Python, e
um job de ETL do Glue teria custo e complexidade incompatíveis com o
escopo; a projeção (média móvel e MAE) é feita em Python. A execução
completa do pipeline na nuvem fica como trabalho futuro.



## DA-34 — Dashboard Power BI sobre a Gold gerada na nuvem

**Decisão:** dashboard de página única no Power BI Desktop, conectado ao Athena
por driver ODBC (Amazon Athena ODBC 2.x, DSN de usuário athena_tcc_galpoes,
autenticação IAM Credentials com as credenciais temporárias do Learner Lab),
em modo Importar. Consome gold_vacancia_segmento_trimestral_nuvem,
gold_vacancia_fundo_trimestral_nuvem e gold_projecao_vacancia_trimestral, sem
relacionamentos entre elas. Visuais: série da vacância ponderada × média
simples (linhas retas com marcadores); três cartões do último trimestre
observado (2026-T2, filtro no próprio visual); ranking dos 10 fundos com maior
área vaga em 2026-T2 (filtro Top N); três cartões da projeção (agregação
Average), com fundo diferenciado, e nota do método. A conversão para
porcentagem é feita só no Power BI (DA-28). O arquivo .pbix fica fora do
versionamento; o PDF exportado e o print são versionados.

**Motivo:** o modo Importar mantém o dashboard funcional depois que as
credenciais temporárias expiram, o que DirectQuery não permitiria. A projeção
por média móvel é constante no horizonte, então foi apresentada em cartões
(valor e faixa) em vez de uma tabela com quatro linhas iguais; o fundo
diferenciado distingue valor projetado de valor observado. Cada visual usa uma
única tabela, o que evita filtros cruzados inesperados. Linhas sem suavização
evitam desenhar valores inexistentes entre trimestres. O .pbix contém cópia
dos dados importados (DA-04).



## DA-35 — Premissa de base física para Percentual_Vacancia

**Decisão:** Percentual_Vacancia é interpretado como proporção da área do imóvel,
e Area_Vaga_m2 = Area × Percentual_Vacancia é tratada como estimativa sob essa premissa.

**Motivo:** nem o Anexo 39-II da Instrução CVM nº 571/2015 nem o dicionário de dados da
CVM especificam se a vacância é apurada sobre a área ou sobre a receita potencial
(a descrição do campo no dicionário oficial está vazia). A conversão para m² exige
base física. A premissa é declarada como limitação na monografia.

(Esta decisão estava registrada por engano como "DA-31"; renumerada em 16/10/2026.)



## DA-36 — Evidências da migração na monografia (16/10/2026)

**Decisão:** entram na monografia quatro prints: ev01 (raiz do bucket), ev05 (esquema da
Silver no Glue), ev12 (Gold por fundo, nuvem × local) e ev16 (painel). Os valores das
outras validações (ev07, ev08, ev11) estão na Tabela 9, e os demais prints ficam para a
apresentação da defesa. O print do painel de créditos do Learner Lab (ev10) não é usado, e
a monografia não informa valor de custo.

**Motivo:** os prints que ficaram de fora repetem informação que já está no texto ou em
tabela, e encheriam o capítulo 3 de imagens quase iguais. O custo não é objeto de análise;
o ambiente acadêmico foi escolhido por cobrir o uso com créditos (DA-11).

(Atualizada em 17/10/2026, na redação dos resultados.)
