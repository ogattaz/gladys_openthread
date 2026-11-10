#!/usr/bin/env bash
# =============================================================================
# validate-otbr.sh
# Vérifie le bon fonctionnement d'un OpenThread Border Router (conteneur Docker
# "otbr" en network_mode host, dongle RCP /dev/nrf52840).
#
# Contrôles effectués :
#   1. Conteneur et image (en cours d'exécution, network_mode host)
#   2. Dongle RCP présent (/dev/nrf52840) et détecté par l'agent
#   3. État OpenThread (leader attendu) et réseau Thread (canal, panid...)
#   4. Dataset présent + interface wpan0 avec adresses IPv6
#   5. Services Border Router : Backbone Router, NAT64, DNS/SRP, Border Agent
#   6. Écoutes web (8090) et REST (8081) sur les bons ports/adresses
#   7. Annonce mDNS _meshcop._udp sur le LAN (si avahi-browse est installé)
#   8. (option --persistence) Le dataset survit à un redémarrage du conteneur
#
# Usage :  ./validate-otbr.sh [--persistence]
#          --persistence : inclut le test de persistance du dataset.
#          ATTENTION : ce test REDEMARRE le conteneur otbr (interruption
#          temporaire du réseau Thread, quelques dizaines de secondes).
#
# Le script n'installe rien et ne modifie rien (sauf le redémarrage du
# conteneur avec --persistence). Code retour 0 si tout est OK, 1 sinon.
# =============================================================================
set -uo pipefail   # pas de -e : chaque échec est tracé puis comptabilisé

# ------------------------------ Arguments -------------------------------------
DO_PERSISTENCE=0
for arg in "$@"; do
    case "$arg" in
        --persistence) DO_PERSISTENCE=1 ;;
        -h|--help)
            grep -E '^# Usage' "$0" | head -n1
            exit 0 ;;
        *)
            echo "Argument inconnu : $arg (utilisez --persistence)" >&2
            exit 1 ;;
    esac
done

CONTAINER="otbr"
RCP_DEV="/dev/nrf52840"
WEB_PORT="8090"
REST_PORT="8081"
BORDER_AGENT_PORT="49153"   # le port d'écoute MeshCoP varie parfois : 49153-49154

PASS=0; FAIL=0; WARN=0
ok()    { echo "  [OK]   $*"; PASS=$((PASS+1)); }
ko()    { echo "  [ÉCHEC] $*"; FAIL=$((FAIL+1)); }
warn()  { echo "  [ATTENTION] $*"; WARN=$((WARN+1)); }
header(){ echo ""; echo "===== $* ====="; }
# ot-ctl émet ses réponses avec des retours chariot (\r\n, format interactif)
# et termine chaque réponse par une ligne "Done" : on nettoie les deux pour
# pouvoir comparer proprement les valeurs (état, canal, etc.).
ctl()   { docker exec "$CONTAINER" ot-ctl "$@" 2>/dev/null | tr -d '\r' | sed '/^Done$/d' || true; }

echo ":: Validation OTBR ($(date '+%d/%m/%Y %H:%M:%S'))"

# ------------------------- 1. Conteneur Docker --------------------------------
header "1/8 Conteneur Docker"
STATE=$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null || true)
if [[ "$STATE" == "running" ]]; then
    ok "conteneur '$CONTAINER' en cours d'exécution"
else
    ko "conteneur '$CONTAINER' introuvable ou arrêté (état : ${STATE:-aucun})"
    echo "        Diagnostics : docker ps -a | grep otbr ; docker logs otbr"
    echo "        Le reste des tests est abandonné."
    exit 1
fi
NETMODE=$(docker inspect -f '{{.HostConfig.NetworkMode}}' "$CONTAINER" 2>/dev/null || true)
[[ "$NETMODE" == "host" ]] && ok "network_mode : host" \
    || ko "network_mode inattendu : '${NETMODE}' (host requis pour mDNS/routage)"
IMAGE=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || true)
ok "image : ${IMAGE:-inconnue}"

# ------------------------- 2. Dongle RCP --------------------------------------
header "2/8 Dongle RCP ($RCP_DEV)"
if [[ -e "$RCP_DEV" ]]; then
    ok "périphérique $RCP_DEV présent"
else
    ko "$RCP_DEV absent (règle udev non appliquée ? dongle débranché ?)"
    echo "        Vérifiez : ls -l /dev/ttyACM* /dev/nrf52840 ; lsblk"
fi
RCPVER=$(ctl rcp version || true)
if [[ -n "$RCPVER" ]]; then
    ok "RCP détecté par l'agent : $RCPVER"
