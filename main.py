import logging
from database import SessionLocal, engine
from models import Base, Cliente, Endereco, Pedido

# Configuração do formato do Log: [Hora] [Nível] [Contexto] Mensagem
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("ORM-SISTEMA-LOJA")

def executar_fluxo_teste():
    logger.info("=== INICIANDO OPERAÇÃO DE BANCO DE DADOS ===")
    
    # ONDE: Verificação de tabelas no PostgreSQL
    logger.info(f"Local: Banco de Dados definido no .env")
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    try:
        # COMO: Definindo dados de entrada
        email_alvo = "yan.detalhado@email.com"
        logger.info(f"Ação: Verificando registro único | Critério: email='{email_alvo}'")
        
        cliente = db.query(Cliente).filter(Cliente.email == email_alvo).first()
        
        if not cliente:
            # O QUÊ: Inserção de novo registro
            logger.info("Status: Cliente não encontrado. Iniciando criação de novo perfil.")
            
            # Etapa 1: Cliente
            novo_cliente = Cliente(nome="Yan Brasil", email=email_alvo, cpf="12345678955")
            db.add(novo_cliente)
            db.flush() # Sincroniza para obter o ID
            logger.info(f"Sucesso: Cliente '{novo_cliente.nome}' inserido com ID {novo_cliente.id} na tabela 'cliente'.")
            
            # Etapa 2: Endereço (Relacionamento 1)
            logger.info(f"Relacionamento: Vinculando novo endereço ao Cliente ID {novo_cliente.id}...")
            novo_endereco = Endereco(
                logradouro="Rua da Automação, 777", 
                cep="60123456", cidade="Fortaleza", uf="CE", 
                id_cliente=novo_cliente.id
            )
            db.add(novo_endereco)
            db.flush()
            logger.info(f"Sucesso: Endereço ID {novo_endereco.id} mapeado na tabela 'enderecos'.")
            
            # Etapa 3: Pedido (Relacionamento 2)
            logger.info(f"Financeiro: Gerando pedido vinculado ao Endereço ID {novo_endereco.id}...")
            novo_pedido = Pedido(
                id_cliente=novo_cliente.id, 
                id_endereco=novo_endereco.id, 
                valor_total=850.40, 
                status="CRIADO"
            )
            db.add(novo_pedido)
            
            # COMMIT FINAL: Onde os dados são persistidos de fato
            db.commit()
            logger.info(f"TRANSACIONAL: Pedido #{novo_pedido.id} persistido com sucesso no banco de dados.")
        else:
            logger.warning(f"Abortar: O cliente '{cliente.nome}' (ID: {cliente.id}) já existe. Nenhuma alteração feita.")

        # RELATÓRIO DE SAÍDA
        print("\n" + "="*60)
        print(f"{'RESUMO DE REGISTROS NO BANCO':^60}")
        print("="*60)
        
        vendas = db.query(Pedido).all()
        for v in vendas:
            # Demonstração do Relacionamento via ORM
            print(f"[{v.data_pedido.strftime('%d/%m/%y %H:%M')}] PEDIDO #{v.id:03} | "
                  f"CLIENTE: {v.cliente.nome:<15} | "
                  f"LOCAL: {v.endereco.logradouro}")
        
        print("="*60 + "\n")

    except Exception as e:
        logger.error(f"ERRO CRÍTICO: Falha ao processar operação. Causa: {e}")
        db.rollback()
        logger.info("Rollback executado: Nenhuma alteração foi salva no banco.")
    finally:
        db.close()
        logger.info("Conexão encerrada com segurança.")

if __name__ == "__main__":
    executar_fluxo_teste()