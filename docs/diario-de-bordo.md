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


Inspeção do conflito de datas (fundo 13.012.312/0001-67, 2023 T1): os dois
registros são o mesmo imóvel (Pilkington, 2.230 m², vacância 0, Versao 1), com
datas 31/01 e 31/03. Confirma a regra da DA-24: o descarte da data anterior
evita dupla contagem e não remove nenhum imóvel real.


Criada a view imoveis_trimestre com a regra da DA-24 (DA-25): 5.606 registros,
igual à Gold 1. Gold 2 gerada a partir dela (vacância por fundo por trimestre,
gold/vacancia_fundo_trimestral.parquet): 892 linhas (= soma de qtd_fundos da
Gold 1), 5.606 registros, área vaga total idêntica à da Gold 1. Fundo
identificado só por CNPJ (DA-26).


Decidido não criar a Gold 3 (evolução do mercado): as colunas já existem na
Gold 1 (DA-27). Camada Gold fechada com duas tabelas. Célula de conclusões
adicionada ao fim do notebook 03.


Notebook 04 criado (análise exploratória). Setup lê as duas tabelas da Gold:
26 e 892 linhas, conferidas. Figura 1 (vacância ponderada × simples) gerada.
Fases observadas: 2020–2021 simples bem acima da ponderada; 2022–2023 linhas
próximas (em 2022-T1 a ponderada fica 0,15 ponto acima da simples, exceção à
anotação do notebook 03); 2024-T3 a 2025-T3 ponderada cai para cerca de 2% e
simples se mantém entre 3% e 5%; a partir de 2025-T4 a ponderada sobe e passa
a simples, chegando a 7,6% em 2026-T2. Eixo Y ajustado para começar em zero
(DA-28).


Figura 1 refeita com eixo Y a partir de zero. Figura 2 (evolução da amostra:
fundos, imóveis e área total) gerada em três painéis com eixo X compartilhado.
Observações: (1) salto simultâneo em 2025-T1 nos três painéis (35 → 48 fundos,
212 → 338 imóveis, 8,5 → 12,2 mi m²); hipótese a verificar: fundos existentes
reclassificados como Logística em 2025, entrando pela seleção anual (DA-17);
(2) 2022-T1: imóveis 158 → 225 com fundos estáveis (32 → 31); (3) 2026-T1 →
2026-T2: imóveis 275 → 201 com área estável (12,78 → 12,81 mi m²) e fundos
48 → 49, o que enfraquece a hipótese de 2026-T2 incompleto por falta de
entrega. Na queda da ponderada em 2025-T1 com área total crescendo, hipótese
de efeito de composição: fundos novos com imóveis grandes e bem ocupados.


Investigação do salto de 2025-T4 (Gold 2): aumento do segmento de 570.968 m²
de área vaga, validado pela soma das variações por fundo. Os cinco maiores
aumentos somam 574.578 m² (100,6% do total); os demais fundos reduziram, em
conjunto, cerca de 3.610 m². O fundo 63.574.240/0001-10, ausente no 2025-T3,
responde sozinho por 338.478 m² (59,3%). Entre os fundos presentes nos dois
trimestres, destaque para 16.671.412/0001-93 (de 6.427 para 128.176 m² vagos).
O 35.652.278/0001-28 (fundo do imóvel Aurora em quarentena) aparece com 67.420
m² de aumento, vindos dos seus demais imóveis.


Decomposição do salto de 2025-T4 (DA-29): entraram 4 fundos (338.478 m²,
59,3%), saíram 4 (0 m²), permaneceram 51 (232.491 m², 40,7%). Toda a parcela
de entrada vem do 63.574.240/0001-10: um imóvel de 338.477,53 m², 100% vago em
2025-T4, 2026-T1 e 2026-T2 — 37,8% da área vaga do segmento em 2026-T1 e
34,8% em 2026-T2. Histórico 2025–2026: 16.671.412/0001-93 sobe para 50,2% em
2025-T4 e volta a 0% em 2026-T2 (área total cai de 255.512 para 192.350 m² em
2026-T1 com os mesmos 5 imóveis, motivo não identificável nos dados);
35.652.278/0001-28 vai de 0% para 14,6% e se mantém. Sem esses três, a área
vaga dos demais fundos sobe de 314.479 m² (2025-T4) para 566.596 m² (2026-T2).
Prazo: EDA será encerrada com as figuras 3 e 4.


Imóvel do fundo 63.574.240/0001-10 identificado na Silver: Terminal Multimodal
de Camaçari (Polo Petroquímico de Camaçari), 338.477,53 m², vacância 100% em
2025-12-31, 2026-03-31 e 2026-06-30. Figura 3 gerada (área vaga 2024-T1 a
2026-T2 em barras empilhadas: demais fundos × Terminal de Camaçari); legenda
ajustada com o nome do imóvel. Observação para a Discussão: o segmento
Logística reúne ativos heterogêneos (terminal multimodal × condomínio de
galpões), conforme classificação declarada pelo próprio fundo.


