# Diário de bordo — TCC galpões logísticos

Registro do que foi feito, quando e por quê. Base para o capítulo de Materiais e Métodos.
Início do projeto: 16/08/2026.

Revisado em 16/10/2026. Alguns blocos de setembro e outubro ficaram sem data na época, então
coloquei só o nome da etapa. Quando a execução mostrou que algo anotado antes estava errado,
deixei uma nota de correção em vez de apagar o texto original.

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
qualquer pessoa recrie o mesmo ambiente, que é o que garante a reprodutibilidade.

Configurei o VS Code para usar o interpretador do `.venv` e instalei as extensões Python e
Jupyter.

Criei também a pasta `scripts/setup`, para rotinas administrativas em PowerShell. Fica
separada de `src`, que é para código Python reutilizável do pipeline. É a mesma lógica de
separar rotina de manutenção do ambiente da lógica funcional do sistema.

Erro bobo que cometi: salvei o arquivo como `requeriments.txt` em vez de `requirements.txt`.
Corrigi. O nome errado quebraria o `pip install -r`.

Confirmei que o ambiente está certo rodando `python -c "import sys; print(sys.executable)"`.
Retornou o caminho de dentro do `.venv`. Vale guardar esse comando: é o teste definitivo de
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

> Nota (16/10/2026): suposição corrigida em 24/09. `nvarchar` é o tipo no banco da CVM; no
> CSV os números vêm com ponto decimal e o pandas os lê como `float64`.

### Dicionário do informe trimestral

Achei o que eu precisava. A tabela `imovel` tem `Area`, `Percentual_Locado`,
`Percentual_Vacancia`, `Percentual_Inadimplencia` e `Percentual_Receitas_FII`, com uma linha
por imóvel por trimestre. É a tabela central do trabalho.

A CVM já entrega a vacância calculada. Isso muda o que eu vou fazer de feature engineering:
em vez de calcular a vacância, vou (a) validar `Percentual_Locado + Percentual_Vacancia = 100%`
e mandar o que falhar para a quarentena, (b) converter percentual em área absoluta, (c)
consolidar por fundo ponderando por área, e (d) cruzar vacância física com participação na
receita.

> Nota (16/10/2026): a vacância não é calculada pela CVM. Ela é declarada pelo administrador
> do fundo no informe (Instrução CVM 472, art. 39) e publicada pela CVM, que não a calcula
> nem a audita.

> Nota (16/10/2026): o item (a) caiu em 13/09 (`Percentual_Locado` com 97,7% de nulos, DA-14);
> o item (d) não foi executado e fica como trabalho futuro.

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

> Nota (16/10/2026): a afirmação sobre a pandemia não tem fonte verificada e não entra na
> monografia como explicação dos dados.

---

## 29/08/2026 — Inventário dos dados

Notebook: `analises/01-inventario-dados.ipynb`.

Cada ZIP do informe trimestral tem 14 CSV dentro, batendo com o que o dicionário descrevia.

Abri o `inf_trimestral_fii_geral_2025.csv`: 4.577 linhas, 39 colunas. Confirmei os parâmetros
de leitura na prática: separador `;` e encoding `latin-1`. Com `utf-8` os acentos quebrariam.

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
nomes até divergem. Vi "LOGINVEST FUNDO DE INVESTIMENTO IMOBILIÁRIO INDUSTRIAL" e "LOGINVEST
FII INDUSTRIAL DE RESPONSABILIDADE LIMITADA", que parecem ser o mesmo fundo. Por isso os 299
registros viram 100 fundos.

Na Silver a deduplicação tem que ser por CNPJ, não por nome.

> Nota (16/10/2026): na prática, a regra atuou na contagem de fundos da tabela `geral`; a
> tabela `imovel` não teve duplicatas (DA-08).

---

## 03/09/2026 — Revisão e particionamento

Revisei os três documentos de `docs/` e organizei as decisões com identificador (DA-01 a
DA-10) no `decisoes-arquiteturais.md`.

