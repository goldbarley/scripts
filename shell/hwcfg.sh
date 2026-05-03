#!/bin/sh

if [ $(id -u) -ne 0 ]; then
	printf "Run as root.\nUsage: sudo $0\n"
	exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
CURFILE=$(basename "$0")

CONF_FILE='/etc/hwcfg.conf'
[ -f "$CONF_FILE" ]
CONF_FILE_EXISTS="$?"
if [ $CONF_FILE_EXISTS -ne 0 ]; then
	printf "%s: warning: Could not locate configuration file.\n" "$CURFILE"
else
	. "$CONF_FILE"
fi

install()
{
	echo "Checking bianries..."

	for BIN in cmake dkms git make nvidia-smi pkg-config; do
		if ! command -v "$BIN" > /dev/null 2>&1; then
			printf "%s: error: %s is not installed. Install it before proceeding.\n" "$CURFILE" "$BIN"
			exit 1
		fi
		printf "%s: info: Found `%s`.\n" "$CURFILE" "$BIN"
	done

	if ! pkg-config --exists libpci; then
		printf "%s: error: Missing dependency 'libpci'. Install it before proceeding.\n" "$CURFILE"
		exit 1
	fi

	clone_and_build()
	{
		_src=$1
		_hash=$2
		_dir=$3
		_cmd=$4

		if [ -d "$_dir" ]; then
			printf "%s: warning: '%s' exists Removing it before proceeding...\n" "$CURFILE" "$_dir"
			if ! rm -rf "$_dir" > /dev/null 2>&1; then
				printf "%s: error: Failed to remove directory: '%s'.\n" "$CURFILE" "$_dir"
				return
			fi
		fi

		git clone "$_src" "$_dir" || return 1
		(
			set -e
			cd "$_dir"
			git checkout -b "__Const_branch_at_${_hash}" "$_hash"
			eval "$_cmd"
		)
	}

	if ! clone_and_build "https://github.com/amkillam/ryzen_smu.git" \
		"d3bfbe97623a2a26c46c5b88b2053cfa2b08e91a" "ryzen_smu" \
		"make dkms-install"; then
		printf "%s: error: Failed to install 'ryzen_smu'.\n" "$CURFILE"

		return 1
	fi

	if ! clone_and_build "https://github.com/FlyGoat/RyzenAdj.git" \
		"527cacc5a8d53f54c259b75b3aba7e47d6bc464d" "RyzenAdj" \
		"rm -rf win32 && mkdir -p build && cd build && cmake -DCMAKE_BUILD_TYPE=Release .. && make -j$(nproc)"; then
		printf "%s: error: Failed to install 'RyzenAdj'.\n" "$CURFILE"

		return 1
	fi

	# For Acer laptops only
	if ! clone_and_build "https://github.com/frederik-h/acer-wmi-battery.git" \
		"9f90d75cc9237aeed7964622d10dbdf4d2c7b518" "acer-wmi-battery" \
		"make"; then
		printf "%s: error: Failed to install 'acer-wmi-battery'.\n" "$CURFILE"

		return 1
	fi

	_status=0

	if ! cp -r 'acer-wmi-battery' '/usr/src/acer-wmi-battery-0.2.0' > /dev/null 2>&1; then
		printf "%s: error: Failed to copy kernel module: 'acer-wmi-battery'.\n" "$CURFILE"
		return 1
	fi

	printf "%s\n%s\n%s\n%s\n%s\n" \
	'PACKAGE_NAME="acer-wmi-battery"' \
	'PACKAGE_VERSION="0.2.0"' \
	'BUILT_MODULE_NAME[0]="acer-wmi-battery"' \
	'DEST_MODULE_LOCATION[0]="/updates"' \
	'AUTOINSTALL="yes"' > /usr/src/acer-wmi-battery-0.2.0/dkms.conf

	if ! dkms add -m acer-wmi-battery -v 0.2.0 > /dev/null 2>&1; then
		printf "%s: error: Failed to add kernel module: 'acer-wmi-battery'.\n" "$CURFILE"
		return 1
	fi

	if ! dkms build -m acer-wmi-battery -v 0.2.0 > /dev/null 2>&1; then
		printf "%s: error: Failed to build kernel module: 'acer-wmi-battery'.\n" "$CURFILE"
		return 1
	fi

	if ! dkms install -m acer-wmi-battery -v 0.2.0 > /dev/null 2>&1; then
		printf "%s: error: Failed to install kernel module: 'acer-wmi-battery'.\n" "$CURFILE"
		return 1
	fi

	if ! ln -sf "${SCRIPT_DIR}/RyzenAdj/build/ryzenadj" '/usr/local/bin/ryzenadj' > /dev/null 2>&1; then
		printf "%s: error: Failed to create symbolic link for 'ryzenadj'.\n" "$CURFILE"
		_status=1
	fi

	if ! chmod +x "${SCRIPT_DIR}/hwcfg.sh" > /dev/null 2>&1; then
		printf "%s: error: Failed to make 'hwcfg.sh' an executable.\n" "$CURFILE"
		_status=1
	fi

	if ! ln -sf "${SCRIPT_DIR}/hwcfg.sh" '/usr/local/bin/hwcfg' > /dev/null 2>&1; then
		printf "%s: error: Failed to create symbolic link for 'hwcfg'.\n" "$CURFILE"
		_status=1
	fi

	printf "%s: info: 'hwcfg' setup complete.\n" "$CURFILE"
	printf "Usage: sudo hwcfg\n"
	printf "You can create a configuration file at '/etc/hwcfg.conf'.\n"

	return "$_status"
}

