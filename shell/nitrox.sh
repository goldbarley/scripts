#!/usr/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OG_DIR=$(pwd)

TXSN_NITROX='nitrox'

tmux_exec()
{
	if ! tmux send-keys -t "$TXSN_NITROX" "$1" C-m > /dev/null 2>&1; then
		printf "%s.\nCommand: %s\n " "$2" "$1"
		return 1
	fi

	return 0
}

get_dotnet()
{
	_dotnet_dir="$SCRIPT_DIR/.dotnet-runtime-9.0.15";

	if [ -d "$_dotnet_dir" ]; then
		if ! rm -rf "$_dotnet_dir" > /dev/null 2>&1; then
			printf "Failed to remove directory: '%s'\n" "$_dotnet_dir"
			exit 1
		fi
	fi

	if ! mkdir -p "$_dotnet_dir"; then
		printf "Failed to create directory: %s\n" "$_dotnet_dir"
	fi

	if ! curl --output-dir "$_dotnet_dir" -O "https://builds.dotnet.microsoft.com/dotnet/Runtime/9.0.15/dotnet-runtime-9.0.15-linux-x64.tar.gz"; then
		printf "Failed to get .NET runtime 9.0.15 for Linux x64.\n"
		return 1
	fi

	if ! cd "$_dotnet_dir"; then
		printf "Failed to change directory to: '%s'\n" "$_dotnet_dir"
	fi

	if ! tar -xzf 'dotnet-runtime-9.0.15-linux-x64.tar.gz' > /dev/null 2>&1; then
		printf "Failed to extract gzip: 'dotnet-runtime-9.0.15-linux-x64.tar.gz'\n"
		return 1
	fi

	if ! rm -f 'dotnet-runtime-9.0.15-linux-x64.tar.gz' > /dev/null 2>&1; then
		printf "Failed to remove file: 'dotnet-runtime-9.0.15-linux-x64.tar.gz'\n"
	fi
}

nitrox_start()
{
	if tmux has-session -t "$TXSN_NITROX" > /dev/null 2>&1; then
		printf "tmux session: '%s' is already active.\n" "$TXSN_NITROX"
		return 1
	fi

	if ! tmux new-session -s "$TXSN_NITROX" -d -c "$SCRIPT_DIR" > /dev/null 2>&1; then
		printf "Failed to create tmux session: '%s'\n" "$TXSN_NITROX"
		return 1
	fi

	_cmd1="export DOTNET_ROOT=\"$SCRIPT_DIR/.dotnet-runtime-9.0.15\""
	_cmd2='export PATH="$DOTNET_ROOT:$PATH"'
	_cmd3="exec ./Nitrox.Launcher"

	if ! tmux_exec "$_cmd1" "Failed to export .NET runtime."; then
		return 1
	fi

	if ! tmux_exec "$_cmd2" "Failed to update environment variable 'PATH'."; then
		return 1
	fi

	if ! tmux_exec "$_cmd3" "Failed to launch Nitrox.Launcher."; then
		return 1
	fi

	return 0
}

nitrox_stop()
{
	if ! tmux has-session -t "$TXSN_NITROX" > /dev/null 2>&1; then
		printf "No tmux session with name '%s' was found.\n" "$TXSN_NITROX"
		return 1
	fi

	printf "Checking for Nitrox.Launcher process...\n"
	while pgrep -f 'Nitrox*' > /dev/null 2>&1; do
		sleep 1
	done
	printf "Process(es): 'Nitrox*' terminated.\nClosing tmux session: '%s'\n" "$TXSN_NITROX"
	if ! tmux send-keys -t "$TXSN_NITROX" "exit" C-m > /dev/null 2>&1; then
		printf "Failed to exit tmux session: '%s'\n" "$TXSN_NITROX"
		printf "Killing tmux session: '%s' in 1 second...\n" "$TXSN_NITROX"
		sleep 1
		if ! tmux kill-session -t "$TXSN_NITROX" > /dev/null 2>&1; then
			printf "Failed to kill tmux session: '%s'. Manual intervention necessary.\n" "$TXSN_NITROX"
		fi
	fi
}

case $1 in
	'init')
		if ! get_dotnet; then
			exit 1
		fi

		;;
	'start')
		if ! nitrox_start; then
			exit 1;
		fi

		printf "Operation successful.\n"
		printf "Execute command: 'tmux ls' to view active sessions.\n"
		printf "Execute command: 'tmux attach -t <session-name>' to attach to a specific session.\n"
		printf "When inside a tmux session, press Ctrl + B and D to exit.\n"
		printf "Note: The aforementioned key combination will NOT terminate the session but only detach you from it.\n"

		;;
	'stop')
		if ! nitrox_stop; then
			exit 1;
		fi

		;;
	*)
		printf "Not a valid argument.\n"
		printf "Usage: %s [init|start|stop]\n" "$0"
esac


STATUS=0

if ! chmod +x "$SCRIPT_DIR/.dotnet-runtime-9.0.15/dotnet"; then
	printf "Failed to make 'dotnet' an executable.\n"
	STATUS=1
fi

if ! chmod +x "$SCRIPT_DIR/Nitrox.Launcher"; then
	printf "Failed to make 'Nitrox.Launcher' an executable.\n"
	STATUS=1
fi

if ! cd "$OG_DIR"; then
	printf "Failed to change directory to: '%s'\n" "$OG_DIR"
	STATUS=1
fi
exit $STATUS