Levantei a dúvida se cada ano deveria ficar em uma subpasta separada na Bronze, para reduzir
custo de consulta na nuvem. **A conclusão foi que não faz diferença ali.** Athena e o endpoint
SQL do Fabric não leem dentro de ZIP. A Bronze é lida uma vez na ingestão e não é consultada.
O particionamento vale a partir da Silver, em Parquet, no padrão `ano=AAAA/`.

Também fechei o entendimento sobre o que estou entregando de fato. A vacância já vem calculada
da CVM, então a contribuição não é calcular o indicador. É integrar sete anos de informes
dispersos, tratar tipagem e duplicidade, consolidar por segmento com ponderação por área (que
não existe na fonte) e montar a série histórica para análise e projeção. Isso é coerente com
a questão de pesquisa, que pergunta pela arquitetura do pipeline, não pelo indicador.

> Nota (16/10/2026): onde se lê "vem calculada da CVM", leia-se "vem declarada pelo
> administrador do fundo e publicada pela CVM".

> Nota (16/10/2026): a questão de pesquisa foi reformulada após o feedback de 14/09 e passou a
> perguntar pelas técnicas de tratamento e feature engineering (ver 17/09 e DA-10).

---

## 13/09/2026 — Diagnóstico de qualidade

Rodei diagnóstico de qualidade na tabela imovel (2025, fundos logísticos, 1640 registros).

Percentual_Locado tem 97,7% de valores vazios, só 37 registros preenchidos. Coluna
inutilizável. Cai por terra o plano de validar Locado + Vacancia = 100%. Vou usar
Percentual_Vacancia como indicador único e derivar ocupação como 1 - vacância.

Vacancia, Inadimplencia e Receitas_FII têm ~6% de vazios, o que é aceitável.
Area não tem nenhum vazio.

Confirmado que os percentuais estão em escala decimal (0 a 1), não 0 a 100. O max de
Percentual_Vacancia é exatamente 1.0. Vacância média de 4,1%, mediana zero, coerente
com o mercado logístico.

Encontrei outlier grave em Area: máximo de 191.766.900 m². Área mediana é 13.912 m².
Provável erro de preenchimento na origem. Primeiro caso concreto para a quarentena.

> Nota (16/10/2026): o valor exato do máximo, conferido em 24/09, é 191.766.920 m².

---

## 17/09/2026 — Feedback do professor orientador

Prof. Luiz Sérgio devolveu a MonoLeandroV0 com 6 comentários e alterações rastreadas.

Mensagem central, repetida 3 vezes (2 comentários + e-mail): a contribuição da
pesquisa está no OE2, feature engineering. Os outros objetivos são auxiliares.
Pediu uma seção detalhada sobre feature engineering no capítulo 2.

Segundo ponto: cuidado com a palavra "arquitetura". Lakehouse medalhão já existe,
não é algo a propor. Ele editou o texto trocando "propor a arquitetura" por
"implementar um pipeline" em dois lugares.

Terceiro: marcou com "???" os termos vagos: "metodologia técnica", "framework
analítico", "dados brutos". Precisam de definição concreta.

Boa notícia: o trabalho técnico que venho fazendo já é feature engineering
(derivação de ocupação, conversão para área absoluta, ponderação por área, regras
de quarentena, deduplicação por CNPJ). O ajuste é de ênfase no texto, não de rumo.

---

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
verificadas que tenho em PDF. Quatro delas estavam na lista mas nunca eram citadas
no texto, agora estão.

Pendente: decidir se recupero Ballou e as demais, o que exige localizar as obras.

> Nota (16/10/2026): Ballou (2006) foi incorporado em 18/09 (DA-15); as demais seguem fora.

---

## 24/09/2026 — Extremos de área e início do notebook 02

Investigação dos extremos da coluna Area (imóveis logísticos, 2025).

Caso Aurora (CNPJ 35.652.278/0001-28): o mesmo imóvel aparece com 19.176.692 m²
no 1º trimestre e 191.766.920 m² nos três seguintes, exatamente 10 vezes maior,
com um zero acrescentado. Galpão não cresce 10x em um trimestre. Mas mesmo o valor
do 1º trimestre é absurdo (1.917 hectares). Erro de preenchimento na origem.

