#!/usr/bin/env bash

# AIDE utils
# Firewall service checker : foxwall 
# TODO: Check SSH keys

log_file="/var/log/opcon_client/journal.log"

log() {
    local level=$1
    local message=$2
    echo "$(date '+%d-%m-%Y %H:%M:%S') - [$level] - $message" >> "$log_file"
}

check_and_modify_firewall() {
    local service=$1
    local type=$2
    local zone=$3

    if [[ "$type" == "service" ]]; then
        check_cmd="firewall-cmd --zone=$zone --query-service=$service"
    elif [[ "$type" == "port" ]]; then
        check_cmd="firewall-cmd --zone=$zone --query-port=$service"
    fi

    if ! $check_cmd; then
        log "INFO" "$service $type not open"
        firewall-cmd --zone="$zone" --add-$type=$service --permanent
        echo "true"
    else
        echo "false"
    fi
}

need_reload=false

if [ ! -d "$(dirname "$log_file")" ]; then
    mkdir -p "$(dirname "$log_file")"
fi

if [ ! -f "$log_file" ]; then
    touch "$log_file"
fi

# Check firewall SSH Service
if [[ $(check_and_modify_firewall "ssh" "service" "public") == "true" ]]; then
    need_reload=true
fi

# Check firewall SSH port 22
if [[ $(check_and_modify_firewall "22/tcp" "port" "public") == "true" ]]; then
    need_reload=true
fi

if [[ $need_reload == true ]]; then
    firewall-cmd --reload
    log "INFO" "Firewall reloaded"
fi

# Check SSH Service State
service_status=$(systemctl is-active sshd)
if [[ $service_status != "active" ]]; then
    log "WARN" "SSH service is $service_status"
    if systemctl restart sshd; then
        log "INFO" "SSH service restart successfully"
    else
        log "ERROR" "Failed to restart SSH service"
    fi
else
    log "INFO" "SSH service running"
fi