else
    ko "l'agent ne répond pas 'rcp version' (dongle non détecté par otbr-agent)"
    echo "        Diagnostics : docker logs otbr | tail -n 30"
fi

# ------------------------- 3. État OpenThread ---------------------------------
header "3/8 État OpenThread"
OTSTATE=$(ctl state || true)
if [[ "$OTSTATE" == "leader" ]]; then
    ok "état : leader (le routeur de bordure dirige le réseau Thread)"
elif [[ -n "$OTSTATE" ]]; then
    ko "état : '$OTSTATE' (leader attendu)"
    echo "        'disabled'  : réseau Thread non démarré"
    echo "        'detached'  : élection en cours, relancez dans 30 s"
else
    ko "ot-ctl ne répond pas (agent OTBR arrêté ?)"
fi
NETNAME=$(ctl networkname || true)
CHANNEL=$(ctl channel || true)
PANID=$(ctl panid || true)
[[ -n "$NETNAME" ]] && ok "réseau Thread : '$NETNAME', canal ${CHANNEL:-?}, panid ${PANID:-?}" \
    || ko "impossible de lire le nom/canal/panid du réseau Thread"
echo "        Table des routeurs Thread :"
ctl router table | sed 's/^/          /' || warn "table des routeurs indisponible"
# NB : si seul le routeur 16 (vous-même) apparaît, c'est normal tant qu'aucun
# appareil Thread n'est appairé sur ce réseau.

# ------------------------- 4. Dataset et wpan0 --------------------------------
header "4/8 Dataset Thread et interface wpan0"
DATASET=$(ctl dataset active -x 2>/dev/null | grep -E '^[0-9a-f]{40,}$' || true)
if [[ -n "$DATASET" ]]; then
    ok "dataset actif présent (${#DATASET} caractères hexa)"
    echo "        $DATASET"
else
    ko "aucun dataset actif lu via 'dataset active -x'"
    echo "        Sortie brute pour diagnostic :"
    docker exec "$CONTAINER" ot-ctl dataset active -x 2>&1 | tr -d '\r' | sed 's/^/          /'
    echo "        Alternatives à essayer :"
    echo "          docker exec otbr ot-ctl dataset active"
    echo "          docker exec otbr ot-ctl dataset mgmtgetcommand"
fi
if ip link show wpan0 >/dev/null 2>&1; then
    ok "interface wpan0 présente sur le host"
    V6COUNT=$(ip -6 addr show wpan0 2>/dev/null | grep -c 'inet6' || true)
    [[ "${V6COUNT:-0}" -ge 2 ]] && ok "wpan0 : ${V6COUNT} adresses IPv6 (OMR + ML)" \
        || ko "wpan0 n'a que ${V6COUNT:-0} adresse(s) IPv6 (2 attendues minimum)"
    ip -6 addr show wpan0 scope global 2>/dev/null | awk '/inet6/{print "          " $2}' \
        || true
else
    ko "interface wpan0 absente du host"
    echo "        Vérifiez : docker logs otbr | grep -i wpan ; ip link"
fi

# ------------------------- 5. Services Border Router -------------------------
header "5/8 Services Border Router"
BBR=$(ctl bbr state || true)
[[ "$BBR" == "Primary" ]] && ok "Backbone Router : Primary" \
    || warn "Backbone Router : '${BBR:-inconnu}' (Primary attendu ; si l'élection \
vient d'avoir lieu, patientez 1 min)"
SRP=$(ctl srp server state 2>/dev/null || true)
[[ "$SRP" == "Enabled" || "$SRP" == "running" ]] && ok "serveur SRP : $SRP" \
    || warn "serveur SRP : '${SRP:-inconnu}' (Enabled/running attendu)"
NAT64=$(ctl nat64prefixes 2>/dev/null | grep -E '^[[:space:]]*fd' | head -n1 || true)
[[ -n "$NAT64" ]] && ok "NAT64 : $NAT64" \
    || warn "préfixe NAT64 illisible ou non publié (commande nat64prefixes \
absente de cette version d'ot-ctl ? vérifiez : docker exec otbr ot-ctl nat64prefix)"
DNS=$(ctl dns state 2>/dev/null || true)
[[ -n "$DNS" ]] && ok "service DNS : actif" || warn "état DNS illisible"
NETDATA=$(ctl netdata show 2>/dev/null | wc -l || true)
[[ "${NETDATA:-0}" -gt 0 ]] && ok "données réseau Thread publiées (${NETDATA} entrées)" \
    || ko "aucune donnée réseau publiée (netdata vide)"