Outros suspeitos: "80198_52371" (21,6 mi m², nome é código), "BTLP Cajamar"
(7,5 mi m²), "IMOVEL GSA" (1,5 mi m², consistente nos 4 trimestres; pode ser
real, mas não dá para confirmar).

57 registros com área zero (3,5%).

Ponto de quebra da distribuição: percentil 99 = 552.080 m²; percentil 99,9 =
191.766.920 m². Salto de 347 vezes.

Decidi NÃO corrigir os valores. Dividir por 10 seria supor o valor verdadeiro,
que eu não conheço. Os registros vão para a quarentena.

Constatei que o separador decimal no CSV é ponto, não vírgula. O pandas leu Area e
os percentuais já como float64. O dicionário oficial marca esses campos como
nvarchar, mas isso é o tipo no banco da CVM, não o formato do arquivo. Corrigi o
dicionário de dados.

Regras de quarentena aplicadas em 2025: 71 registros (4,3%): 57 com área zero e
14 acima de 1 milhão de m². Média da área caiu de 424.871 para 39.565 m² após o corte.

Ponto em aberto: menor área aprovada é 14,54 m², tamanho de uma sala. Investigar depois.

Iniciado o notebook 02. Processo de carga encapsulado em função, para reaproveitar
nos sete anos sem duplicar código.

Ao carregar os sete anos, deu KeyError: 'CNPJ_Fundo_Classe' em 2020. Diagnóstico:
só o arquivo de 2020 usa CNPJ_Fundo e Nome_Fundo; de 2021 em diante o nome é
CNPJ_Fundo_Classe. Minha hipótese inicial (mudança pela Resolução CVM 175, fim de
2023) não bateu com o dado. Explicação mais provável: a CVM mantém atualizados os
últimos cinco anos (2021–2026) e o arquivo de 2020 ficou fora dessa janela.
Corrigido com renomeação de colunas dentro da função (DA-18).

> Nota (16/10/2026): a página do conjunto de dados na CVM confirma que os arquivos dos
> últimos cinco anos são atualizados semanalmente e que o histórico anterior fica fora dessa
> política. A explicação é compatível com a fonte, mas a CVM não declara a causa exata da
> diferença de nomes de colunas.



### Notebook 02 — carga, versões e escopo (data não registrada; entre 24/09 e 26/09)

Carga dos sete anos concluída: 6.192 registros no total. Cada registro é um imóvel
em um trimestre, não um imóvel. 2025 tem 1.640 registros, cerca de 410 imóveis.

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



### Notebook 02 — qualidade e Silver (data não registrada; entre 24/09 e 26/09)

Aplicado escopo e regras de qualidade nos sete anos: 5.737 registros no escopo,
5.607 aprovados, 130 em quarentena (2,3%): 106 por área zero, 23 por área acima
de 1 milhão de m², 1 por vacância ausente.

Achado: no notebook 01, 6,2% da vacância estava vazia. Após o filtro de escopo,
restou 1 registro. A ausência era estrutural, concentrada em imóveis em construção
e à venda, onde vacância não se aplica. Valida a DA-19 com dado. O mesmo para os
terrenos: nenhum restou entre os aprovados.

Silver concluída: 5.607 registros, 17 colunas, gravada em Parquet particionado por
ano (ano=2020 a ano=2026). Verificação de leitura bateu. Teste de sanidade: área
vaga + área locada reconstitui a área total (diferença máxima 5,8e-11, arredondamento).

Quarentena gravada em dados/quarentena/imoveis.parquet, com 130 registros e o
motivo de cada rejeição.



### Notebook 03 — Silver para Gold (data não registrada; até 01/10)

Notebook 03 iniciado. View DuckDB sobre a Silver enxerga os 5.607 registros.

A Gold de vacância por trimestre saiu com 35 linhas em vez de ~26. Causa: fundos
informam Data_Referencia de formas diferentes: último dia útil (2022-12-30,
2024-03-28) ou último dia do calendário (2022-12-31, 2024-03-31), além de datas
fora do padrão (2023-01-31, 2025-09-01). Agrupar pela data exata parte o trimestre.

