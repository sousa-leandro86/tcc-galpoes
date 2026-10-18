# Dicionário de dados

Estrutura dos dados usados no projeto. A parte das camadas Silver e Gold está resumida no
Apêndice A da monografia; aqui fica a versão completa, com os campos de origem da CVM.
Atualizado em 16/10/2026: corrigi o que tinha escrito antes da execução sobre tipagem e
separador decimal, juntei os campos derivados numa tabela só e incluí Silver e quarentena.



## Origem

Informes Mensal e Trimestral Estruturados de FII, publicados pela CVM no portal de Dados
Abertos. Base normativa: Instrução CVM 571/2015, anexos 39-I (mensal) e 39-II (trimestral).
Envio pelo sistema Fundos.NET. Os valores são declarados pelo administrador de cada fundo
(Instrução CVM 472, art. 39) e publicados pela CVM, que não os calcula nem os audita.

Período coletado: 2020 a 2026. Distribuição em ZIP anual com vários CSV dentro.

Parâmetros de leitura, confirmados na prática:

| Parâmetro | Valor |
|---|---|
| Separador de colunas | `;` |
| Codificação | `latin-1` (com `utf-8` os acentos quebram) |
| Separador decimal | `.` (ponto); o pandas lê os campos numéricos diretamente como `float64` |
| Escala dos percentuais | decimal, de 0 a 1 |



## Tabelas do informe mensal

| Tabela | Conteúdo |
|---|---|
| `geral` | Cadastro do fundo, endereço, administrador, segmento |
| `ativo_passivo` | Estrutura patrimonial, em valores financeiros |
| `complemento` | Patrimônio líquido, valor da cota, cotistas, rentabilidade |

Não contém área nem vacância. É um retrato financeiro, não físico. **Não utilizado no
pipeline.**

Campos de interesse em `ativo_passivo` (para trabalhos futuros): `Contas_Receber_Aluguel`,
`Imoveis_Renda_Acabados`, `Imoveis_Renda_Construcao`, `Total_Investido`. Todos
consolidados por fundo, não por imóvel.



## Tabelas do informe trimestral

| Tabela | Uso no projeto |
|---|---|
| `imovel` | **Fonte central**: área e vacância por imóvel |
| `geral` | Seleção dos fundos logísticos |
| `complemento` | Não utilizada nesta versão (vencimento de contratos e indexadores; trabalho futuro) |
| `imovel_renda_acabado_inquilino` | Não utilizada (setor do locatário, participação na receita) |
| `imovel_renda_acabado_contrato` | Não utilizada (características contratuais em texto livre) |
| `rentabilidade_efetiva` | Não utilizada |
| `resultado_contabil_financeiro` | Não utilizada |
| `aquisicao_imovel`, `alienacao_imovel` | Não utilizadas (movimentações do portfólio) |
| `ativo`, `ativo_garantia_rentabilidade`, `direito` | Não utilizadas |
| `terreno`, `aquisicao_terreno`, `alienacao_terreno` | Não utilizadas |
| `imovel_desempenho` | Não utilizada |



## Chaves

`CNPJ_Fundo_Classe` (varchar 18) e `Data_Referencia` (date, AAAA-MM-DD) aparecem em todas as
tabelas dos dois informes. A combinação das duas é o que permite relacionar as tabelas.

Existe também `Versao` (tinyint), relevante quando um informe é reapresentado. No período
estudado, nenhum informe (fundo × trimestre) apresentou mais de uma versão.

Exceção: o arquivo de 2020 usa `CNPJ_Fundo` e `Nome_Fundo`; os nomes são harmonizados na
carga (DA-18).

A CVM não fornece identificador único de imóvel; `Nome_Imovel` é texto livre.



## Tabela `imovel` (trimestral) — campos de origem

Uma linha por imóvel, por trimestre. A coluna "Tipo na CVM" é o tipo declarado no
dicionário oficial, que se refere ao banco de dados da CVM; no CSV publicado, os campos
numéricos vêm com ponto decimal e são lidos como número.

| Campo | Tipo na CVM | Descrição |
|---|---|---|
| `CNPJ_Fundo_Classe` | varchar(18) | Fundo dono do imóvel |
| `Data_Referencia` | date | Data de referência do informe |
| `Versao` | tinyint | Versão do informe |
| `Nome_Imovel` | varchar(255) | Nome do imóvel (texto livre) |
| `Endereco` | varchar(255) | Endereço (texto livre) |
| `Classe` | varchar(32) | Classificação do imóvel (renda/venda, acabado/em construção) |
| `Area` | nvarchar(4000) | Área em m² |
| `Numero_Unidades` | int | Quantidade de unidades |
| `Percentual_Locado` | nvarchar(4000) | Percentual locado (previsto no formulário só para imóveis em construção) |
| `Percentual_Vacancia` | nvarchar(4000) | Percentual de vacância (base física ou financeira não declarada; ver DA-35) |
| `Percentual_Inadimplencia` | nvarchar(4000) | Percentual de inadimplência |
| `Percentual_Receitas_FII` | nvarchar(4000) | Peso do imóvel na receita do fundo |
| `Percentual_Imovel_Total_Investido` | nvarchar(4000) | Peso no total investido |
| `Percentual_Vendido` | nvarchar(4000) | Percentual vendido |
| `Custo_Construcao_Realizado` | nvarchar(4000) | Custo realizado |
| `Custo_Construcao_Previsto` | nvarchar(4000) | Custo previsto |
| `Percentual_Conclusao_Obras_Realizado` | nvarchar(4000) | Andamento de obra realizado |
| `Percentual_Conclusao_Obras_Previsto` | nvarchar(4000) | Andamento de obra previsto |
| `Outras_Caracteristicas_Relevantes` | varchar(max) | Texto livre |

