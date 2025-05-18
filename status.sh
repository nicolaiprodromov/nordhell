#!/bin/bash
# status.sh - List all active VPN tunnels

# Define checkmark and X symbols
CHECK_MARK="✓" 
X_MARK="✗"

echo "-------------------------------------"
echo "LLUSTR TNNLs:"
echo "-------------------------------------"

# Check if any llustr containers are running
if ! docker ps --filter "name=llustr-proxy-tunnel-" | grep -q llustr-proxy-tunnel; then
    echo "No active VPN tunnels found."
    exit 0
fi

# Make sure the docker commands will work
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Create temporary file to store the table data
TABLE_DATA=$(mktemp)

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Add header to the table data
echo -e "TUNNEL\tPORT\tSTATUS\tTIME ALIVE\tSERVER\tLOCATION" > "$TABLE_DATA"
echo -e "------\t----\t------\t----------\t------\t--------" >> "$TABLE_DATA"

# Create country code mapping function
get_country_name() {
    local code=$1
    case "$code" in
        ad) echo "Andorra" ;;
        ae) echo "UAE" ;;
        af) echo "Afghanistan" ;;
        al) echo "Albania" ;;
        am) echo "Armenia" ;;
        ao) echo "Angola" ;;
        ar) echo "Argentina" ;;
        at) echo "Austria" ;;
        au) echo "Australia" ;;
        az) echo "Azerbaijan" ;;
        ba) echo "Bosnia" ;;
        bd) echo "Bangladesh" ;;
        be) echo "Belgium" ;;
        bg) echo "Bulgaria" ;;
        bh) echo "Bahrain" ;;
        bm) echo "Bermuda" ;;
        bn) echo "Brunei" ;;
        bo) echo "Bolivia" ;;
        br) echo "Brazil" ;;
        bs) echo "Bahamas" ;;
        bt) echo "Bhutan" ;;
        bz) echo "Belize" ;;
        ca) echo "Canada" ;;
        ch) echo "Switzerland" ;;
        cl) echo "Chile" ;;
        co) echo "Colombia" ;;
        cr) echo "Costa Rica" ;;
        cy) echo "Cyprus" ;;
        cz) echo "Czechia" ;;
        de) echo "Germany" ;;
        dk) echo "Denmark" ;;
        do) echo "Dominican Republic" ;;
        dz) echo "Algeria" ;;
        ec) echo "Ecuador" ;;
        ee) echo "Estonia" ;;
        eg) echo "Egypt" ;;
        es) echo "Spain" ;;
        et) echo "Ethiopia" ;;
        fi) echo "Finland" ;;
        fr) echo "France" ;;
        ge) echo "Georgia" ;;
        gh) echo "Ghana" ;;
        gl) echo "Greenland" ;;
        gr) echo "Greece" ;;
        gt) echo "Guatemala" ;;
        gu) echo "Guam" ;;
        hk) echo "Hong Kong" ;;
        hn) echo "Honduras" ;;
        hr) echo "Croatia" ;;
        hu) echo "Hungary" ;;
        id) echo "Indonesia" ;;
        ie) echo "Ireland" ;;
        il) echo "Israel" ;;
        im) echo "Isle of Man" ;;
        in) echo "India" ;;
        iq) echo "Iraq" ;;
        is) echo "Iceland" ;;
        it) echo "Italy" ;;
        jp) echo "Japan" ;;
        kr) echo "South Korea" ;;
        lu) echo "Luxembourg" ;;
        lv) echo "Latvia" ;;
        md) echo "Moldova" ;;
        mx) echo "Mexico" ;;
        my) echo "Malaysia" ;;
        nl) echo "Netherlands" ;;
        no) echo "Norway" ;;
        nz) echo "New Zealand" ;;
        pl) echo "Poland" ;;
        pt) echo "Portugal" ;;
        ro) echo "Romania" ;;
        rs) echo "Serbia" ;;
        ru) echo "Russia" ;;
        se) echo "Sweden" ;;
        sg) echo "Singapore" ;;
        th) echo "Thailand" ;;
        tr) echo "Turkey" ;;
        tw) echo "Taiwan" ;;
        ua) echo "Ukraine" ;;
        uk) echo "United Kingdom" ;;
        us) echo "United States" ;;
        vn) echo "Vietnam" ;;
        za) echo "South Africa" ;;
        *) echo "Unknown" ;;
    esac
}

# Get all running containers with the llustr prefix and store in an array
mapfile -t CONTAINER_ARRAY < <(docker ps --filter "name=llustr-proxy-tunnel-" --format "{{.Names}}" | sort -V)

