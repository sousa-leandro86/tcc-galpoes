# Decisões arquiteturais

Registro das decisões técnicas do projeto e seus motivos. O diário conta o processo;
aqui fica só a decisão final. Serve de base para Materiais e Métodos.



## DA-01 — Fonte de dados (16/08/2026)

**Decisão:** usar os Informes Mensais e Trimestrais Estruturados de FII, publicados pela CVM
no portal de Dados Abertos.

A ideia original era usar dados contratuais da empresa onde trabalho, com contratos e
recebíveis em nível individual. Ficou de fora por confidencialidade comercial e por conta da
LGPD, já que contratos de locação costumam ter fiadores e contatos que são pessoa física.

Isso trouxe uma vantagem: com dados públicos, qualquer pessoa consegue reproduzir o estudo
inteiro. E os dados são auditados por órgão regulador.

A limitação é que a granularidade é por imóvel e por trimestre, não por contrato. Análise de
renovação contratual, inadimplência por locatário e vencimento individual ficam de fora —
entram como trabalhos futuros.



## DA-02 — Arquitetura em camadas (17/08/2026)

**Decisão:** Bronze, Silver e Gold, mais uma área de quarentena.

Bronze guarda o dado bruto e imutável, como veio da fonte. Se eu errar o tratamento,
reprocesso a partir dela sem perder nada.

Silver guarda o dado limpo e tipado, mantendo a granularidade original.

Gold guarda o dado agregado, pronto para consumo e para o BI.

Quarentena isola os registros que falharem nas regras de qualidade. A ideia é medir e
reportar a taxa de rejeição, não descartar em silêncio.

A mesma estrutura é criada local e replicada na nuvem, com os mesmos nomes de pasta.



## DA-03 — Ambiente isolado (18/08/2026)

**Decisão:** ambiente virtual `venv` por projeto, com as versões registradas em
`requirements.txt`.

Evita conflito de versão com outros projetos da máquina, e o arquivo de versões permite
recriar o ambiente exato — que é o critério de reprodutibilidade que a banca pode cobrar.

Bibliotecas: pandas, pyarrow (Parquet), duckdb (SQL local), scikit-learn, matplotlib,
seaborn, ipykernel e openpyxl.



## DA-04 — O que vai para o Git (27/08/2026)

**Decisão:** versionar código, documentação e configuração. Dados, modelos e o `.venv` ficam
de fora, via `.gitignore`.

Git não foi feito para arquivo binário grande. E excluir a pasta `dados` é medida de
segurança: se um dia entrarem dados da empresa, a política já impede que subam para
repositório, mesmo sendo privado.

Branch única (`main`), por ser trabalho de um autor só.



## DA-05 — Formato de arquivo (27/08/2026)

**Decisão:** manter o formato original na Bronze (ZIP com CSV) e usar Parquet da Silver em
diante.

Parquet é colunar, então a consulta lê só as colunas que precisa. Comprime melhor que CSV e
carrega o esquema de tipos dentro do próprio arquivo, sem precisar inferir a cada leitura.
É o formato nativo tanto do S3/Athena quanto do OneLake, o que garante portabilidade na
migração.



## DA-06 — Recorte temporal (27/08/2026)

**Decisão:** informes trimestrais de 2020 a 2026.

A tabela `imovel` é trimestral, ou seja, 4 observações por ano. Três anos dariam uns 12
pontos, pouco demais para série temporal. Sete anos dão uns 26.

Incluir 2020–2022 traz o período de pandemia, quando o setor logístico teve expansão atípica
com o e-commerce. Em vez de problema, vira assunto de análise.



## DA-07 — Seleção dos fundos logísticos (29/08/2026)

**Decisão:** filtrar `Segmento_Atuacao == 'Logística'` na tabela `geral` do informe
trimestral.

É critério objetivo, definido pela própria CVM no cadastro do fundo. Elimina a seleção manual
de CNPJ e o risco de viés na escolha da amostra.

Fundos "Multicategoria" e "Híbrido" ficam de fora. Podem ter parte logística no portfólio,
mas trariam fundos que talvez sejam minoritariamente logísticos. O recorte prioriza pureza de
segmento.

