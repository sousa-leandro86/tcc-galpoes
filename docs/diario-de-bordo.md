# Diário de bordo — TCC galpões logísticos

Registro do que foi feito, quando e por quê. Base para o capítulo de Materiais e Métodos.
Início do projeto: 16/08/2026.

---

## 16/08/2026 — Escolha da fonte de dados

Procurei bases de contratos de locação e contas a receber de galpões no Kaggle e em outros
repositórios abertos. Não existe. Esse tipo de dado é contratual e nenhuma empresa publica.

Cheguei no portal de Dados Abertos da CVM. Os FIIs são obrigados a enviar informes periódicos
e a CVM disponibiliza tudo em CSV. Como existem FIIs do segmento logístico, dá para montar
uma base real de galpões a partir daí.

**Decisão:** usar os informes da CVM como fonte principal. Mantive o tema e os objetivos
aprovados na eEDB-007.

---

## 17/08/2026 — Estrutura de pastas

Reorganizei o `C:\dev` em três pastas: `cursos`, `projetos` e `labs`. Antes estava tudo
misturado. Curso e projeto têm ciclos de vida diferentes.

Criei a estrutura do projeto em `C:\dev\projetos\tcc-galpoes`, já com as camadas
`dados/bronze`, `dados/silver`, `dados/gold` e `dados/quarentena`, mais `analises`, `src`,
`modelos`, `docs` e `monografia`.

Adotei nomes sempre em minúsculas, sem acento e sem espaço, com hífen no lugar do espaço.
Espaço e acento em caminho quebram script Python e vão quebrar caminho na nuvem depois.

---

## 18/08/2026 — Ambiente Python

Criei o ambiente virtual `.venv` na raiz do projeto e instalei pandas, pyarrow, duckdb,
scikit-learn, matplotlib, seaborn, ipykernel e openpyxl. Gerei o `requirements.txt` com
`pip freeze`.

**Por quê:** o venv isola as dependências do projeto do Python geral da máquina. Se eu
instalar outra coisa em outro projeto, não quebra este. E o `requirements.txt` permite que
qualquer pessoa recrie o mesmo ambiente — é o que atende reprodutibilidade.

Configurei o VS Code para usar o interpretador do `.venv` e instalei as extensões Python e
Jupyter.

Criei também a pasta `scripts/setup`, para rotinas administrativas em PowerShell. Fica
separada de `src`, que é para código Python reutilizável do pipeline. É a mesma lógica de
separar rotina de manutenção do ambiente da lógica funcional do sistema.

Erro bobo que cometi: salvei o arquivo como `requeriments.txt` em vez de `requirements.txt`.
Corrigi. O nome errado quebraria o `pip install -r`.

Confirmei que o ambiente está certo rodando `python -c "import sys; print(sys.executable)"`.
Retornou o caminho de dentro do `.venv`. Vale guardar esse comando — é o teste definitivo de
qual Python está ativo, melhor que qualquer indicador visual.

---

## 27/08/2026 — Git, GitHub e download dos dados

### Versionamento

Criei o `.gitignore` excluindo `.venv/`, `dados/`, `modelos/`, `*.zip` e caches. Depois o
`README.md`, e só então rodei `git init`.

A ordem importa: o `.gitignore` precisa existir antes do `git init`, senão o Git já enxerga
a pasta `dados` cheia de ZIP antes de ser instruído a ignorá-la.

Antes disso encontrei uma pasta `.git` solta dentro de `C:\dev` e removi. Se ela ficasse lá,
o `C:\dev` inteiro seria um repositório e o projeto ficaria dentro dele, misturando cursos e
projetos no mesmo histórico.

Criei o repositório privado `sousa-leandro86/tcc-galpoes` no GitHub, vazio (sem README, sem
.gitignore, sem licença), e subi o histórico local. Tinha que ser vazio: se o GitHub criasse
um README próprio, seriam dois históricos diferentes brigando pela mesma branch.

