#!/usr/bin/env bash
# Apply MT7927 + Logitech USB runtime PM stability policy immediately.

set -euo pipefail

RULE_FILE="/usr/lib/udev/rules.d/99-mt7927-logitech-stability.rules"

log() {
	echo "==> $*"
}

warn() {
	echo "WARN: $*" >&2
}

set_control_on() {
	local devdir="$1"
	local control_file="${devdir}/power/control"
	if [ -w "${control_file}" ]; then
		echo on > "${control_file}" || true
	fi
}

match_and_apply() {
	local devdir="$1"
	local vendor_file="${devdir}/idVendor"
	local product_file="${devdir}/idProduct"
	[ -r "${vendor_file}" ] || return 0
	[ -r "${product_file}" ] || return 0

	local vendor product
	vendor="$(tr '[:upper:]' '[:lower:]' < "${vendor_file}")"
	product="$(tr '[:upper:]' '[:lower:]' < "${product_file}")"

	case "${vendor}:${product}" in
	0489:e13a|0489:e0fa|0489:e10f|0489:e110|0489:e116|13d3:3588|0e8d:6639|046d:c547|046d:c548)
		set_control_on "${devdir}"
		;;
	esac
}

main() {
	if [ "${EUID}" -ne 0 ]; then
		warn "Run as root"
		exit 1
	fi

	if ! command -v udevadm >/dev/null 2>&1; then
		warn "udevadm not found; cannot apply runtime policy"
		exit 0
	fi

	if [ ! -f "${RULE_FILE}" ]; then
		warn "Rule file not found at ${RULE_FILE}"
	fi

	log "Reloading udev rules"
	udevadm control --reload-rules || true

	log "Triggering usb udev events"
	udevadm trigger --subsystem-match=usb --action=change || true

	log "Applying power/control=on for matched devices"
	for devdir in /sys/bus/usb/devices/*; do
		[ -d "${devdir}" ] || continue
		match_and_apply "${devdir}"
	done
}

main "$@"
