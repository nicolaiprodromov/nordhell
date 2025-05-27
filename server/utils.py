import os
import re
import json
import glob
import asyncio
import aiohttp
from datetime import datetime
from typing import List, Dict, Any, Optional
from fastapi import HTTPException
from fastapi.responses import JSONResponse


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
        "is": "Iceland", "it": "Italy", "jp": "Japan", "je": "Jersey", 
        "jm": "Jamaica", "jo": "Jordan", "ke": "Kenya", "kh": "Cambodia", 
        "km": "Comoros", "kr": "South Korea", "kw": "Kuwait", "ky": "Cayman Islands", 
        "kz": "Kazakhstan", "la": "Laos", "lb": "Lebanon", "li": "Liechtenstein", 
        "lk": "Sri Lanka", "lt": "Lithuania", "lu": "Luxembourg", "lv": "Latvia", 
        "ly": "Libya", "ma": "Morocco", "mc": "Monaco", "md": "Moldova", 
        "me": "Montenegro", "mk": "North Macedonia", "mm": "Myanmar", "mn": "Mongolia", 
        "mr": "Mauritania", "mt": "Malta", "mx": "Mexico", "my": "Malaysia", 
        "mz": "Mozambique", "ng": "Nigeria", "nl": "Netherlands", "no": "Norway", 
        "np": "Nepal", "nz": "New Zealand", "pa": "Panama", "pe": "Peru", 
        "pg": "Papua New Guinea", "ph": "Philippines", "pk": "Pakistan", "pl": "Poland", 
        "pr": "Puerto Rico", "pt": "Portugal", "py": "Paraguay", "qa": "Qatar", 
        "ro": "Romania", "rs": "Serbia", "rw": "Rwanda", "se": "Sweden", 
        "sg": "Singapore", "si": "Slovenia", "sk": "Slovakia", "sn": "Senegal", 
        "so": "Somalia", "sv": "El Salvador", "td": "Chad", "tg": "Togo", 
        "th": "Thailand", "tn": "Tunisia", "tr": "Turkey", "tt": "Trinidad and Tobago", 
        "tw": "Taiwan", "ua": "Ukraine", "uk": "United Kingdom", "us": "United States", 
        "uy": "Uruguay", "uz": "Uzbekistan", "ve": "Venezuela", "vn": "Vietnam", 
        "za": "South Africa"
    }
    return country_map.get(code, "Unknown")


