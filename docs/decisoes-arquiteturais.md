# Decisões arquiteturais

Registro das decisões técnicas do projeto e seus motivos. O diário conta o processo;
aqui fica só a decisão final. Serve de base para Materiais e Métodos.



## DA-01 — Fonte de dados (16/08/2026)

**Decisão:** usar os Informes Mensais e Trimestrais Estruturados de FII, publicados pela CVM
no portal de Dados Abertos.

A ideia original era usar dados contratuais da empresa onde trabalho, com contratos e
recebíveis em nível individual. Ficou de fora por confidencialidade comercial e por conta da
LGPD, já que contratos de locação costumam ter fiadores e contatos que são pessoa física.

Isso trouxe uma vantagem: com dados públicos, qualquer pessoa consegue reproduzir o estudo
inteiro. E os dados são auditados por órgão regulador.

A limitação é que a granularidade é por imóvel e por trimestre, não por contrato. Análise de
renovação contratual, inadimplência por locatário e vencimento individual ficam de fora —
entram como trabalhos futuros.



## DA-02 — Arquitetura em camadas (17/08/2026)

**Decisão:** Bronze, Silver e Gold, mais uma área de quarentena.

Bronze guarda o dado bruto e imutável, como veio da fonte. Se eu errar o tratamento,
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
recriar o ambiente exato — que é o critério de reprodutibilidade que a banca pode cobrar.

Bibliotecas: pandas, pyarrow (Parquet), duckdb (SQL local), scikit-learn, matplotlib,
seaborn, ipykernel e openpyxl.



## DA-04 — O que vai para o Git (27/08/2026)

**Decisão:** versionar código, documentação e configuração. Dados, modelos e o `.venv` ficam
de fora, via `.gitignore`.

Git não foi feito para arquivo binário grande. E excluir a pasta `dados` é medida de
segurança: se um dia entrarem dados da empresa, a política já impede que subam para
repositório, mesmo sendo privado.

Branch única (`main`), por ser trabalho de um autor só.



## DA-05 — Formato de arquivo (27/08/2026)

**Decisão:** manter o formato original na Bronze (ZIP com CSV) e usar Parquet da Silver em
diante.

Parquet é colunar, então a consulta lê só as colunas que precisa. Comprime melhor que CSV e
carrega o esquema de tipos dentro do próprio arquivo, sem precisar inferir a cada leitura.
É o formato nativo tanto do S3/Athena quanto do OneLake, o que garante portabilidade na
migração.



## DA-06 — Recorte temporal (27/08/2026)

**Decisão:** informes trimestrais de 2020 a 2026.

A tabela `imovel` é trimestral, ou seja, 4 observações por ano. Três anos dariam uns 12
pontos, pouco demais para série temporal. Sete anos dão uns 26.

Incluir 2020–2022 traz o período de pandemia, quando o setor logístico teve expansão atípica
com o e-commerce. Em vez de problema, vira assunto de análise.



## DA-07 — Seleção dos fundos logísticos (29/08/2026)

**Decisão:** filtrar `Segmento_Atuacao == 'Logística'` na tabela `geral` do informe
trimestral.

É critério objetivo, definido pela própria CVM no cadastro do fundo. Elimina a seleção manual
de CNPJ e o risco de viés na escolha da amostra.

Fundos "Multicategoria" e "Híbrido" ficam de fora. Podem ter parte logística no portfólio,
mas trariam fundos que talvez sejam minoritariamente logísticos. O recorte prioriza pureza de
segmento.

No informe de 2025 o filtro retornou 299 registros e 100 CNPJs distintos.



## DA-08 — Deduplicação por CNPJ (29/08/2026)

**Decisão:** deduplicar fundos pelo campo `CNPJ_Fundo_Classe`, nunca pelo nome.

O campo `Tipo_Fundo_Classe` assume "Fundo" ou "Classe". Fundos com classes de cotas geram
mais de uma linha para o mesmo CNPJ, e os nomes divergem entre elas. Contar por nome geraria
dupla contagem; contar por CNPJ preserva a entidade.



## DA-09 — Particionamento (03/09/2026)

**Decisão:** Bronze fica em estrutura plana, com o ano no nome do arquivo. O particionamento
físico no padrão `ano=AAAA/` começa na Silver, em Parquet.

