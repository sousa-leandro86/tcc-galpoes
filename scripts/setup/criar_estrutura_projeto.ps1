# Arquivo: criar_estrutura_projeto.ps1
# Objetivo: Criar (ou confirmar) toda a estrutura de pastas do projeto
#           tcc-galpoes, incluindo scripts\setup, que ainda não existia
# Entrada: Nenhuma (caminho fixo do projeto)
# Saída: Árvore completa de pastas em C:\dev\projetos\tcc-galpoes
# Onde roda: Local (PowerShell) — Camada: preparação de ambiente (fora do lakehouse)

# Guarda o caminho da raiz do projeto em uma variável, para não repetir
# o caminho longo em cada linha e facilitar manutenção caso mude no futuro
$raiz = "C:\dev\projetos\tcc-galpoes"

# Lista com todas as subpastas que o projeto precisa, incluindo as que já
# existem (Bloco 2 do checklist original) e as duas novas de scripts\setup.
# Manter a lista completa aqui, e não só as pastas faltantes, é o que torna
# este script a documentação reproduzível de toda a árvore, não só de uma parte dela.
$pastas = @(
    "dados\bronze\cvm-inf-mensal",
    "dados\bronze\cvm-inf-trimestral",
    "dados\bronze\sintetico",
    "dados\silver",
    "dados\gold",
    "dados\quarentena",
    "analises",
    "src",
    "modelos",
    "docs",
    "monografia\texto",
    "monografia\figuras",
    "scripts\setup"
)

# Percorre cada item da lista e cria a pasta correspondente.
# -Force garante que pastas já existentes não gerem erro, o que torna
# seguro rodar este script quantas vezes for necessário.
foreach ($pasta in $pastas) {
    New-Item -Path "$raiz\$pasta" -ItemType Directory -Force | Out-Null
}

# Exibe a árvore de pastas resultante, para conferência visual
tree $raiz