async def run_command(cmd: List[str], cwd: str) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, and stderr"""
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        cwd=cwd
    )
    stdout, stderr = await process.communicate()
    return process.returncode, stdout.decode(), stderr.decode()


async def get_external_ip_via_proxy(port: str) -> tuple[str, str]:
    """Get external IP and country using SOCKS proxy"""
    try:
        import aiohttp_socks
        
        # Create SOCKS proxy connector
        connector = aiohttp_socks.ProxyConnector.from_url(f'socks5://127.0.0.1:{port}')
        timeout = aiohttp.ClientTimeout(total=10)
        
        async with aiohttp.ClientSession(
            connector=connector, 
            timeout=timeout
        ) as session:
            # Get IP
            async with session.get("http://httpbin.org/ip") as response:
                data = await response.json()
                ip = data.get("origin", "Unknown")
                
            # Get country info
            async with session.get(f"http://ip-api.com/json/{ip}") as response:
                geo_data = await response.json()
                country = geo_data.get("country", "Unknown")
                
        return ip, country
    except Exception as e:
        # Fall back to simpler approach if aiohttp_socks not available
        try:
            # Use subprocess to call curl with SOCKS proxy
            cmd = ["curl", "--socks5", f"127.0.0.1:{port}", "-s", "http://httpbin.org/ip"]
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                import json
                data = json.loads(stdout.decode())
                ip = data.get("origin", "Unknown")
                
                # Get country using ip-api
                cmd_geo = ["curl", "--socks5", f"127.0.0.1:{port}", "-s", f"http://ip-api.com/json/{ip}"]
                process_geo = await asyncio.create_subprocess_exec(
                    *cmd_geo,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout_geo, stderr_geo = await process_geo.communicate()
                
                if process_geo.returncode == 0:
                    geo_data = json.loads(stdout_geo.decode())
                    country = geo_data.get("country", "Unknown")
                    return ip, country
            
        except Exception:
            pass
            
        return "Unknown", "Unknown"


def parse_uptime(created_time_str: str) -> str:
    """Parse container creation time and calculate uptime"""
    try:
        # Docker returns timestamps with nanosecond precision (9 digits after decimal)
        # but Python's fromisoformat only supports microsecond precision (6 digits)
        # We need to truncate the nanoseconds to microseconds
        
        # Replace Z with timezone offset
        timestamp = created_time_str.replace('Z', '+00:00')
        
        # Handle nanosecond precision by truncating to microseconds
        if '.' in timestamp and '+' in timestamp:
            # Split on the decimal point
            date_part, time_part = timestamp.split('.')
            # Split the fractional seconds and timezone
            fractional_part, tz_part = time_part.split('+')
            # Truncate to 6 digits (microseconds) if longer
            if len(fractional_part) > 6:
                fractional_part = fractional_part[:6]
            # Reconstruct the timestamp
            timestamp = f"{date_part}.{fractional_part}+{tz_part}"
        
        # Parse the corrected timestamp
        created_time = datetime.fromisoformat(timestamp)
        now = datetime.now(created_time.tzinfo)
        uptime = now - created_time
        
        days = uptime.days
        hours, remainder = divmod(uptime.seconds, 3600)
        minutes, _ = divmod(remainder, 60)
        
        if days > 0:
            return f"{days}d {hours}h {minutes}m"
        elif hours > 0:
            return f"{hours}h {minutes}m"
        else:
            return f"{minutes}m"
    except Exception:
        return "Unknown"


def parse_memory_usage(mem_stats: str) -> float:
    """Parse Docker memory usage string and return MB"""
    try:
        # Format is usually like "123.4MiB / 1.234GiB"
        mem_part = mem_stats.split(' / ')[0].strip()
        
        if 'GiB' in mem_part:
            return float(mem_part.replace('GiB', '')) * 1024
        elif 'MiB' in mem_part:
            return float(mem_part.replace('MiB', ''))
        elif 'KiB' in mem_part:
            return float(mem_part.replace('KiB', '')) / 1024
        else:
            return 0.0
    except Exception:
        return 0.0


def extract_vpn_server_from_logs(logs: str) -> str:
    """Extract VPN server from container logs"""
    for log_line in logs.split('\n'):
        if "Connected to VPN server" in log_line:
            # Extract server info from log line
            match = re.search(r'Connected to VPN server\s+(.+)', log_line)
            if match:
                return match.group(1).strip()
    return "Unknown"


def get_entrypoint_info(tunnel_id_str: str, root_dir: str) -> tuple[str, str]:
    """Get entrypoint location and IP from config file"""
    config_num_padded = f"{int(tunnel_id_str):03d}"
    config_pattern = os.path.join(root_dir, "vpn-configs", f"{config_num_padded}-*.tcp.ovpn")
    config_files = glob.glob(config_pattern)
    
    if config_files:
        config_filename = os.path.basename(config_files[0])
        country_match = re.match(r'^[0-9]{3}-([a-z]{2})[0-9a-zA-Z]*\.nordvpn\.com', config_filename)
        
        if country_match:
            country_code = country_match.group(1)
            country_name = get_country_name(country_code)
            
            # Extract IP from config file
            try:
                with open(config_files[0], 'r') as f:
                    for line in f:
                        if line.startswith('remote '):
                            parts = line.strip().split()
                            if len(parts) >= 2:
                                return country_name, parts[1]
            except Exception:
                pass
            
            return country_name, "Unknown"
    
    return "Unknown", "Unknown"