Conferi no `git status` que `dados/` e `.venv/` não estão sendo versionados.

Trabalho em branch única (`main`). Fluxo com `develop` e pull request é para equipe; aqui
seria complexidade sem ganho.

### Download

Baixei os informes trimestrais e mensais da CVM, de 2020 a 2026, e o dicionário de dados
oficial. Os ZIP ficaram em `dados/bronze/cvm-inf-trimestral/` e `.../cvm-inf-mensal/`, sem
descompactar. O dicionário extraí em `docs/cvm-dicionario-de-dados/`, porque é documentação,
não dado.

Não descompacto os ZIP de propósito: o arquivo original é a evidência de origem, e o Python
lê os CSV de dentro dele sem precisar extrair.

### Dicionário do informe mensal

Li os três arquivos (`geral`, `ativo_passivo`, `complemento`) campo a campo. **Nenhum tem
área nem vacância.** O informe mensal é um retrato financeiro do fundo: patrimônio, valor da
cota, cotistas, rentabilidade. Os imóveis aparecem, mas em valor em reais, não em metros
quadrados.

Isso derrubou minha suposição inicial de que a vacância viria do informe mensal. Ela tem que
vir do trimestral.

Dois achados úteis mesmo assim: o campo `Segmento_Atuacao` na tabela `geral`, que deve
permitir filtrar os fundos logísticos sem levantar CNPJ na mão; e o campo
`Contas_Receber_Aluguel` no `ativo_passivo`, que é o tema que eu procurava no começo, só que
consolidado por fundo e não por contrato.

Reparei também que quase todo campo numérico vem como `nvarchar`, ou seja, texto. Vai exigir
conversão de tipo na Silver.

### Dicionário do informe trimestral

Achei o que eu precisava. A tabela `imovel` tem `Area`, `Percentual_Locado`,
`Percentual_Vacancia`, `Percentual_Inadimplencia` e `Percentual_Receitas_FII`, com uma linha
por imóvel por trimestre. É a tabela central do trabalho.

A CVM já entrega a vacância calculada. Isso muda o que eu vou fazer de feature engineering:
em vez de calcular a vacância, vou (a) validar `Percentual_Locado + Percentual_Vacancia = 100%`
e mandar o que falhar para a quarentena, (b) converter percentual em área absoluta, (c)
consolidar por fundo ponderando por área, e (d) cruzar vacância física com participação na
receita.

Na tabela `complemento` encontrei o cronograma de vencimento de contratos por faixa de meses
e os indexadores de reajuste (IGPM, IPCA, INCC, INPC). Contrato vencendo perto é risco de
vacância futura. Pode virar variável explicativa.

### Mudança no recorte temporal

Tinha decidido usar 2023–2025 para não pegar o período de pandemia, que distorceu o mercado
de galpões. **Mudei para 2020–2026.**

Motivo: a tabela `imovel` é trimestral, então são só 4 pontos por ano. Com três anos eu teria
uns 12 pontos, insuficiente para série temporal. Com sete anos vou para uns 26.

E a pandemia deixa de ser problema e vira assunto: o setor logístico foi um dos poucos que se
beneficiou, com a explosão do e-commerce. Dá para analisar isso em vez de esconder.

---

## 29/08/2026 — Inventário dos dados

Notebook: `analises/01-inventario-dados.ipynb`.

Cada ZIP do informe trimestral tem 14 CSV dentro, batendo com o que o dicionário descrevia.

Abri o `inf_trimestral_fii_geral_2025.csv`: 4.577 linhas, 39 colunas. Confirmei os parâmetros
de leitura na prática — separador `;` e encoding `latin-1`. Com `utf-8` os acentos quebrariam.

Extraí os valores distintos de `Segmento_Atuacao`: Shoppings, Híbrido, Outros, Lajes
Corporativas, Escritórios, Multicategoria, Educacional, Logística, Hospital, Títulos e Val.
Mob., Hotel, Residencial, Varejo, mais registros nulos.

