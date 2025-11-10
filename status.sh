#!/bin/bash

CHECK_MARK="✓" 
X_MARK="✗"

echo "-------------------------------------"
echo "LLUSTR TNNLs:"
echo "-------------------------------------"


if ! docker ps --filter "name=llustr-proxy-tunnel-" | grep -q llustr-proxy-tunnel; then
    echo "No active VPN tunnels found."
    exit 0
fi


if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi


TABLE_DATA=$(mktemp)

if [ -z "$TABLE_DATA" ]; then
    echo "Error: Could not create temporary file."
    exit 1
fi

trap 'rm -f "$TABLE_DATA"' EXIT


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


echo -e "TUNNEL\tPORT\tSTATUS\tTIME ALIVE\tENTRYPOINT IP\tENTRYPOINT\tEXITPOINT IP\tEXITPOINT\tMEMORY" > "$TABLE_DATA"
echo -e "------\t----\t------\t----------\t------\t----------\t------------\t---------\t------" >> "$TABLE_DATA"


TOTAL_MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" 0)


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
        je) echo "Jersey" ;;
        jm) echo "Jamaica" ;;
        jo) echo "Jordan" ;;
        jp) echo "Japan" ;;
        ke) echo "Kenya" ;;
        kh) echo "Cambodia" ;;
        km) echo "Comoros" ;;
        kr) echo "South Korea" ;;
        kw) echo "Kuwait" ;;
        ky) echo "Cayman Islands" ;;
        kz) echo "Kazakhstan" ;;
        la) echo "Laos" ;;
        lb) echo "Lebanon" ;;
        li) echo "Liechtenstein" ;;
        lk) echo "Sri Lanka" ;;
        lt) echo "Lithuania" ;;
        lu) echo "Luxembourg" ;;
        lv) echo "Latvia" ;;
        ly) echo "Libya" ;;
        ma) echo "Morocco" ;;
        mc) echo "Monaco" ;;
        md) echo "Moldova" ;;
        me) echo "Montenegro" ;;
        mk) echo "North Macedonia" ;;
        mm) echo "Myanmar" ;;
        mn) echo "Mongolia" ;;
        mr) echo "Mauritania" ;;
        mt) echo "Malta" ;;
        mx) echo "Mexico" ;;
        my) echo "Malaysia" ;;
        mz) echo "Mozambique" ;;
        ng) echo "Nigeria" ;;
        nl) echo "Netherlands" ;;
        no) echo "Norway" ;;
        np) echo "Nepal" ;;
        nz) echo "New Zealand" ;;
        pa) echo "Panama" ;;
        pe) echo "Peru" ;;
        pg) echo "Papua New Guinea" ;;
        ph) echo "Philippines" ;;
        pk) echo "Pakistan" ;;
        pl) echo "Poland" ;;
        pr) echo "Puerto Rico" ;;
        pt) echo "Portugal" ;;
        py) echo "Paraguay" ;;
        qa) echo "Qatar" ;;
        ro) echo "Romania" ;;
        rs) echo "Serbia" ;;
        rw) echo "Rwanda" ;;
        se) echo "Sweden" ;;
        sg) echo "Singapore" ;;
        si) echo "Slovenia" ;;
        sk) echo "Slovakia" ;;
        sn) echo "Senegal" ;;
        so) echo "Somalia" ;;
        sv) echo "El Salvador" ;;
        td) echo "Chad" ;;
        tg) echo "Togo" ;;
        th) echo "Thailand" ;;
        tn) echo "Tunisia" ;;
        tr) echo "Turkey" ;;
        tt) echo "Trinidad and Tobago" ;;
        tw) echo "Taiwan" ;;
        ua) echo "Ukraine" ;;
        uk) echo "United Kingdom" ;;
        us) echo "United States" ;;
        uy) echo "Uruguay" ;;
        uz) echo "Uzbekistan" ;;
        ve) echo "Venezuela" ;;
        vn) echo "Vietnam" ;;
        za) echo "South Africa" ;;
        *) echo "Unknown" ;;
    esac
}


determine_cgroup_version() {
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
        echo "2"
    else
        echo "1"
    fi
}


CGROUP_VERSION=$(determine_cgroup_version)


echo "Gathering container information..." >&2
CONTAINER_DATA=$(docker ps --filter "name=llustr-proxy-tunnel-" --format "{{.ID}}|{{.Names}}|{{.Status}}|{{.Ports}}")