Figura 3 finalizada com legenda nomeando o Terminal Multimodal de Camaçari.
Figuras apagadas por engano e regeneradas com Run All (reprodutibilidade).
Figura 4 gerada (distribuição da vacância por faixas, por ano, DA-30): 5.607
registros, nenhum sem faixa. Faixa 0% (locado) entre 85,2% e 90,0% em todos os
anos. Faixa 100% (vago) em formato de U: 4,5% (2020), 3,6% (2021), 1,5%
(2022), 1,4% (2023), 2,1% (2024), 2,6% (2025), 4,2% (2026). Faixa 10% a 50%
entre 4,3% e 7,2%, sem tendência. A tabela de percentuais vai para a
monografia junto com a figura.


Notebook 05 criado. Série de 26 trimestres (2020-T1 a 2026-T2). Comparação de
métodos com holdout temporal dos 4 últimos trimestres (DA-13): MAE média móvel
3,57 pontos, tendência linear 3,73, ingênuo 3,75; inclinação da reta no treino
de −0,121 ponto por trimestre. No 2025-T3 os três erram menos de 0,3 ponto; de
2025-T4 em diante, todos projetam até cerca de 2% contra reais de 5,52% a
7,59%. Métodos simples acompanham o regime estável e não antecipam a ruptura
de composição identificada na EDA.


Projeção final (DA-13) recalculada com a série inteira: média dos 4 últimos
trimestres = (1,81 + 5,52 + 7,00 + 7,59) ÷ 4 = 5,48%, repetida de 2026-T3 a
2027-T2. Faixa de erro de ± 3,57 pontos (MAE do teste): 1,91% a 9,05%. A
projeção fica abaixo do último valor observado (7,59%) porque a janela ainda
inclui o 2025-T3, anterior à ruptura. Gravada em
gold/projecao_vacancia_trimestral.parquet (escala 0 a 1). Figura 5 gerada
(série observada, média móvel, projeção e faixa de erro).



## 01/10/2026 — Auditoria da monografia e nuvem

Auditoria da MonoLeandroV2 contra o modelo PECE. Capítulos 1 e 2 completos,
mas com afirmações anteriores à execução que os dados desmentiram (campos como
texto, deduplicação de registros, dados de contratos). Capítulos 3 e 4 ausentes.
Referências com erros conferidos nos PDFs: Hayta (não Haytad), Nguyen com
terceiro autor (Tran), Sousa e Oliveira nº 9779, paginação de Santos e Baptista.
Ribeiro et al. (2022) declaram que sua base não exigiu limpeza; não sustentam
o argumento sobre preparação dos dados.

Nuvem: iniciados testes na AWS. Corte em 03/10; sem ambiente funcional até lá,
a migração entra na monografia como etapa planejada. DA-11 será fechada
após os testes.


## 01/10/2026 — Anexo 39-II da Instrução CVM 571/2015

Localizei o normativo que define o informe trimestral. Três achados: o formulário
não diz se a vacância é física ou financeira (vira premissa, DA-31); "% locado" só
existe para imóveis em construção, o que explica os 97,7% de nulos (complemento da
DA-14); o prazo de entrega é de 45 dias após o trimestre, o que ajuda a explicar
2026 com só dois trimestres. Capítulo 2 revisado: retiradas as afirmações não
sustentadas sobre Ribeiro et al. (2022), incluídos os métodos de projeção na 2.4.


Início da migração para a nuvem (DA-11): AWS Academy Learner Lab. Bucket
criado com bronze/ (7 ZIPs trimestrais), silver/imoveis/ (partições ano=2020
a ano=2026), gold/ (uma pasta por tabela), quarentena/imoveis/ e
athena-resultados/. Prints da estrutura salvos.


Migração para a AWS (Learner Lab, us-east-1): bucket tcc-galpoes-leandro-2026
com bronze/, silver/, gold/ (uma pasta por tabela), quarentena/ e
athena-resultados/. Esquema dos Parquet levantado no notebook 03
(Data_Referencia em timestamp[us], Trimestre em int32). Banco tcc_galpoes com
5 tabelas externas; 7 partições da Silver registradas via MSCK REPAIR (DA-31).
Problema: o script 1 colado inteiro executou só o CREATE DATABASE, porque o
editor do Athena executa uma instrução por vez; resolvido rodando bloco a
bloco, em abas separadas. Validações: V1 5.607 registros e 7 anos; V2 26 /
5.606 / 892 / 4; V3 area_zero 106, area_acima_limite 23, vacancia_ausente 1;
V4 Gold 1 recalculada no Athena com 26 trimestres, 5.606 registros e maior
diferença de vacância ponderada de 2,78E-17 (ponto flutuante). Resultados
idênticos ao ambiente local.


Gold gerada na nuvem (DA-33): view imoveis_trimestre e CTAS das Gold 1 e 2
no Athena, gravadas em gold_nuvem/. Validação contra a Gold local — Gold 1:
26 linhas, 26 casadas, 0 contagens divergentes, diferença máxima de 2,78E-17
(ponderada) e 1,39E-17 (simples), 929 ms, 2,29 KB lidos. Gold 2: 892 linhas,
892 casadas, 0 divergentes, diferença máxima de 5,82E-11 m² (área vaga) e
1,11E-16 (ponderada), 820 ms, 16,15 KB lidos. Diferenças atribuídas à
aritmética de ponto flutuante.