No informe de 2025 o filtro retornou 299 registros e 100 CNPJs distintos.



## DA-08 — Deduplicação por CNPJ (29/08/2026)

**Decisão:** deduplicar fundos pelo campo `CNPJ_Fundo_Classe`, nunca pelo nome.

O campo `Tipo_Fundo_Classe` assume "Fundo" ou "Classe". Fundos com classes de cotas geram
mais de uma linha para o mesmo CNPJ, e os nomes divergem entre elas. Contar por nome geraria
dupla contagem; contar por CNPJ preserva a entidade.



## DA-09 — Particionamento (03/09/2026)

**Decisão:** Bronze fica em estrutura plana, com o ano no nome do arquivo. O particionamento
físico no padrão `ano=AAAA/` começa na Silver, em Parquet.

O particionamento reduz custo porque o motor de consulta ignora as pastas fora do filtro
(*partition pruning*). Mas isso só funciona em formato que o motor consegue ler direto.
Athena e o endpoint SQL do Fabric não abrem ZIP — a Bronze é lida uma vez na ingestão e nunca
é consultada. Particioná-la não economizaria nada.



## DA-10 — O que este trabalho entrega (revisado em 17/09/2026)

Revisão após feedback do Prof. Luiz Sérgio (14/09/2026).

A CVM já publica o Percentual_Vacancia calculado, por imóvel. E a arquitetura
medalhão é padrão de mercado consolidado — não é algo a propor.

A contribuição central do trabalho é o **feature engineering**: as decisões de
tratamento e as variáveis derivadas que transformam o dado bruto da CVM em base
analítica utilizável. Em concreto:

- derivação da ocupação a partir da vacância, dado que Percentual_Locado tem 97,7% de nulos
- conversão de percentual para área absoluta em m², o que permite somar imóveis
  de tamanhos diferentes
- consolidação por fundo com ponderação por área — indicador inexistente na fonte
- regras de qualidade e critérios de quarentena (faixa de vacância, plausibilidade de área)
- deduplicação por CNPJ em razão do desdobramento Fundo/Classe
- tratamento de tipagem: campos numéricos entregues como texto, em escala decimal

O pipeline medalhão é o **meio** que viabiliza esse tratamento em escala e de forma
reprodutível, não o fim do trabalho.

Vocabulário: usar "implementar um pipeline" e não "propor uma arquitetura".



## Ainda em aberto

- **DA-11** — Nuvem: AWS (S3/Glue/Athena) ou Microsoft Fabric (OneLake). Aguardando
  confirmação de créditos na AWS e de capacidade no tenant do Fabric.
- **DA-12** — O que fazer com registros de `Segmento_Atuacao` nulo. Defino ao implementar a
  Silver.
- **DA-13** — Método de projeção da série temporal. Defino depois da análise exploratória.



## DA-14 — Indicador de ocupação (10/09/2026)

Decisão: usar Percentual_Vacancia como indicador único e derivar a ocupação como
1 - vacância. Percentual_Locado não é utilizado.

Motivo: o campo Percentual_Locado tem 97,7% de nulos na amostra analisada,
inviabilizando qualquer análise sobre ele. Como ocupação e vacância são
complementares, nenhuma informação se perde — apenas a possibilidade de validação
cruzada entre os dois campos, que é substituída por regras de faixa (vacância entre
0 e 1) e de plausibilidade de área.



## DA-15 — Incorporação de Ballou (2006) — 18/09/2026

Anexado Ballou (2006), publicado na revista Produção. Não é a obra citada na V0
(Ballou, 1993, livro), mas é verificável e cumpre função equivalente.

Uso: definição de logística via CSCMP (Introdução), peso econômico da cadeia de
suprimentos (1.1), e fundamentação da vacância financeira via a discussão sobre
ótica de receita versus custo (2.1).

Descartados: Assis et al. (2018) e Faria et al. (2018) — tratam de transporte, não
de armazenagem; trazê-los afastaria o texto do tema central.

CNT: o PDF anexado é a Agenda Institucional 2022, que NÃO contém a afirmação sobre
redução de 25% dos custos citada na V0. O dado provavelmente está na Pesquisa CNT
de Rodovias. Citação permanece fora até verificação.

