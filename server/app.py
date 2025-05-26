import os
import sys
import subprocess
import asyncio
import re
import json
from datetime import datetime
from typing import List, Optional, Dict, Any
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn
import httpx

# Add parent directory to path to access scripts
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

app = FastAPI(title="VPN Orchestrator API", version="1.0.0")

# Get the root directory (parent of server)
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class StartRequest(BaseModel):
    tunnel_id: Optional[str] = "0"  # Can be single number or range like "0-4"
    build: Optional[bool] = False
    update_configs: Optional[bool] = False

class StopRequest(BaseModel):
    tunnel_id: str  # Can be number or "all"

class ReplaceRequest(BaseModel):
    stop_tunnel: int
    start_tunnel: int

class PrettyJSONResponse(JSONResponse):
    def render(self, content: Any) -> bytes:
        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=2,
            separators=(",", ": ")
        ).encode("utf-8")

def get_country_name(code: str) -> str:
    """Convert country code to country name"""
    country_map = {
        "ad": "Andorra", "ae": "UAE", "af": "Afghanistan", "al": "Albania",
        "am": "Armenia", "ao": "Angola", "ar": "Argentina", "at": "Austria",
        "au": "Australia", "az": "Azerbaijan", "ba": "Bosnia", "bd": "Bangladesh",
        "be": "Belgium", "bg": "Bulgaria", "bh": "Bahrain", "bm": "Bermuda",
        "bn": "Brunei", "bo": "Bolivia", "br": "Brazil", "bs": "Bahamas",
        "bt": "Bhutan", "bz": "Belize", "ca": "Canada", "ch": "Switzerland",
        "cl": "Chile", "co": "Colombia", "cr": "Costa Rica", "cy": "Cyprus",
        "cz": "Czechia", "de": "Germany", "dk": "Denmark", "do": "Dominican Republic",
        "dz": "Algeria", "ec": "Ecuador", "ee": "Estonia", "eg": "Egypt",
        "es": "Spain", "et": "Ethiopia", "fi": "Finland", "fr": "France",
        "ge": "Georgia", "gh": "Ghana", "gl": "Greenland", "gr": "Greece",
        "gt": "Guatemala", "gu": "Guam", "hk": "Hong Kong", "hn": "Honduras",
        "hr": "Croatia", "hu": "Hungary", "id": "Indonesia", "ie": "Ireland",
        "il": "Israel", "im": "Isle of Man", "in": "India", "iq": "Iraq",
        "is": "Iceland", "it": "Italy", "jp": "Japan",        "je": "Jersey", "jm": "Jamaica", "jo": "Jordan", "jp": "Japan",
        "ke": "Kenya", "kh": "Cambodia", "km": "Comoros", "kr": "South Korea",
        "kw": "Kuwait", "ky": "Cayman Islands", "kz": "Kazakhstan", "la": "Laos",
        "lb": "Lebanon", "li": "Liechtenstein", "lk": "Sri Lanka", "lt": "Lithuania",
        "lu": "Luxembourg", "lv": "Latvia", "ly": "Libya", "ma": "Morocco",
        "mc": "Monaco", "md": "Moldova", "me": "Montenegro", "mk": "North Macedonia",
        "mm": "Myanmar", "mn": "Mongolia", "mr": "Mauritania", "mt": "Malta",
        "mx": "Mexico", "my": "Malaysia", "mz": "Mozambique", "ng": "Nigeria",
        "nl": "Netherlands", "no": "Norway", "np": "Nepal", "nz": "New Zealand",
        "pa": "Panama", "pe": "Peru", "pg": "Papua New Guinea", "ph": "Philippines",
        "pk": "Pakistan", "pl": "Poland", "pr": "Puerto Rico", "pt": "Portugal",
        "py": "Paraguay", "qa": "Qatar", "ro": "Romania", "rs": "Serbia",
        "rw": "Rwanda", "se": "Sweden", "sg": "Singapore", "si": "Slovenia",
        "sk": "Slovakia", "sn": "Senegal", "so": "Somalia", "sv": "El Salvador",
        "td": "Chad", "tg": "Togo", "th": "Thailand", "tn": "Tunisia",
        "tr": "Turkey", "tt": "Trinidad and Tobago", "tw": "Taiwan", "ua": "Ukraine",
        "uk": "United Kingdom", "us": "United States", "uy": "Uruguay", "uz": "Uzbekistan",
        "ve": "Venezuela", "vn": "Vietnam", "za": "South Africa"
    }
    return country_map.get(code, "Unknown")