mapfile -t CONTAINER_ARRAY < <(echo "$CONTAINER_DATA" | sort -t '-' -k4 -n)


for container_info in "${CONTAINER_ARRAY[@]}"; do
    
    IFS='|' read -r CONTAINER_ID CONTAINER STATUS_TEXT PORT_INFO <<< "$container_info"
    
    
    if [[ "$CONTAINER" =~ llustr-proxy-tunnel-([0-9]+) ]]; then
        TUNNEL_ID="${BASH_REMATCH[1]}"
        TUNNEL_NAME="LLUSTR[$TUNNEL_ID]"
    else
        TUNNEL_NAME="$CONTAINER"
    fi
    
    
    PORT="N/A"
    if [[ "$PORT_INFO" =~ 0\.0\.0\.0:([0-9]+)- ]]; then
        PORT="${BASH_REMATCH[1]}"
    fi
    
    
    if [[ "$STATUS_TEXT" == *"Up"* && "$STATUS_TEXT" != *"unhealthy"* ]]; then
        STATUS="$CHECK_MARK"
    else
        STATUS="$X_MARK"
    fi
    
    
    CREATED_TIME=$(docker inspect -f '{{.Created}}' "$CONTAINER_ID" 2>/dev/null)
    
    
    TIME_ALIVE="Unknown"
    if [ -n "$CREATED_TIME" ]; then
        CREATED_TIMESTAMP=$(date -d "$CREATED_TIME" +%s 2>/dev/null)
        if [ -n "$CREATED_TIMESTAMP" ]; then
            CURRENT_TIMESTAMP=$(date +%s)
            UPTIME_SECONDS=$((CURRENT_TIMESTAMP - CREATED_TIMESTAMP))
            
            DAYS=$((UPTIME_SECONDS / 86400))
            REMAINING_SECONDS=$((UPTIME_SECONDS % 86400))
            HOURS=$((REMAINING_SECONDS / 3600))
            MINUTES=$(( (REMAINING_SECONDS % 3600) / 60 ))
            SECONDS_DISPLAY=$((REMAINING_SECONDS % 60))
            
            if [ $DAYS -gt 0 ]; then
                TIME_ALIVE=$(printf "%dd %02d:%02d:%02d" "$DAYS" "$HOURS" "$MINUTES" "$SECONDS_DISPLAY")
            else
                TIME_ALIVE=$(printf "%02d:%02d:%02d" "$HOURS" "$MINUTES" "$SECONDS_DISPLAY")
            fi
        fi
    fi
    
    
    
    VPN_SERVER="Unknown" 
    SERVER_CACHE_PATH="/tmp/vpn_server_${CONTAINER_ID}"
    
    if [ -f "$SERVER_CACHE_PATH" ]; then
        VPN_SERVER=$(cat "$SERVER_CACHE_PATH")
    else
        VPN_SERVER_INFO=$(docker logs "$CONTAINER_ID" 2>/dev/null | grep "Connected to VPN server" | head -1)
        if [ -n "$VPN_SERVER_INFO" ]; then
            VPN_SERVER=$(echo "$VPN_SERVER_INFO" | sed -e 's/.*Connected to VPN server: //' -e 's/nordvpn //g' -e 's/[()]//g' -e 's/\[//g' -e 's/\]//g' | awk '{print $1}')
            echo "$VPN_SERVER" > "$SERVER_CACHE_PATH"
        fi
    fi
    
    
    ENTRYPOINT_LOCATION="Unknown" 
    if [[ -n "$TUNNEL_ID" ]]; then
        CONFIG_NUM_PADDED=$(printf "%03d" "$TUNNEL_ID")
        CONFIG_FILE_PATH=$(find "${SCRIPT_DIR}/vpn-configs/" -maxdepth 1 -type f -name "${CONFIG_NUM_PADDED}-*.tcp.ovpn" -print -quit 2>/dev/null)
        
        if [[ -n "$CONFIG_FILE_PATH" ]]; then
            CONFIG_FILENAME=$(basename "$CONFIG_FILE_PATH")
            if [[ "$CONFIG_FILENAME" =~ ^[0-9]{3}-([a-z]{2})[0-9a-zA-Z]*\.nordvpn\.com ]]; then
                COUNTRY_CODE="${BASH_REMATCH[1]}"
                ENTRYPOINT_LOCATION=$(get_country_name "$COUNTRY_CODE")
            fi
        fi
    fi

    
    EXITPOINT_IP="Unknown"
    EXITPOINT_COUNTRY="Unknown"
    if [[ "$PORT" != "N/A" && "$STATUS" == "$CHECK_MARK" ]]; then
        
        EXITPOINT_INFO=$(timeout 10 curl -s --socks5 127.0.0.1:$PORT https://ipinfo.io/json 2>/dev/null || echo "")
        if [[ -n "$EXITPOINT_INFO" ]]; then
            
            EXITPOINT_IP=$(echo "$EXITPOINT_INFO" | grep -o '"ip"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "Unknown")
            EXITPOINT_COUNTRY=$(echo "$EXITPOINT_INFO" | grep -o '"country"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"country"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "Unknown")
        fi
    fi
    
    
    
    CONTAINER_PID=$(docker inspect --format='{{.State.Pid}}' "$CONTAINER_ID" 2>/dev/null)
    MEMORY_MB="0.00"
    
    if [[ -n "$CONTAINER_PID" && "$CONTAINER_PID" != "0" ]]; then
        
        if [ -f "/proc/$CONTAINER_PID/cgroup" ]; then
            
            if [ "$CGROUP_VERSION" = "1" ]; then
                
                MEMORY_CGROUP_PATH=$(grep memory /proc/$CONTAINER_PID/cgroup | cut -d: -f3)
                if [ -n "$MEMORY_CGROUP_PATH" ]; then
                    MEMORY_USAGE_FILE="/sys/fs/cgroup/memory$MEMORY_CGROUP_PATH/memory.usage_in_bytes"
                    if [ -f "$MEMORY_USAGE_FILE" ]; then
                        MEMORY_BYTES=$(cat "$MEMORY_USAGE_FILE" 2>/dev/null)
                        if [[ -n "$MEMORY_BYTES" && "$MEMORY_BYTES" =~ ^[0-9]+$ ]]; then
                            MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=2; $MEMORY_BYTES / 1024 / 1024" | bc))
                        fi
                    fi
                fi
            else
                
                CGROUP_PATH=$(grep '' /proc/$CONTAINER_PID/cgroup | cut -d: -f3)
                if [ -n "$CGROUP_PATH" ]; then
                    MEMORY_USAGE_FILE="/sys/fs/cgroup$CGROUP_PATH/memory.current"
                    if [ -f "$MEMORY_USAGE_FILE" ]; then
                        MEMORY_BYTES=$(cat "$MEMORY_USAGE_FILE" 2>/dev/null)
                        if [[ -n "$MEMORY_BYTES" && "$MEMORY_BYTES" =~ ^[0-9]+$ ]]; then
                            MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=2; $MEMORY_BYTES / 1024 / 1024" | bc))
                        fi
                    fi
                fi
            fi
        fi
    fi
    
    
    if [[ "$MEMORY_MB" = "0.00" ]]; then
        MEMORY_STATS=$(docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_ID" 2>/dev/null | head -1)
        if [[ -n "$MEMORY_STATS" ]]; then
            
            MEMORY_USAGE_PART=$(echo "$MEMORY_STATS" | cut -d'/' -f1 | tr -d ' ')
            
            
            MEMORY_VALUE=$(echo "$MEMORY_USAGE_PART" | sed -E 's/([0-9.]+).*/\1/')
            MEMORY_UNIT=$(echo "$MEMORY_USAGE_PART" | sed -E 's/[0-9.]+//')
            
            
            case "$MEMORY_UNIT" in
                "KiB")
                    MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=4; $MEMORY_VALUE / 1024" | bc))
                    ;;
                "MiB")
                    MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" "$MEMORY_VALUE")
                    ;;
                "GiB")
                    MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=2; $MEMORY_VALUE * 1024" | bc))
                    ;;
                *)
                    
                    ;;
            esac
        fi
    fi
    
    
    TOTAL_MEMORY_MB=$(LC_NUMERIC=C printf "%.2f" $(echo "scale=2; $TOTAL_MEMORY_MB + $MEMORY_MB" | bc))
    MEMORY_DISPLAY="${MEMORY_MB}MB"
    
    
    echo -e "$TUNNEL_NAME\t$PORT\t$STATUS\t$TIME_ALIVE\t$VPN_SERVER\t$ENTRYPOINT_LOCATION\t$EXITPOINT_IP\t$EXITPOINT_COUNTRY\t$MEMORY_DISPLAY" >> "$TABLE_DATA"
done


column -t -s $'\t' "$TABLE_DATA"


echo -e "\nTotal memory: ${TOTAL_MEMORY_MB} MB"
echo "-------------------------------------"
