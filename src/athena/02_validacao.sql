-- Arquivo: src/athena/02_validacao.sql
-- Objetivo: validar a migração comparando contagens e recalculando a Gold 1 no Athena a partir da Silver
-- Entrada: tabelas do banco tcc_galpoes (criadas pelo 01_criar_tabelas.sql)
-- Saída: resultados de conferência no editor do Athena (prints para a monografia)
-- Onde roda: AWS Athena, us-east-1 (AWS Academy Learner Lab) — Validação Silver e Gold

-- V1: a Silver na nuvem precisa ter os mesmos 5.607 registros e 7 anos do
-- ambiente local.
SELECT COUNT(*) AS registros, COUNT(DISTINCT ano) AS anos
FROM tcc_galpoes.silver_imoveis;

-- V2: tamanhos das tabelas Gold, iguais aos validados nos notebooks 03 e 05.
SELECT
    (SELECT COUNT(*)           FROM tcc_galpoes.gold_vacancia_segmento_trimestral) AS gold1_trimestres,
    (SELECT SUM(qtd_registros) FROM tcc_galpoes.gold_vacancia_segmento_trimestral) AS gold1_registros,
    (SELECT COUNT(*)           FROM tcc_galpoes.gold_vacancia_fundo_trimestral)    AS gold2_linhas,
    (SELECT COUNT(*)           FROM tcc_galpoes.gold_projecao_vacancia_trimestral) AS projecao_linhas;

-- V3: quarentena por motivo, a mesma distribuição registrada no notebook 02.
SELECT motivo_quarentena, COUNT(*) AS registros
FROM tcc_galpoes.quarentena_imoveis
GROUP BY motivo_quarentena
ORDER BY registros DESC;

-- V4: recalcula a Gold 1 dentro do Athena, a partir da Silver, com a mesma
-- regra da DA-24, e compara com a Gold 1 enviada pronta. Se a maior
-- diferença for praticamente zero, o SQL é portável e a nuvem reproduz o pipeline.
WITH ultima_data AS (
    SELECT cnpj_fundo_classe, ano, trimestre, MAX(data_referencia) AS data_max
    FROM tcc_galpoes.silver_imoveis
    GROUP BY cnpj_fundo_classe, ano, trimestre
),
imoveis_trimestre AS (
    SELECT s.*
    FROM tcc_galpoes.silver_imoveis AS s
    JOIN ultima_data AS u
      ON  s.cnpj_fundo_classe = u.cnpj_fundo_classe
      AND s.ano              = u.ano
      AND s.trimestre        = u.trimestre
      AND s.data_referencia  = u.data_max
),
gold_recalculada AS (
    SELECT ano, trimestre,
           COUNT(*)                      AS qtd_registros,
           SUM(area_vaga_m2) / SUM(area) AS vacancia_ponderada
    FROM imoveis_trimestre
    GROUP BY ano, trimestre
)
SELECT
    COUNT(*)                                             AS trimestres_comparados,
    SUM(r.qtd_registros)                                 AS registros_recalculados,
    MAX(ABS(r.vacancia_ponderada - g.vacancia_ponderada)) AS maior_diferenca
FROM gold_recalculada AS r
JOIN tcc_galpoes.gold_vacancia_segmento_trimestral AS g
  ON r.ano = g.ano AND r.trimestre = g.trimestre;