# Dicionário de dados

Estrutura dos dados usados no projeto. Vai como apêndice da monografia.
Atualizado em 03/09/2026.



## Origem

Informes Mensal e Trimestral Estruturados de FII, publicados pela CVM no portal de Dados
Abertos. Base normativa: Instrução CVM 571/2015, anexos 39-I (mensal) e 39-II (trimestral).
Envio pelo sistema Fundos.NET.

Período coletado: 2020 a 2026. Distribuição em ZIP anual com vários CSV dentro.

Parâmetros de leitura, confirmados na prática:

| Separador decimal | `.` (ponto) — confirmado na leitura; o pandas converte automaticamente |



## Tabelas do informe mensal

| Tabela | Conteúdo |
|---|---|
| `geral` | Cadastro do fundo, endereço, administrador, segmento |
| `ativo_passivo` | Estrutura patrimonial, em valores financeiros |
| `complemento` | Patrimônio líquido, valor da cota, cotistas, rentabilidade |

Não contém área nem vacância. É um retrato financeiro, não físico.

Campos de interesse em `ativo_passivo`: `Contas_Receber_Aluguel`, `Imoveis_Renda_Acabados`,
`Imoveis_Renda_Construcao`, `Total_Investido`. Todos consolidados por fundo, não por imóvel.



## Tabelas do informe trimestral

| Tabela | Uso no projeto |
|---|---|
| `imovel` | **Fonte central** — área, ocupação, vacância |
| `geral` | Seleção dos fundos logísticos |
| `complemento` | Vencimento de contratos e indexadores |
| `imovel_renda_acabado_inquilino` | A avaliar — setor do locatário, participação na receita |
| `imovel_renda_acabado_contrato` | A avaliar — características contratuais em texto livre |
| `rentabilidade_efetiva` | A avaliar |
| `resultado_contabil_financeiro` | A avaliar |
| `aquisicao_imovel`, `alienacao_imovel` | A avaliar — movimentações do portfólio |
| `ativo`, `ativo_garantia_rentabilidade`, `direito` | Não utilizadas |
| `terreno`, `aquisicao_terreno`, `alienacao_terreno` | Não utilizadas |
| `imovel_desempenho` | Não utilizada |



## Chaves

`CNPJ_Fundo_Classe` (varchar 18) e `Data_Referencia` (date, AAAA-MM-DD) aparecem em todas as
tabelas dos dois informes. A combinação das duas é o que permite relacionar as tabelas e
juntar mensal com trimestral.

Existe também `Versao` (tinyint), relevante quando um informe é reapresentado.



## Tabela `imovel` (trimestral)

Uma linha por imóvel, por trimestre.

| Campo | Tipo na CVM | Descrição |
|---|---|---|
| `CNPJ_Fundo_Classe` | varchar(18) | Fundo dono do imóvel |
| `Data_Referencia` | date | Trimestre |
| `Nome_Imovel` | varchar(255) | Nome do imóvel |
| `Endereco` | varchar(255) | Endereço |
| `Classe` | varchar(32) | Classificação do imóvel |
| `Area` | nvarchar(4000) | Área — vem como texto |
| `Numero_Unidades` | int | Quantidade de unidades |
| `Percentual_Locado` | nvarchar(4000) | Percentual da área locada |
| `Percentual_Vacancia` | nvarchar(4000) | Percentual de vacância |
| `Percentual_Inadimplencia` | nvarchar(4000) | Percentual de inadimplência |
| `Percentual_Receitas_FII` | nvarchar(4000) | Peso do imóvel na receita do fundo |
| `Percentual_Imovel_Total_Investido` | nvarchar(4000) | Peso no total investido |
| `Percentual_Vendido` | nvarchar(4000) | Percentual vendido |
| `Custo_Construcao_Realizado` | nvarchar(4000) | Custo realizado |
| `Custo_Construcao_Previsto` | nvarchar(4000) | Custo previsto |
| `Percentual_Conclusao_Obras_Realizado` | nvarchar(4000) | Andamento de obra |
| `Outras_Caracteristicas_Relevantes` | varchar(max) | Texto livre |



## Tabela `geral` (trimestral) — campos usados

4.577 linhas e 39 colunas no informe de 2025. Uma linha por fundo (ou classe), por trimestre.

| Campo | Tipo na CVM | Descrição |
|---|---|---|
| `CNPJ_Fundo_Classe` | varchar(18) | CNPJ |
| `Nome_Fundo_Classe` | varchar(255) | Nome do fundo |
| `Tipo_Fundo_Classe` | varchar(6) | "Fundo" ou "Classe" |
| `Segmento_Atuacao` | varchar(255) | Segmento do fundo |
| `Data_Encerramento_Trimestre` | date | Encerramento do trimestre |
| `Cidade`, `Estado`, `Bairro` | varchar(255) | Endereço do fundo, não dos imóveis |
| `Nome_Administrador` | varchar(255) | Administrador |
| `Tipo_Gestao` | varchar(255) | Modalidade de gestão |

### `Segmento_Atuacao`

