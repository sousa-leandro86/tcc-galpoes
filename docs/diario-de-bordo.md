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


## [29/08/2026]
Identificado que a tabela geral pode conter registros duplicados por CNPJ quando o fundo possui classes de cotas (Tipo_Fundo_Classe = Fundo/Classe). 
Será necessário tratamento na camada Silver para evitar dupla contagem.


## [29/08/2026]
Aberto o CSV `geral` do informe trimestral 2025 (4577 linhas, 39 colunas).
Extraídos os valores únicos de `Segmento_Atuacao`: Shoppings, Híbrido, Outros,
Lajes Corporativas, Escritórios, Multicategoria, nan, Educacional, Logística,
Hospital, Títulos e Val. Mob., Hotel, Residencial, Varejo.

Confirmado o valor exato usado pela CVM para o segmento de interesse: "Logística"
(com acento). Decidido excluir "Multicategoria" e "Híbrido" do filtro inicial,
para manter o recorte limpo — fundos puramente logísticos.

Identificado que `Tipo_Fundo_Classe` pode duplicar o mesmo CNPJ (registros
"Fundo" e "Classe" separados) — requer tratamento na Silver para não contar
duas vezes.

## [29/08/2026]
Aplicado filtro `Segmento_Atuacao == 'Logística'` no CSV `geral` do
Informe Trimestral 2025. Resultado: 299 linhas, correspondendo a 100
CNPJs (fundos) distintos. Nomes de fundos confirmam a suspeita de
duplicação por `Tipo_Fundo_Classe` (ex.: "LOGINVEST FUNDO DE
INVESTIMENTO IMOBILIÁRIO INDUSTRIAL" e "LOGINVEST FII INDUSTRIAL DE
RESPONSABILIDADE LIMITADA" parecem ser o mesmo fundo em registros
Fundo/Classe separados). CNPJ será a chave de deduplicação na Silver,
não o nome.