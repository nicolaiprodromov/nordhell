#!/usr/bin/env python3

import sys
import os
import uvicorn
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

# Add parent directory to path to access scripts
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from config import config
from api import router

# Create FastAPI app
app = FastAPI(title=config.APP_NAME, version=config.VERSION)

# Mount static files
if os.path.exists(config.STATIC_DIR):
    app.mount("/static", StaticFiles(directory=config.STATIC_DIR), name="static")

# Include API routes
app.include_router(router)

if __name__ == "__main__":
    log_level = "debug" if config.DEBUG else "info"
    uvicorn.run(app, host=config.HOST, port=config.PORT, log_level=log_level)
