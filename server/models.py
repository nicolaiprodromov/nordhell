from typing import Optional
from pydantic import BaseModel


class StartRequest(BaseModel):
    tunnel_id: Optional[str] = "0"  # Can be single number or range like "0-4"
    build: Optional[bool] = False
    update_configs: Optional[bool] = False


class StopRequest(BaseModel):
    tunnel_id: str  # Can be number or "all"


class ReplaceRequest(BaseModel):
    stop_tunnel: int
    start_tunnel: int