**O valor que a CVM usa é `"Logística"`, com acento e L maiúsculo.** Era isso que eu precisava
saber para filtrar.

Filtrei `Segmento_Atuacao == 'Logística'` no informe de 2025: **299 linhas, 100 CNPJs
distintos.** Esse é o tamanho da amostra.

Decidi ficar só com "Logística" pura. "Multicategoria" e "Híbrido" podem ter parte logística
no portfólio, mas trariam fundos que talvez sejam 10% logísticos. Prefiro o recorte limpo.

**Problema encontrado:** o campo `Tipo_Fundo_Classe` tem os valores "Fundo" e "Classe", e o
mesmo CNPJ aparece em mais de uma linha quando o fundo tem classes de cotas diferentes. Os
nomes até divergem — vi "LOGINVEST FUNDO DE INVESTIMENTO IMOBILIÁRIO INDUSTRIAL" e "LOGINVEST
FII INDUSTRIAL DE RESPONSABILIDADE LIMITADA", que parecem ser o mesmo fundo. Por isso os 299
registros viram 100 fundos.

Na Silver a deduplicação tem que ser por CNPJ, não por nome.



## 03/09/2026 — Revisão e particionamento

Revisei os três documentos de `docs/` e organizei as decisões com identificador (DA-01 a
DA-10) no `decisoes-arquiteturais.md`.

Levantei a dúvida se cada ano deveria ficar em uma subpasta separada na Bronze, para reduzir
custo de consulta na nuvem. **A conclusão foi que não faz diferença ali.** Athena e o endpoint
SQL do Fabric não leem dentro de ZIP — a Bronze é lida uma vez na ingestão e não é consultada.
O particionamento vale a partir da Silver, em Parquet, no padrão `ano=AAAA/`.

Também fechei o entendimento sobre o que estou entregando de fato. A vacância já vem calculada
da CVM, então a contribuição não é calcular o indicador. É integrar sete anos de informes
dispersos, tratar tipagem e duplicidade, consolidar por segmento com ponderação por área — que
não existe na fonte — e montar a série histórica para análise e projeção. Isso é coerente com
a questão de pesquisa, que pergunta pela arquitetura do pipeline, não pelo indicador.



## Pendências

- Escolha da nuvem: AWS ou Microsoft Fabric. Não bloqueia o trabalho local.
- Autorização para usar dados da empresa. Opcional — o trabalho se sustenta só com a CVM.
- Solicitar template e normas ABNT à coordenação.
- Verificar na fonte as citações clássicas do referencial teórico antes de fechar o texto.

## 13/09/2026 — Duagnóstico de Qualidade

Rodei diagnóstico de qualidade na tabela imovel (2025, fundos logísticos, 1640 registros).

Percentual_Locado tem 97,7% de valores vazios — só 37 registros preenchidos. Coluna
inutilizável. Cai por terra o plano de validar Locado + Vacancia = 100%. Vou usar
Percentual_Vacancia como indicador único e derivar ocupação como 1 - vacância.

Vacancia, Inadimplencia e Receitas_FII têm ~6% de vazios, o que é aceitável.
Area não tem nenhum vazio.

Confirmado que os percentuais estão em escala decimal (0 a 1), não 0 a 100. O max de
Percentual_Vacancia é exatamente 1.0. Vacância média de 4,1%, mediana zero — coerente
com o mercado logístico.

Encontrei outlier grave em Area: máximo de 191.766.900 m². Área mediana é 13.912 m².
Provável erro de preenchimento na origem. Primeiro caso concreto para a quarentena.



## 17/09/2026 — Feedback do professor orientador

Prof. Luiz Sérgio devolveu a MonoLeandroV0 com 6 comentários e alterações rastreadas.

Mensagem central, repetida 3 vezes (2 comentários + e-mail): a contribuição da
pesquisa está no OE2, feature engineering. Os outros objetivos são auxiliares.
Pediu uma seção detalhada sobre feature engineering no capítulo 2.

