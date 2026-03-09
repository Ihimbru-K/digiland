from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import Response
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List
from database import get_db
from models import Plot, GPSPoint, Photo, Witness, Certificate, PlotStatus, AcquisitionMethod, PhotoCategory
from auth import get_current_user
from services.plot_id import generate_plot_id
from services.pdf import generate_certificate
from services.storage import upload_file
from services.blockchain import get_blockchain_service
from config import get_settings
import json

router  = APIRouter(prefix="/plots", tags=["plots"])
settings = get_settings()


# ── Schemas ───────────────────────────────────────────────────
class GPSPointIn(BaseModel):
    latitude:       float
    longitude:      float
    altitude:       Optional[float] = None
    accuracy:       Optional[float] = None
    sequence_order: int = 0

class WitnessIn(BaseModel):
    full_name:           str
    phone:               str
    relationship_to_plot: str
    statement_text:      str

class CreatePlotRequest(BaseModel):
    owner_name:         str
    owner_id_number:    Optional[str] = None
    owner_phone:        Optional[str] = None
    acquisition_method: AcquisitionMethod
    acquisition_date:   Optional[str] = None
    description:        Optional[str] = None
    region:             Optional[str] = None
    gps_points:         List[GPSPointIn] = []
    witnesses:          List[WitnessIn]  = []

class PlotSummary(BaseModel):
    id:                 str
    lv_plot_id:         str
    owner_name:         str
    acquisition_method: str
    status:             str
    region:             Optional[str]
    created_at:         str
    has_certificate:    bool

    class Config:
        from_attributes = True


# ── Helpers ───────────────────────────────────────────────────
def plot_to_summary(p: Plot) -> dict:
    return {
        "id":                 p.id,
        "lv_plot_id":         p.lv_plot_id,
        "owner_name":         p.owner_name,
        "acquisition_method": p.acquisition_method.value,
        "status":             p.status.value,
        "region":             p.region,
        "created_at":         p.created_at.isoformat(),
        "has_certificate":    p.certificate is not None,
    }


# ── Routes ────────────────────────────────────────────────────
@router.post("/")
async def create_plot(
    body: CreatePlotRequest,
    db:   Session = Depends(get_db),
    user = Depends(get_current_user),
):
    """Create a new plot registration."""
    plot_id = generate_plot_id(db)

    plot = Plot(
        lv_plot_id=plot_id,
        owner_name=body.owner_name,
        owner_id_number=body.owner_id_number,
        owner_phone=body.owner_phone,
        acquisition_method=body.acquisition_method,
        acquisition_date=body.acquisition_date,
        description=body.description,
        region=body.region or user.region,
        agent_id=user.id,
        status=PlotStatus.draft,
    )
    db.add(plot)
    db.flush()

    for pt in body.gps_points:
        db.add(GPSPoint(plot_id=plot.id, **pt.model_dump()))

    for w in body.witnesses:
        db.add(Witness(plot_id=plot.id, **w.model_dump()))

    db.commit()
    db.refresh(plot)
    return {"plot_id": plot.id, "lv_plot_id": plot.lv_plot_id, "status": "draft"}


@router.get("/")
async def list_plots(
    db:   Session = Depends(get_db),
    user = Depends(get_current_user),
):
    """List plots — agents see their own, admins see all."""
    if user.role == "admin":
        plots = db.query(Plot).order_by(Plot.created_at.desc()).all()
    else:
        plots = db.query(Plot).filter(Plot.agent_id == user.id).order_by(Plot.created_at.desc()).all()
    return [plot_to_summary(p) for p in plots]


@router.get("/{plot_id}")
async def get_plot(
    plot_id: str,
    db:   Session = Depends(get_db),
    user = Depends(get_current_user),
):
    plot = db.query(Plot).filter(Plot.id == plot_id).first()
    if not plot:
        raise HTTPException(404, "Plot not found")
    if user.role != "admin" and plot.agent_id != user.id:
        raise HTTPException(403, "Access denied")

    return {
        "id":                 plot.id,
        "lv_plot_id":         plot.lv_plot_id,
        "owner_name":         plot.owner_name,
        "owner_id_number":    plot.owner_id_number,
        "owner_phone":        plot.owner_phone,
        "acquisition_method": plot.acquisition_method.value,
        "acquisition_date":   plot.acquisition_date,
        "description":        plot.description,
        "region":             plot.region,
        "status":             plot.status.value,
        "gps_points": [
            {"lat": p.latitude, "lng": p.longitude, "accuracy": p.accuracy, "order": p.sequence_order}
            for p in plot.gps_points
        ],
        "photos": [
            {"id": p.id, "url": p.storage_url, "category": p.category.value}
            for p in plot.photos
        ],
        "witnesses": [
            {"name": w.full_name, "phone": w.phone, "statement": w.statement_text}
            for w in plot.witnesses
        ],
        "certificate": {
            "pdf_url":           plot.certificate.pdf_url,
            "tx_hash":           plot.certificate.blockchain_tx_hash,
            "doc_hash":          plot.certificate.sha256_hash,
            "generated_at":      plot.certificate.generated_at.isoformat(),
        } if plot.certificate else None,
    }