Valores de `Classe`: Imóveis para renda acabados; Imóveis para renda em construção;
Imóveis para venda acabados; Imóveis para venda em construção. O estudo usa só o
primeiro (DA-19).



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

O valor usado no filtro é `"Logística"`, com acento e L maiúsculo (DA-07).

Aceita nulo quando o fundo não tem segmento no cadastro. Como o filtro é por igualdade
exata, esses registros ficam de fora automaticamente (DA-12).

### `Tipo_Fundo_Classe`

Valores: "Fundo" e "Classe".

O mesmo CNPJ pode aparecer em várias linhas quando o fundo tem classes de cotas diferentes, e
os nomes divergem entre elas. Vi "LOGINVEST FUNDO DE INVESTIMENTO IMOBILIÁRIO INDUSTRIAL" e
"LOGINVEST FII INDUSTRIAL DE RESPONSABILIDADE LIMITADA" como registros separados. Por isso a
identificação e a contagem de fundos são feitas por CNPJ (DA-08).



## Tabela `complemento` (trimestral) — não utilizada nesta versão

**Vencimento de contratos.** Campos com prefixo `Percentual_Vencimento_Receita_FII_Faixa_`,
nas faixas: até 3 meses, 3a6, 6a9, 9a12, 12a15, 15a18, 18a21, 21a24, 24a27, 27a30, 30a33,
33a36, acima de 36, e indeterminado. Existe conjunto equivalente com prefixo
`Percentual_Vencimento_Valor_Total_Faixa_`.

Potencial indicador antecedente: receita com vencimento próximo é risco de vacância futura.

**Indexadores.** `Percentual_Indexador_Receita_FII_IGPM`, `_IPCA`, `_INCC`, `_INPC`, com
conjunto equivalente para `Valor_Total`. Mostra por qual índice os contratos são reajustados.



## Observações para o tratamento

**Tipagem.** O dicionário oficial marca os campos numéricos como nvarchar, mas esse é o
tipo no banco de origem da CVM. No CSV os valores vêm com ponto decimal e o pandas
os converte para float automaticamente. Verificar o dtype a cada leitura, sem assumir.

**Escala.** Os campos percentuais (Percentual_Vacancia, Percentual_Locado,
Percentual_Inadimplencia, Percentual_Receitas_FII) vêm em escala decimal, de 0 a 1.
A conversão para % é feita só na apresentação (DA-28).

**Preenchimento (2025, fundos logísticos, 1.640 registros).** `Area` sem nulos;
`Percentual_Locado` 97,7% de nulos (inutilizável; ver DA-14); `Percentual_Vacancia` e
`Percentual_Inadimplencia` 6,2%; `Percentual_Receitas_FII` 6,6%. Após o recorte de escopo
(DA-19), restou 1 registro sem vacância: a ausência era estrutural, concentrada nas classes
em construção e à venda.

**Duplicidade.** Registros "Fundo" e "Classe" para o mesmo CNPJ na tabela `geral` (DA-08).
Na tabela `imovel`, zero duplicatas exatas.

**Datas de referência.** Os fundos usam o último dia útil ou o último dia do calendário como
data de fechamento, além de datas fora do padrão. As agregações usam ano + trimestre e, quando
um fundo tem duas datas no mesmo trimestre, a mais recente (DA-24). Um caso no período:
fundo 13.012.312/0001-67, 2023-T1, datas 31/01 e 31/03, mesmo imóvel.



## silver/imoveis/ (Parquet particionado por `ano=AAAA/`)

Granularidade: um registro por imóvel por trimestre. 5.607 registros, 17 colunas
(16 nos arquivos + `ano`, que vem da pasta). Origem: notebook 02.

