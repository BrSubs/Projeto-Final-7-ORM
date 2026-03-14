from sqlalchemy import Column, Integer, String, ForeignKey, DECIMAL, TIMESTAMP
from sqlalchemy.orm import relationship
from database import Base
import datetime

class Categoria(Base):
    __tablename__ = "categorias"
    id = Column(Integer, primary_key=True, index=True)
    nome_categoria = Column(String(100), nullable=False)

class Cliente(Base):
    __tablename__ = "cliente"
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(255), nullable=False)
    email = Column(String(254), nullable=False, unique=True)
    cpf = Column(String(11), nullable=False, unique=True)
    
    # Relacionamento: Um cliente tem vários endereços e vários pedidos
    enderecos = relationship("Endereco", back_populates="cliente")
    pedidos = relationship("Pedido", back_populates="cliente")

class Endereco(Base):
    __tablename__ = "enderecos"
    id = Column(Integer, primary_key=True, index=True)
    logradouro = Column(String(150), nullable=False)
    cep = Column(String(8), nullable=False)
    cidade = Column(String(100), nullable=False)
    uf = Column(String(2), nullable=False)
    id_cliente = Column(Integer, ForeignKey("cliente.id"))
    
    cliente = relationship("Cliente", back_populates="enderecos")
    pedidos = relationship("Pedido", back_populates="endereco")

class Produto(Base):
    __tablename__ = "produtos"
    sku = Column(String(50), primary_key=True, index=True)
    nome = Column(String(255), nullable=False)
    preco = Column(DECIMAL(10, 2), nullable=False)
    estoque = Column(Integer, nullable=False)
    id_categoria = Column(Integer, ForeignKey("categorias.id"))

class Pedido(Base):
    __tablename__ = "pedidos"
    id = Column(Integer, primary_key=True, index=True)
    data_pedido = Column(TIMESTAMP, default=datetime.datetime.utcnow)
    valor_total = Column(DECIMAL(10, 2), nullable=False)
    status = Column(String(20), default="CRIADO")
    id_cliente = Column(Integer, ForeignKey("cliente.id"))
    id_endereco = Column(Integer, ForeignKey("enderecos.id")) # Campo obrigatório no seu SQL
    
    cliente = relationship("Cliente", back_populates="pedidos")
    endereco = relationship("Endereco", back_populates="pedidos")
    itens = relationship("ItemPedido", back_populates="pedido")

class ItemPedido(Base):
    __tablename__ = "item_pedidos"
    id = Column(Integer, primary_key=True, index=True)
    quantidade = Column(Integer, nullable=False)
    preco_unitario_aplicado = Column(DECIMAL(10, 2), nullable=False)
    sku_produto = Column(String(50), ForeignKey("produtos.sku"))
    id_pedido = Column(Integer, ForeignKey("pedidos.id"))
    
    pedido = relationship("Pedido", back_populates="itens")