Valores encontrados em 2025: Shoppings, Híbrido, Outros, Lajes Corporativas, Escritórios,
Multicategoria, Educacional, **Logística**, Hospital, Títulos e Val. Mob., Hotel, Residencial,
Varejo, e nulos.

O valor usado no filtro é `"Logística"` — com acento e L maiúsculo.

Aceita nulo quando o fundo não tem segmento no cadastro. Como o filtro é por igualdade
exata, esses registros já ficam de fora automaticamente.

### `Tipo_Fundo_Classe`

Valores: "Fundo" e "Classe".

O mesmo CNPJ pode aparecer em várias linhas quando o fundo tem classes de cotas diferentes, e
os nomes divergem entre elas — vi "LOGINVEST FUNDO DE INVESTIMENTO IMOBILIÁRIO INDUSTRIAL" e
"LOGINVEST FII INDUSTRIAL DE RESPONSABILIDADE LIMITADA" como registros separados. Por isso a
deduplicação tem que ser por CNPJ.



## Tabela `complemento` (trimestral)

**Vencimento de contratos.** Campos com prefixo `Percentual_Vencimento_Receita_FII_Faixa_`,
nas faixas: até 3 meses, 3a6, 6a9, 9a12, 12a15, 15a18, 18a21, 21a24, 24a27, 27a30, 30a33,
33a36, acima de 36, e indeterminado. Existe conjunto equivalente com prefixo
`Percentual_Vencimento_Valor_Total_Faixa_`.

Serve como indicador antecedente: receita com vencimento próximo é risco de vacância futura.

**Indexadores.** `Percentual_Indexador_Receita_FII_IGPM`, `_IPCA`, `_INCC`, `_INPC`, com
conjunto equivalente para `Valor_Total`. Mostra por qual índice os contratos são reajustados.



## Observações para o tratamento

**Tipagem.** O dicionário oficial marca os campos numéricos como nvarchar, mas esse é o
tipo no banco de origem da CVM. No CSV os valores vêm com ponto decimal e o pandas
os converte para float automaticamente. Verificar o dtype a cada leitura, sem assumir.

**Decimal.** Valores usam vírgula como separador decimal. Precisa trocar por ponto antes de
converter.

**Duplicidade.** Registros "Fundo" e "Classe" para o mesmo CNPJ. Ver DA-08.

**Nulos.** `Segmento_Atuacao` aceita nulo. Os demais campos ainda não foram avaliados.

**Escala:** os campos percentuais (Percentual_Vacancia, Percentual_Locado,
Percentual_Inadimplencia, Percentual_Receitas_FII) vêm em escala decimal, de 0 a 1.
Multiplicar por 100 para apresentação.

Preenchimento: Percentual_Locado tem 97,7% de nulos na amostra de 2025 e não é
utilizável. Os demais percentuais têm cerca de 6% de nulos.



## Campos derivados

Preencher conforme os indicadores forem criados na Silver e na Gold.

| Campo | Fórmula | Camada | Por quê |
|---|---|---|---|
| | | | |


| Taxa_Ocupacao | 1 − Percentual_Vacancia | Silver | Percentual_Locado inutilizável (97,7% vazio) |
| Area_Vaga_m2 | Area × Percentual_Vacancia | Silver | Permite soma entre imóveis de tamanhos distintos |
| Area_Locada_m2 | Area × Taxa_Ocupacao | Silver | Idem |
| Trimestre | trimestre de Data_Referencia | Silver | Organização da série temporal |


| vacancia_ponderada | SUM(Area_Vaga_m2) / SUM(Area) | Gold | Vacância do conjunto, com peso proporcional à área de cada imóvel |


Verificação de datas por fundo e trimestre: 1 caso — fundo 13.012.312/0001-67,
1º trimestre de 2023, datas 31/01 e 31/03, 1 registro em cada. Regra aplicada:
manter a data mais recente de cada fundo no trimestre (DA-24). Gold refeita com
agrupamento por ano e trimestre.


## gold/vacancia_segmento_trimestral.parquet

Granularidade: uma linha por trimestre, segmento logístico inteiro.
Origem: silver/imoveis, notebook 03 (SQL no DuckDB). Alinhamento temporal: DA-24.

| Campo                  | Tipo            | Descrição                                              | Regra de cálculo                      |
|------------------------|-----------------|--------------------------------------------------------|---------------------------------------|
| ano                    | inteiro         | Ano de referência                                      | Partição ano=AAAA da Silver           |
| Trimestre              | inteiro (1 a 4) | Trimestre do ano                                       | Vem da Silver                         |
| periodo                | texto           | Rótulo do período (ex.: 2023-T1)                       | ano + "-T" + Trimestre                |
| qtd_fundos             | inteiro         | Fundos com imóveis aprovados no trimestre              | COUNT(DISTINCT CNPJ_Fundo_Classe)     |
| qtd_registros          | inteiro         | Registros de imóvel usados no trimestre                | COUNT(*) após filtro da data recente  |
| area_total_m2          | decimal         | Área total dos imóveis, em m²                          | SUM(Area)                             |
| area_vaga_m2           | decimal         | Área vaga total, em m²                                 | SUM(Area_Vaga_m2)                     |
| vacancia_ponderada     | decimal (0 a 1) | Vacância ponderada pela área; indicador central        | SUM(Area_Vaga_m2) / SUM(Area)         |
| vacancia_media_simples | decimal (0 a 1) | Média simples da vacância dos imóveis; só comparação   | AVG(Percentual_Vacancia)              |