| Campo | Tipo (Parquet / Athena) | Descrição |
|---|---|---|
| `CNPJ_Fundo_Classe` | string | Fundo dono do imóvel |
| `Data_Referencia` | timestamp | Data de referência do informe |
| `Trimestre` | int | Trimestre de referência (1 a 4) |
| `Versao` | bigint | Versão do informe |
| `Nome_Imovel` | string | Nome do imóvel |
| `Endereco` | string | Endereço |
| `Classe` | string | Sempre "Imóveis para renda acabados" |
| `Area` | double | Área em m² |
| `Numero_Unidades` | double | Quantidade de unidades |
| `Percentual_Vacancia` | double | Vacância (0 a 1) |
| `Taxa_Ocupacao` | double | Derivada (ver abaixo) |
| `Area_Vaga_m2` | double | Derivada (ver abaixo) |
| `Area_Locada_m2` | double | Derivada (ver abaixo) |
| `Percentual_Inadimplencia` | double | Inadimplência (0 a 1) |
| `Percentual_Receitas_FII` | double | Peso na receita do fundo (0 a 1) |
| `Percentual_Imovel_Total_Investido` | double | Peso no total investido (0 a 1) |
| `ano` | bigint | Partição |



## Campos derivados

| Campo | Fórmula | Camada | Por quê |
|---|---|---|---|
| `Trimestre` | Trimestre de `Data_Referencia` (pd.to_datetime) | Silver | Organização da série temporal |
| `Taxa_Ocupacao` | 1 − `Percentual_Vacancia` | Silver | `Percentual_Locado` inutilizável (DA-14) |
| `Area_Vaga_m2` | `Area` × `Percentual_Vacancia` | Silver | Permite somar imóveis de tamanhos distintos; estimativa sob a premissa da DA-35 |
| `Area_Locada_m2` | `Area` × `Taxa_Ocupacao` | Silver | Idem |
| `periodo` | ano + "-T" + Trimestre | Gold | Rótulo do período |
| `vacancia_ponderada` | SUM(`Area_Vaga_m2`) / SUM(`Area`) | Gold | Vacância do conjunto, com peso proporcional à área de cada imóvel |
| `vacancia_media_simples` | AVG(`Percentual_Vacancia`) | Gold | Apenas para comparação com a ponderada |

Teste de sanidade na Silver: `Area_Vaga_m2` + `Area_Locada_m2` − `Area` com diferença
máxima de 5,8e-11 (arredondamento).



## quarentena/imoveis.parquet

130 registros rejeitados pelas regras de qualidade (DA-16, DA-20), com as colunas de origem
e a coluna `motivo_quarentena`, que acumula o código de todas as regras violadas.

| Código | Regra | Registros no período |
|---|---|---|
| `area_ausente` | Área nula | 0 |
| `area_zero` | Área igual a 0 | 106 |
| `area_acima_limite` | Área > 1.000.000 m² | 23 |
| `vacancia_ausente` | Vacância nula | 1 |
| `vacancia_fora_faixa` | Vacância fora de 0 a 1 | 0 |



## gold/vacancia_segmento_trimestral.parquet

Granularidade: uma linha por trimestre, segmento logístico inteiro (26 linhas).
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



## gold/vacancia_fundo_trimestral.parquet

Granularidade: uma linha por fundo por trimestre (892 linhas).
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



## Tabelas no catálogo do Athena (banco tcc_galpoes, AwsDataCatalog, us-east-1)

| Tabela no Athena                   | Local no S3                                  | Origem local                                   |
|------------------------------------|----------------------------------------------|------------------------------------------------|
| silver_imoveis (partição: ano)     | silver/imoveis/                              | dados/silver/imoveis/                          |
| gold_vacancia_segmento_trimestral  | gold/vacancia_segmento_trimestral/           | dados/gold/vacancia_segmento_trimestral.parquet|
| gold_vacancia_fundo_trimestral     | gold/vacancia_fundo_trimestral/              | dados/gold/vacancia_fundo_trimestral.parquet   |
| gold_projecao_vacancia_trimestral  | gold/projecao_vacancia_trimestral/           | dados/gold/projecao_vacancia_trimestral.parquet|
| quarentena_imoveis                 | quarentena/imoveis/                          | dados/quarentena/imoveis.parquet               |

Observações: no Athena, os nomes de colunas aparecem em minúsculas. A tabela
quarentena_imoveis declara só as colunas de auditoria (cnpj_fundo_classe,
nome_imovel, classe, area, percentual_vacancia, ano, motivo_quarentena).

| Objeto no Athena                         | Tipo   | Local no S3                                   | Origem                                     |
|------------------------------------------|--------|-----------------------------------------------|--------------------------------------------|
| imoveis_trimestre                        | view   | (não tem; é só a consulta salva)              | silver_imoveis com a regra da DA-24        |
| gold_vacancia_segmento_trimestral_nuvem  | tabela | gold_nuvem/vacancia_segmento_trimestral/      | CTAS no Athena (03_gold_na_nuvem.sql)      |
| gold_vacancia_fundo_trimestral_nuvem     | tabela | gold_nuvem/vacancia_fundo_trimestral/         | CTAS no Athena (03_gold_na_nuvem.sql)      |

Colunas iguais às das Gold correspondentes enviadas do ambiente local.