async def run_command(cmd: List[str], cwd: str = ROOT_DIR) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, and stderr"""
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=cwd
    )
    stdout, stderr = await process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()

async def get_tunnel_status(tunnel_id: Optional[int] = None) -> List[Dict[str, Any]]:
    """Get status of VPN tunnels"""
    # Get container data using docker
    cmd = ["docker", "ps", "--filter", "name=llustr-proxy-tunnel-"]
    if tunnel_id is not None:
        cmd.extend(["--filter", f"name=llustr-proxy-tunnel-{tunnel_id}"])
    cmd.extend(["--format", "{{.ID}}|{{.Names}}|{{.Status}}|{{.Ports}}"])
    
    returncode, stdout, stderr = await run_command(cmd)
    if returncode != 0:
        raise HTTPException(status_code=500, detail=f"Docker command failed: {stderr}")
    
    tunnels = []
    total_memory_mb = 0.0
    
    for line in stdout.strip().split('\n'):
        if not line:
            continue
            
        parts = line.split('|')
        if len(parts) < 4:
            continue
            
        container_id, container_name, status_text, port_info = parts
        
        # Extract tunnel ID
        match = re.match(r'llustr-proxy-tunnel-(\d+)', container_name)
        if not match:
            continue
        tunnel_id_str = match.group(1)
        tunnel_name = f"LLUSTR[{tunnel_id_str}]"
        
        # Extract port
        port = "N/A"
        port_match = re.search(r'0\.0\.0\.0:(\d+)-', port_info)
        if port_match:
            port = port_match.group(1)
        
        # Determine status
        status = "up" if "Up" in status_text and "unhealthy" not in status_text else "down"
        
        # Get container creation time
        cmd_inspect = ["docker", "inspect", "-f", "{{.Created}}", container_id]
        _, created_time, _ = await run_command(cmd_inspect)
        
        # Calculate uptime
        time_alive = "Unknown"
        if created_time.strip():
            try:
                # Handle Docker's timestamp format with nanoseconds
                # Format: 2025-05-26T13:07:54.214207407Z
                timestamp_str = created_time.strip()
                
                # If there are nanoseconds (more than 6 digits after decimal), truncate to microseconds
                if '.' in timestamp_str:
                    # Split into datetime part and fractional seconds + timezone
                    dt_part, frac_and_tz = timestamp_str.split('.', 1)
                    # Extract fractional seconds and timezone
                    if 'Z' in frac_and_tz:
                        frac_part, tz_part = frac_and_tz.split('Z')
                        # Truncate to 6 digits (microseconds) if longer
                        if len(frac_part) > 6:
                            frac_part = frac_part[:6]
                        timestamp_str = f"{dt_part}.{frac_part}Z"
                
                # Parse the timestamp
                created_dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                current_dt = datetime.now(created_dt.tzinfo)
                uptime_seconds = int((current_dt - created_dt).total_seconds())
                
                days = uptime_seconds // 86400
                remaining = uptime_seconds % 86400
                hours = remaining // 3600
                minutes = (remaining % 3600) // 60
                seconds = remaining % 60
                
                if days > 0:
                    time_alive = f"{days}d {hours:02d}:{minutes:02d}:{seconds:02d}"
                else:
                    time_alive = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            except Exception as e:
                # For debugging: you could log the error
                # print(f"Error parsing timestamp '{created_time.strip()}': {e}")
                pass
        
        # Get VPN server info from logs
        cmd_logs = ["docker", "logs", container_id]
        _, logs, _ = await run_command(cmd_logs)
        vpn_server = "Unknown"
        for log_line in logs.split('\n'):
            if "Connected to VPN server" in log_line:
                vpn_server = re.sub(r'.*Connected to VPN server: |nordvpn |[()[\]]', '', log_line).split()[0]
                break
        
        # Determine location from config file (this is the entrypoint)
        entrypoint_location = "Unknown"
        config_num_padded = f"{int(tunnel_id_str):03d}"
        config_pattern = os.path.join(ROOT_DIR, "vpn-configs", f"{config_num_padded}-*.tcp.ovpn")
        import glob
        config_files = glob.glob(config_pattern)
        if config_files:
            config_filename = os.path.basename(config_files[0])
            country_match = re.match(r'^[0-9]{3}-([a-z]{2})[0-9a-zA-Z]*\.nordvpn\.com', config_filename)
            if country_match:
                country_code = country_match.group(1)
                entrypoint_location = get_country_name(country_code)
        
        # Get exit point IP and country using the SOCKS proxy
        exitpoint_ip = "Unknown"
        exitpoint_country = "Unknown"
        if port != "N/A" and status == "up":
            try:
                # Configure SOCKS proxy
                proxy_url = f"socks5://127.0.0.1:{port}"
                
                # Create a client with timeout and proxy
                async with httpx.AsyncClient(
                    proxies=proxy_url,
                    timeout=httpx.Timeout(10.0),
                    follow_redirects=True
                ) as client:
                    response = await client.get("https://ipinfo.io/json")
                    if response.status_code == 200:
                        data = response.json()
                        exitpoint_ip = data.get("ip", "Unknown")
                        exitpoint_country = data.get("country", "Unknown")
            except Exception:
                # If anything fails, keep default values
                pass
        
        # Get memory usage
        cmd_stats = ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}}", container_id]
        _, mem_stats, _ = await run_command(cmd_stats)
        memory_mb = 0.0
        if mem_stats.strip():
            mem_part = mem_stats.strip().split('/')[0].strip()
            mem_match = re.match(r'([\d.]+)([A-Za-z]+)', mem_part)
            if mem_match:
                value = float(mem_match.group(1))
                unit = mem_match.group(2)
                if unit == "KiB":
                    memory_mb = value / 1024
                elif unit == "MiB":
                    memory_mb = value
                elif unit == "GiB":
                    memory_mb = value * 1024
        
        total_memory_mb += memory_mb
        
        tunnels.append({
            "tunnel_id": int(tunnel_id_str),
            "tunnel_name": tunnel_name,
            "port": port,
            "status": status,
            "time_alive": time_alive,
            "vpn_server": vpn_server,
            "entrypoint_location": entrypoint_location,
            "exitpoint_ip": exitpoint_ip,
            "exitpoint_country": exitpoint_country,
            "memory_mb": round(memory_mb, 2)
        })
    
    # Sort by tunnel_id
    tunnels.sort(key=lambda x: x["tunnel_id"])
    
    return tunnels

@app.get("/", response_class=PrettyJSONResponse)
async def root():
    return {"message": "VPN Orchestrator API", "version": "1.0.0"}

@app.post("/start", response_class=PrettyJSONResponse)
async def start_tunnel(request: StartRequest):
    """Start VPN tunnel(s)"""
    cmd = [os.path.join(ROOT_DIR, "start.sh")]
    
    if request.build:
        cmd.append("--build")
    if request.update_configs:
        cmd.append("--update-configs")
    
    cmd.append(request.tunnel_id)
    
    returncode, stdout, stderr = await run_command(cmd)
    
    if returncode != 0:
        raise HTTPException(status_code=500, detail=f"Failed to start tunnel: {stderr}")
    
    return {
        "status": "success",
        "tunnel_id": request.tunnel_id,
        "output": stdout
    }

@app.post("/stop", response_class=PrettyJSONResponse)
async def stop_tunnel(request: StopRequest):
    """Stop VPN tunnel(s)"""
    cmd = [os.path.join(ROOT_DIR, "stop.sh"), request.tunnel_id]
    
    returncode, stdout, stderr = await run_command(cmd)
    
    if returncode != 0:
        raise HTTPException(status_code=500, detail=f"Failed to stop tunnel: {stderr}")
    
    return {
        "status": "success",
        "tunnel_id": request.tunnel_id,
        "output": stdout
    }

@app.get("/status", response_class=PrettyJSONResponse)
async def get_status(tunnel_ids: Optional[List[int]] = Query(None)):
    """Get status of VPN tunnels
    
    Parameters:
    - tunnel_ids: Optional list of tunnel IDs to filter by. If not provided, returns all tunnels.
    
    Examples:
    - /status - Returns all tunnels
    - /status?tunnel_ids=0&tunnel_ids=1&tunnel_ids=2 - Returns tunnels 0, 1, and 2
    """
    try:
        all_tunnels = await get_tunnel_status()
        
        # Filter by requested tunnel IDs if provided
        if tunnel_ids:
            filtered_tunnels = [t for t in all_tunnels if t["tunnel_id"] in tunnel_ids]
        else:
            filtered_tunnels = all_tunnels
        
        # Calculate total memory for filtered tunnels
        total_memory_mb = sum(t["memory_mb"] for t in filtered_tunnels)
        
        return {
            "tunnels": filtered_tunnels,
            "total_memory_mb": round(total_memory_mb, 2),
            "count": len(filtered_tunnels)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/replace", response_class=PrettyJSONResponse)
async def replace_tunnel(request: ReplaceRequest):
    """Replace one tunnel with another"""
    # First stop the old tunnel
    stop_cmd = [os.path.join(ROOT_DIR, "stop.sh"), str(request.stop_tunnel)]
    returncode, stop_stdout, stop_stderr = await run_command(stop_cmd)
    
    if returncode != 0:
        raise HTTPException(status_code=500, detail=f"Failed to stop tunnel {request.stop_tunnel}: {stop_stderr}")
    
    # Wait a moment to ensure port is released
    await asyncio.sleep(2)
    
    # Then start the new tunnel
    start_cmd = [os.path.join(ROOT_DIR, "start.sh"), str(request.start_tunnel)]
    returncode, start_stdout, start_stderr = await run_command(start_cmd)
    
    if returncode != 0:
        raise HTTPException(status_code=500, detail=f"Failed to start tunnel {request.start_tunnel}: {start_stderr}")
    
    return {
        "status": "success",
        "stopped_tunnel": request.stop_tunnel,
        "started_tunnel": request.start_tunnel,
        "stop_output": stop_stdout,
        "start_output": start_stdout
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")