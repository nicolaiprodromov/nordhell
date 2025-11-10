import unittest
import requests
import sys
import subprocess
from typing import List, Tuple, Optional
class ProxyTester(unittest.TestCase):
    def setUp(self):
        self.host_ip = self._get_ip()
        print(f"Host IP: {self.host_ip}")
        self.tunnels = self._get_running_tunnels()
        if not self.tunnels:
            print("No active VPN tunnels found.")
    def _get_ip(self) -> Optional[str]:
        try:
            response = requests.get('https://api.ipify.org?format=json', timeout=10)
            return response.json()['ip']
        except Exception as e:
            print(f"Error getting IP: {e}")
            return None
    def _get_running_tunnels(self) -> List[Tuple[str, int]]:
        tunnels = []
        try:
            cmd = "docker ps --filter \"name=nordhell-passage-\" --format \"{{.Names}}\""
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            container_names = result.stdout.strip().split('\n')
            container_names = [name for name in container_names if name]
            for name in container_names:
                port_cmd = f"docker port {name} 1080/tcp"
                port_result = subprocess.run(port_cmd, shell=True, capture_output=True, text=True)
                if port_result.stdout:
                    port = port_result.stdout.strip().split(':')[-1]
                    tunnels.append((name, int(port)))
        except Exception as e:
            print(f"Error getting running tunnels: {e}")
        return tunnels
    def _get_proxy_ip(self, port: int) -> Optional[str]:
        try:
            proxies = {
                'http': f'socks5://localhost:{port}',
                'https': f'socks5://localhost:{port}'
            }
            response = requests.get('https://api.ipify.org?format=json', 
                                   proxies=proxies, 
                                   timeout=10)
            return response.json()['ip']
        except Exception as e:
            return None
    def test_host_ip(self):
        self.assertIsNotNone(self.host_ip, "Failed to get host IP address")
    def test_tunnels_running(self):
        self.assertTrue(len(self.tunnels) > 0, "No VPN tunnels are running")
    def test_all_tunnels(self):
        if not self.tunnels:
            self.skipTest("No tunnels to test")
        for name, port in self.tunnels:
            with self.subTest(f"Tunnel {name} on port {port}"):
                proxy_ip = self._get_proxy_ip(port)
                self.assertIsNotNone(proxy_ip, f"Failed to get IP through proxy on port {port}")
                self.assertNotEqual(self.host_ip, proxy_ip, 
                                   f"Tunnel {name} (port {port}) has same IP as host")
                print(f"Tunnel {name} (port {port}): IP = {proxy_ip} [PASSED]")
if __name__ == "__main__":
    print("VPN Tunnels Test")
    print("-----------------")
    unittest.main(verbosity=2)
