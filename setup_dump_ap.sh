#!/bin/ash

# Configurable Variables
HOSTNAME="WifiAP"
LAN_IP="192.168.100.201"
LAN_NETMASK="255.255.255.0"
GATEWAY="192.168.100.1"
DNS="192.168.100.1"
SSID="OpenWrt"
WIFI_PASSWORD="password"
ENABLE_VLAN=false  # Set to true if VLAN is needed
VLAN_ID="10"        # VLAN ID if ENABLE_VLAN is true

# Helper Function: Check and set UCI values
set_uci() {
    local option="$1"
    local value="$2"

    current_value=$(uci get "$option" 2>/dev/null)
    if [ "$current_value" != "$value" ]; then
        echo "$option = $current_value -> $value"
        uci set "$option"="$value"
    fi
}

del_uci() {
    local option="$1"

    if uci get "$option" >/dev/null 2>&1; then
        echo "Delete $option"
        uci delete "$option"
    fi
}

# Disable unnecessary services
for service in firewall dnsmasq odhcpd; do
    if /etc/init.d/"$service" enabled; then
        /etc/init.d/"$service" disable
        /etc/init.d/"$service" stop
    fi
done

# Set hostname
set_uci system.@system[0].hostname "$HOSTNAME"

# Set timezone
del_uci system.ntp.enabled
del_uci system.ntp.enable_server
set_uci system.@system[0].zonename='Asia/Jakarta'
set_uci system.@system[0].timezone='WIB-7'
set_uci system.@system[0].log_proto='udp'
set_uci system.@system[0].conloglevel='8'
set_uci system.@system[0].cronloglevel='5'

# Configure LAN as a bridge with a static IP
set_uci network.lan.proto 'static'
set_uci network.lan.ipaddr "$LAN_IP"
set_uci network.lan.netmask "$LAN_NETMASK"
set_uci network.lan.gateway "$GATEWAY"
set_uci network.lan.dns "$DNS"
set_uci network.lan.device 'br-lan'

# Optionally configure VLAN
if [ "$ENABLE_VLAN" = true ]; then
    set_uci network.vlan.device 'br-lan'
    set_uci network.vlan.id "$VLAN_ID"
    set_uci network.vlan.ports 'lan1 lan2 lan3'
fi

# Remove WAN interfaces if they exist
if uci get network.wan >/dev/null 2>&1; then
    uci delete network.wan
fi

if uci get network.wan6 >/dev/null 2>&1; then
    uci delete network.wan6
fi

# Configure wireless for 2G and 5G
set_uci wireless.default_radio0.ssid "$SSID"
set_uci wireless.default_radio0.encryption 'psk2'
set_uci wireless.default_radio0.key "$WIFI_PASSWORD"
set_uci wireless.default_radio0.network 'lan'

set_uci wireless.default_radio1.ssid "$SSID"
set_uci wireless.default_radio1.encryption 'psk2'
set_uci wireless.default_radio1.key "$WIFI_PASSWORD"
set_uci wireless.default_radio1.network 'lan'

# Enable hardware flow offloading
set_uci firewall.@defaults[0].flow_offloading '1'
set_uci firewall.@defaults[0].flow_offloading_hw '1'

# Persistently disable services in rc.local
cat <<EOF > /etc/rc.local
# Disable unnecessary services
for service in firewall dnsmasq odhcpd; do
    if /etc/init.d/"\$service" enabled; then
        /etc/init.d/"\$service" disable
        /etc/init.d/"\$service" stop
    fi
done
EOF

# Apply changes and restart services
uci commit network
uci commit wireless
uci commit firewall
wifi reload
/etc/init.d/network restart

# Completion message
echo "Configuration complete. Connect the WAN cable to a LAN port."
