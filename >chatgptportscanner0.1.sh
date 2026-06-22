#!/usr/bin/env bash
# ==========================================
# ChatGPT's Port Scanner 0.1
# Simple TCP port scanner (pure .sh)
# ==========================================
#   bash chatgptportscanner0.1.sh
#   bash chatgptportscanner0.1.sh 127.0.0.1
#   bash chatgptportscanner0.1.sh 127.0.0.1 1 1024
#   sh chatgptportscanner0.1.sh 127.0.0.1 22 22

if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -u

SCRIPT_NAME="$(basename "$0")"
NAME="ChatGPT's Port Scanner 0.1"
TARGET=""
START_PORT=""
END_PORT=""
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-0.25}"
MAX_PORTS="${MAX_PORTS:-8192}"

GREEN='\033[32m'
RESET='\033[0m'
PROBE=""

show_help() {
    cat <<EOF
${NAME}

USAGE
  bash ${SCRIPT_NAME} [target] [start_port] [end_port]

INTERACTIVE
  bash ${SCRIPT_NAME}
  (prompts for target and port range)

EXAMPLES
  bash ${SCRIPT_NAME} 127.0.0.1
  bash ${SCRIPT_NAME} 127.0.0.1 1 500
  bash ${SCRIPT_NAME} scanme.nmap.org 22 80

OPTIONS
  -h, --help     Show help

ENV
  CONNECT_TIMEOUT=0.25   seconds per port (default)
  MAX_PORTS=8192         max ports per scan

NOTE: Run with bash or sh — not python3.
EOF
    exit 0
}

die() {
    echo "Error: $*" >&2
    exit 1
}

is_uint() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

run_timeout() {
    local seconds="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$seconds" "$@"
        return $?
    fi
    "$@" &
    local pid=$!
    ( sleep "$seconds"; kill "$pid" 2>/dev/null ) &
    local watcher=$!
    wait "$pid" 2>/dev/null
    local st=$?
    kill "$watcher" 2>/dev/null
    wait "$watcher" 2>/dev/null
    return "$st"
}

detect_probe() {
    local err
    err="$(bash -c 'echo >/dev/tcp/127.0.0.1/1' 2>&1)" || true
    case "$err" in
        *"No such file"*|*"not supported"*)
            command -v nc >/dev/null 2>&1 || die "need bash /dev/tcp or nc"
            PROBE="nc"
            ;;
        *) PROBE="bash" ;;
    esac
}

port_open() {
    local host="$1" port="$2"
    case "$PROBE" in
        bash)
            run_timeout "$CONNECT_TIMEOUT" bash -c "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null
            ;;
        nc)
            nc -z -w "$CONNECT_TIMEOUT" "$host" "$port" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

validate_ports() {
    is_uint "$START_PORT" || die "start port must be a number (got: $START_PORT)"
    is_uint "$END_PORT"   || die "end port must be a number (got: $END_PORT)"
    [ "$START_PORT" -ge 1 ]     || die "start port must be >= 1"
    [ "$END_PORT"   -le 65535 ] || die "end port must be <= 65535"
    [ "$START_PORT" -le "$END_PORT" ] || die "start port must be <= end port"
    local count=$((END_PORT - START_PORT + 1))
    [ "$count" -le "$MAX_PORTS" ] || die "range too large ($count ports, max $MAX_PORTS)"
}

prompt_interactive() {
    printf '\n'
    echo "=========================================="
    echo "   ChatGPT's Port Scanner 0.1"
    echo "=========================================="
    printf '\n'
    read -r -p "Target IP or Hostname: " TARGET
    read -r -p "Start Port [1]: " START_PORT
    read -r -p "End Port [1024]: " END_PORT
    START_PORT="${START_PORT:-1}"
    END_PORT="${END_PORT:-1024}"
}

parse_args() {
    case "${1:-}" in
        -h|--help|-help|help) show_help ;;
    esac

    if [ $# -eq 0 ]; then
        prompt_interactive
        return
    fi

    TARGET="$1"
    START_PORT="${2:-1}"
    END_PORT="${3:-1024}"

    [ -n "$TARGET" ] || die "missing target (try --help)"
}

run_scan() {
    local port open_count=0 total current=0
    total=$((END_PORT - START_PORT + 1))

    echo
    echo "=========================================="
    echo "   ChatGPT's Port Scanner 0.1"
    echo "=========================================="
    echo "Target : $TARGET"
    echo "Range  : $START_PORT - $END_PORT"
    echo "Probe  : $PROBE (${CONNECT_TIMEOUT}s timeout)"
    echo "=========================================="
    echo
    echo "Scanning $TARGET..."
    echo

    for ((port = START_PORT; port <= END_PORT; port++)); do
        current=$((current + 1))
        if port_open "$TARGET" "$port"; then
            echo -e "${GREEN}[OPEN]${RESET} Port $port"
            open_count=$((open_count + 1))
        fi
        if [ "$total" -gt 100 ] && [ $((current % 50)) -eq 0 ]; then
            printf '\rProgress: %d / %d ports' "$current" "$total" >&2
        fi
    done

    [ "$total" -gt 100 ] && printf '\r%-32s\n' " " >&2

    echo
    echo "=========================================="
    echo "Scan complete. $open_count open port(s) found."
    echo "=========================================="
}

parse_args "$@"
validate_ports
detect_probe

trap 'echo; echo "Interrupted."; exit 130' INT
run_scan