Correção prevista: agrupar por ano + Trimestre. Antes, verificar se algum fundo
tem duas datas no mesmo trimestre, o que causaria dupla contagem.

Prévia: vacância ponderada em geral menor que a média simples (vacância concentrada
em galpões pequenos); a partir do 4º trimestre de 2025 a área vaga sobe para mais
de 850 mil m² e a ponderada supera a simples.

Verificação de datas por fundo e trimestre: 1 caso, o fundo 13.012.312/0001-67,
1º trimestre de 2023, datas 31/01 e 31/03, 1 registro em cada. Regra aplicada:
manter a data mais recente de cada fundo no trimestre (DA-24). Gold refeita com
agrupamento por ano e trimestre: 26 trimestres (2020-T1 a 2026-T2), 5.606
registros (5.607 da Silver − 1). Arquivo gold/vacancia_segmento_trimestral.parquet
sobrescrito.

Observações para a EDA: vacância ponderada abaixo da simples até 2025-T3; em
2025-T4 a área vaga triplica (277 mil → 849 mil m²) com área total estável; em
2026 caem registros (378 → 275 → 201) e área total (15,4 → 12,8 mi m²). Checar
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



### Notebook 04 — análise exploratória (data não registrada; até 01/10)

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
2025-T4, 2026-T1 e 2026-T2, o que dá 37,8% da área vaga do segmento em 2026-T1 e
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



### Notebook 05 — série temporal e projeção (data não registrada; até 01/10)

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

---

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

---

## 01/10/2026 — Anexo 39-II da Instrução CVM 571/2015

Localizei o normativo que define o informe trimestral. Três achados: o formulário
não diz se a vacância é física ou financeira (vira premissa, DA-35); "% locado" só
existe para imóveis em construção, o que explica os 97,7% de nulos (complemento da
DA-14); o prazo de entrega é de 45 dias após o trimestre, o que ajuda a explicar
2026 com só dois trimestres. Capítulo 2 revisado: retiradas as afirmações não
sustentadas sobre Ribeiro et al. (2022), incluídos os métodos de projeção na 2.4.

---

## 02/10 a 13/10/2026 — Migração para a AWS (datas de cada passo não registradas)

Comecei a migração (DA-11) no AWS Academy Learner Lab, região us-east-1. Criei o bucket
tcc-galpoes-leandro-2026 com bronze/ (7 ZIPs trimestrais), silver/imoveis/ (partições
ano=2020 a ano=2026), gold/ (uma pasta por tabela), quarentena/imoveis/ e
athena-resultados/, e salvei os prints da estrutura. Esquema dos Parquet levantado no notebook 03
(Data_Referencia em timestamp[us], Trimestre em int32). Banco tcc_galpoes com
5 tabelas externas; 7 partições da Silver registradas via MSCK REPAIR (DA-31).
Problema: o script 1 colado inteiro executou só o CREATE DATABASE, porque o
editor do Athena executa uma instrução por vez; resolvido rodando bloco a
bloco, em abas separadas. Validações: V1 5.607 registros e 7 anos; V2 26 /
5.606 / 892 / 4; V3 area_zero 106, area_acima_limite 23, vacancia_ausente 1;
V4 Gold 1 recalculada no Athena com 26 trimestres, 5.606 registros e maior
diferença de vacância ponderada de 2,78E-17 (ponto flutuante). Bateu tudo com o
ambiente local.

Gold gerada na nuvem (DA-33): view imoveis_trimestre e CTAS das Gold 1 e 2
no Athena, gravadas em gold_nuvem/. Validação contra a Gold local. Gold 1:
26 linhas, 26 casadas, 0 contagens divergentes, diferença máxima de 2,78E-17
(ponderada) e 1,39E-17 (simples), 929 ms, 2,29 KB lidos. Gold 2: 892 linhas,
892 casadas, 0 divergentes, diferença máxima de 5,82E-11 m² (área vaga) e
1,11E-16 (ponderada), 820 ms, 16,15 KB lidos. Diferenças atribuídas à
aritmética de ponto flutuante.

