#!/usr/bin/env python3

import requests
import sys

def check_ip():
    print("Checking your regular IP without proxy...")
    try:
        response = requests.get('https://api.ipify.org?format=json')
        regular_ip = response.json()['ip']
        print(f"Your regular IP: {regular_ip}")
    except Exception as e:
        print(f"Error getting regular IP: {e}")
        regular_ip = None

    print("\nChecking IP through SOCKS5 proxy...")
    try:
        proxies = {
            'http': 'socks5://localhost:1080',
            'https': 'socks5://localhost:1080'
        }
        response = requests.get('https://api.ipify.org?format=json', proxies=proxies)
        proxy_ip = response.json()['ip']
        print(f"Your proxy IP: {proxy_ip}")

        if regular_ip and regular_ip != proxy_ip:
            print("\nSuccess! Your IP is different when using the proxy.")
            return True
        else:
            print("\nWarning: Your IP is the same with and without the proxy.")
            return False
    except Exception as e:
        print(f"Error connecting through proxy: {e}")
        return False

if __name__ == "__main__":
    print("SOCKS5 Proxy Test")
    print("-----------------")
    success = check_ip()
    sys.exit(0 if success else 1)
