#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_HTML="$SCRIPT_DIR/index.html"

IP="192.168.1.76"
ENDPOINT="http://$IP/index?state=1"
HTML_FILE_URL="http://$IP/api/lfs/index.html"

pkill cloudflared
cloudflared tunnel run mytunnel &

while true; do
    DATA=$(curl -s "$ENDPOINT")

   UPDATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
   WIFI_RSSI=$(echo "$DATA" | grep -oP 'Wifi RSSI: \K[^<]+')
   CHIP_TEMP=$(echo "$DATA" | grep -oP 'Chip temperature: \K[^<]+')
   POWER_STATE=$(echo "$DATA" | grep -q "<td class='off'>OFF</td>" && echo "OFF" || echo "ON")
    echo $UPDATE_TIME
    echo $WIFI_RSSI
    echo $CHIP_TEMP
    echo $POWER_STATE

    curl -s "$HTML_FILE_URL" -o "$LOCAL_HTML"

    # Escape & in variables for sed replacement
    esc_UPDATE_TIME=$(printf ' %s\n' "$UPDATE_TIME" | sed 's/&/\\&/g')
    esc_WIFI_RSSI=$(printf ' %s\n' "$WIFI_RSSI" | sed 's/&/\\&/g')
    esc_CHIP_TEMP=$(printf ' %s\n' "$CHIP_TEMP" | sed 's/&/\\&/g')

    # Update spans inside the HTML
    sed -i "s|\(<span id=\"updateTime\">\)[^<]*\(</span>\)|\1$esc_UPDATE_TIME\2|" "$LOCAL_HTML"
    sed -i "s|\(<span id=\"wifiRSSI\">\)[^<]*\(</span>\)|\1$esc_WIFI_RSSI\2|" "$LOCAL_HTML"
    sed -i "s|\(<span id=\"chipTemp\">\)[^<]*\(</span>\)|\1$esc_CHIP_TEMP\2|" "$LOCAL_HTML"

    # Power state color
    if [ "$POWER_STATE" == "ON" ]; then
        COLOR="rgb(2, 184, 2)"
    else
        COLOR="rgb(184, 2, 2)"
    fi
    esc_COLOR=$(printf '%s\n' "$COLOR" | sed 's/&/\\&/g')

    sed -i "s|<span id=\"powerState\".*>.*</span>|<span id=\"powerState\" style=\"background-color:$esc_COLOR;color:#fff;padding:2px 4px\"><b>$POWER_STATE</b></span>|" "$LOCAL_HTML"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - HTML updated at $LOCAL_HTML"

    curl -X POST "$HTML_FILE_URL" \
     -H "Content-Type: text/plain;charset=UTF-8" \
     --data-binary @"$LOCAL_HTML"

    # update every 30 minutes to be nice to the plug
    sleep 1800
done