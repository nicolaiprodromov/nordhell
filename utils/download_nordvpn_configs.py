#!/usr/bin/env python3

import os
import sys
import requests
import zipfile
import io
import argparse
import traceback
import random
import shutil
from collections import defaultdict
import re

def download_nordvpn_zip(output_dir, protocol='tcp', count=200, max_per_country=1, clear_folder=True):
    # Ensure we're using absolute path if relative path is provided
    if not os.path.isabs(output_dir):
        # Assuming this script is in utils/ directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(script_dir)
        output_dir = os.path.join(project_root, output_dir)
    
    # Clear the output directory if requested
    if clear_folder and os.path.exists(output_dir):
        print(f"Clearing existing configs from {output_dir}...")
        for file in os.listdir(output_dir):
            file_path = os.path.join(output_dir, file)
            if os.path.isfile(file_path) and file.endswith('.ovpn'):
                os.remove(file_path)
        print(f"Cleared {output_dir}")
    
    os.makedirs(output_dir, exist_ok=True)
    url = "https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip"
    print(f"Downloading NordVPN OpenVPN config ZIP for {protocol}...")

    try:
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        resp = requests.get(url, headers=headers, timeout=60)
        if resp.status_code != 200:
            print(f"Failed to download ZIP: status {resp.status_code}")
            return False

        successful_downloads = 0
        with zipfile.ZipFile(io.BytesIO(resp.content)) as z:
            config_files_in_zip = [f for f in z.namelist() if f'ovpn_{protocol}' in f and f.endswith('.ovpn')]
            
            # Group configs by country code
            country_pattern = re.compile(r'([a-z]{2})\d+\.nordvpn\.com')
            country_configs = defaultdict(list)
            for file in config_files_in_zip:
                filename = os.path.basename(file)
                match = country_pattern.match(filename)
                if match:
                    country_code = match.group(1)
                    country_configs[country_code].append(file)
                else:
                    # For files that don't match the pattern, group them under 'unknown'
                    country_configs['unknown'].append(file)
            
            # Sort country codes to ensure consistent ordering
            country_codes = sorted(country_configs.keys())
            print(f"Found configs for {len(country_codes)} different countries")
            
            # Print a summary of available countries and counts
            for country in country_codes:
                print(f"  {country}: {len(country_configs[country])} servers")
            
            selected_files = []
            # Select exactly one config from each country
            for country in country_codes:
                country_files = country_configs[country]
                # Sort files within a country to get consistent selection
                country_files.sort()
                # Take one random server from each country
                if country_files:
                    selected_from_country = random.sample(country_files, 1)
                    selected_files.extend(selected_from_country)
                    print(f"  Selected 1 server from {country}")
            
            # Apply the count limit if specified (though with one per country, we typically won't hit this)
            if len(selected_files) > count:
                print(f"Selected {len(selected_files)} configs, but count is limited to {count}")
                random.shuffle(selected_files)
                selected_files = selected_files[:count]
            
            # Sort the final selection for consistent numbering
            selected_files.sort()
            print(f"Total selected servers: {len(selected_files)}")
            
            # Process the selected files
            for i, file in enumerate(selected_files):
                filename = os.path.basename(file)
                file_path = os.path.join(output_dir, f"{i:03d}-{filename}")
                original_content_bytes = z.read(file)
                original_content = original_content_bytes.decode('utf-8', errors='ignore')

                lines = original_content.splitlines()
                new_lines = []
                script_security_found = False
                auth_user_pass_modified = False
                has_ping_restart = False
                
                for line in lines:
                    stripped_line = line.strip()

                    if stripped_line.startswith('pull-filter ignore "dhcp-option DNS"'): continue
                    if stripped_line.startswith('pull-filter ignore "dhcp-option DOMAIN"'): continue
                    if stripped_line.startswith('pull-filter ignore "block-outside-dns"'): continue
                    if stripped_line.startswith('pull-filter ignore "redirect-gateway"'): continue
                    if stripped_line == 'route-noexec': continue

                    # Skip keepalive directive if we find a ping directive
                    if stripped_line.startswith('ping-restart'):
                        has_ping_restart = True
                        new_lines.append(line)
                    elif stripped_line.startswith('ping-exit'): 
                        has_ping_restart = True
                        new_lines.append(line)
                    elif stripped_line.startswith('ping '): 
                        has_ping_restart = True
                        new_lines.append(line)
                    elif stripped_line.startswith('keepalive') and has_ping_restart:
                        # Skip keepalive if we have ping directives
                        continue
                    elif stripped_line == 'auth-user-pass':
                        new_lines.append('auth-user-pass /run/vpn-credentials/auth.txt')
                        auth_user_pass_modified = True
                    elif stripped_line.startswith('script-security'):
                        script_security_found = True
                        try:
                            level = int(stripped_line.split()[-1])
                            new_lines.append(line if level >= 2 else 'script-security 2')
                        except (ValueError, IndexError):
                            new_lines.append('script-security 2')
                    elif stripped_line.startswith(('up ', 'down ')) and ('resolv' in stripped_line or 'systemd-resolved' in stripped_line):
                        continue
                    elif stripped_line.startswith('redirect-gateway'):
                        continue
                    elif stripped_line.startswith('up '):
                        continue
                    elif stripped_line.startswith('down '):
                        continue
                    else:
                        new_lines.append(line)

                if not auth_user_pass_modified: new_lines.insert(1, 'auth-user-pass /run/vpn-credentials/auth.txt')
                if not script_security_found: new_lines.insert(1, 'script-security 2')
                
                # Add the enhanced directives
                # If we don't have ping-restart already, add it
                if not has_ping_restart:
                    new_lines.append('ping-restart 60')
                
                # Add connection resilience directives that won't conflict
                new_lines.append('connect-retry 2 10')
                new_lines.append('connect-timeout 10')
                new_lines.append('connect-retry-max 10')
                # Temporarily comment out script-related directives that might be causing issues
                # new_lines.append('route-up /app/scripts/vpn_up.sh')
                # new_lines.append('down /app/scripts/vpn_down.sh')
                # new_lines.append('up-restart')

                modified_content = "\n".join(new_lines) + "\n"

                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(modified_content)
                successful_downloads += 1
                if successful_downloads % 25 == 0 or successful_downloads == 1 or successful_downloads == len(selected_files):
                    print(f"  Processed {successful_downloads}/{len(selected_files)} ({filename})")

        print(f"\nExtracted and modified {successful_downloads} {protocol} configs to {output_dir}")
        return successful_downloads > 0

    except requests.exceptions.RequestException as e:
        print(f"Network error downloading ZIP: {str(e)}")
        return False
    except zipfile.BadZipFile:
        print("Error: Downloaded file is not a valid ZIP archive.")
        return False
    except ImportError:
        pass
    except Exception as e:
        print(f"An unexpected error occurred in download_nordvpn_zip: {str(e)}")
        traceback.print_exc()
        return False

def main():
    parser = argparse.ArgumentParser(description='Download and Modify NordVPN OpenVPN config ZIP for Policy Routing')
    parser.add_argument('--output', '-o', default='./vpn-configs', help='Output directory (default: ./vpn-configs)')
    parser.add_argument('--protocol', '-p', default='tcp', choices=['tcp', 'udp'], help='Protocol (tcp or udp, default: tcp)')
    parser.add_argument('--count', '-c', type=int, default=200, help='Maximum number of configs to extract (default: 200)')
    parser.add_argument('--max-per-country', '-m', type=int, default=1, help='Maximum configs to download per country (default: 1)')
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    try:
        import natsort
    except ImportError:
        print("\nWarning: 'natsort' package not found for natural sorting of config files.")
        print("         Consider installing it: python3 -m pip install natsort\n")

    success = download_nordvpn_zip(args.output, args.protocol, args.count, args.max_per_country)
    if success:
        print("\nConfiguration files downloaded and modified successfully.")
    else:
        print("\nFailed to download/modify configuration files.")
        sys.exit(1)

if __name__ == "__main__":
    main()