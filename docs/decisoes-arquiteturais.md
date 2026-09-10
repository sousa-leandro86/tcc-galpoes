# Decisões arquiteturais

Registro das decisões técnicas do projeto e seus motivos. O diário conta o processo;
aqui fica só a decisão final. Serve de base para Materiais e Métodos.

---

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

---

## DA-02 — Arquitetura em camadas (17/08/2026)

**Decisão:** Bronze, Silver e Gold, mais uma área de quarentena.

Bronze guarda o dado bruto e imutável, como veio da fonte. Se eu errar o tratamento,
reprocesso a partir dela sem perder nada.

Silver guarda o dado limpo e tipado, mantendo a granularidade original.

Gold guarda o dado agregado, pronto para consumo e para o BI.

Quarentena isola os registros que falharem nas regras de qualidade. A ideia é medir e
reportar a taxa de rejeição, não descartar em silêncio.

A mesma estrutura é criada local e replicada na nuvem, com os mesmos nomes de pasta.

---

## DA-03 — Ambiente isolado (18/08/2026)

**Decisão:** ambiente virtual `venv` por projeto, com as versões registradas em
`requirements.txt`.

Evita conflito de versão com outros projetos da máquina, e o arquivo de versões permite
recriar o ambiente exato — que é o critério de reprodutibilidade que a banca pode cobrar.

Bibliotecas: pandas, pyarrow (Parquet), duckdb (SQL local), scikit-learn, matplotlib,
seaborn, ipykernel e openpyxl.

---

## DA-04 — O que vai para o Git (27/08/2026)

**Decisão:** versionar código, documentação e configuração. Dados, modelos e o `.venv` ficam
de fora, via `.gitignore`.

Git não foi feito para arquivo binário grande. E excluir a pasta `dados` é medida de
segurança: se um dia entrarem dados da empresa, a política já impede que subam para
repositório, mesmo sendo privado.

Branch única (`main`), por ser trabalho de um autor só.

---

## DA-05 — Formato de arquivo (27/08/2026)

**Decisão:** manter o formato original na Bronze (ZIP com CSV) e usar Parquet da Silver em
diante.

Parquet é colunar, então a consulta lê só as colunas que precisa. Comprime melhor que CSV e
carrega o esquema de tipos dentro do próprio arquivo, sem precisar inferir a cada leitura.
É o formato nativo tanto do S3/Athena quanto do OneLake, o que garante portabilidade na
migração.

---

## DA-06 — Recorte temporal (27/08/2026)

**Decisão:** informes trimestrais de 2020 a 2026.

A tabela `imovel` é trimestral, ou seja, 4 observações por ano. Três anos dariam uns 12
pontos, pouco demais para série temporal. Sete anos dão uns 26.

Incluir 2020–2022 traz o período de pandemia, quando o setor logístico teve expansão atípica
com o e-commerce. Em vez de problema, vira assunto de análise.

---

## DA-07 — Seleção dos fundos logísticos (29/08/2026)

**Decisão:** filtrar `Segmento_Atuacao == 'Logística'` na tabela `geral` do informe
trimestral.

É critério objetivo, definido pela própria CVM no cadastro do fundo. Elimina a seleção manual
de CNPJ e o risco de viés na escolha da amostra.

Fundos "Multicategoria" e "Híbrido" ficam de fora. Podem ter parte logística no portfólio,
mas trariam fundos que talvez sejam minoritariamente logísticos. O recorte prioriza pureza de
segmento.

No informe de 2025 o filtro retornou 299 registros e 100 CNPJs distintos.

---

## DA-08 — Deduplicação por CNPJ (29/08/2026)

**Decisão:** deduplicar fundos pelo campo `CNPJ_Fundo_Classe`, nunca pelo nome.

O campo `Tipo_Fundo_Classe` assume "Fundo" ou "Classe". Fundos com classes de cotas geram
mais de uma linha para o mesmo CNPJ, e os nomes divergem entre elas. Contar por nome geraria
dupla contagem; contar por CNPJ preserva a entidade.

---

## DA-09 — Particionamento (03/09/2026)

**Decisão:** Bronze fica em estrutura plana, com o ano no nome do arquivo. O particionamento
físico no padrão `ano=AAAA/` começa na Silver, em Parquet.

O particionamento reduz custo porque o motor de consulta ignora as pastas fora do filtro
(*partition pruning*). Mas isso só funciona em formato que o motor consegue ler direto.
Athena e o endpoint SQL do Fabric não abrem ZIP — a Bronze é lida uma vez na ingestão e nunca
é consultada. Particioná-la não economizaria nada.

---

## DA-10 — O que este trabalho entrega (03/09/2026)

A CVM já publica o `Percentual_Vacancia` calculado, por imóvel. Então a contribuição não é
calcular o indicador.

**O que o trabalho entrega:** a arquitetura que integra sete anos de informes trimestrais
dispersos; o tratamento de tipagem (campos numéricos vêm como texto) e de duplicidade por
classe de cotas; os indicadores consolidados por segmento com ponderação por área, que não
existem na fonte; e a série histórica montada para análise e projeção.

Isso é coerente com a questão de pesquisa aprovada, que pergunta pela metodologia e
arquitetura de pipeline necessárias para coletar, integrar e tratar os dados. O objeto é o
pipeline, não o indicador.

---

## Ainda em aberto

- **DA-11** — Nuvem: AWS (S3/Glue/Athena) ou Microsoft Fabric (OneLake). Aguardando
  confirmação de créditos na AWS e de capacidade no tenant do Fabric.
- **DA-12** — O que fazer com registros de `Segmento_Atuacao` nulo. Defino ao implementar a
  Silver.
- **DA-13** — Método de projeção da série temporal. Defino depois da análise exploratória.