---

## 15 e 16/10/2026 — Dashboard Power BI

Power BI conectado ao Athena (DA-34): driver ODBC 2.x instalado, DSN
athena_tcc_galpoes testado com sucesso (Athena engine version 3, us-east-1).
Problema 1: teste falhou com "security token ... invalid"; causa: valor colado
com prefixo ou incompleto; resolvido copiando só o valor após o "=", via Bloco
de Notas. Carga em modo Importar: 26, 892 e 4 linhas, conferidas no Table
view. Problema 2: a tabela de dados da projeção foi removida do modelo por
engano (confusão entre o visual de tabela e a tabela de dados); recarregada
do Athena. Problema 3: o Format painter copiou o formato percentual do cartão
de vacância para o de área vaga; corrigido manualmente (Display units None, 0
casas). Cartões: 7,59%, 972.494 m² e 49 fundos (2026-T2); projeção 5,48%,
faixa de 1,91% a 9,05%.

Achado no ranking de 2026-T2: 63.574.240/0001-10 com 338.478 m² e
26.502.794/0001-85 com 266.763 m² vagos. Cálculo manual: o segundo fundo tinha
47.208 m² vagos em 2025-T4, e o aumento de 219.555 m² responde por cerca de
87% do aumento da área vaga dos demais fundos entre 2025-T4 e 2026-T2
(252.117 m²); os dois maiores somam cerca de 62% da área vaga do segmento em
2026-T2 (605.240 de 972.494 m²), e os dez maiores, cerca de 97%. A vacância
recente é concentrada em poucos ativos grandes.

> Nota (16/10/2026): conferi o ranking no print do painel (ev16) e achei o valor de
> 2025-T4 na saída da célula de decomposição do notebook 04 (47.208,18 m²; em 2025-T3 eram
> 47.079,17 m²). Refazendo as contas com os valores executados: aumento de 219.555 m², 87,1%
> dos 252.117 m² dos demais fundos; dois maiores com 605.241 m² (62,2%); dez maiores com
> 945.918 m² (97,3%), usando os valores arredondados do painel.

---

## 16/10/2026 — Documentação revisada e fontes verificadas

Arrumei as decisões arquiteturais. Tinha número repetido: a projeção virou DA-13, o
Athena ficou com a DA-31 e a premissa física com a DA-35. Registrei a DA-12, tirei da DA-10
a frase antiga sobre campos em texto e criei a DA-36 (sem print e sem valor de custo).
No dicionário de dados corrigi o separador decimal e incluí Silver, quarentena e derivadas.

Também conferi as fontes da monografia. Hyndman e Athanasopoulos (2021) tratam a média
móvel como suavização, não como método de previsão; para a previsão por média móvel a fonte
certa é Hyndman (2011). Confirmei nas editoras os fascículos de Ribeiro (n. 3), Sousa e
Oliveira (n. 22) e Tufano (n. 3). Os 11 artigos do projeto continuam sendo a base do
referencial; as fontes novas são de estatística e da documentação das ferramentas.

---

## 16/10/2026 — Quem informa a vacância

Eu vinha escrevendo desde o começo que a CVM calcula a vacância. Está errado. Quem
informa o percentual é o administrador do fundo, no informe trimestral (o art. 39 da
Instrução CVM 472 coloca as informações periódicas como obrigação do administrador), e a
CVM só publica, sem recalcular nem auditar. Isso reforça a necessidade das regras de
qualidade: o erro do Aurora (área 10 vezes maior) chegou ao arquivo público sem filtro
nenhum. Corrigi a DA-01, que falava em dados auditados por órgão regulador.

---

## 17/10/2026 — Imóveis do segundo fundo com maior área vaga

Fiz uma consulta pontual na Silver (célula nova no notebook 04, entre a fig03 e a fig04)
sobre o fundo 26.502.794/0001-85, o segundo com mais área vaga em 2026-T2. As somas por data
bateram com a Gold 2 (47.079; 47.208; 122.541; 266.763 m²) e a soma das variações deu o
aumento do fundo (219.555 m²).