load_kernel_module()
{
	if [ $# -eq 0 ]; then
		printf "%s: error: No module provided." "$CURFILE"
		return 1
	fi

	for _module in "$@"; do
		 _usd_module=$(printf "$_module" | tr '-' '_')
		if lsmod | grep -qw "$_usd_module"; then
			printf "%s: info: Kernel module: '%s' is already loaded.\n" "$CURFILE" "$_usd_module"
			continue
		fi

		if modprobe "$_module" > /dev/null 2>&1; then
			printf "%s: info: Successfully loaded kernel module: '%s'.\n" "$CURFILE" "$_module"
		else
			printf "%s: error: Faled to load kernel module: '%s'.\n" "$CURFILE" "$_module"
		fi
	done
}

# Only works for Acer laptops
set_battery_health_mode()
{
	_mode=${1:-1}
	if [ "$_mode" != '1' ] && [ "$_mode" != '0' ]; then
		printf "%s: warning: Invalid mode. Defaulting to '1'.\n" "$CURFILE"
		_mode=1
	fi
		
	printf "$_mode\n" > /sys/bus/wmi/drivers/acer-wmi-battery/health_mode

	printf "%s: info: Battery health mode set to '%s'.\n" "$CURFILE" "$_mode"
}

# Only works for Acer laptops
reset_battery_health_mode()
{
	printf "0\n" > /sys/bus/wmi/drivers/acer-wmi-battery/health_mode
}

update_ddns()
{
	if [ $CONF_FILE_EXISTS -ne 0 ]; then
		printf "%s: error: No DDNS configuration found.\n" "$CURFILE"
		exit 1
	fi
	
	if [ "$DDNS_TOKEN" = '' ]; then
		printf "%s: error: DDNS token/domain not found. It should be present in your
		/etc/hwcfg.conf file. Example:
			DDNS_TOKEN=abcd-efgh-1234-5678
			DDNS_DOMAIN=mydomain\n" "$CURFILE"
			
		return 1
	fi

	printf "%s: info: Updating DuckDNS IP for $DDNS_DOMAIN.\n" "$CURFILE"
	UPDATE_RES=$(curl -s --connect-timeout 10 "https://www.duckdns.org/update?domains=$DDNS_DOMAIN&token=$DDNS_TOKEN&ip=")

	if [ $? -ne 0 ]; then
		printf "%s: error: Could not update DDNS Domain.\n" "$CURFILE"
		return 1
	fi

	if [ "$UPDATE_RES" = 'OK' ]; then
		printf "%s: info: DuckDNS IP updated successfully. $UPDATE_RES\n" "$CURFILE"
	else
		printf "%s: warning: Failed to update DuckDNS IP. $UPDATE_RES\n" "$CURFILE"
	fi
}

case "$1" in
	'install')
		if ! install; then
			printf "%s: error: Failed to install dependencies.\n" "$CURFILE"
			exit 1
		fi

		exit 0

		;;

	'--gaming')
		GPU_CLOCK_FREQ=${GPU_CLOCK_FREQ:-1200}
		CPU_TDP=${CPU_TDP:-25000}
		CPU_TDP_FAST=${CPU_TDP_FAST:-30000}
		CPU_TEMP_LIMIT=${CPU_TEMP_LIMIT:-70}
		AMD_PSTATE_STATUS=${AMD_PSTATE_STATUS:-passive}

		;;

	'--server-host')
		GPU_CLOCK_FREQ=${GPU_CLOCK_FREQ:-400}
		CPU_TDP=${CPU_TDP:-15000}
		CPU_TDP_FAST=${CPU_TDP_FAST:-17000}
		CPU_TEMP_LIMIT=${CPU_TEMP_LIMIT:-60}
		AMD_PSTATE_STATUS=${AMD_PSTATE_STATUS:-passive}

		;;

	'--game-server-host')
		GPU_CLOCK_FREQ=${GPU_CLOCK_FREQ:-1200}
		CPU_TDP=${CPU_TDP:-25000}
		CPU_TDP_FAST=${CPU_TDP_FAST:-30000}
		CPU_TEMP_LIMIT=${CPU_TEMP_LIMIT:-70}
		AMD_PSTATE_STATUS=${AMD_PSTATE_STATUS:-passive}

		;;
		
	'--update-ddns')
		update_ddns
		
		exit 0

		;;
		
	'--load-kmod')
		shift
		load_kernel_module "$@"

		exit 0;

		;;

	'--battery-health')
		shift
		set_battery_health_mode "$@"
		
		exit 0

		;;

	'--reset-battery-health')
		reset_battery_health_mode
		
		exit 0

		;;
		
	*)
		printf "%s: error: '%s' is not a valid argument.\n" "$CURFILE" "$1"
		
		exit 1
