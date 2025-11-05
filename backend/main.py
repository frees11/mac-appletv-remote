import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from app.api import devices, control, debug, screenshot
from app.ws import websocket

load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    print("🚀 Starting Apple TV Remote Backend...")
    yield
    print("👋 Shutting down Apple TV Remote Backend...")


app = FastAPI(
    title="Apple TV Remote API",
    description="Backend API for controlling Apple TV devices",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS configuration
cors_origins_env = os.getenv("CORS_ORIGINS", "http://localhost:5173")

# Handle wildcard CORS for Electron app
if cors_origins_env == "*":
    origins = ["*"]
else:
    origins = [origin.strip() for origin in cors_origins_env.split(",")]

print(f"🔐 CORS origins: {origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(devices.router, prefix="/api", tags=["devices"])
app.include_router(control.router, prefix="/api", tags=["control"])
app.include_router(debug.router, prefix="/api", tags=["debug"])
app.include_router(screenshot.router, prefix="/api/screenshot", tags=["screenshot"])
app.include_router(websocket.router, prefix="/ws", tags=["websocket"])


@app.get("/")
async def root():
    return {
        "message": "Apple TV Remote API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    import sys

    # Force unbuffered output
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)

    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", 8000))

    # Detect if running from PyInstaller bundle
    is_bundled = getattr(sys, 'frozen', False) and hasattr(sys, '_MEIPASS')

    print(f"🚀 Starting server on {host}:{port}")
    print(f"📦 Bundled: {is_bundled}")

    if is_bundled:
        # In bundled mode, pass app object directly (no reload possible)
        uvicorn.run(
            app,  # Pass app object directly
            host=host,
            port=port,
            log_level="info"
        )
    else:
        # In development, use string module path to enable reload
        uvicorn.run(
            "main:app",
            host=host,
            port=port,
            reload=True,
            log_level="info"
        )
