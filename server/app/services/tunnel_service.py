import os
import re
import asyncio
from typing import List, Dict, Any, Optional
from fastapi import HTTPException

from app.utils.helpers import (
    run_command, get_external_ip_via_proxy, parse_uptime, 
    parse_memory_usage, extract_vpn_server_from_logs, get_entrypoint_info
)


class TunnelService:
    def __init__(self, root_dir: str):
        self.root_dir = root_dir
        self._entrypoint_cache = {}  # Cache for entrypoint info
    
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
        """Get status of VPN tunnels - optimized version"""
        
        # Get container data using docker
        cmd = ["docker", "ps", "--filter", "name=llustr-proxy-tunnel-"]
        if tunnel_id is not None:
            cmd.extend(["--filter", f"name=llustr-proxy-tunnel-{tunnel_id}"])
        cmd.extend(["--format", "{{.ID}}|{{.Names}}|{{.Status}}|{{.Ports}}"])
        
        returncode, stdout, stderr = await run_command(cmd, self.root_dir)
        if returncode != 0:
            raise HTTPException(status_code=500, detail=f"Docker command failed: {stderr}")
        
        if not stdout.strip():
            return []
        
        container_info = []
        container_ids = []
        
        # Parse container basic info
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
            
            # Extract port
            port = "N/A"
            port_match = re.search(r'0\.0\.0\.0:(\d+)-', port_info)
            if port_match:
                port = port_match.group(1)
            
            # Determine status
            status = "up" if "Up" in status_text and "unhealthy" not in status_text else "down"
            
            container_info.append({
                "container_id": container_id,
                "tunnel_id": int(tunnel_id_str),
                "tunnel_id_str": tunnel_id_str,
                "port": port,
                "status": status
            })
            container_ids.append(container_id)
        
        if not container_info:
            return []
        
        # Batch Docker operations for better performance
        batch_tasks = []
        
        # 1. Get creation times for all containers in batch
        if container_ids:
            cmd_inspect = ["docker", "inspect", "-f", "{{.Created}}", *container_ids]
            batch_tasks.append(run_command(cmd_inspect, self.root_dir))
        
        # 2. Get memory stats for all containers in batch
        if container_ids:
            cmd_stats = ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}}", *container_ids]
            batch_tasks.append(run_command(cmd_stats, self.root_dir))
        
        # 3. Get logs for all containers (we'll do this in parallel but separately due to potentially large output)
        log_tasks = [run_command(["docker", "logs", cid], self.root_dir) for cid in container_ids]
        
        # Execute batch operations
        batch_results = await asyncio.gather(*batch_tasks, return_exceptions=True)
        creation_times = []
        memory_stats = []
        
        if len(batch_results) >= 1 and not isinstance(batch_results[0], Exception):
            _, created_output, _ = batch_results[0]
            creation_times = created_output.strip().split('\n') if created_output.strip() else []
        
        if len(batch_results) >= 2 and not isinstance(batch_results[1], Exception):
            _, mem_output, _ = batch_results[1]
            memory_stats = mem_output.strip().split('\n') if mem_output.strip() else []
        
        # Get logs in parallel
        log_results = await asyncio.gather(*log_tasks, return_exceptions=True)
        
        # Get entrypoint info (cached)
        entrypoint_tasks = []
        for info in container_info:
            entrypoint_tasks.append(self._get_entrypoint_info_cached(info["tunnel_id_str"]))
        
        if entrypoint_tasks:
            entrypoint_results = await asyncio.gather(*entrypoint_tasks, return_exceptions=True)
        else:
            entrypoint_results = []
        
        # Get external IP/country info in parallel for running tunnels
        external_ip_tasks = []
        external_ip_indices = []
        
        for i, info in enumerate(container_info):
            if info["status"] == "up" and info["port"] != "N/A":
                external_ip_tasks.append(get_external_ip_via_proxy(info["port"]))
                external_ip_indices.append(i)
        
        if external_ip_tasks:
            external_ip_results = await asyncio.gather(*external_ip_tasks, return_exceptions=True)
        else:
            external_ip_results = []
        
        # Build final results
        tunnels = []
        
        for i, info in enumerate(container_info):
            tunnel_name = f"LLUSTR[{info['tunnel_id_str']}]"
            
            # Get creation time
            time_alive = "Unknown"
            if i < len(creation_times) and creation_times[i]:
                time_alive = parse_uptime(creation_times[i]) 
            
            # Get VPN server info from logs
            vpn_server = "Unknown"
            if i < len(log_results) and not isinstance(log_results[i], Exception):
                _, logs, _ = log_results[i]
                vpn_server = extract_vpn_server_from_logs(logs)
            
            # Get entrypoint info
            entrypoint_location = "Unknown"
            entrypoint_ip = "Unknown"
            if i < len(entrypoint_results) and not isinstance(entrypoint_results[i], Exception):
                entrypoint_location, entrypoint_ip = entrypoint_results[i]
            
            # Get external IP info
            exitpoint_ip = "Unknown"
            exitpoint_country = "Unknown"
            external_ip_idx = next((j for j, idx in enumerate(external_ip_indices) if idx == i), None)
            if external_ip_idx is not None and external_ip_idx < len(external_ip_results):
                if not isinstance(external_ip_results[external_ip_idx], Exception):
                    exitpoint_ip, exitpoint_country = external_ip_results[external_ip_idx]
            
            # Get memory usage
            memory_mb = 0.0
            if i < len(memory_stats) and memory_stats[i]:
                memory_mb = parse_memory_usage(memory_stats[i])
            
            tunnels.append({
                "tunnel_id": info["tunnel_id"],
                "tunnel": tunnel_name,
                "port": info["port"],
                "status": info["status"],
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
    
    async def _get_entrypoint_info_cached(self, tunnel_id_str: str) -> tuple[str, str]:
        """Get entrypoint info with caching"""
        if tunnel_id_str not in self._entrypoint_cache:
            result = get_entrypoint_info(tunnel_id_str, self.root_dir)
            self._entrypoint_cache[tunnel_id_str] = result
            return result
        return self._entrypoint_cache[tunnel_id_str]

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
