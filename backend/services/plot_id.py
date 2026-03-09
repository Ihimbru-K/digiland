from sqlalchemy.orm import Session
from models import Plot
from datetime import datetime


def generate_plot_id(db: Session) -> str:
    """Generate next sequential LandVault Plot ID — format: LV-YYYY-NNNN"""
    year = datetime.utcnow().year
    prefix = f"LV-{year}-"
    count = db.query(Plot).filter(Plot.lv_plot_id.like(f"{prefix}%")).count()
    return f"{prefix}{str(count + 1).zfill(4)}"