Resultado: 206.680 m² do aumento (94,1%) vêm de seis imóveis que não estavam no informe de
2025-T4 e que entraram já 100% vagos. CD São Bernardo - CD CL Imigrantes V (62.457 m²) entrou em
2026-T1; CD Jundiaí I, CD Jundiaí II, CD Gaia AR Jarinu, CD Barão de Mauá Atibaia e
CD Gaia TF Jarinu (144.223 m²) entraram em 2026-T2. Os 12.876 m² restantes vêm de imóveis
já informados, sobretudo Piracicaba (+10.878 m²).

Como a CVM não tem identificador de imóvel, precisei descartar a hipótese de renomeação.
A quantidade de imóveis do fundo foi 17 → 23 → 24 → 29 e a área total 931.097 → 1.249.089 →
1.311.546 → 1.455.768 m². Os acréscimos de 2026-T1 (+62.457 m²) e de 2026-T2 (+144.222 m²)
batem com as áreas dos imóveis novos, então são inclusões e não nomes trocados.

Isso muda a leitura do resultado: 82,0% do aumento da área vaga dos demais fundos entre
2025-T4 e 2026-T2 (206.680 de 252.117 m²) também é efeito de composição, só que no nível do
imóvel. A composição muda em dois níveis: fundos entrando na amostra (Terminal de Camaçari) e
imóveis entrando em fundos que já estavam nela. Atualizei as Seções 3.7.3 e 3.7.4. Por que
esses imóveis estão totalmente vagos os dados não dizem.

Aproveitei para passar o `import numpy as np` da célula das faixas para a primeira célula do
notebook, junto com os outros imports.

---

## 16 e 17/10/2026 — Redação dos capítulos 3 e 4

Escrevi os resultados (3.6 a 3.9), a discussão e as limitações (3.10) e o capítulo 4 a partir
das saídas dos notebooks, dos prints do Athena e do painel, sem número estimado. Depois revisei
a Introdução: a abertura e a 1.1 repetiam os mesmos autores, e duas frases afirmavam coisas sem
fonte, então saíram. Por último entraram Resumo, Abstract, Agradecimentos e o Apêndice A com o
dicionário de dados resumido.

Dos prints de evidência, só quatro entraram no texto (ev01, ev05, ev12 e ev16). Os outros
repetem informação que já está nas tabelas e ficam para a apresentação da defesa.

---

## 17/10/2026 — Revisão final e versão para o orientador

Revisei a monografia inteira contra os critérios da PECE. Conferi a estrutura obrigatória, as
33 referências (todas citadas, nenhuma citação sem referência), as 10 figuras e 13 tabelas
(todas citadas no texto e com fonte), as abreviaturas e os números do Resumo contra o
capítulo 3. Achei e corrigi um resto do modelo na capa, termos em inglês sem itálico
(pipeline, notebooks, benchmarking), a falta de tradução de pipeline e a sigla LGPD, que estava
na lista mas não no texto. A versão de envio ao orientador é a MonoLeandroV12.

---

## 04/11/2026 — Ajustes pedidos pelo orientador

O orientador devolveu a V12 com uma observação geral: o trabalho precisa mostrar resultados de
aplicação geral, e a vacância dos galpões deve aparecer como estudo de caso, uma prova de
conceito que levanta hipóteses para outras áreas. Mudei o enquadramento sem mudar nenhum número.

- Resumo, Abstract e palavras-chave reescritos com o enquadramento geral.
- Capítulo 1: tirei a motivação pessoal, o objetivo e a questão de pesquisa ficaram gerais,
  entrou o objetivo (e) sobre hipóteses e a seção 1.3 foi refeita (prova de conceito,
  contribuição acadêmica e contribuição para organizações).
- Capítulo 2: a seção de vacância foi para o fim (2.4) como conceito do estudo de caso, entrou
  a nota de rodapé de "estrutura subjacente" e a frase da learning table ficou geral.