O particionamento reduz custo porque o motor de consulta ignora as pastas fora do filtro
(*partition pruning*). Mas isso só funciona em formato que o motor consegue ler direto.
Athena e o endpoint SQL do Fabric não abrem ZIP — a Bronze é lida uma vez na ingestão e nunca
é consultada. Particioná-la não economizaria nada.



## DA-10 — O que este trabalho entrega (revisado em 17/09/2026)

Revisão após feedback do Prof. Luiz Sérgio (14/09/2026).

A CVM já publica o Percentual_Vacancia calculado, por imóvel. E a arquitetura
medalhão é padrão de mercado consolidado — não é algo a propor.

A contribuição central do trabalho é o **feature engineering**: as decisões de
tratamento e as variáveis derivadas que transformam o dado bruto da CVM em base
analítica utilizável. Em concreto:

- derivação da ocupação a partir da vacância, dado que Percentual_Locado tem 97,7% de nulos
- conversão de percentual para área absoluta em m², o que permite somar imóveis
  de tamanhos diferentes
- consolidação por fundo com ponderação por área — indicador inexistente na fonte
- regras de qualidade e critérios de quarentena (faixa de vacância, plausibilidade de área)
- deduplicação por CNPJ em razão do desdobramento Fundo/Classe
- tratamento de tipagem: campos numéricos entregues como texto, em escala decimal

O pipeline medalhão é o **meio** que viabiliza esse tratamento em escala e de forma
reprodutível, não o fim do trabalho.

Vocabulário: usar "implementar um pipeline" e não "propor uma arquitetura".



## Ainda em aberto

- **DA-11** — Nuvem: AWS (S3/Glue/Athena) ou Microsoft Fabric (OneLake). Aguardando
  confirmação de créditos na AWS e de capacidade no tenant do Fabric.
- **DA-12** — O que fazer com registros de `Segmento_Atuacao` nulo. Defino ao implementar a
  Silver.
- **DA-13** — Método de projeção da série temporal. Defino depois da análise exploratória.



## DA-14 — Indicador de ocupação (10/09/2026)

Decisão: usar Percentual_Vacancia como indicador único e derivar a ocupação como
1 - vacância. Percentual_Locado não é utilizado.

Motivo: o campo Percentual_Locado tem 97,7% de nulos na amostra analisada,
inviabilizando qualquer análise sobre ele. Como ocupação e vacância são
complementares, nenhuma informação se perde — apenas a possibilidade de validação
cruzada entre os dois campos, que é substituída por regras de faixa (vacância entre
0 e 1) e de plausibilidade de área.

Complemento (01/10/2026): o Anexo 39-II da Instrução CVM nº 571/2015 prevê a coluna
"% locado" apenas para imóveis para renda em construção (item 1.1.2.2.1); para imóveis
para renda acabados, o formulário prevê "% de vacância" (item 1.1.2.1.1). A alta
proporção de nulos em Percentual_Locado é compatível com o desenho do formulário,
e não com falha de preenchimento.



## DA-15 — Incorporação de Ballou (2006) — 18/09/2026

Anexado Ballou (2006), publicado na revista Produção. Não é a obra citada na V0
(Ballou, 1993, livro), mas é verificável e cumpre função equivalente.

Uso: definição de logística via CSCMP (Introdução), peso econômico da cadeia de
suprimentos (1.1), e fundamentação da vacância financeira via a discussão sobre
ótica de receita versus custo (2.1).

Descartados: Assis et al. (2018) e Faria et al. (2018) — tratam de transporte, não
de armazenagem; trazê-los afastaria o texto do tema central.

CNT: o PDF anexado é a Agenda Institucional 2022, que NÃO contém a afirmação sobre
redução de 25% dos custos citada na V0. O dado provavelmente está na Pesquisa CNT
de Rodovias. Citação permanece fora até verificação.

Restam 5 citações da V0 não recuperadas: CNT, Santiago (2019), Faria (2018),
Lima et al. (2021), Gagliardi et al. (2018), Rajendran e Jayakrishnan (2022).



## DA-16 — Regras de qualidade para a coluna Area

Decisão: registros com Area = 0 ou Area > 1.000.000 m² vão para a quarentena.

Regra de domínio: área zero não existe fisicamente.

Regra de plausibilidade: o limite de 1.000.000 m² fica no vão entre o percentil 99
da distribuição observada (552.080 m²) e o primeiro valor suspeito identificado
(1.512.456 m²). O corte é justificado pelo próprio dado.