Segundo ponto: cuidado com a palavra "arquitetura". Lakehouse medalhão já existe,
não é algo a propor. Ele editou o texto trocando "propor a arquitetura" por
"implementar um pipeline" em dois lugares.

Terceiro: marcou com "???" os termos vagos — "metodologia técnica", "framework
analítico", "dados brutos". Precisam de definição concreta.

Boa notícia: o trabalho técnico que venho fazendo já é feature engineering
(derivação de ocupação, conversão para área absoluta, ponderação por área, regras
de quarentena, deduplicação por CNPJ). O ajuste é de ênfase no texto, não de rumo.



## 17/09/2026 — Revisão da monografia após feedback

Reescrevi a MonoLeandroV0 incorporando os 6 comentários e as alterações rastreadas
do Prof. Luiz Sérgio.

Principais mudanças: contribuição reposicionada no feature engineering (1.3
reescrita); palavra "arquitetura" substituída por "pipeline" e "propor" por
"implementar"; termos vagos definidos; seção 2.2 nova e detalhada sobre feature
engineering, com 4 subseções.

Problema que encontrei sozinho: o documento citava 8 obras que não constavam da
lista de referências (Ballou, CSCMP, CNT, Santiago, Faria, Lima, Gagliardi,
Rajendran), e 2 citações estavam por título e não por autor. As orientações da
disciplina avaliam exatamente isso. Reescrevi usando só as 10 referências
verificadas que tenho em PDF — 4 delas estavam na lista mas nunca eram citadas
no texto, agora estão.

Pendente: decidir se recupero Ballou e as demais, o que exige localizar as obras.


## 24/09/2026
Investigação dos extremos da coluna Area (imóveis logísticos, 2025).

Caso Aurora (CNPJ 35.652.278/0001-28): o mesmo imóvel aparece com 19.176.692 m²
no 1º trimestre e 191.766.920 m² nos três seguintes — exatamente 10 vezes maior,
com um zero acrescentado. Galpão não cresce 10x em um trimestre. Mas mesmo o valor
do 1º trimestre é absurdo (1.917 hectares). Erro de preenchimento na origem.

Outros suspeitos: "80198_52371" (21,6 mi m², nome é código), "BTLP Cajamar"
(7,5 mi m²), "IMOVEL GSA" (1,5 mi m², consistente nos 4 trimestres — pode ser
real, mas não dá para confirmar).

57 registros com área zero (3,5%).

Ponto de quebra da distribuição: percentil 99 = 552.080 m²; percentil 99,9 =
191.766.920 m². Salto de 347 vezes.

Decidi NÃO corrigir os valores. Dividir por 10 seria supor o valor verdadeiro,
que eu não conheço. Os registros vão para a quarentena.

Constatei que o separador decimal no CSV é ponto, não vírgula — o pandas leu Area e
os percentuais já como float64. O dicionário oficial marca esses campos como
nvarchar, mas isso é o tipo no banco da CVM, não o formato do arquivo. Corrigi o
dicionário de dados. Documentação descreve intenção; o dado descreve a realidade.

Regras de quarentena aplicadas em 2025: 71 registros (4,3%) — 57 com área zero e
14 acima de 1 milhão de m². Média da área caiu de 424.871 para 39.565 m² após o corte.

Ponto em aberto: menor área aprovada é 14,54 m², tamanho de uma sala. Investigar depois.

Iniciado o notebook 02. Processo de carga encapsulado em função, para reaproveitar
nos sete anos sem duplicar código.

Ao carregar os sete anos, deu KeyError: 'CNPJ_Fundo_Classe' em 2020. Diagnóstico:
só o arquivo de 2020 usa CNPJ_Fundo e Nome_Fundo; de 2021 em diante o nome é
CNPJ_Fundo_Classe. Minha hipótese inicial (mudança pela Resolução CVM 175, fim de
2023) não bateu com o dado. Explicação mais provável: a CVM mantém atualizados os
últimos cinco anos (2021–2026) e o arquivo de 2020 ficou fora dessa janela.
Corrigido com renomeação de colunas dentro da função — ver DA-18.



