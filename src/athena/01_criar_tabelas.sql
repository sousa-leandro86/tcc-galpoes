-- Arquivo: src/athena/01_criar_tabelas.sql
-- Objetivo: registrar no Glue Data Catalog as tabelas Silver, Gold e Quarentena que apontam para o S3
-- Entrada: s3://tcc-galpoes-leandro-2026/silver/, gold/ e quarentena/ (Parquet enviados do ambiente local)
-- Saída: banco tcc_galpoes no AwsDataCatalog, com tabelas externas
-- Onde roda: AWS Athena, us-east-1 (AWS Academy Learner Lab) — Camadas Silver, Gold e Quarentena

-- Bloco 1: cria o banco (agrupador lógico das tabelas no catálogo).
-- IF NOT EXISTS permite rodar de novo sem erro.
CREATE DATABASE IF NOT EXISTS tcc_galpoes;

-- Bloco 2: Silver. Tipos copiados do esquema lido no notebook 03. A coluna ano
-- não está nos arquivos; vem do nome das pastas, por isso é declarada em
-- PARTITIONED BY, e não na lista de colunas.
CREATE EXTERNAL TABLE IF NOT EXISTS tcc_galpoes.silver_imoveis (
    cnpj_fundo_classe                 string,
    data_referencia                   timestamp,
    trimestre                         int,
    versao                            bigint,
    nome_imovel                       string,
    endereco                          string,
    classe                            string,
    area                              double,
    numero_unidades                   double,
    percentual_vacancia               double,
    taxa_ocupacao                     double,
    area_vaga_m2                      double,
    area_locada_m2                    double,
    percentual_inadimplencia          double,
    percentual_receitas_fii           double,
    percentual_imovel_total_investido double
)
PARTITIONED BY (ano bigint)
STORED AS PARQUET
LOCATION 's3://tcc-galpoes-leandro-2026/silver/imoveis/';

-- Bloco 3: varre as pastas ano=2020 … ano=2026 e registra cada partição no
-- catálogo. Sem este passo, a tabela existe mas retorna zero linhas.
MSCK REPAIR TABLE tcc_galpoes.silver_imoveis;

-- Bloco 4: Gold 1 (segmento por trimestre). Cada tabela aponta para a pasta
-- exclusiva dela no S3.
CREATE EXTERNAL TABLE IF NOT EXISTS tcc_galpoes.gold_vacancia_segmento_trimestral (
    ano                    bigint,
    trimestre              int,
    periodo                string,
    qtd_fundos             bigint,
    qtd_registros          bigint,
    area_total_m2          double,
    area_vaga_m2           double,
    vacancia_ponderada     double,
    vacancia_media_simples double
)
STORED AS PARQUET
LOCATION 's3://tcc-galpoes-leandro-2026/gold/vacancia_segmento_trimestral/';

-- Bloco 5: Gold 2 (fundo por trimestre).
CREATE EXTERNAL TABLE IF NOT EXISTS tcc_galpoes.gold_vacancia_fundo_trimestral (
    cnpj_fundo_classe  string,
    ano                bigint,
    trimestre          int,
    periodo            string,
    qtd_registros      bigint,
    area_total_m2      double,
    area_vaga_m2       double,
    vacancia_ponderada double
)
STORED AS PARQUET
LOCATION 's3://tcc-galpoes-leandro-2026/gold/vacancia_fundo_trimestral/';

-- Bloco 6: projeção (notebook 05). Inteiros declarados como bigint, o tipo
-- mais largo, porque a tabela foi montada em Python e a saída do esquema
-- foi cortada antes de mostrá-la.
CREATE EXTERNAL TABLE IF NOT EXISTS tcc_galpoes.gold_projecao_vacancia_trimestral (
    ano                bigint,
    trimestre          bigint,
    periodo            string,
    vacancia_projetada double,
    limite_inferior    double,
    limite_superior    double,
    metodo             string
)
STORED AS PARQUET
LOCATION 's3://tcc-galpoes-leandro-2026/gold/projecao_vacancia_trimestral/';

-- Bloco 7: quarentena. Declara só as colunas usadas na auditoria; o Athena
-- lê o Parquet pelo nome da coluna, então as demais são ignoradas sem erro.
CREATE EXTERNAL TABLE IF NOT EXISTS tcc_galpoes.quarentena_imoveis (
    cnpj_fundo_classe   string,
    nome_imovel         string,
    classe              string,
    area                double,
    percentual_vacancia double,
    ano                 bigint,
    motivo_quarentena   string
)
STORED AS PARQUET
LOCATION 's3://tcc-galpoes-leandro-2026/quarentena/imoveis/';