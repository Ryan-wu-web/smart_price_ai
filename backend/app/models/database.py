import uuid
from datetime import datetime

from sqlalchemy import JSON, Column, DateTime, Float, Integer, String, Text, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings

Base = declarative_base()


def generate_uuid() -> str:
    return str(uuid.uuid4())


class Product(Base):
    __tablename__ = "products"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False)
    brand = Column(String(100), default="")
    category = Column(String(100), nullable=False)
    color = Column(String(50), default="")
    price = Column(Float, nullable=False)
    platform = Column(String(100), nullable=False)
    rating = Column(Float, default=0.0)
    tags = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)


class PriceHistory(Base):
    __tablename__ = "price_histories"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    product_id = Column(String(36), nullable=False, index=True)
    platform = Column(String(100), nullable=False)
    price = Column(Float, nullable=False)
    recorded_at = Column(DateTime, default=datetime.utcnow)


class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(100), nullable=False)
    context = Column(JSON, default=list)
    expires_at = Column(DateTime, nullable=True)


class DecisionReport(Base):
    __tablename__ = "decision_reports"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    session_id = Column(String(36), nullable=False, index=True)
    report_data = Column(JSON, default=dict)
    share_image_url = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)
