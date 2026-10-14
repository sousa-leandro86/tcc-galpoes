-- Arquivo: src/athena/03_gold_na_nuvem.sql
-- Objetivo: executar a transformação Silver → Gold na nuvem (view com a regra da DA-24 + CTAS) e validar contra a Gold local
-- Entrada: tcc_galpoes.silver_imoveis (s3://tcc-galpoes-leandro-2026/silver/imoveis/)
-- Saída: tabelas gold_*_nuvem em s3://tcc-galpoes-leandro-2026/gold_nuvem/ + resultados de validação
-- Onde roda: AWS Athena, us-east-1 (AWS Academy Learner Lab) — Camada Silver → Gold

-- Bloco 1: view com a regra de alinhamento temporal (DA-24), centralizada
-- como na DA-25. Para cada fundo e trimestre, só entram os registros da data
-- de referência mais recente. A view não grava dados: é uma consulta salva.
CREATE OR REPLACE VIEW tcc_galpoes.imoveis_trimestre AS
WITH ultima_data AS (
    SELECT cnpj_fundo_classe, ano, trimestre, MAX(data_referencia) AS data_max
    FROM tcc_galpoes.silver_imoveis
    GROUP BY cnpj_fundo_classe, ano, trimestre
)
SELECT s.*,
       CAST(s.ano AS VARCHAR) || '-T' || CAST(s.trimestre AS VARCHAR) AS periodo
FROM tcc_galpoes.silver_imoveis AS s
JOIN ultima_data AS u
  ON  s.cnpj_fundo_classe = u.cnpj_fundo_classe
  AND s.ano              = u.ano
  AND s.trimestre        = u.trimestre
  AND s.data_referencia  = u.data_max;

-- Bloco 2: Gold 1 gerada na nuvem (segmento por trimestre). O CTAS executa a
-- agregação e grava o resultado em Parquet numa pasta nova, separada da Gold
-- enviada do ambiente local, para permitir a comparação.
CREATE TABLE tcc_galpoes.gold_vacancia_segmento_trimestral_nuvem
WITH (
    format = 'PARQUET',
    external_location = 's3://tcc-galpoes-leandro-2026/gold_nuvem/vacancia_segmento_trimestral/'
) AS
SELECT ano, trimestre, periodo,
       COUNT(DISTINCT cnpj_fundo_classe) AS qtd_fundos,
       COUNT(*)                          AS qtd_registros,
       SUM(area)                         AS area_total_m2,
       SUM(area_vaga_m2)                 AS area_vaga_m2,
       SUM(area_vaga_m2) / SUM(area)     AS vacancia_ponderada,
       AVG(percentual_vacancia)          AS vacancia_media_simples
FROM tcc_galpoes.imoveis_trimestre
GROUP BY ano, trimestre, periodo;

-- Bloco 3: Gold 2 gerada na nuvem (fundo por trimestre), mesma lógica,
-- agrupando também pelo CNPJ.
CREATE TABLE tcc_galpoes.gold_vacancia_fundo_trimestral_nuvem
WITH (
    format = 'PARQUET',
    external_location = 's3://tcc-galpoes-leandro-2026/gold_nuvem/vacancia_fundo_trimestral/'
) AS
SELECT cnpj_fundo_classe, ano, trimestre, periodo,
       COUNT(*)                      AS qtd_registros,
       SUM(area)                     AS area_total_m2,
       SUM(area_vaga_m2)             AS area_vaga_m2,
       SUM(area_vaga_m2) / SUM(area) AS vacancia_ponderada
FROM tcc_galpoes.imoveis_trimestre
GROUP BY cnpj_fundo_classe, ano, trimestre, periodo;

-- Bloco 4: valida a Gold 1 da nuvem contra a Gold 1 local. Conta as linhas da
-- nuvem, quantos trimestres casam entre as duas, quantos têm contagens
-- diferentes e a maior diferença nas vacâncias.
SELECT
    (SELECT COUNT(*) FROM tcc_galpoes.gold_vacancia_segmento_trimestral_nuvem) AS linhas_nuvem,
    COUNT(*)                                                                    AS trimestres_casados,
    SUM(CASE WHEN n.qtd_fundos    <> l.qtd_fundos
              OR n.qtd_registros <> l.qtd_registros THEN 1 ELSE 0 END)          AS contagens_divergentes,
    MAX(ABS(n.vacancia_ponderada     - l.vacancia_ponderada))                   AS dif_max_ponderada,
    MAX(ABS(n.vacancia_media_simples - l.vacancia_media_simples))               AS dif_max_simples
FROM tcc_galpoes.gold_vacancia_segmento_trimestral_nuvem AS n
JOIN tcc_galpoes.gold_vacancia_segmento_trimestral       AS l
  ON n.ano = l.ano AND n.trimestre = l.trimestre;

-- Bloco 5: valida a Gold 2 da nuvem contra a Gold 2 local, casando por fundo,
-- ano e trimestre.
SELECT
    (SELECT COUNT(*) FROM tcc_galpoes.gold_vacancia_fundo_trimestral_nuvem) AS linhas_nuvem,
    COUNT(*)                                                                AS linhas_casadas,
    SUM(CASE WHEN n.qtd_registros <> l.qtd_registros THEN 1 ELSE 0 END)     AS contagens_divergentes,
    MAX(ABS(n.area_vaga_m2       - l.area_vaga_m2))                         AS dif_max_area_vaga,
    MAX(ABS(n.vacancia_ponderada - l.vacancia_ponderada))                   AS dif_max_ponderada
FROM tcc_galpoes.gold_vacancia_fundo_trimestral_nuvem AS n
JOIN tcc_galpoes.gold_vacancia_fundo_trimestral       AS l
  ON  n.cnpj_fundo_classe = l.cnpj_fundo_classe
  AND n.ano = l.ano AND n.trimestre = l.trimestre;