Registros suspeitos não são corrigidos, apenas isolados. Corrigir exigiria supor o
valor verdadeiro, o que introduziria informação não sustentada pela fonte.

Pendente: regra de consistência temporal (variação brusca de área do mesmo imóvel
entre trimestres), a implementar quando os sete anos estiverem integrados.



## DA-17 — Seleção de fundos por ano (evita viés de sobrevivência)

Decisão: a lista de fundos logísticos é obtida da tabela geral de cada ano, e não
de uma lista fixa extraída de um único ano.

Motivo: fundos são criados, liquidados ou mudam de segmento ao longo do período.
Usar a lista de 2025 para os anos anteriores excluiria fundos encerrados antes de
2025 — que tendem a ser os de pior desempenho —, produzindo viés de sobrevivência
e uma série histórica de vacância artificialmente favorável.



## DA-18 — Harmonização de esquema entre anos

Decisão: dentro da função de carga, as colunas CNPJ_Fundo e Nome_Fundo são
renomeadas para CNPJ_Fundo_Classe e Nome_Fundo_Classe, em todos os anos.

Motivo: o arquivo de 2020 usa nomes de coluna diferentes dos anos de 2021 a 2026.
Padroniza-se para o nome atual porque é o esquema vigente da fonte. A renomeação é
aplicada a todos os anos, sem condicional por ano, pois não produz efeito onde a
coluna antiga não existe — a regra fica genérica e não depende de caso especial.



## DA-19 — Recorte de escopo pela classe do imóvel

Decisão: o estudo considera apenas registros com Classe = "Imóveis para renda
acabados" (5.737 de 6.192 registros, 92,7%).

Motivo: vacância pressupõe imóvel pronto e destinado a aluguel. Imóveis em
construção ainda não podem ter inquilino; imóveis para venda não são alugados.

Os registros excluídos por escopo não vão para a quarentena: são válidos, mas fora
do objeto. A quarentena fica reservada a registros suspeitos, para que a taxa de
rejeição reflita problemas reais de qualidade.

## DA-20 — Regras de qualidade e registro de motivo

Decisão: cinco regras aplicadas aos registros no escopo — área ausente, área zero,
área acima de 1.000.000 m², vacância ausente, vacância fora da faixa 0 a 1. Cada
registro rejeitado recebe na coluna motivo_quarentena o código de todas as regras
que violou.

Motivo: vacância ausente impede o registro de contribuir para o indicador central;
mantê-lo apenas na soma das áreas tornaria a ponderação inconsistente. O motivo
registrado torna a quarentena auditável e permite reportar a rejeição por causa.



## DA-21 — Variáveis derivadas na Silver

Taxa_Ocupacao = 1 − Percentual_Vacancia (complementaridade).
Area_Vaga_m2 = Area × Percentual_Vacancia; Area_Locada_m2 = Area × Taxa_Ocupacao
(conversão de relativo em absoluto, para permitir soma entre imóveis).
Trimestre extraído de Data_Referencia.

Seleção de 17 colunas. Excluídas as colunas de construção e venda (pertencem a
classes fora do escopo), Percentual_Locado (97,7% de vazios) e o texto livre de
características.



## DA-22 — Gravação idempotente da Silver

A pasta de destino é apagada antes de cada gravação. A gravação particionada
acrescenta arquivos às partições existentes; sem a limpeza, reexecutar o notebook
duplicaria os dados. A Silver é sempre reconstruível a partir da Bronze.



## DA-23 — Agregações da Gold em SQL (DuckDB)

As tabelas da Gold são produzidas por consultas SQL executadas no DuckDB sobre os
arquivos Parquet da Silver, expostos como view com reconstrução da partição por ano.

Motivo: o SQL é portável — a mesma consulta roda com alterações mínimas no Amazon
Athena ou no endpoint SQL do Microsoft Fabric na fase de migração.

Indicador central: vacancia_ponderada = SUM(Area_Vaga_m2) / SUM(Area), por
trimestre. A média simples dos percentuais é calculada apenas para comparação.


## DA-24 — Alinhamento temporal na Gold

Decisão: as agregações da Gold agrupam por ano e trimestre, e não pela data de
referência exata. Quando um fundo apresenta mais de uma data de referência no
mesmo trimestre, apenas os registros da data mais recente são considerados.

