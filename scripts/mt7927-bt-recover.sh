#!/usr/bin/env bash
# Recover Bluetooth controller state after resume/reconnect failures.

set -euo pipefail

log() {
	echo "==> $*"
}

has_mt6639_usb() {
	for devdir in /sys/bus/usb/devices/*; do
		[ -r "${devdir}/idVendor" ] || continue
		[ -r "${devdir}/idProduct" ] || continue
		vendor="$(tr '[:upper:]' '[:lower:]' < "${devdir}/idVendor")"
		product="$(tr '[:upper:]' '[:lower:]' < "${devdir}/idProduct")"
		case "${vendor}:${product}" in
		0489:e13a|0489:e0fa|0489:e10f|0489:e110|0489:e116|13d3:3588|0e8d:6639)
			return 0
			;;
		esac
	done
	return 1
}

reload_bt_stack() {
	log "Reloading btusb/btmtk"
	modprobe -r btusb btmtk 2>/dev/null || true
	sleep 1
	modprobe btusb 2>/dev/null || true
}

restart_bluetoothd() {
	if command -v systemctl >/dev/null 2>&1; then
		log "Restarting bluetooth.service"
		systemctl restart bluetooth || true
	fi
}

main() {
	if [ "${EUID}" -ne 0 ]; then
		echo "Run as root" >&2
		exit 1
	fi

	if ! has_mt6639_usb; then
		log "No MT6639 USB device detected, skipping recovery"
		exit 0
	fi

	if command -v rfkill >/dev/null 2>&1; then
		rfkill unblock bluetooth || true
	fi

	reload_bt_stack
	restart_bluetoothd
}

main "$@"
