import os
from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import HTMLResponse

from models import StartRequest, StopRequest, ReplaceRequest
from utils import PrettyJSONResponse
from services import TunnelService
from config import config

# Initialize tunnel service
tunnel_service = TunnelService(config.ROOT_DIR)

# Create router
router = APIRouter()


@router.get("/", response_class=HTMLResponse)
async def dashboard():
    """Serve the interactive dashboard"""
    template_path = os.path.join(config.TEMPLATES_DIR, "dashboard.html")
    try:
        with open(template_path, 'r') as f:
            return f.read()
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail="Dashboard template not found")


@router.get("/api", response_class=PrettyJSONResponse)
async def api_root():
    return {"message": "VPN Orchestrator API", "version": "1.0.0"}


@router.get("/docs")
async def get_docs():
    """Get API documentation as markdown"""
    docs_path = os.path.join(os.path.dirname(__file__), "README.md")
    try:
        with open(docs_path, 'r') as f:
            content = f.read()
        return {"documentation": content}
    except FileNotFoundError:
        return {"error": "Documentation not found"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error reading documentation: {str(e)}")


@router.post("/start", response_class=PrettyJSONResponse)
async def start_tunnel(request: StartRequest):
    """Start VPN tunnel(s)"""
    try:
        returncode, stdout, stderr = await tunnel_service.start_tunnel(
            request.tunnel_id, 
            request.build, 
            request.update_configs
        )
        
        if returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to start tunnel: {stderr}")
        
        return {
            "status": "success",
            "tunnel_id": request.tunnel_id,
            "output": stdout
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stop", response_class=PrettyJSONResponse)
async def stop_tunnel(request: StopRequest):
    """Stop VPN tunnel(s)"""
    try:
        returncode, stdout, stderr = await tunnel_service.stop_tunnel(request.tunnel_id)
        
        if returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to stop tunnel: {stderr}")
        
        return {
            "status": "success",
            "tunnel_id": request.tunnel_id,
            "output": stdout
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/status", response_class=PrettyJSONResponse)
async def get_status(tunnel_ids: Optional[List[int]] = Query(None)):
    """Get status of VPN tunnels
    
    Parameters:
    - tunnel_ids: Optional list of tunnel IDs to filter by. If not provided, returns all tunnels.
    
    Examples:
    - /status - Returns all tunnels
    - /status?tunnel_ids=0&tunnel_ids=1&tunnel_ids=2 - Returns tunnels 0, 1, and 2
    """
    try:
        if tunnel_ids:
            # Get status for specific tunnels
            all_tunnels = []
            for tunnel_id in tunnel_ids:
                tunnels = await tunnel_service.get_tunnel_status(tunnel_id)
                all_tunnels.extend(tunnels)
        else:
            # Get status for all tunnels
            all_tunnels = await tunnel_service.get_tunnel_status()
        
        # Calculate total memory
        total_memory_mb = sum(
            float(tunnel["memory"].replace("MB", "")) 
            for tunnel in all_tunnels 
            if tunnel["memory"] != "N/A"
        )
        
        return {
            "tunnels": all_tunnels,
            "total_memory_mb": round(total_memory_mb, 2),
            "count": len(all_tunnels)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get tunnel status: {str(e)}")


@router.post("/replace", response_class=PrettyJSONResponse)
async def replace_tunnel(request: ReplaceRequest):
    """Replace one tunnel with another"""
    try:
        stop_output, start_output = await tunnel_service.replace_tunnel(
            request.stop_tunnel, 
            request.start_tunnel
        )
        
        return {
            "status": "success",
            "stopped_tunnel": request.stop_tunnel,
            "started_tunnel": request.start_tunnel,
            "stop_output": stop_output,
            "start_output": start_output
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
