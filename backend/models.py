from sqlalchemy import (
    Column, String, Float, Integer, DateTime, Text,
    ForeignKey, Boolean, Enum as SAEnum
)
from sqlalchemy.orm import relationship, declarative_base
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime, timezone
import uuid
import enum

Base = declarative_base()


def utcnow():
    return datetime.now(timezone.utc)


def new_uuid():
    return str(uuid.uuid4())


# ── Enums ────────────────────────────────────────────────────
class AcquisitionMethod(str, enum.Enum):
    purchase   = "purchase"
    inheritance = "inheritance"
    customary  = "customary"
    gift       = "gift"

class PlotStatus(str, enum.Enum):
    draft     = "draft"
    complete  = "complete"
    archived  = "archived"

class PhotoCategory(str, enum.Enum):
    overview   = "overview"
    north      = "north"
    south      = "south"
    east       = "east"
    west       = "west"
    document   = "document"
    other      = "other"


# ── Models ───────────────────────────────────────────────────
class User(Base):
    __tablename__ = "users"

    id              = Column(String, primary_key=True, default=new_uuid)
    firebase_uid    = Column(String, unique=True, nullable=False, index=True)
    email           = Column(String, unique=True, nullable=False)
    full_name       = Column(String, nullable=False)
    role            = Column(String, default="agent")  # admin | agent | viewer
    region          = Column(String, nullable=True)
    is_active       = Column(Boolean, default=True)
    created_at      = Column(DateTime(timezone=True), default=utcnow)

    plots           = relationship("Plot", back_populates="agent")


class Plot(Base):
    __tablename__ = "plots"

    id                  = Column(String, primary_key=True, default=new_uuid)
    lv_plot_id          = Column(String, unique=True, nullable=False, index=True)  # LV-2026-0001
    owner_name          = Column(String, nullable=False)
    owner_id_number     = Column(String, nullable=True)
    owner_phone         = Column(String, nullable=True)
    acquisition_method  = Column(SAEnum(AcquisitionMethod), nullable=False)
    acquisition_date    = Column(String, nullable=True)
    description         = Column(Text, nullable=True)
    region              = Column(String, nullable=True)
    status              = Column(SAEnum(PlotStatus), default=PlotStatus.draft)
    agent_id            = Column(String, ForeignKey("users.id"), nullable=False)
    created_at          = Column(DateTime(timezone=True), default=utcnow)
    updated_at          = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    agent               = relationship("User", back_populates="plots")
    gps_points          = relationship("GPSPoint", back_populates="plot", cascade="all, delete-orphan")
    photos              = relationship("Photo", back_populates="plot", cascade="all, delete-orphan")
    witnesses           = relationship("Witness", back_populates="plot", cascade="all, delete-orphan")
    certificate         = relationship("Certificate", back_populates="plot", uselist=False, cascade="all, delete-orphan")


class GPSPoint(Base):
    __tablename__ = "gps_points"

    id              = Column(String, primary_key=True, default=new_uuid)
    plot_id         = Column(String, ForeignKey("plots.id"), nullable=False)
    latitude        = Column(Float, nullable=False)
    longitude       = Column(Float, nullable=False)
    altitude        = Column(Float, nullable=True)
    accuracy        = Column(Float, nullable=True)   # meters
    sequence_order  = Column(Integer, nullable=False, default=0)
    captured_at     = Column(DateTime(timezone=True), default=utcnow)

    plot            = relationship("Plot", back_populates="gps_points")


class Photo(Base):
    __tablename__ = "photos"

    id              = Column(String, primary_key=True, default=new_uuid)
    plot_id         = Column(String, ForeignKey("plots.id"), nullable=False)
    storage_url     = Column(String, nullable=False)
    appwrite_file_id = Column(String, nullable=True)
    category        = Column(SAEnum(PhotoCategory), default=PhotoCategory.other)
    gps_lat         = Column(Float, nullable=True)
    gps_lng         = Column(Float, nullable=True)
    file_size_kb    = Column(Integer, nullable=True)
    captured_at     = Column(DateTime(timezone=True), default=utcnow)

    plot            = relationship("Plot", back_populates="photos")


class Witness(Base):
    __tablename__ = "witnesses"

    id              = Column(String, primary_key=True, default=new_uuid)
    plot_id         = Column(String, ForeignKey("plots.id"), nullable=False)
    full_name       = Column(String, nullable=False)
    phone           = Column(String, nullable=False)
    relationship_to_plot = Column(String, nullable=False)
    statement_text  = Column(Text, nullable=False)
    signature_url   = Column(String, nullable=True)
    created_at      = Column(DateTime(timezone=True), default=utcnow)

    plot            = relationship("Plot", back_populates="witnesses")


class Certificate(Base):
    __tablename__ = "certificates"

    id                  = Column(String, primary_key=True, default=new_uuid)
    plot_id             = Column(String, ForeignKey("plots.id"), unique=True, nullable=False)
    pdf_url             = Column(String, nullable=True)
    appwrite_file_id    = Column(String, nullable=True)
    sha256_hash         = Column(String, nullable=True)
    blockchain_tx_hash  = Column(String, nullable=True)
    blockchain_network  = Column(String, default="polygon_amoy")
    generated_at        = Column(DateTime(timezone=True), default=utcnow)
    generated_by        = Column(String, ForeignKey("users.id"), nullable=False)

    plot                = relationship("Plot", back_populates="certificate")
