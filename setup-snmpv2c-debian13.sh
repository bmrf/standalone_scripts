#!/usr/bin/env bash
#
# setup-snmpv2c-debian13.sh - SNMPv2c read-only configuration for Debian 13 (Trixie)
# Target: Debian 13 hosts
# Author: vocatus on reddit.com/r/sysadmin ( vocatus.gate@gmail.com ) // PGP key ID: 0x82A211A2
#
# - sysName   : reported dynamically as the live system hostname (net-snmp default)
# - sysLocation: change-me
# - sysContact : change-me
# - RO community: change-me, restricted to the authorized poller
# - Listens on all interfaces, UDP/161
# - Opens firewall for the poller only if ufw/firewalld is active
#
set -euo pipefail

### ---- Parameters (edit here if anything changes) --------------------------
RO_COMMUNITY="change-me"
POLLER_IP="10.1.0.162"
SYS_LOCATION="change-me"
SYS_CONTACT="change-me"
SNMP_PORT="161"
CONF="/etc/snmp/snmpd.conf"
### --------------------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: run as root (sudo $0)" >&2
    exit 1
fi

echo "==> Installing snmpd if needed..."
if ! dpkg -s snmpd >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y snmpd
fi

echo "==> Backing up existing config..."
if [[ -f "${CONF}" ]]; then
    cp -a "${CONF}" "${CONF}.bak.$(date +%Y%m%d-%H%M%S)"
fi

echo "==> Writing ${CONF}..."
cat > "${CONF}" <<EOF
# Managed by setup-snmpd.sh  ($(date +%Y-%m-%d))
# SNMPv2c, read-only.

# Listen on all interfaces (IPv4). Add ',udp6:[::]:${SNMP_PORT}' for IPv6.
agentaddress udp:${SNMP_PORT}

# System information.
# sysName is intentionally left unset so snmpd reports the live hostname.
sysLocation  ${SYS_LOCATION}
sysContact   ${SYS_CONTACT}

# Read-only community, accepted only from the authorized poller and localhost.
rocommunity  ${RO_COMMUNITY}  ${POLLER_IP}
rocommunity ${RO_COMMUNITY} 127.0.0.1
EOF
chmod 600 "${CONF}"

# Debian ships /etc/default/snmpd; make sure it doesn't force loopback-only.
if [[ -f /etc/default/snmpd ]]; then
    sed -i -E "s/^(SNMPDOPTS=.*)127\.0\.0\.1(.*)$/# \0/" /etc/default/snmpd || true
fi

echo "==> Configuring firewall (only if one is active)..."
fw_done=false

# ufw
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi "Status: active"; then
    ufw allow from "${POLLER_IP}" to any port "${SNMP_PORT}" proto udp
    echo "    ufw: allowed ${POLLER_IP} -> udp/${SNMP_PORT}"
    fw_done=true
fi

# firewalld
if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -qi "running"; then
    firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=${POLLER_IP} port port=${SNMP_PORT} protocol=udp accept"
    firewall-cmd --reload
    echo "    firewalld: allowed ${POLLER_IP} -> udp/${SNMP_PORT}"
    fw_done=true
fi

if ! $fw_done; then
    echo "    No active ufw/firewalld detected - no firewall rule added."
    echo "    (If you use nftables/iptables directly, open udp/${SNMP_PORT} from ${POLLER_IP} manually.)"
fi

echo "==> Enabling and (re)starting snmpd..."
systemctl enable snmpd >/dev/null 2>&1 || true
systemctl restart snmpd

echo "==> Verifying..."
sleep 1
systemctl --no-pager --full status snmpd | head -n 5 || true
echo
echo "Listening sockets on udp/${SNMP_PORT}:"
ss -lnup | grep ":${SNMP_PORT} " || echo "    (nothing found - check 'journalctl -u snmpd')"

echo
echo "Done. Test from the poller (${POLLER_IP}):"
echo "  snmpget -v2c -c ${RO_COMMUNITY} <this-host> 1.3.6.1.2.1.1.5.0   # sysName"
echo "  snmpget -v2c -c ${RO_COMMUNITY} <this-host> 1.3.6.1.2.1.1.6.0   # sysLocation"
