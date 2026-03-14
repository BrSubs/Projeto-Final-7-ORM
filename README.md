esta é uma integração python e postgresql usando sqlalchemy


Aqui foi implementado o mapeamento das entidades do sistema:

    Cada tabela principal do projeto deve vira uma classe/entidade

    Cada entidade deve contem:

        chave primária

        campos básicos (colunas)

        relacionamentos coerentes com o modelo


📌 Regra prática:

    tabelas principais mapeadas

    mapear pelo menos 2 relacionamentos (ex.: 1–N e N–N, ou 1–N e N–1)



.env
DB_USER=postgres
DB_PASSWORD=admin
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ProjetoFinal_ModeloLogico_SISTEMA_DE_LOJA_VIRTUAL_SIMPLIFICADA


pip install -r requirements.txt