#!/usr/bin/env bash
# Boot-time Logitech Bluetooth autoconnect helper for MT7927/MT6639.

set -euo pipefail

log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

list_target_devices() {
	bluetoothctl devices Trusted | while read -r _ mac name; do
		[ -n "${mac:-}" ] || continue
		info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
		echo "$info" | grep -q "Trusted: yes" || continue
		echo "$info" | grep -qi "Icon: input-" || continue
		echo "$info" | grep -qi "Name: Logitech" || continue
		printf "%s\n" "$mac"
	done
}

power_on_adapter() {
	bluetoothctl --timeout 5 power on >/dev/null 2>&1 || true
}

connect_target_devices() {
	local attempts=12
	local delay=2

	for _ in $(seq 1 "$attempts"); do
		for mac in $(list_target_devices); do
			bluetoothctl --timeout 8 connect "$mac" >/dev/null 2>&1 || true
		done

		# Exit early if all target devices are connected.
		local all_connected=true
		local any_target=false
		for mac in $(list_target_devices); do
			any_target=true
			info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
			echo "$info" | grep -q "Connected: yes" || all_connected=false
		done

		$any_target && $all_connected && return 0
		sleep "$delay"
	done

	return 0
}

main() {
	command -v bluetoothctl >/dev/null 2>&1 || exit 0

	log "Powering on Bluetooth adapter"
	power_on_adapter

	log "Attempting Logitech BT input autoconnect"
	connect_target_devices
}

main "$@"
