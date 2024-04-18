#!/usr/bin/env bash

# Firewall service checker + log
# Codes de retour Opcon:
#   10 - Port/service ajouté et pare-feu rechargé.
#   20 - Aucun port/service n'a besoin d'être ajouté.
#   30 - Service SSH dans un état différent de "active" et redémarré avec succès.
#   40 - Service SSH déjà en état "active", aucune action nécessaire.
#   50 - Échec du redémarrage du service SSH.
# TODO: Check SSH keys

log_file="/var/log/opcon_client/journal.log"

log() {
    local level=$1
    local message=$2
    echo "$(date '+%d-%m-%Y %H:%M:%S') - [$level] - $message" >> "$log_file"
}

setup_environment() {
    if [ ! -d "$(dirname "$log_file")" ]; then
        mkdir -p "$(dirname "$log_file")"
    fi

    if [ ! -f "$log_file" ]; then
        touch "$log_file"
    fi\
}

add_firewall_rule_if_needed() {
    local service=$1
    local type=$2
    local zone=$3

    local current=$(firewall-cmd --zone="$zone" --list-$type)
    if [[ "$current" != *"$service"* ]]; then
        if firewall-cmd --zone="$zone" --add-$type="$service" --permanent; then
            log "INFO" "$service $type successfully added."
            return 1  # Signal that a reload is needed
        else
            log "ERROR" "Fail to add $service $type to the firewall."
            return 0
        fi
    else
        log "INFO" "$service $type is already configured in the firewall."
        return 2
    fi
}

# Setup environment
setup_environment

need_reload=0

# Check firewall SSH Service 
add_firewall_rule_if_needed "ssh" "service" "public" && need_reload=1
# Check firewall SSH Ports
add_firewall_rule_if_needed "22/tcp" "port" "public" && need_reload=1

if [[ $need_reload -eq 1 ]]; then
    firewall-cmd --reload
    log "INFO" "Firewall reloaded."
    exit 10 
fi

exit 20  # Nothing added

# Check SSH Service State
service_status=$(systemctl is-active sshd)
log "INFO" "SSH service status: $service_status"
if [[ $service_status != "active" ]]; then
    if systemctl restart sshd; then
        log "INFO" "SSH service restart successfully."
        exit 30
    else
        log "ERROR" "Fail to restart SSH service."
        exit 50
    fi
else
    log "INFO" "SSH service already running."
    exit 40
fi
