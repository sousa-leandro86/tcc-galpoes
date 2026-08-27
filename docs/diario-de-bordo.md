## 2026-08-18 — Setup inicial do ambiente local

**Decisão:** Estrutura de pastas criada manualmente em C:\dev\projetos\tcc-galpoes 
(Windows Explorer, botão direito → Novo → Pasta); ambiente virtual .venv 
configurado com pandas, pyarrow, duckdb, scikit-learn, matplotlib, seaborn, 
ipykernel e openpyxl.

**Por quê:** Isolar as dependências do projeto do Python global da máquina, 
evitando conflito de versão com outros projetos; as bibliotecas escolhidas 
cobrem toda a cadeia Bronze → Silver → Gold e a fase de modelagem, sem 
excesso de dependências não usadas.

**Camada / onde roda:** Local (.venv) — etapa de preparação de ambiente, 
anterior à ingestão da camada Bronze.

**Arquivo(s) relacionado(s):** Estrutura de pastas C:\dev\projetos\tcc-galpoes