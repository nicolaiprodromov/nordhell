import os
import re
from typing import List, Dict, Any, Optional
from fastapi import HTTPException

from utils import (
    run_command, get_external_ip_via_proxy, parse_uptime, 
    parse_memory_usage, extract_vpn_server_from_logs, get_entrypoint_info
)


class TunnelService:
    def __init__(self, root_dir: str):
        self.root_dir = root_dir
    
    async def get_tunnel_health(self, tunnel_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get basic health status of VPN tunnels (lightweight, fast)"""
        # Get container data using docker - only basic info needed for health check
        cmd = ["docker", "ps", "--filter", "name=llustr-proxy-tunnel-"]
        if tunnel_id is not None:
            cmd.extend(["--filter", f"name=llustr-proxy-tunnel-{tunnel_id}"])
        cmd.extend(["--format", "{{.Names}}|{{.Status}}|{{.Ports}}"])
        
        returncode, stdout, stderr = await run_command(cmd, self.root_dir)
        if returncode != 0:
            raise HTTPException(status_code=500, detail=f"Docker command failed: {stderr}")
        
        tunnels = []
        
        for line in stdout.strip().split('\n'):
            if not line:
                continue
                
            parts = line.split('|')
            if len(parts) < 3:
                continue
                
            container_name, status_text, port_info = parts
            
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
            
            # Determine status - only thing we need for health check
            status = "up" if "Up" in status_text and "unhealthy" not in status_text else "down"
            
            tunnels.append({
                "tunnel_id": int(tunnel_id_str),
                "tunnel": tunnel_name,
                "port": port,
                "status": status,
                "is_healthy": status == "up"
            })
        
        # Sort by tunnel_id
        tunnels.sort(key=lambda x: x["tunnel_id"])
        
        return tunnels
    
    async def get_tunnel_status(self, tunnel_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """Get status of VPN tunnels"""
        
        # Get container data using docker
        cmd = ["docker", "ps", "--filter", "name=llustr-proxy-tunnel-"]
        if tunnel_id is not None:
            cmd.extend(["--filter", f"name=llustr-proxy-tunnel-{tunnel_id}"])
        cmd.extend(["--format", "{{.ID}}|{{.Names}}|{{.Status}}|{{.Ports}}"])
        
        returncode, stdout, stderr = await run_command(cmd, self.root_dir)
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
            _, created_time, _ = await run_command(cmd_inspect, self.root_dir)
            
            # Calculate uptime
            time_alive = parse_uptime(created_time.strip()) if created_time.strip() else "Unknown"
            
            # Get VPN server info from logs
            cmd_logs = ["docker", "logs", container_id]
            _, logs, _ = await run_command(cmd_logs, self.root_dir)
            vpn_server = extract_vpn_server_from_logs(logs)
            
            # Determine location and IP from config file
            entrypoint_location, entrypoint_ip = get_entrypoint_info(tunnel_id_str, self.root_dir)
            
            # Get exit point IP and country using the SOCKS proxy
            exitpoint_ip = "Unknown"
            exitpoint_country = "Unknown"
            if port != "N/A" and status == "up":
                exitpoint_ip, exitpoint_country = await get_external_ip_via_proxy(port)
            
            # Get memory usage
            cmd_stats = ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}}", container_id]
            _, mem_stats, _ = await run_command(cmd_stats, self.root_dir)
            memory_mb = parse_memory_usage(mem_stats.strip()) if mem_stats.strip() else 0.0
            
            total_memory_mb += memory_mb
            
            tunnels.append({
                "tunnel_id": int(tunnel_id_str),
                "tunnel": tunnel_name,
                "port": port,
                "status": status,
                "time_alive": time_alive,
                "entrypoint_ip": entrypoint_ip,
                "entrypoint": entrypoint_location,
                "exitpoint_ip": exitpoint_ip,
                "exitpoint": exitpoint_country,
                "memory": f"{round(memory_mb, 2)}MB"
            })
        
        # Sort by tunnel_id
        tunnels.sort(key=lambda x: x["tunnel_id"])
        
        return tunnels

    async def start_tunnel(self, tunnel_id: str, build: bool = False, update_configs: bool = False) -> tuple[int, str, str]:
        """Start VPN tunnel(s)"""
        
        cmd = [os.path.join(self.root_dir, "start.sh")]
        
        if build:
            cmd.append("--build")
        if update_configs:
            cmd.append("--update-configs")
        
        cmd.append(tunnel_id)
        
        returncode, stdout, stderr = await run_command(cmd, self.root_dir)
        
        return returncode, stdout, stderr

    async def stop_tunnel(self, tunnel_id: str) -> tuple[int, str, str]:
        """Stop VPN tunnel(s)"""
        
        cmd = [os.path.join(self.root_dir, "stop.sh"), tunnel_id]
        returncode, stdout, stderr = await run_command(cmd, self.root_dir)
        
        return returncode, stdout, stderr

    async def replace_tunnel(self, stop_tunnel: int, start_tunnel: int) -> tuple[str, str]:
        """Replace one tunnel with another"""
        
        # First stop the old tunnel
        stop_returncode, stop_stdout, stop_stderr = await self.stop_tunnel(str(stop_tunnel))
        
        if stop_returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to stop tunnel {stop_tunnel}: {stop_stderr}")
        
        # Wait a moment to ensure port is released
        import asyncio
        await asyncio.sleep(2)
        
        # Then start the new tunnel
        start_returncode, start_stdout, start_stderr = await self.start_tunnel(str(start_tunnel))
        
        if start_returncode != 0:
            raise HTTPException(status_code=500, detail=f"Failed to start tunnel {start_tunnel}: {start_stderr}")
        
        return stop_stdout, start_stdout
