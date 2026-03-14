este projeto adiciona 3 clientes e seus dados a tabela cliente
esta é uma integração python e postgresql usando sqlalchemy

DADOS INSERIDOS
Cliente(nome="Ana Tech", email="ana@exemplo.com", cpf="12345678901"),
Cliente(nome="Bruno Dev", email="bruno@exemplo.com", cpf="10987654321"),
Cliente(nome="Carla Code", email="carla@exemplo.com", cpf="56473829102")


.env
DB_USER=postgres
DB_PASSWORD=admin
DB_HOST=localhost
DB_PORT=5432
DB_NAME=ProjetoFinal_ModeloLogico_SISTEMA_DE_LOJA_VIRTUAL_SIMPLIFICADA


pip install -r requirements.txt