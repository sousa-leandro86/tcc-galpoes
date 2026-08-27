# TCC — Análise de Vacância e Ocupação de Galpões Logísticos

Especialização em Engenharia de Dados e Big Data — PECE/Poli-USP

## Objetivo
Arquitetura de dados em nuvem (Bronze/Silver/Gold) para coletar, tratar e
analisar dados históricos de aluguéis e ocupação de galpões logísticos,
gerando indicadores de vacância e previsão por série temporal.

## Fonte de dados
Informes públicos de FIIs logísticos (CVM), 2023–2025.

## Como recriar o ambiente
​```
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
​```

## Estrutura
- `dados/` — camadas Bronze, Silver, Gold e Quarentena (não versionado)
- `analises/` — notebooks numerados na ordem de execução
- `src/` — código Python reutilizável
- `scripts/` — rotinas administrativas (PowerShell)
- `docs/` — diário de bordo, dicionário de dados, decisões
- `monografia/` — texto e figuras