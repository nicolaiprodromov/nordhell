import os
from typing import Optional

class Config:
    """Application configuration"""
    
    # Server settings
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    
    # Application settings
    APP_NAME: str = "VPN Orchestrator API"
    VERSION: str = "1.0.0"
    
    # Paths
    ROOT_DIR: str = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    TEMPLATES_DIR: str = os.path.join(os.path.dirname(__file__), "templates")
    STATIC_DIR: str = os.path.join(os.path.dirname(__file__), "static")
    
    # VPN Configuration
    VPN_CONFIGS_DIR: str = os.path.join(ROOT_DIR, "vpn-configs")
    
    # Docker settings
    CONTAINER_PREFIX: str = "llustr-proxy-tunnel-"
    
    # API settings
    AUTO_REFRESH_INTERVAL: int = 30  # seconds
    REQUEST_TIMEOUT: int = 10  # seconds
    
    @classmethod
    def get_script_path(cls, script_name: str) -> str:
        """Get full path to a script in the root directory"""
        return os.path.join(cls.ROOT_DIR, script_name)


# Create global config instance
config = Config()
