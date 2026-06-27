#!/bin/bash
#
# turbo-boost.sh - Manage Intel Turbo Boost on macOS
#
# Usage:
#   sudo ./turbo-boost.sh status    Show current Turbo Boost state
#   sudo ./turbo-boost.sh disable   Disable Turbo Boost (load kext)
#   sudo ./turbo-boost.sh enable    Re-enable Turbo Boost (unload kext)
#   sudo ./turbo-boost.sh info      Show CPU frequency info
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEXT_NAME="DisableTurboBoost"
KEXT_BUNDLE="${SCRIPT_DIR}/${KEXT_NAME}.kext"
KEXT_ID="com.local.DisableTurboBoost"
INSTALL_DIR="/Library/Extensions"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root (use sudo)${RESET}"
        exit 1
    fi
}

check_intel() {
    if ! sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -qi intel; then
        echo -e "${RED}Error: This utility only works on Intel CPUs${RESET}"
        exit 1
    fi
}

is_kext_loaded() {
    kextstat 2>/dev/null | grep -q "${KEXT_ID}" 2>/dev/null
}

check_kext_built() {
    if [[ ! -d "${KEXT_BUNDLE}" ]] && [[ ! -d "${INSTALL_DIR}/${KEXT_NAME}.kext" ]]; then
        echo -e "${RED}Error: Kext not found. Run 'make' first to build it.${RESET}"
        exit 1
    fi
}

cmd_status() {
    echo -e "${BOLD}Turbo Boost Status${RESET}"
    echo "-------------------"

    local cpu_brand
    cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    echo "CPU: ${cpu_brand}"

    if is_kext_loaded; then
        echo -e "Turbo Boost: ${RED}DISABLED${RESET} (kext loaded)"
    else
        echo -e "Turbo Boost: ${GREEN}ENABLED${RESET} (kext not loaded)"
    fi

    # Show thermal info if available
    local thermal
    thermal=$(sysctl -n machdep.xcpm.cpu_thermal_level 2>/dev/null || echo "N/A")
    echo "Thermal level: ${thermal}"

    # Show current CPU speed if powermetrics is available
    if command -v powermetrics &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Tip: Run 'sudo powermetrics -s cpu_power -n 1' for detailed frequency info${RESET}"
    fi
}

cmd_disable() {
    check_kext_built

    if is_kext_loaded; then
        echo "Turbo Boost is already disabled."
        return 0
    fi

    echo "Disabling Turbo Boost..."

    # Prefer installed kext, fall back to local build
    if [[ -d "${INSTALL_DIR}/${KEXT_NAME}.kext" ]]; then
        kextload "${INSTALL_DIR}/${KEXT_NAME}.kext"
    else
        chown -R root:wheel "${KEXT_BUNDLE}"
        chmod -R 755 "${KEXT_BUNDLE}"
        kextload "${KEXT_BUNDLE}"
    fi

    if is_kext_loaded; then
        echo -e "${GREEN}Turbo Boost disabled successfully.${RESET}"
    else
        echo -e "${RED}Failed to load kext. Check SIP settings (see README).${RESET}"
        exit 1
    fi
}

cmd_enable() {
    if ! is_kext_loaded; then
        echo "Turbo Boost is already enabled."
        return 0
    fi

    echo "Re-enabling Turbo Boost..."

    kextunload -b "${KEXT_ID}" 2>/dev/null || true

    if is_kext_loaded; then
        echo -e "${RED}Failed to unload kext.${RESET}"
        exit 1
    else
        echo -e "${GREEN}Turbo Boost re-enabled successfully.${RESET}"
    fi
}

cmd_info() {
    echo -e "${BOLD}CPU Information${RESET}"
    echo "---------------"

    sysctl -n machdep.cpu.brand_string 2>/dev/null || true

    echo ""
    echo "Core count: $(sysctl -n hw.physicalcpu 2>/dev/null || echo N/A)"
    echo "Thread count: $(sysctl -n hw.logicalcpu 2>/dev/null || echo N/A)"

    local freq
    freq=$(sysctl -n hw.cpufrequency 2>/dev/null || echo "")
    if [[ -n "$freq" ]]; then
        echo "Base frequency: $(echo "scale=2; ${freq} / 1000000000" | bc) GHz"
    fi

    local max_freq
    max_freq=$(sysctl -n hw.cpufrequency_max 2>/dev/null || echo "")
    if [[ -n "$max_freq" ]]; then
        echo "Max frequency: $(echo "scale=2; ${max_freq} / 1000000000" | bc) GHz"
    fi

    echo ""
    if is_kext_loaded; then
        echo -e "Turbo Boost: ${RED}DISABLED${RESET}"
    else
        echo -e "Turbo Boost: ${GREEN}ENABLED${RESET}"
    fi
}

usage() {
    echo "Usage: sudo $0 {status|disable|enable|info}"
    echo ""
    echo "Commands:"
    echo "  status   Show current Turbo Boost state"
    echo "  disable  Disable Turbo Boost (load kext)"
    echo "  enable   Re-enable Turbo Boost (unload kext)"
    echo "  info     Show CPU frequency information"
}

# Main
check_intel

case "${1:-}" in
    status)
        check_root
        cmd_status
        ;;
    disable)
        check_root
        cmd_disable
        ;;
    enable)
        check_root
        cmd_enable
        ;;
    info)
        check_root
        cmd_info
        ;;
    *)
        usage
        exit 1
        ;;
esac
