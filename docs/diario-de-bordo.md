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


Informe Mensal analisado via dicionário oficial da CVM. Constatado que não contém dados de área nem vacância — apenas informações financeiras e cadastrais. 
Vacância deverá ser obtida do Informe Trimestral. Identificado o campo Segmento_Atuacao como critério objetivo de seleção dos fundos logísticos. 
Campos numéricos vêm como texto (nvarchar), exigindo conversão de tipos na camada Silver.


Dicionário do Informe Trimestral analisado. Confirmada a tabela imovel como fonte central: 
contém Area, Percentual_Locado, Percentual_Vacancia, Percentual_Inadimplencia e Percentual_Receitas_FII, na granularidade imóvel/trimestre. 
Vacância vem calculada pela CVM; o feature engineering se desloca para validação cruzada, conversão para área absoluta e ponderação por área. 
Identificado na tabela complemento o cronograma de vencimento de contratos por faixa e os indexadores de reajuste — potenciais variáveis explicativas.