- Capítulo 3: virou "Estudo de Caso", com um parágrafo de abertura sobre prova de conceito, nove
  parágrafos "Aplicação a outros contextos" nos pontos que ele marcou e a nova seção 3.10.2 com
  quatro hipóteses (composição, ponderação, taxa de rejeição e portabilidade do SQL).
- Capítulo 4 reescrito com os achados gerais primeiro e os resultados do caso depois.
- Seis referências novas, todas conferidas na fonte: Janssen, Charalabidis e Zuiderwijk (2012),
  Wang e Strong (1996), Kandel et al. (2011), Lino et al. (2019), Wilkinson et al. (2016) e
  Armbrust et al. (2021).

Versão gerada: MonoLeandroV13.

---

## 10/11/2026 — Título novo

O título aprovado na proposta citava "dados históricos de aluguéis" e "características
operacionais dos imóveis", que o trabalho não usa, e colocava a vacância como objeto principal.
Depois da revisão, sugeri ao orientador um título alinhado ao objetivo e ele aprovou a troca:
"Feature engineering em dados públicos periódicos: estudo de caso da vacância de galpões
logísticos". Ele também liberou o envio ao PECE depois da revisão final de formatação ABNT e
das referências.

---

## 10/11/2026 — Revisão final de formatação (v4)

Revisei a v3 contra o modelo da PECE, a orientação do trabalho escrito, os slides da disciplina
eEDB-007 e as normas ABNT. Correções: erros de digitação e itálico no título; referência à
Seção 3.10.3; palavras-chave com ponto e vírgula (NBR 6028:2021); siglas explicadas na primeira
vez em cada capítulo, como pede a Aula 3; tradução de benchmarking e notebooks; ARIMA e AWS na
lista de abreviaturas. Os slides pedem pelo menos cinco artigos dos últimos três anos, contando
o ano atual, e havia só três (Fioravanti 2024, Silva 2024 e Öztürk 2025). Entraram mais dois,
conferidos na fonte, na Seção 2.1.3: Oliveira e Silva (2024) e Silva e Silva (2025).

---

## 10/11/2026 — Repositório público

Deixei o repositório do GitHub público (https://github.com/sousa-leandro86/tcc-galpoes), porque a
disciplina pede que os algoritmos e os dados considerados sejam divulgados e porque o trabalho
defende a reprodutibilidade. Antes, conferi que não há dados, arquivo .pbix nem credenciais
versionados. A monografia passou a citar o repositório na 3.1.2 e na 4.1, com a referência
SOUSA (2026). Versão gerada: v5.

A área de concentração da folha de rosto fica como no modelo da PECE: o cadastro do curso no
sistema Apolo da USP registra a área de conhecimento "Engenharia/Tecnologia/Gestão", a mesma do
modelo.

---

## Pendências (atualizado em 10/11/2026)

- ~~Escolha da nuvem: AWS ou Microsoft Fabric.~~ Resolvido: AWS Academy Learner Lab (DA-11).
- ~~Solicitar template e normas ABNT à coordenação.~~ Resolvido: modelo PECE em uso.
- ~~Verificar na fonte as citações clássicas do referencial teórico.~~ Feito em 01/10 e 16/10.
- ~~Confirmar os 47.208 m² vagos do fundo 26.502.794/0001-85 em 2025-T4.~~ Confirmado no
  notebook 04.
- ~~Redigir os capítulos 3 e 4 e os elementos pré-textuais.~~ Feito (MonoLeandroV12).
- Autorização para usar dados da empresa: não obtida. O trabalho fica só com a CVM (DA-01) e os
  dados corporativos vão para trabalhos futuros.
- ~~Confirmar o push do notebook 04.~~ Está no GitHub (commit de 17/10).
- Enviar ao GitHub o diário e o README atualizados em novembro.
- ~~Aplicar os ajustes do orientador quando ele devolver a V12.~~ Feito (MonoLeandroV13).
- ~~Confirmar a área de concentração da folha de rosto.~~ Mantida como no modelo (cadastro Apolo).
- Revisão final de formatação ABNT e referências, depois envio da versão final ao PECE.
- Gerar a ficha catalográfica no formulário da Biblioteca da Poli por último, com a paginação
  final.
