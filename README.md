# TCC — Análise de Vacância e Ocupação de Galpões Logísticos

Especialização em Engenharia de Dados e Big Data — PECE/Poli-USP

## Objetivo
Aplicar técnicas de tratamento e feature engineering sobre dados históricos de
aluguéis e características operacionais de galpões logísticos, integrados via
pipeline em camadas (Bronze/Silver/Gold), gerando indicadores de vacância e
ocupação e uma série temporal analítica.

## Fonte de dados
Informes públicos de FIIs logísticos (CVM), 2020–2026.

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
