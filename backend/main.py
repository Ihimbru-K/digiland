from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import create_tables
from routes.plot_routes import router as plot_router
from routes.auth_routes import router as auth_router

app = FastAPI(
    title="LandVault API",
    description="Informal Land Documentation & Verification Platform — Bamenda, Cameroon",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup():
    create_tables()


@app.get("/")
async def root():
    return {
        "app":     "LandVault API",
        "version": "1.0.0",
        "status":  "running",
        "docs":    "/docs",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}


app.include_router(auth_router)
app.include_router(plot_router)