@router.post("/{plot_id}/photos")
async def upload_photo(
    plot_id:  str,
    category: str = Form(default="other"),
    gps_lat:  Optional[float] = Form(default=None),
    gps_lng:  Optional[float] = Form(default=None),
    file:     UploadFile = File(...),
    db:       Session = Depends(get_db),
    user    = Depends(get_current_user),
):
    """Upload a photo for a plot."""
    plot = db.query(Plot).filter(Plot.id == plot_id).first()
    if not plot:
        raise HTTPException(404, "Plot not found")

    contents = await file.read()
    result   = upload_file(contents, file.filename or "photo.jpg", file.content_type or "image/jpeg")

    try:
        cat = PhotoCategory(category)
    except ValueError:
        cat = PhotoCategory.other

    photo = Photo(
        plot_id=plot_id,
        storage_url=result["url"],
        appwrite_file_id=result["file_id"],
        category=cat,
        gps_lat=gps_lat,
        gps_lng=gps_lng,
        file_size_kb=len(contents) // 1024,
    )
    db.add(photo)
    db.commit()
    return {"photo_id": photo.id, "url": result["url"]}


@router.post("/{plot_id}/generate-certificate")
async def generate_cert(
    plot_id: str,
    db:      Session = Depends(get_db),
    user   = Depends(get_current_user),
):
    """
    Generate the Property Verification Certificate PDF,
    upload to Appwrite, anchor hash to Polygon blockchain.
    """
    plot = db.query(Plot).filter(Plot.id == plot_id).first()
    if not plot:
        raise HTTPException(404, "Plot not found")
    if user.role != "admin" and plot.agent_id != user.id:
        raise HTTPException(403, "Access denied")
    if len(plot.witnesses) < 2:
        raise HTTPException(400, "Minimum 2 witnesses required before generating certificate")
    if len(plot.gps_points) < 1:
        raise HTTPException(400, "At least 1 GPS point required")

    base_url = f"https://landvault-api.onrender.com"

    # 1. Generate PDF
    pdf_bytes = generate_certificate(plot, tx_hash="pending", doc_hash="pending", base_url=base_url)

    # 2. Upload PDF to Appwrite
    storage_result = upload_file(
        pdf_bytes,
        f"{plot.lv_plot_id}_certificate.pdf",
        "application/pdf"
    )

    # 3. Anchor hash to blockchain
    blockchain = get_blockchain_service()
    chain_result = blockchain.anchor_plot(plot.lv_plot_id, pdf_bytes)

    # 4. Regenerate PDF with real tx hash
    pdf_final = generate_certificate(
        plot,
        tx_hash=chain_result["tx_hash"],
        doc_hash=chain_result["document_hash"],
        base_url=base_url
    )

    # Upload final PDF
    final_storage = upload_file(
        pdf_final,
        f"{plot.lv_plot_id}_certificate_final.pdf",
        "application/pdf"
    )

    # 5. Save certificate record
    cert = Certificate(
        plot_id=plot.id,
        pdf_url=final_storage["url"],
        appwrite_file_id=final_storage["file_id"],
        sha256_hash=chain_result["document_hash"],
        blockchain_tx_hash=chain_result["tx_hash"],
        blockchain_network="polygon_amoy",
        generated_by=user.id,
    )
    db.add(cert)
    plot.status = PlotStatus.complete
    db.commit()

    return {
        "certificate_url":  final_storage["url"],
        "tx_hash":          chain_result["tx_hash"],
        "document_hash":    chain_result["document_hash"],
        "blockchain_explorer": f"https://amoy.polygonscan.com/tx/{chain_result['tx_hash']}",
        "lv_plot_id":       plot.lv_plot_id,
    }


@router.get("/verify/{lv_plot_id}")
async def verify_certificate(
    lv_plot_id: str,
    db:         Session = Depends(get_db),
):
    """
    Public endpoint — no auth required.
    Verifies a certificate against blockchain. Used by QR code.
    """
    plot = db.query(Plot).filter(Plot.lv_plot_id == lv_plot_id).first()
    if not plot or not plot.certificate:
        raise HTTPException(404, "Certificate not found")

    blockchain = get_blockchain_service()
    chain_data = blockchain.verify_plot(lv_plot_id)

    return {
        "lv_plot_id":        lv_plot_id,
        "owner_name":        plot.owner_name,
        "region":            plot.region,
        "certificate_url":   plot.certificate.pdf_url,
        "generated_at":      plot.certificate.generated_at.isoformat(),
        "blockchain": {
            "network":       "Polygon Amoy Testnet",
            "tx_hash":       plot.certificate.blockchain_tx_hash,
            "stored_hash":   chain_data["document_hash"],
            "timestamp":     chain_data["timestamp"],
            "verified":      chain_data["exists"],
            "explorer_url":  f"https://amoy.polygonscan.com/tx/{plot.certificate.blockchain_tx_hash}",
        }
    }