Motivo: fundos informam a data de referência de formas diferentes — último dia
útil ou último dia do calendário (2022-12-30 e 2022-12-31, por exemplo) —, o que
partia o mesmo trimestre em várias linhas (35 em vez de 26) e criava um falso
período (2025-09-01, com 33% de vacância). A verificação identificou um fundo
(13.012.312/0001-67) com duas datas no 1º trimestre de 2023 (31/01 e 31/03).
Como o informe descreve a posição no fechamento do período, a data mais recente
substitui a anterior; sem essa regra, o fundo seria contado duas vezes no
trimestre. O descarte ocorre só na agregação; a Silver permanece inalterada.


## DA-25 — Regra de alinhamento temporal centralizada em view

Decisão: a regra da DA-24 (data mais recente de cada fundo no trimestre) foi
transformada na view imoveis_trimestre, criada no notebook 03 a partir da view
silver_imoveis. As tabelas Gold por fundo e seguintes leem dessa view.

Motivo: evitar que a mesma regra fique escrita em várias consultas; se ela
mudar, a alteração acontece em um único ponto. A view foi validada contra a
Gold 1: 5.606 registros nos dois casos.


## DA-26 — Identificação do fundo na Gold por CNPJ

Decisão: a Gold por fundo identifica cada fundo apenas pelo CNPJ_Fundo_Classe,
sem o nome.

Motivo: o nome não está na Silver (fica na tabela geral da Bronze), e trazê-lo
exigiria alterar o notebook 02. O CNPJ é o identificador estável adotado desde
a DA-08; nomes podem ser consultados pontualmente na análise, quando necessário.


## DA-27 — Gold de evolução do mercado não criada

Decisão: a tabela Gold prevista para a evolução do mercado (quantidade de
fundos, registros e área total por trimestre) não foi criada como arquivo
separado.

Motivo: essas três medidas já estão na Gold do segmento
(vacancia_segmento_trimestral: qtd_fundos, qtd_registros, area_total_m2).
Uma tabela à parte duplicaria dados e documentação sem acrescentar informação.


## DA-28 — Padrão das figuras da análise

Decisão: as figuras são salvas em monografia/figuras/ como PNG a 300 dpi, com
nome no formato figNN_descricao.png, sem título dentro da imagem e com eixo Y
iniciando em zero. Conversões de escala (vacância em %, área em milhões de m²)
são feitas apenas no gráfico; a Gold mantém vacância na escala 0 a 1 e área em m².

Motivo: o título da figura fica no texto da monografia, conforme a ABNT, e não
deve aparecer duplicado. O eixo a partir de zero evita exagero visual das
oscilações. Manter uma única escala nas camadas evita conversão dupla no
consumo (por exemplo, o formato de porcentagem do Power BI multiplicaria por
100 um valor já convertido).


## DA-29 — Decomposição da variação da área vaga por presença na amostra

Decisão: variações relevantes da área vaga do segmento entre dois trimestres
são decompostas em três parcelas, conforme a presença de cada fundo: fundos
que entraram, fundos que saíram e fundos presentes nos dois trimestres. Fundo
ausente em um trimestre conta como área vaga zero naquele trimestre.

Motivo: como a seleção de fundos é anual (DA-17), a composição da amostra muda
ao longo do tempo, e a quantidade de fundos pode permanecer igual mesmo com
entradas e saídas (2025-T3 e 2025-T4: 55 fundos, com 4 entradas e 4 saídas).
A decomposição separa mudança de amostra de variação real de ocupação. As três
parcelas somam exatamente a variação do segmento na Gold do segmento.


## DA-30 — Distribuição da vacância por faixas no nível do imóvel

Decisão: a distribuição da vacância é analisada na Silver (nível imóvel ×
trimestre), classificando cada registro em cinco faixas: 0% (locado), até 10%,
10% a 50%, 50% a 100% e 100% (vago). Os percentuais são calculados por ano
sobre o número de registros. A regra da DA-24 não é reaplicada nesta análise.

Motivo: um histograma simples seria dominado pela concentração em zero; faixas
com significado de negócio tornam a cauda legível. A Gold não serve porque é
agregada por trimestre e por fundo. A única duplicidade temporal da Silver
(Pilkington, 2023-T1, vacância 0) representa 1 registro em 5.607, efeito
desprezível nos percentuais; reaplicar a regra aqui duplicaria a lógica
centralizada na view imoveis_trimestre (DA-25). Limitação: os percentuais são
de registros, não de imóveis distintos, porque a CVM não fornece
identificador único de imóvel.


