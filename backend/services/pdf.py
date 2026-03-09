from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, Image as RLImage
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
import qrcode
import io
from datetime import datetime
from models import Plot

# Brand colors
GREEN_DARK  = colors.HexColor("#1B4332")
GREEN_MID   = colors.HexColor("#40916C")
GREEN_LIGHT = colors.HexColor("#D8F3DC")
ACCENT      = colors.HexColor("#52B788")
GRAY        = colors.HexColor("#6B7280")


def generate_qr_code(data: str) -> io.BytesIO:
    qr = qrcode.QRCode(version=2, box_size=4, border=2)
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#1B4332", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return buf


def generate_certificate(plot: Plot, tx_hash: str, doc_hash: str, base_url: str) -> bytes:
    """
    Generate a Property Verification Certificate PDF.
    Returns PDF as bytes.
    """
    buf = io.BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        rightMargin=2*cm, leftMargin=2*cm,
        topMargin=2*cm, bottomMargin=2*cm
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "CertTitle",
        parent=styles["Heading1"],
        fontSize=22, textColor=GREEN_DARK,
        alignment=TA_CENTER, spaceAfter=4
    )
    sub_style = ParagraphStyle(
        "CertSub",
        parent=styles["Normal"],
        fontSize=11, textColor=GREEN_MID,
        alignment=TA_CENTER, spaceAfter=2
    )
    label_style = ParagraphStyle(
        "Label",
        parent=styles["Normal"],
        fontSize=9, textColor=GRAY,
        spaceAfter=1
    )
    value_style = ParagraphStyle(
        "Value",
        parent=styles["Normal"],
        fontSize=11, textColor=colors.black,
        spaceAfter=6
    )
    small_style = ParagraphStyle(
        "Small",
        parent=styles["Normal"],
        fontSize=7, textColor=GRAY,
        alignment=TA_CENTER, spaceAfter=2
    )

    story = []

    # ── Header ────────────────────────────────────────────
    story.append(Paragraph("🌍 LANDVAULT", title_style))
    story.append(Paragraph("Property Verification Certificate", sub_style))
    story.append(Paragraph("Informal Land Documentation Platform — Bamenda, Cameroon", small_style))
    story.append(HRFlowable(width="100%", thickness=2, color=ACCENT, spaceAfter=8))

    # ── Plot ID badge ─────────────────────────────────────
    plot_id_table = Table(
        [[Paragraph(f"Plot ID: {plot.lv_plot_id}", ParagraphStyle(
            "Badge", parent=styles["Normal"],
            fontSize=14, textColor=colors.white,
            alignment=TA_CENTER, fontName="Helvetica-Bold"
        ))]],
        colWidths=[16*cm]
    )
    plot_id_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), GREEN_DARK),
        ("ROWBACKGROUNDS", (0, 0), (-1, -1), [GREEN_DARK]),
        ("TOPPADDING",    (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("ROUNDEDCORNERS", [4]),
    ]))
    story.append(plot_id_table)
    story.append(Spacer(1, 0.4*cm))

    # ── Owner Information ─────────────────────────────────
    story.append(Paragraph("OWNER INFORMATION", ParagraphStyle(
        "Section", parent=styles["Normal"],
        fontSize=9, textColor=GREEN_MID,
        fontName="Helvetica-Bold", spaceAfter=4
    )))

    owner_data = [
        [Paragraph("Full Name", label_style), Paragraph(plot.owner_name, value_style)],
        [Paragraph("ID Number", label_style), Paragraph(plot.owner_id_number or "Not provided", value_style)],
        [Paragraph("Phone", label_style), Paragraph(plot.owner_phone or "Not provided", value_style)],
        [Paragraph("Acquisition", label_style), Paragraph(plot.acquisition_method.value.title(), value_style)],
        [Paragraph("Acq. Date", label_style), Paragraph(plot.acquisition_date or "Not specified", value_style)],
    ]
    owner_table = Table(owner_data, colWidths=[4*cm, 12*cm])
    owner_table.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (0, -1), GREEN_LIGHT),
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING",    (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING",   (0, 0), (-1, -1), 6),
        ("GRID",          (0, 0), (-1, -1), 0.5, colors.HexColor("#E5E7EB")),
    ]))
    story.append(owner_table)
    story.append(Spacer(1, 0.4*cm))

    # ── GPS Coordinates ───────────────────────────────────
    story.append(Paragraph("GPS BOUNDARY POINTS", ParagraphStyle(
        "Section", parent=styles["Normal"],
        fontSize=9, textColor=GREEN_MID,
        fontName="Helvetica-Bold", spaceAfter=4
    )))

    gps_header = [
        Paragraph("Point", ParagraphStyle("H", parent=styles["Normal"], fontSize=9, textColor=colors.white, fontName="Helvetica-Bold")),
        Paragraph("Latitude", ParagraphStyle("H", parent=styles["Normal"], fontSize=9, textColor=colors.white, fontName="Helvetica-Bold")),
        Paragraph("Longitude", ParagraphStyle("H", parent=styles["Normal"], fontSize=9, textColor=colors.white, fontName="Helvetica-Bold")),
        Paragraph("Accuracy", ParagraphStyle("H", parent=styles["Normal"], fontSize=9, textColor=colors.white, fontName="Helvetica-Bold")),
    ]
    gps_rows = [gps_header]
    for i, pt in enumerate(plot.gps_points):
        gps_rows.append([
            Paragraph(f"P{i+1}", styles["Normal"]),
            Paragraph(f"{pt.latitude:.6f}", styles["Normal"]),
            Paragraph(f"{pt.longitude:.6f}", styles["Normal"]),
            Paragraph(f"±{pt.accuracy:.1f}m" if pt.accuracy else "N/A", styles["Normal"]),
        ])

    gps_table = Table(gps_rows, colWidths=[2*cm, 5*cm, 5*cm, 4*cm])
    gps_table.setStyle(TableStyle([
        ("BACKGROUND",    (0, 0), (-1, 0), GREEN_DARK),
        ("TEXTCOLOR",     (0, 0), (-1, 0), colors.white),
        ("FONTNAME",      (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE",      (0, 0), (-1, -1), 9),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, GREEN_LIGHT]),
        ("GRID",          (0, 0), (-1, -1), 0.5, colors.HexColor("#E5E7EB")),
        ("TOPPADDING",    (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING",   (0, 0), (-1, -1), 6),
    ]))
    story.append(gps_table)
    story.append(Spacer(1, 0.4*cm))

    # ── Witnesses ─────────────────────────────────────────
    story.append(Paragraph("WITNESS STATEMENTS", ParagraphStyle(
        "Section", parent=styles["Normal"],
        fontSize=9, textColor=GREEN_MID,
        fontName="Helvetica-Bold", spaceAfter=4
    )))

    for i, w in enumerate(plot.witnesses):
        w_data = [
            [Paragraph(f"Witness {i+1}: {w.full_name}", ParagraphStyle(
                "WH", parent=styles["Normal"], fontSize=10,
                fontName="Helvetica-Bold", textColor=GREEN_DARK
            ))],
            [Paragraph(f"Phone: {w.phone} | Relationship: {w.relationship_to_plot}", label_style)],
            [Paragraph(f'"{w.statement_text}"', ParagraphStyle(
                "WS", parent=styles["Normal"], fontSize=9,
                textColor=colors.black, leftIndent=10, italics=True
            ))],
        ]
        w_table = Table(w_data, colWidths=[16*cm])
        w_table.setStyle(TableStyle([
            ("BACKGROUND",    (0, 0), (-1, 0), GREEN_LIGHT),
            ("TOPPADDING",    (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ("LEFTPADDING",   (0, 0), (-1, -1), 8),
            ("BOX",           (0, 0), (-1, -1), 1, ACCENT),
        ]))
        story.append(w_table)
        story.append(Spacer(1, 0.2*cm))

    story.append(Spacer(1, 0.4*cm))

    # ── Blockchain Proof + QR ─────────────────────────────
    story.append(HRFlowable(width="100%", thickness=1, color=ACCENT, spaceAfter=6))
    story.append(Paragraph("BLOCKCHAIN VERIFICATION", ParagraphStyle(
        "Section", parent=styles["Normal"],
        fontSize=9, textColor=GREEN_MID,
        fontName="Helvetica-Bold", spaceAfter=4
    )))

    verify_url = f"{base_url}/verify/{plot.lv_plot_id}"
    qr_buf = generate_qr_code(verify_url)
    qr_img = RLImage(qr_buf, width=2.5*cm, height=2.5*cm)

    blockchain_info = [
        [Paragraph("Network", label_style),  Paragraph("Polygon Amoy Testnet", value_style)],
        [Paragraph("Tx Hash", label_style),   Paragraph(tx_hash or "Pending...", ParagraphStyle("mono", parent=styles["Normal"], fontSize=7, fontName="Courier"))],
        [Paragraph("Doc Hash", label_style),  Paragraph(doc_hash or "Pending...", ParagraphStyle("mono", parent=styles["Normal"], fontSize=7, fontName="Courier"))],
        [Paragraph("Timestamp", label_style), Paragraph(datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC"), value_style)],
    ]
    bc_text = Table(blockchain_info, colWidths=[3*cm, 10.5*cm])
    bc_text.setStyle(TableStyle([
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING",    (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ("LEFTPADDING",   (0, 0), (-1, -1), 4),
    ]))

    combined = Table([[bc_text, qr_img]], colWidths=[13.5*cm, 2.5*cm])
    combined.setStyle(TableStyle([
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING",   (0, 0), (-1, -1), 0),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 0),
    ]))
    story.append(combined)

    # ── Footer ────────────────────────────────────────────
    story.append(Spacer(1, 0.4*cm))
    story.append(HRFlowable(width="100%", thickness=1, color=GREEN_LIGHT, spaceAfter=4))
    story.append(Paragraph(
        "⚠️  This certificate is NOT a legal land title. It is an informal ownership documentation record. "
        "Scan the QR code or visit the URL above to verify this record on the blockchain.",
        ParagraphStyle("Disclaimer", parent=styles["Normal"], fontSize=7, textColor=GRAY, alignment=TA_CENTER)
    ))
    story.append(Paragraph(
        f"Generated by LandVault | {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')} | Open Source — MIT License",
        ParagraphStyle("Footer", parent=styles["Normal"], fontSize=7, textColor=GRAY, alignment=TA_CENTER)
    ))

    doc.build(story)
    buf.seek(0)
    return buf.read()