# Loop through each container in reverse order
for ((i=${#CONTAINER_ARRAY[@]}-1; i>=0; i--)); do
    CONTAINER="${CONTAINER_ARRAY[i]}"
    # Get the port
    PORT=$(docker port $CONTAINER 1080/tcp | cut -d ':' -f 2)
    
    # Get the raw status output
    RAW_STATUS=$(docker ps --filter "name=$CONTAINER" --format "{{.Status}}" | head -1)
    
    # Get container creation time and calculate uptime precisely
    CREATED_TIME=$(docker inspect --format='{{.Created}}' $CONTAINER)
    CREATED_TIMESTAMP=$(date -d "$CREATED_TIME" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    UPTIME_SECONDS=$((CURRENT_TIMESTAMP - CREATED_TIMESTAMP))
    
    # Format time as HH:MM:SS
    HOURS=$((UPTIME_SECONDS / 3600))
    MINUTES=$(( (UPTIME_SECONDS % 3600) / 60 ))
    SECONDS=$((UPTIME_SECONDS % 60))
    
    # Handle days if uptime is more than 24 hours
    if [ $HOURS -ge 24 ]; then
        DAYS=$((HOURS / 24))
        HOURS=$((HOURS % 24))
        TIME_ALIVE=$(printf "%dd %02d:%02d:%02d" $DAYS $HOURS $MINUTES $SECONDS)
    else
        TIME_ALIVE=$(printf "%02d:%02d:%02d" $HOURS $MINUTES $SECONDS)
    fi
    
    # Set status icon
    if [[ "$RAW_STATUS" =~ Up.*healthy ]]; then
        STATUS="$CHECK_MARK"
    else
        STATUS="$X_MARK"
    fi
    
    # Get VPN server info from logs - extract IP only, no brackets
    VPN_SERVER_INFO=$(docker logs $CONTAINER 2>&1 | grep "Connected to VPN server" | head -1)
    VPN_SERVER=$(echo "$VPN_SERVER_INFO" | sed -e 's/.*Connected to VPN server: //' -e 's/nordvpn //g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g')
    
    # Extract container number from container name
    CONTAINER_NUM=0
    if [[ "$CONTAINER" =~ llustr-proxy-tunnel-([0-9]+) ]]; then
        CONTAINER_NUM=${BASH_REMATCH[1]}
    fi
    
    # Look for the matching VPN config file in the host system
    CONFIG_NUM=$(printf "%03d" $CONTAINER_NUM)
    CONFIG_FILE=$(ls -1 ${SCRIPT_DIR}/vpn-configs/${CONFIG_NUM}-*.tcp.ovpn 2>/dev/null)
    
    # Extract country code from config file name
    if [[ -n "$CONFIG_FILE" && "$CONFIG_FILE" =~ /([0-9]{3})-([a-z]{2})[0-9]+\.nordvpn\.com ]]; then
        COUNTRY_CODE="${BASH_REMATCH[2]}"
        LOCATION=$(get_country_name "$COUNTRY_CODE")
    else
        # Fallback to extracting from logs if file not found
        SERVER_DOMAIN=$(echo "$VPN_SERVER_INFO" | grep -o '[a-z][a-z][0-9]\+\.nordvpn\.com' | head -1)
        
        if [[ "$SERVER_DOMAIN" =~ ^([a-z][a-z])[0-9]+ ]]; then
            COUNTRY_CODE="${BASH_REMATCH[1]}"
            LOCATION=$(get_country_name "$COUNTRY_CODE")
        else
            LOCATION="Unknown"
        fi
    fi
    
    # If we couldn't find the VPN server info, mark as unknown
    if [ -z "$VPN_SERVER" ]; then
        VPN_SERVER="Unknown"
    fi
    
    # Format container name as LLUSTR[tunnel_id]
    if [[ "$CONTAINER" =~ llustr-proxy-tunnel-([0-9]+) ]]; then
        TUNNEL_ID=${BASH_REMATCH[1]}
        TUNNEL_NAME="LLUSTR[$TUNNEL_ID]"
    else
        TUNNEL_NAME=$CONTAINER
    fi
    
    # Add the row to our table data file (tab-separated)
    echo -e "$TUNNEL_NAME\t$PORT\t$STATUS\t$TIME_ALIVE\t$VPN_SERVER\t$LOCATION" >> "$TABLE_DATA"
done

# Format and display the table using column command
column -t -s $'\t' "$TABLE_DATA"

# Remove temporary file
rm "$TABLE_DATA"

echo "-------------------------------------"