# ------------------------- 6. Écoutes web/REST/border agent ------------------
header "6/8 Ports d'écoute (web $WEB_PORT / REST $REST_PORT / border agent $BORDER_AGENT_PORT)"
if ss -tln 2>/dev/null | grep -q "0.0.0.0:${WEB_PORT} "; then
    ok "interface web : écoute 0.0.0.0:${WEB_PORT} (joignable depuis le LAN)"
elif ss -tln 2>/dev/null | grep -qE "(:| )${WEB_PORT} "; then
    warn "port ${WEB_PORT} en écoute, mais pas sur 0.0.0.0 (inaccessible du LAN ?)"
else
    ko "rien n'écoute le port ${WEB_PORT} (otbr-web démarré ?)"
fi
if ss -tln 2>/dev/null | grep -q "127.0.0.1:${REST_PORT} "; then
    ok "API REST : écoute 127.0.0.1:${REST_PORT}"
else
    warn "API REST absente de 127.0.0.1:${REST_PORT} (vérifiez OT_REST_LISTEN_*)"
fi
if ss -uln 2>/dev/null | grep -qE ":4915[0-9] "; then
    AGENTPORT=$(ss -uln 2>/dev/null | grep -oE ':4915[0-9] ' | head -n1 | tr -d ' :')
    ok "Border Agent : UDP ${AGENTPORT} en écoute (appairage MeshCoP)"
else
    ko "aucun Border Agent en écoute UDP 49153-49154"
fi

# ------------------------- 7. Annonce mDNS sur le LAN ------------------------
header "7/8 Annonce mDNS _meshcop._udp sur le LAN"
if command -v avahi-browse >/dev/null 2>&1; then
    MDNS=$(timeout 5 avahi-browse -rt _meshcop._udp 2>/dev/null || true)
    if echo "$MDNS" | grep -q "openthread\|border-router\|= *rieux\|_meshcop"; then
        ok "service _meshcop._udp publié sur le LAN (découverte par les \
contrôleurs Matter/Thread possible)"
    else
        warn "service _meshcop._udp non vu en 5 s (annonce lente ? relancez)"
    fi
else
    warn "avahi-browse non installé : annonce mDNS non vérifiée"
    echo "        Pour activer ce contrôle : sudo apt install avahi-utils"
fi

# ------------------------- 8. Persistance du dataset -------------------------
header "8/8 Persistance du dataset Thread"
if [[ $DO_PERSISTENCE -eq 0 ]]; then
    echo "  Test sauté (lancez avec --persistence pour l'activer)."
    echo "  Rappel : ce test redémarre le conteneur '$CONTAINER'."
elif [[ -z "$DATASET" ]]; then
    ko "pas de dataset à comparer : test impossible"
else
    echo "  Redémarrage du conteneur..."
    docker restart "$CONTAINER" >/dev/null 2>&1 \
        || { ko "redémarrage du conteneur impossible"; exit 1; }
    echo -n "  Attente du retour à l'état leader (max 120 s) : "
    NEWSTATE=""
    for _i in $(seq 1 40); do
        NEWSTATE=$(ctl state || true)
        [[ "$NEWSTATE" == "leader" ]] && break
        echo -n "."
        sleep 3
    done
    echo ""
    [[ "$NEWSTATE" == "leader" ]] && ok "état leader restauré après redémarrage" \
        || ko "état '${NEWSTATE:-inconnu}' après 120 s (leader attendu)"
    NEWDATASET=$(ctl dataset active -x 2>/dev/null | grep -E '^[0-9a-f]{40,}$' || true)
    if [[ -n "$NEWDATASET" ]]; then
        if [[ "$NEWDATASET" == "$DATASET" ]]; then
            ok "dataset IDENTIQUE après redémarrage : le réseau Thread est persistant"
        else
            ko "dataset CHANGÉ après redémarrage : le RCP ne conserve pas le \
dataset (firmware -DOT_RCP_RESTORATION_MAX_COUNT=0 ? à recompiler avec =2 et reflasher)"
            echo "        Avant : $DATASET"
            echo "        Après : $NEWDATASET"
        fi
    else
        ko "aucun dataset après redémarrage : réseau Thread non reformé"
    fi
fi

# ------------------------------ Bilan -----------------------------------------
echo ""
echo "=============================================="
echo " Bilan : $((PASS)) OK, $((FAIL)) échec(s), $((WARN)) avertissement(s)"
echo "=============================================="
[[ $FAIL -eq 0 ]] || exit 1
exit 0
