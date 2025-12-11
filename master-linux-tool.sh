configure_static_ip() {
    echo -e "${BLUE}=== Configure Static IP (Wizard) ===${NC}"
    echo "Detected network manager: $NETWORK_MANAGER"

    # Detect available interfaces (exclude lo, docker*, veth*, etc.)
    mapfile -t INTERFACES < <(ip -br link show | grep -v '^lo\|^docker\|^veth\|^br-\|^virbr' | awk '{print $1}' | grep -v '^$')
    if [[ ${#INTERFACES[@]} -eq 0 ]]; then
        echo -e "${RED}✗ No valid network interfaces found.${NC}"
        read_tty "Press Enter to continue..." _
        return 1
    fi

    echo -e "\n${CYAN}Available interfaces:${NC}"
    for i in "${!INTERFACES[@]}"; do
        local iface="${INTERFACES[$i]}"
        local addr=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2; exit}' | cut -d'/' -f1)
        [[ -z "$addr" ]] && addr="(no IPv4)"
        echo -e "  ${YELLOW}$((i+1))${NC}) $iface → $addr"
    done
    echo

    # Interface selection
    local choice
    while true; do
        read_tty "Select interface [1-${#INTERFACES[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#INTERFACES[@]} )); then
            break
        else
            echo -e "${RED}Invalid choice. Try again.${NC}"
        fi
    done
    local IFACE="${INTERFACES[$((choice-1))]}"
    log "Selected interface: $IFACE"

    # IP/CIDR input (with validation)
    local IP_CIDR
    while true; do
        read_tty "Enter static IP/CIDR (e.g., 192.168.1.10/24): " IP_CIDR
        if [[ "$IP_CIDR" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            local ip_part="${IP_CIDR%/*}"
            local cidr_part="${IP_CIDR#*/}"
            if (( cidr_part >= 1 && cidr_part <= 32 )); then
                # Basic octet validation
                IFS='.' read -r a b c d <<< "$ip_part"
                if (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )); then
                    break
                fi
            fi
        fi
        echo -e "${RED}Invalid IP/CIDR format. Example: 192.168.1.10/24${NC}"
    done

    # Gateway
    local GATEWAY
    while true; do
        read_tty "Enter gateway (e.g., 192.168.1.1): " GATEWAY
        if [[ "$GATEWAY" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            IFS='.' read -r a b c d <<< "$GATEWAY"
            if (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )); then
                break
            fi
        fi
        echo -e "${RED}Invalid gateway IP.${NC}"
    done

    # DNS
    local DNS
    read_tty "Enter DNS servers (space-separated, e.g., 8.8.8.8 1.1.1.1) [default: 8.8.8.8]: " DNS
    DNS=${DNS:-8.8.8.8}

    # Confirm
    echo -e "\n${CYAN}Summary:${NC}"
    echo -e "  Interface: $IFACE"
    echo -e "  IP/CIDR:   $IP_CIDR"
    echo -e "  Gateway:   $GATEWAY"
    echo -e "  DNS:       $DNS"
    echo
    read_tty "Apply this configuration? (y/N): " confirm
    [[ "${confirm,,}" != "y" ]] && { echo -e "${YELLOW}Cancelled.${NC}"; read_tty "Press Enter to continue..." _; return 0; }

    # --- Apply Based on Network Manager ---
    if [[ "$NETWORK_MANAGER" == "NetworkManager" ]]; then
        # Existing NM logic (kept for compatibility)
        local conn_name
        conn_name=$(nmcli -t -f NAME,DEVICE con show | grep ":$IFACE\$" | head -1 | cut -d: -f1)
        if [[ -z "$conn_name" ]]; then
            echo -e "${YELLOW}⚠ No NM connection found for $IFACE — creating 'static-$IFACE'...${NC}"
            nmcli con add type ethernet con-name "static-$IFACE" ifname "$IFACE" ipv4.method manual \
                ipv4.addresses "$IP_CIDR" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS" 2>/dev/null
            conn_name="static-$IFACE"
        else
            nmcli con mod "$conn_name" ipv4.method manual \
                ipv4.addresses "$IP_CIDR" ipv4.gateway "$GATEWAY" ipv4.dns "$DNS" 2>/dev/null
        fi
        nmcli con up "$conn_name" 2>/dev/null
        echo -e "${GREEN}✓ Static IP configured via NetworkManager.${NC}"

    elif [[ "$NETWORK_MANAGER" == "systemd-networkd" ]]; then
        # ✅ Enhanced systemd-networkd support
        local CONF_DIR="/etc/systemd/network"
        local CONF_FILE="$CONF_DIR/10-$IFACE-static.network"

        echo -e "${CYAN}⚙ Applying systemd-networkd config to: $CONF_FILE${NC}"
        mkdir -p "$CONF_DIR"

        # Backup existing
        [[ -f "$CONF_FILE" ]] && cp "$CONF_FILE" "$CONF_FILE.bak-$(date +%s)" && log "Backed up $CONF_FILE"

        # Write minimal robust .network file
        cat > "$CONF_FILE" <<EOF
[Match]
Name=$IFACE

[Network]
Address=$IP_CIDR
Gateway=$GATEWAY
$(printf 'DNS=%s\n' $DNS)
EOF

        log "Wrote config to $CONF_FILE"

        # Reload & apply without full restart
        if systemctl is-active --quiet systemd-networkd; then
            echo -e "Reloading systemd-networkd..."
            networkctl reload 2>/dev/null || systemctl reload systemd-networkd
            echo -e "Reconfiguring interface $IFACE..."
            networkctl reconfigure "$IFACE" 2>/dev/null || {
                echo -e "${YELLOW}⚠ 'networkctl reconfigure' failed — trying 'systemctl restart systemd-networkd'...${NC}"
                systemctl restart systemd-networkd
            }
        else
            echo -e "${YELLOW}⚠ systemd-networkd not active — enabling and starting...${NC}"
            systemctl enable --now systemd-networkd
        fi

        # Verify
        sleep 1
        local new_ip=$(ip -4 addr show "$IFACE" 2>/dev/null | awk '/inet / {print $2; exit}')
        if [[ "$new_ip" == "${IP_CIDR%/*}/"* ]]; then
            echo -e "${GREEN}✓ Static IP applied successfully via systemd-networkd.${NC}"
            echo -e "  Current IP: $new_ip"
        else
            echo -e "${RED}✗ IP not applied. Check config and journal: journalctl -u systemd-networkd -b${NC}"
        fi

    else
        echo -e "${RED}✗ Unsupported network manager: $NETWORK_MANAGER${NC}"
        echo -e "${YELLOW}Manual configuration required.${NC}"
    fi

    read_tty "Press Enter to continue..." _
}