Restam 5 citações da V0 não recuperadas: CNT, Santiago (2019), Faria (2018),
Lima et al. (2021), Gagliardi et al. (2018), Rajendran e Jayakrishnan (2022).



## DA-16 — Regras de qualidade para a coluna Area

Decisão: registros com Area = 0 ou Area > 1.000.000 m² vão para a quarentena.

Regra de domínio: área zero não existe fisicamente.

Regra de plausibilidade: o limite de 1.000.000 m² fica no vão entre o percentil 99
da distribuição observada (552.080 m²) e o primeiro valor suspeito identificado
(1.512.456 m²). O corte é justificado pelo próprio dado.

Registros suspeitos não são corrigidos, apenas isolados. Corrigir exigiria supor o
valor verdadeiro, o que introduziria informação não sustentada pela fonte.

Pendente: regra de consistência temporal (variação brusca de área do mesmo imóvel
entre trimestres), a implementar quando os sete anos estiverem integrados.



## DA-17 — Seleção de fundos por ano (evita viés de sobrevivência)

Decisão: a lista de fundos logísticos é obtida da tabela geral de cada ano, e não
de uma lista fixa extraída de um único ano.

Motivo: fundos são criados, liquidados ou mudam de segmento ao longo do período.
Usar a lista de 2025 para os anos anteriores excluiria fundos encerrados antes de
2025 — que tendem a ser os de pior desempenho —, produzindo viés de sobrevivência
e uma série histórica de vacância artificialmente favorável.



## DA-18 — Harmonização de esquema entre anos

Decisão: dentro da função de carga, as colunas CNPJ_Fundo e Nome_Fundo são
renomeadas para CNPJ_Fundo_Classe e Nome_Fundo_Classe, em todos os anos.

Motivo: o arquivo de 2020 usa nomes de coluna diferentes dos anos de 2021 a 2026.
Padroniza-se para o nome atual porque é o esquema vigente da fonte. A renomeação é
aplicada a todos os anos, sem condicional por ano, pois não produz efeito onde a
coluna antiga não existe — a regra fica genérica e não depende de caso especial.



## DA-19 — Recorte de escopo pela classe do imóvel

Decisão: o estudo considera apenas registros com Classe = "Imóveis para renda
acabados" (5.737 de 6.192 registros, 92,7%).

Motivo: vacância pressupõe imóvel pronto e destinado a aluguel. Imóveis em
construção ainda não podem ter inquilino; imóveis para venda não são alugados.

Os registros excluídos por escopo não vão para a quarentena: são válidos, mas fora
do objeto. A quarentena fica reservada a registros suspeitos, para que a taxa de
rejeição reflita problemas reais de qualidade.

## DA-20 — Regras de qualidade e registro de motivo

Decisão: cinco regras aplicadas aos registros no escopo — área ausente, área zero,
área acima de 1.000.000 m², vacância ausente, vacância fora da faixa 0 a 1. Cada
registro rejeitado recebe na coluna motivo_quarentena o código de todas as regras
que violou.

Motivo: vacância ausente impede o registro de contribuir para o indicador central;
mantê-lo apenas na soma das áreas tornaria a ponderação inconsistente. O motivo
registrado torna a quarentena auditável e permite reportar a rejeição por causa.



## DA-21 — Variáveis derivadas na Silver

Taxa_Ocupacao = 1 − Percentual_Vacancia (complementaridade).
Area_Vaga_m2 = Area × Percentual_Vacancia; Area_Locada_m2 = Area × Taxa_Ocupacao
(conversão de relativo em absoluto, para permitir soma entre imóveis).
Trimestre extraído de Data_Referencia.

Seleção de 17 colunas. Excluídas as colunas de construção e venda (pertencem a
classes fora do escopo), Percentual_Locado (97,7% de vazios) e o texto livre de
características.

## DA-22 — Gravação idempotente da Silver

A pasta de destino é apagada antes de cada gravação. A gravação particionada
acrescenta arquivos às partições existentes; sem a limpeza, reexecutar o notebook
duplicaria os dados. A Silver é sempre reconstruível a partir da Bronze.