| Campo          | Tipo            | Descrição                          | Regra de cálculo                                      |
|----------------|-----------------|------------------------------------|-------------------------------------------------------|
| Trimestre      | inteiro (1 a 4) | Trimestre de referência do informe | Extraído de Data_Referencia (pd.to_datetime)          |
| Taxa_Ocupacao  | decimal (0 a 1) | Fração da área ocupada             | 1 − Percentual_Vacancia (DA-14)                       |
| Area_Vaga_m2   | decimal         | Área vaga do imóvel, em m²         | Area × Percentual_Vacancia                            |
| Area_Locada_m2 | decimal         | Área ocupada do imóvel, em m²      | Area × Taxa_Ocupacao                                  |

Dicionário de dados (campos derivados da Silver, pendentes desde 24/09):
| Campo          | Tipo            | Descrição                          | Regra de cálculo                                      |
|----------------|-----------------|------------------------------------|-------------------------------------------------------|
| Trimestre      | inteiro (1 a 4) | Trimestre de referência do informe | Extraído de Data_Referencia (pd.to_datetime)          |
| Taxa_Ocupacao  | decimal (0 a 1) | Fração da área ocupada             | 1 − Percentual_Vacancia (DA-14)                       |
| Area_Vaga_m2   | decimal         | Área vaga do imóvel, em m²         | Area × Percentual_Vacancia                            |
| Area_Locada_m2 | decimal         | Área ocupada do imóvel, em m²      | Area × Taxa_Ocupacao                                  |

Dicionário de dados (correção do texto sobre separador decimal):
Nos CSVs da CVM, o separador decimal é ponto e o pandas lê os campos numéricos
diretamente como float64. O tipo nvarchar do dicionário oficial refere-se ao
armazenamento no banco da CVM, não ao arquivo publicado. Percentuais estão em
escala decimal (0 a 1


## gold/vacancia_fundo_trimestral.parquet

Granularidade: uma linha por fundo por trimestre.
Origem: view imoveis_trimestre (Silver com a regra da DA-24), notebook 03.

| Campo              | Tipo            | Descrição                                        | Regra de cálculo              |
|--------------------|-----------------|--------------------------------------------------|-------------------------------|
| CNPJ_Fundo_Classe  | texto           | CNPJ do fundo (identificador, DA-08 e DA-26)     | Vem da Silver                 |
| ano                | inteiro         | Ano de referência                                | Partição ano=AAAA da Silver   |
| Trimestre          | inteiro (1 a 4) | Trimestre do ano                                 | Vem da Silver                 |
| periodo            | texto           | Rótulo do período (ex.: 2023-T1)                 | ano + "-T" + Trimestre        |
| qtd_registros      | inteiro         | Imóveis do fundo no trimestre                    | COUNT(*)                      |
| area_total_m2      | decimal         | Área total dos imóveis do fundo, em m²           | SUM(Area)                     |
| area_vaga_m2       | decimal         | Área vaga dos imóveis do fundo, em m²            | SUM(Area_Vaga_m2)             |
| vacancia_ponderada | decimal (0 a 1) | Vacância do fundo ponderada pela área            | SUM(Area_Vaga_m2) / SUM(Area) |


## gold/projecao_vacancia_trimestral.parquet

Granularidade: uma linha por trimestre projetado (horizonte de 4 trimestres).
Origem: gold/vacancia_segmento_trimestral, notebook 05. Método: DA-13.

| Campo              | Tipo            | Descrição                                     | Regra de cálculo                          |
|--------------------|-----------------|-----------------------------------------------|-------------------------------------------|
| ano                | inteiro         | Ano do trimestre projetado                    | Sequência a partir do último observado    |
| Trimestre          | inteiro (1 a 4) | Trimestre projetado                           | Sequência a partir do último observado    |
| periodo            | texto           | Rótulo do período (ex.: 2026-T3)              | ano + "-T" + Trimestre                    |
| vacancia_projetada | decimal (0 a 1) | Vacância ponderada projetada                  | Média dos 4 últimos trimestres observados |
| limite_inferior    | decimal (0 a 1) | Limite inferior da faixa de erro              | vacancia_projetada − MAE, mínimo 0        |
| limite_superior    | decimal (0 a 1) | Limite superior da faixa de erro              | vacancia_projetada + MAE                  |
| metodo             | texto           | Método de projeção utilizado                  | Fixo: "Média móvel de 4 trimestres"       |

Observação: a faixa de erro é o erro absoluto médio observado no teste
(holdout dos 4 últimos trimestres), não um intervalo de confiança estatístico.