# TCC: Análise de Vacância e Ocupação de Galpões Logísticos

Especialização em Engenharia de Dados e Big Data, PECE/Poli-USP.
Autor: Leandro Pereira de Sousa. Orientador: Prof. Dr. Luiz Sérgio de Souza.

## Objetivo

Aplicar técnicas de tratamento e feature engineering sobre os informes trimestrais dos
fundos imobiliários do segmento logístico, para produzir variáveis consistentes que permitam
medir e acompanhar a vacância e a ocupação dos galpões. O pipeline em camadas
(Bronze, Silver, Gold e quarentena) é o meio que torna esse tratamento reproduzível.

## Fonte de dados

Informe Trimestral Estruturado de FII, publicado pela CVM no portal de Dados Abertos
(https://dados.cvm.gov.br/dados/FII/DOC/INF_TRIMESTRAL/DADOS/), de 2020 a 2026. São usadas
as tabelas `geral` (seleção dos fundos com segmento "Logística") e `imovel` (área e vacância
por imóvel). Os dados não estão no repositório: para reproduzir, baixe os ZIPs anuais e
coloque em `dados/bronze/cvm-inf-trimestral/`, sem descompactar.

## Como recriar o ambiente

Python 3.14. No PowerShell:

```
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

No Git Bash, a ativação é `source .venv/Scripts/activate`.

## Ordem de execução

| Notebook | Etapa | Saída |
|---|---|---|
| `01-inventario-dados.ipynb` | Inventário e diagnóstico de qualidade | só leitura |
| `02-bronze-para-silver.ipynb` | Carga dos sete anos, escopo, regras de qualidade, variáveis derivadas | `dados/silver/imoveis/`, `dados/quarentena/` |
| `03-silver-para-gold.ipynb` | Alinhamento temporal e agregações em SQL (DuckDB) | `dados/gold/` |
| `04-analise-exploratoria.ipynb` | Análise exploratória | `monografia/figuras/fig01` a `fig04` |
| `05-serie-temporal.ipynb` | Comparação de métodos e projeção | `dados/gold/projecao_vacancia_trimestral.parquet`, `fig05` |

Os scripts de `src/athena/` rodam no Amazon Athena, um bloco por vez, depois que as camadas
são enviadas ao S3:

- `01_criar_tabelas.sql`: banco `tcc_galpoes` e tabelas externas
- `02_validacao.sql`: conferência das camadas enviadas contra o ambiente local
- `03_gold_na_nuvem.sql`: Gold gerada no Athena por CTAS e comparação com a Gold local

## Estrutura

- `dados/`: camadas Bronze, Silver, Gold e quarentena (não versionado)
- `analises/`: notebooks numerados na ordem de execução
- `src/athena/`: SQL do Athena (catálogo, validação e Gold na nuvem)
- `scripts/`: rotinas administrativas (PowerShell)
- `dashboard/`: painel do Power BI exportado em PDF (o `.pbix` não é versionado, porque
  guarda cópia dos dados)
- `docs/`: diário de bordo, decisões arquiteturais e dicionário de dados
- `monografia/`: texto e figuras

## Ambiente de nuvem

AWS Academy Learner Lab (us-east-1): Amazon S3 para as camadas, AWS Glue Data Catalog para o
registro das tabelas e Amazon Athena para as consultas. O painel foi feito no Power BI
Desktop, conectado ao Athena por ODBC em modo de importação. As escolhas e os motivos estão
em `docs/decisoes-arquiteturais.md`.