Carga dos sete anos concluída: 6.192 registros no total. Cada registro é um imóvel
em um trimestre, não um imóvel — 2025 tem 1.640 registros, cerca de 410 imóveis.

A verificação de duplicidade por fundo + data + nome do imóvel apontou 181 registros,
mas são falsos positivos: um mesmo fundo cadastra vários terrenos com o nome genérico
"Terreno", cada um com área diferente. Limitação da fonte: a CVM não fornece
identificador único de imóvel; o nome é texto livre. Afeta a regra de consistência
temporal por imóvel. Não afeta a série temporal por segmento e por fundo.

Pontos a investigar: salto de 956 registros (2024) para 1.640 (2025); tipos de imóvel
na coluna Classe (terreno não tem vacância); se o arquivo guarda versões antigas dos
informes.



Diagnóstico de versões: 1.008 informes (fundo + trimestre), nenhum com mais de uma
versão no arquivo. A CVM entrega só a versão vigente. Duplicatas exatas: zero.
A tabela imovel não precisa de deduplicação.

Coluna Classe tem quatro valores: renda acabados (5.737), renda em construção (198),
venda acabados (195), venda em construção (62). Estudo fica com renda acabados.



Aplicado escopo e regras de qualidade nos sete anos: 5.737 registros no escopo,
5.607 aprovados, 130 em quarentena (2,3%) — 106 por área zero, 23 por área acima
de 1 milhão de m², 1 por vacância ausente.

Achado: no notebook 01, 6,2% da vacância estava vazia. Após o filtro de escopo,
restou 1 registro. A ausência era estrutural — concentrada em imóveis em construção
e à venda, onde vacância não se aplica. Valida a DA-19 com dado. O mesmo para os
terrenos: nenhum restou entre os aprovados.



Silver concluída: 5.607 registros, 17 colunas, gravada em Parquet particionado por
ano (ano=2020 a ano=2026). Verificação de leitura bateu. Teste de sanidade: área
vaga + área locada reconstitui a área total (diferença máxima 5,8e-11, arredondamento).

Quarentena gravada em dados/quarentena/imoveis.parquet, com 130 registros e o
motivo de cada rejeição.



Notebook 03 iniciado. View DuckDB sobre a Silver enxerga os 5.607 registros.

A Gold de vacância por trimestre saiu com 35 linhas em vez de ~26. Causa: fundos
informam Data_Referencia de formas diferentes — último dia útil (2022-12-30,
2024-03-28) ou último dia do calendário (2022-12-31, 2024-03-31) —, além de datas
fora do padrão (2023-01-31, 2025-09-01). Agrupar pela data exata parte o trimestre.

Correção prevista: agrupar por ano + Trimestre. Antes, verificar se algum fundo
tem duas datas no mesmo trimestre, o que causaria dupla contagem.

Prévia: vacância ponderada em geral menor que a média simples (vacância concentrada
em galpões pequenos); a partir do 4º trimestre de 2025 a área vaga sobe para mais
de 850 mil m² e a ponderada supera a simples.


Verificação de datas por fundo e trimestre: 1 caso — fundo 13.012.312/0001-67,
1º trimestre de 2023, datas 31/01 e 31/03, 1 registro em cada. Regra aplicada:
manter a data mais recente de cada fundo no trimestre (DA-24). Gold refeita com
agrupamento por ano e trimestre: 26 trimestres (2020-T1 a 2026-T2), 5.606
registros (5.607 da Silver − 1). Arquivo gold/vacancia_segmento_trimestral.parquet
sobrescrito.

Observações para a EDA: vacância ponderada abaixo da simples até 2025-T3; em
2025-T4 a área vaga triplica (277 mil → 849 mil m²) com área total estável; em
2026 caem registros (378 → 275 → 201) e área total (15,4 → 12,8 mi m²) — checar
se 2026-T2 está incompleto ou se houve mudança na composição de fundos.