## DA-31 — Método de projeção da série

Decisão: a projeção da vacância ponderada usa média móvel de 4 trimestres,
escolhida entre três métodos simples (ingênuo, média móvel de 4 trimestres e
tendência linear) por holdout temporal: treino nos 22 primeiros trimestres
(2020-T1 a 2025-T2), teste nos 4 últimos (2025-T3 a 2026-T2), critério MAE.
A projeção final é recalculada com a série inteira, para horizonte de 4
trimestres, e apresentada com faixa de ± MAE do teste.

Motivo: com 26 pontos e uma ruptura de composição em 2025-T4, métodos
complexos não se justificam. MAE no teste: média móvel 3,57 pontos, tendência
linear 3,73, ingênuo 3,75; a diferença entre eles (0,18 ponto) é pequena, e o
erro de todos é dominado pela ruptura. A média móvel foi preferida também por
não prolongar a tendência de queda aprendida até 2025-T2, contrariada pelos
dados seguintes. A projeção tem caráter indicativo.


## DA-31 — Premissa de base física para Percentual_Vacancia

Decisão: Percentual_Vacancia é interpretado como proporção da área do imóvel,
e Area_Vaga_m2 = Area × Percentual_Vacancia é tratada como estimativa sob essa premissa.

Motivo: nem o Anexo 39-II da Instrução CVM nº 571/2015 nem o dicionário de dados da
CVM especificam se a vacância é apurada sobre a área ou sobre a receita potencial
(a descrição do campo no dicionário oficial está vazia). A conversão para m² exige
base física. A premissa é declarada como limitação na monografia.


## DA-11 — Plataforma de nuvem: AWS (AWS Academy Learner Lab)

Decisão: a migração usa o AWS Academy Learner Lab, com S3 para armazenamento
das camadas (mesma estrutura de pastas do ambiente local), Glue Data Catalog
para o registro das tabelas e Athena para as consultas SQL. Cada tabela Gold
fica em uma pasta própria no S3. A Silver e a Gold são enviadas já processadas;
o ambiente local permanece como fonte de verdade.

Motivo: acesso disponível sem depender de autorização para uso do tenant
corporativo exigido pelo Microsoft Fabric; custo coberto pelos créditos do
ambiente acadêmico; o SQL do Athena é próximo ao do DuckDB usado na Gold
(DA-23). Limitações: sessões com tempo limitado, credenciais temporárias e
ambiente vinculado ao curso, o que exige registrar evidências (prints) da
migração.


## DA-31 — Registro das camadas no Athena e validação da migração

Decisão: Silver, Gold e Quarentena foram registradas no Glue Data Catalog como
tabelas externas, criadas por DDL no Athena (src/athena/01_criar_tabelas.sql),
no banco tcc_galpoes. A Silver é particionada por ano, com partições
registradas por MSCK REPAIR TABLE. A quarentena é registrada apenas com as
colunas de auditoria. A validação (src/athena/02_validacao.sql) compara
contagens com o ambiente local e recalcula a Gold do segmento no Athena a
partir da Silver, com a regra da DA-24.

Motivo: DDL explícita e versionada no repositório garante rastreabilidade e
controle dos tipos, obtidos do esquema real dos Parquet, sem depender de
inferência automática por crawler. O recálculo da Gold no Athena comprova a
portabilidade do SQL (DA-23) e a equivalência entre o ambiente local e a
nuvem.


## DA-32 — Componentes da AWS utilizados e descartados

Decisão: na nuvem, são usados o S3 (armazenamento das camadas), o Glue Data
Catalog (metadados das tabelas) e o Athena (consultas SQL). Não são usados o
Glue Crawler, os jobs de ETL do Glue nem o Amazon QuickSight. O dashboard é
construído no Power BI, conectado ao Athena por driver ODBC, em modo de
importação.

Motivo: o processamento das camadas já é feito e validado localmente (pandas
e DuckDB), e o volume (5.607 registros na Silver) não justifica jobs de ETL
em escala, que consomem créditos por tempo de execução. O crawler foi
substituído por DDL explícita e versionada (DA-31). O QuickSight conectaria
ao Athena sem driver, mas exige assinatura com cobrança por usuário,
incompatível com o crédito disponível; o Power BI já era o entregável definido
e é a ferramenta do ecossistema que o autor domina.