esac

for BIN in 'nvidia-smi' 'ryzenadj'; do
	if ! command -v "$BIN" > /dev/null 2>&1; then
		printf "%s: error: '%s' not found in %s.\n" "$CURFILE" "$BIN" "$PATH"
		exit 1
	fi
done

load_kernel_module 'ryzen_smu' 'acer-wmi-battery'

if nvidia-smi -pm 1 > /dev/null 2>&1; then
	printf "%s: info: NVIDIA-SMI persistence mode enabled." "$CURFILE"
else
	printf "%s: error: Failed to enable persistence mode for NVIDIA-SMI." "$CURFILE"
	exit 1
fi

if nvidia-smi -lgc 0,"$GPU_CLOCK_FREQ" > /dev/null 2>&1; then
	printf "%s: info: NVIDIA GPU clock locked at %i MHz.\n" "$CURFILE" "$GPU_CLOCK_FREQ"
else
	printf "%s: error: Failed to lock NVIDIA GPU clock.\n" "$CURFILE"
	exit 1
fi

if ryzenadj --stapm-limit="$CPU_TDP" --fast-limit="$CPU_TDP_FAST" --slow-limit="$CPU_TDP" --tctl-temp="$CPU_TEMP_LIMIT" > /dev/null 2>&1; then
	printf "%s: info: CPU power/temperature limited to %i mW/%i C.\n" "$CURFILE" "$CPU_TDP_FAST" "$CPU_TEMP_LIMIT"
else
	printf "%s: info: Failed to configure CPU limits.\n" "$CURFILE"
	exit 0
fi

if [ "$AMD_PSTATE_STATUS" != 'passive' ] && [ "$AMD_PSTATE_STATUS" != 'active' ]; then
	AMD_PSTATE_STATUS=passive
fi

FILE_AMDPSTATE='/sys/devices/system/cpu/amd_pstate/status'
if [ -f "$FILE_AMDPSTATE" ]; then
	printf "%s\n" "$AMD_PSTATE_STATUS" > "$FILE_AMDPSTATE"
	printf "%s: info: amd_pstate/status set to '$AMD_PSTATE_STATUS'.\n" "$CURFILE"
else
	printf "%s: warning: $FILE_AMDPSTATE not found.\n" "$CURFILE"
fi

set_battery_health_mode '1'

# printf "performance\n" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

printf "%s: info: Hardware configuration complete.\n" "$CURFILE"
exit 0
