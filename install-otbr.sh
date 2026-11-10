#!/usr/bin/env bash
# =============================================================================
# install-otbr.sh
# Installation automatisée d'un OpenThread Border Router (Docker) sur
# Raspberry Pi 4 avec un dongle nRF52840 (MakerDiary MDK USB Dongle).
#
# Étapes : build du firmware RCP -> flashage DFU -> règle udev (nom stable
# /dev/nrf52840) -> docker-compose -> démarrage + création du réseau Thread.
#
# Usage :  sudo ./install-otbr.sh [--already-flashed]
#          --already-flashed : saute l'étape 3/7 (flashage) si le dongle
#          tourne déjà sur le firmware RCP OpenThread.
# =============================================================================
set -euo pipefail

# ------------------------------ Arguments -------------------------------------
SKIP_FLASH=0
for arg in "$@"; do
    case "$arg" in
        --already-flashed|--already_flashed) SKIP_FLASH=1 ;;
        -h|--help)
            grep -E '^# Usage' "$0" | head -n1
            exit 0 ;;
        *) echo "Argument inconnu : $arg (utilisez --already-flashed)" >&2; exit 1 ;;
    esac
done

# ------------------------------ Configuration --------------------------------
INSTALL_DIR="/opt/otbr"
DATA_DIR="${INSTALL_DIR}/data"
BUILD_DIR="${INSTALL_DIR}/firmware"
FW_ZIP="${BUILD_DIR}/ot-rcp.zip"
UDEV_RULE="/etc/udev/rules.d/99-nrf52840-otbr.rules"
PORT_SYMLINK="nrf52840"          # -> /dev/nrf52840
BAUD=115200
INFRA_IF="${INFRA_IF:-}"         # ex: eth0 ; auto-détecté si vide
OTBR_IMAGE="openthread/border-router"
# Serveur web / API REST de l'OTBR (variables lues par le script s6 de l'image)
# Web : écoute sur toutes les interfaces, port 8090 (le port 80 est occupé par Gladys)
WEB_LISTEN_ADDR="${OT_WEB_LISTEN_ADDR:-0.0.0.0}"
WEB_LISTEN_PORT="${OT_WEB_LISTEN_PORT:-8090}"
REST_LISTEN_ADDR="${OT_REST_LISTEN_ADDR:-127.0.0.1}"
REST_LISTEN_PORT="${OT_REST_LISTEN_PORT:-8081}"

# Résolution de l'outil DFU : adafruit-nrfutil (recommandé, Python 3) ou nrfutil.
# nrfutil 5.x (pip) ne fonctionne PAS en Python 3 (iteritems). Le venv est
# cherché dans le home de l'utilisateur appelant (pas /root) car ce script
# tourne en sudo. Surchargez avec :
#   sudo NRFUTIL_BIN=/chemin/vers/adafruit-nrfutil ./install-otbr.sh
NRFUTIL="${NRFUTIL_BIN:-$(command -v adafruit-nrfutil || command -v nrfutil || true)}"
if [[ -z "$NRFUTIL" ]]; then
    REAL_HOME="$HOME"
    [[ -n "${SUDO_USER:-}" ]] && REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    for c in "$REAL_HOME/gladys_openthread/venv/bin/adafruit-nrfutil" \
             "$REAL_HOME/gladys_openthread/venv/bin/nrfutil" \
             /home/*/gladys_openthread/venv/bin/adafruit-nrfutil; do
        if [[ -x "$c" ]]; then NRFUTIL="$c"; break; fi
    done
fi
[[ -n "$NRFUTIL" ]] || die "outil DFU introuvable (adafruit-nrfutil conseillé : pip install adafruit-nrfutil dans le venv)"

log()  { echo -e "\n:: $*"; }
die()  { echo "ERREUR : $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "lancez avec : sudo $0"

# ------------------------- 1. Dépendances déjà en place ----------------------
log "1/7 Vérification des dépendances (aucune installation ici)"
# Les dépendances doivent être installées au préalable :
# exécutez d'abord validate-openthread-dependencies.sh
NEEDED_CMDS=(git curl make python3 pip3 arm-none-eabi-gcc arm-none-eabi-objcopy udevadm docker)
MISSING=()
for c in "${NEEDED_CMDS[@]}"; do
    command -v "$c" >/dev/null 2>&1 || MISSING+=("$c")
done
[[ -n "$NRFUTIL" ]] || MISSING+=("nrfutil")
docker compose version >/dev/null 2>&1 || MISSING+=("docker compose (plugin)")
[[ -e /dev/net/tun ]] || MISSING+=("/dev/net/tun")
if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Dépendances manquantes : ${MISSING[*]}"
    echo "Lancez d'abord : ./validate-openthread-dependencies.sh"
    echo "puis installez les paquets listés avant de relancer ce script."
    die "installation interrompue (dépendances incomplètes)"
fi
systemctl enable --now docker

# ------------------------- 2. Build du firmware RCP --------------------------
log "2/7 Compilation du firmware OpenThread RCP (quelques minutes)"
mkdir -p "$BUILD_DIR"
if [[ ! -d "${BUILD_DIR}/ot-nrf528xx" ]]; then
    git clone --recursive --depth 1 https://github.com/openthread/ot-nrf528xx \
        "${BUILD_DIR}/ot-nrf528xx"
fi
cd "${BUILD_DIR}/ot-nrf528xx"
# INSTALL_FORMAT_TOOLS=0 : saute clang-format/clang-tidy (outils de contribution
# inutiles ici, et leur installateur ne supporte pas aarch64 sur Raspberry Pi)
# OT_RCP_RESTORATION_MAX_COUNT=2 : la valeur par défaut est 0 (le RCP perd son
# dataset à chaque reset de l'agent => nouveau réseau Thread à chaque
# redémarrage du conteneur). Avec 2 (valeur de référence des builds OpenThread),
# le RCP garde le dataset en flash et le réseau survit aux redémarrages.
INSTALL_FORMAT_TOOLS=0 ./script/bootstrap
./script/build nrf52840 USB_trans \
    -DOT_BOOTLOADER=USB \
    -DOT_JOINER=ON \
    -DOT_RCP_RESTORATION_MAX_COUNT=2 \
    -DOT_LOG_LEVEL=WARN
arm-none-eabi-objcopy -O ihex build/bin/ot-rcp ot-rcp.hex
# Paquet DFU : syntaxe différente selon l'outil détecté
if basename "$NRFUTIL" | grep -q adafruit; then
    "$NRFUTIL" dfu genpkg --application ot-rcp.hex "$FW_ZIP"
else
    "$NRFUTIL" pkg generate --hw-version 52 --sd-req 0x00 \
        --application-version 1 --application ot-rcp.hex "$FW_ZIP"
fi
[[ -f "$FW_ZIP" ]] || die "paquet DFU non généré"

# ------------------------- 3. Flashage du dongle ----------------------------
if [[ $SKIP_FLASH -eq 1 ]]; then
    log "3/7 Flashage du dongle : IGNORÉ (--already-flashed)"
    echo "    Le dongle est supposé déjà tourner sur le firmware RCP."
fi
if [[ $SKIP_FLASH -eq 0 ]]; then
log "3/7 Flashage du dongle"
echo ">>> Branchez le dongle en MAINTENANT LE BOUTON APPUYÉ (LED verte = mode DFU) <<<"
read -rp "    Appuyez sur Entrée quand c'est fait... "

# ---- Détection du bootloader : UF2 (lecteur 'Adafruit nRF UF2') ou DFU série ----
# Boucle d'attente avec progression visible : le lecteur peut mettre
# quelques secondes à apparaître après le branchement
echo -n "    Recherche du bootloader (max 30 s) : "
UF2_DEV=""
for _i in $(seq 1 15); do
    UF2_DEV=$(lsblk -rno NAME,MODEL 2>/dev/null | grep -i "nRF.*UF2" \
              | awk '{print "/dev/"$1}' | head -n1 || true)
    if [[ -n "${UF2_DEV:-}" ]]; then echo " trouvé !"; break; fi
    echo -n "."
    sleep 2
done
if [[ -z "${UF2_DEV:-}" ]]; then
    echo " non trouvé"
    echo "    Périphériques blocs visibles actuellement :"
    lsblk -rno NAME,MODEL,SIZE 2>/dev/null | sed 's/^/      /'
    echo "    Vérifiez que le dongle est bien branché en mode DFU (LED verte fixe)"
fi
DFU_PORT=$(ls -1t /dev/ttyACM* 2>/dev/null | head -n1 || true)

if [[ -n "$UF2_DEV" ]]; then
    # ================= Bootloader UF2 : copie d'un fichier .uf2 ================
    echo "    Bootloader UF2 détecté (lecteur $UF2_DEV) : flashage par copie .uf2"
    # Conversion hex -> uf2 (famille nRF52840)
    cd "${BUILD_DIR}/ot-nrf528xx"
    if [[ ! -f uf2conv.py ]]; then
        curl -fsSL https://raw.githubusercontent.com/microsoft/uf2/master/utils/uf2conv.py -o uf2conv.py \
        || curl -fsSL https://raw.githubusercontent.com/microsoft/uf2/master/uf2conv.py -o uf2conv.py \
        || die "téléchargement de uf2conv.py impossible"
    fi
    if [[ ! -f uf2families.json ]] || ! python3 -c "import json; json.load(open('uf2families.json'))" 2>/dev/null; then
        # Téléchargement avec vérification d'intégrité (JSON complet et valide)
        for _try in 1 2 3; do
            curl -fsSL --retry 3 https://raw.githubusercontent.com/microsoft/uf2/master/utils/uf2families.json -o uf2families.json
            if python3 -c "import json; json.load(open('uf2families.json'))" 2>/dev/null; then break; fi
            sleep 2
        done
        # Dernier recours : liste minimale avec la seule famille utile
        if ! python3 -c "import json; json.load(open('uf2families.json'))" 2>/dev/null; then
            cat > uf2families.json <<'EOF'
[
    {
        "id": "0xada52840",
        "short_name": "NRF52840",
        "description": "Nordic nRF52840"
    }
]
EOF
        fi
    fi
    python3 uf2conv.py -c -f 0xADA52840 ot-rcp.hex -o ot-rcp.uf2 \
        || die "conversion hex->uf2 échouée"
    # Copie sur le lecteur UF2 : le dongle flashe puis redémarre tout seul
    mkdir -p /mnt/mdk
    mount "$UF2_DEV" /mnt/mdk || die "montage de $UF2_DEV impossible"
    cp ot-rcp.uf2 /mnt/mdk/ && sync
    sleep 5
    umount /mnt/mdk 2>/dev/null || true
    # Le lecteur disparaît après le flash : c'est le signe du succès
    if lsblk -rno MODEL 2>/dev/null | grep -qi "nRF.*UF2"; then
        die "le lecteur UF2 est toujours présent : le fichier a peut-être été \
refusé (famille UF2 incompatible). Vérifiez le INFO_UF2.TXT du lecteur."
    fi
    echo "    Flashage UF2 effectué, le dongle a redémarré sur le nouveau firmware."
elif [[ -n "$DFU_PORT" ]]; then
    # ================= Bootloader DFU série (anciens dongles) =================
    echo "    Port DFU série détecté : $DFU_PORT"
    DFU_LOG="${BUILD_DIR}/dfu.log"
    if basename "$NRFUTIL" | grep -q adafruit; then
        # Pas de --singlebank : l'effacement immédiat peut faire tomber l'USB
        # en plein transfert (Errno 5). Double-bank par défaut, plus sûr.
        "$NRFUTIL" --verbose dfu serial --package "$FW_ZIP" -p "$DFU_PORT" -b 115200 2>&1 | tee "$DFU_LOG"
        # ATTENTION : adafruit-nrfutil renvoie 0 même en cas d'échec,
        # on vérifie donc le message de succès dans la sortie
        if ! grep -qi "DFU upgrade complete" "$DFU_LOG"; then
            die "flashage ÉCHOUÉ (pas de confirmation 'DFU upgrade complete'). \
Conseils : dongle en mode DFU (bouton maintenu au branchement, LED verte), \
branché directement sur un port USB 2.0 du Pi (sans hub, éviter l'USB 3), puis relancez le script."
        fi
    else
        "$NRFUTIL" dfu usb-serial -pkg "$FW_ZIP" -p "$DFU_PORT" -b 115200 2>&1 | tee "$DFU_LOG" \
            || die "flashage échoué : réessayez en mode DFU (bouton maintenu au branchement)"
    fi
    echo "    Flashage confirmé. Débranchez puis rebranchez le dongle normalement."
else
    die "ni lecteur UF2 ni port /dev/ttyACM* : le dongle n'est pas en mode DFU"
fi
fi   # fin du flashage (skippé si --already-flashed)

# ------------------------- 4. Règle udev (port stable) ----------------------
log "4/7 Règle udev : alias stable /dev/${PORT_SYMLINK}"
read -rp "    Rebranchez le dongle puis appuyez sur Entrée... "
# Boucle d'attente : le port ttyACM peut prendre quelques secondes à apparaître
echo -n "    Recherche du port du dongle (max 30 s) : "
PORT=""
for _i in $(seq 1 15); do
    PORT=$(ls -1t /dev/ttyACM* 2>/dev/null | head -n1 || true)
    if [[ -n "${PORT:-}" ]]; then echo " trouvé ! ($PORT)"; break; fi
    echo -n "."
    sleep 2
done
if [[ -z "${PORT:-}" ]]; then
    echo " non trouvé"
    echo "    Aucun /dev/ttyACM* visible. Vérifiez avec :"
    echo "      ls /dev/ttyACM* ; dmesg | tail -n 15"
    echo "    (LED éteinte = normal pour le firmware RCP, ce n'est pas un souci)"
    die "dongle non détecté après rebranchement"
fi
# Extraction fiable du VID/PID : propriétés udev (ID_VENDOR_ID/ID_MODEL_ID)
# avec repli sur l'analyse -a en n'extrayant QUE la valeur entre guillemets
VID=$(udevadm info --query=property -n "$PORT" 2>/dev/null | grep -oP 'ID_VENDOR_ID=\K[0-9a-f]+' | head -n1 || true)
PID=$(udevadm info --query=property -n "$PORT" 2>/dev/null | grep -oP 'ID_MODEL_ID=\K[0-9a-f]+' | head -n1 || true)
if [[ -z "$VID" ]]; then
    VID=$(udevadm info -a -n "$PORT" 2>/dev/null | grep -oP 'ATTRS\{idVendor\}=="\K[0-9a-f]+' | head -n1 || true)
fi
if [[ -z "$PID" ]]; then
    PID=$(udevadm info -a -n "$PORT" 2>/dev/null | grep -oP 'ATTRS\{idProduct\}=="\K[0-9a-f]+' | head -n1 || true)
fi
[[ -n "$VID" && -n "$PID" ]] || die "impossible de lire VID/PID du dongle"
cat > "$UDEV_RULE" <<EOF
SUBSYSTEM=="tty", ATTRS{idVendor}=="${VID}", ATTRS{idProduct}=="${PID}", \\
    SYMLINK+="${PORT_SYMLINK}", MODE="0660", GROUP="dialout"
EOF
udevadm control --reload-rules
# --action=add : un simple "change" ne recrée pas toujours le symlink
udevadm trigger --action=add "$PORT" 2>/dev/null || udevadm trigger "$PORT"
# Attente de la création de l'alias (peut prendre quelques secondes)
echo -n "    Activation de /dev/${PORT_SYMLINK} (max 15 s) : "
for _i in $(seq 1 15); do
    [[ -e "/dev/${PORT_SYMLINK}" ]] && { echo "OK (VID=${VID} PID=${PID})"; break; }
    echo -n "."
    sleep 1
done
if [[ ! -e "/dev/${PORT_SYMLINK}" ]]; then
    echo " ECHEC"
    echo "    Règle écrite dans ${UDEV_RULE} :"
    cat "$UDEV_RULE" | sed 's/^/      /'
    echo "    Débranchez et rebranchez le dongle, puis vérifiez :"
    echo "      ls -l /dev/${PORT_SYMLINK}"
    echo "    Pour le diagnostic : udevadm info -a -n ${PORT} | grep -m2 idVendor"
    die "l'alias /dev/${PORT_SYMLINK} n'est pas créé"
fi

# ------------------------- 5. docker-compose.yml ----------------------------
log "5/7 Génération de la configuration Docker"
[[ -z "$INFRA_IF" ]] && INFRA_IF=$(ip -o route get 1.1.1.1 2>/dev/null \
    | grep -oP 'dev \K\S+' | head -n1)
echo "    Interface backbone : ${INFRA_IF:-eth0 par défaut}"
mkdir -p "$DATA_DIR"
cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
services:
  otbr:
    image: ${OTBR_IMAGE}
    container_name: otbr
    network_mode: host
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/${PORT_SYMLINK}
      - /dev/net/tun
    volumes:
      - ${DATA_DIR}:/data
    environment:
      # Variables attendues par l'image openthread/border-router
      # (cf. https://openthread.io/guides/border-router/build-docker)
      - OT_RCP_DEVICE=spinel+hdlc+uart:///dev/${PORT_SYMLINK}?uart-baudrate=${BAUD}
      - OT_INFRA_IF=${INFRA_IF:-eth0}
      - OT_THREAD_IF=wpan0
      # UI web (port 8090, toutes interfaces : accessible depuis le LAN)
      - OT_WEB_LISTEN_ADDR=${WEB_LISTEN_ADDR}
      - OT_WEB_LISTEN_PORT=${WEB_LISTEN_PORT}
      # API REST (locale au Pi uniquement)
      - OT_REST_LISTEN_ADDR=${REST_LISTEN_ADDR}
      - OT_REST_LISTEN_PORT=${REST_LISTEN_PORT}
EOF
# IPv6 pour le daemon Docker si absent
if ! grep -q '"ipv6"' /etc/docker/daemon.json 2>/dev/null; then
    mkdir -p /etc/docker
    echo '{ "ipv6": true, "fixed-cidr-v6": "fd00:dead:beef::/64" }' \
        > /etc/docker/daemon.json
    systemctl restart docker
fi

# ------------------------- 6. Démarrage du conteneur ------------------------
log "6/7 Démarrage du conteneur OTBR"
# Sauvegarde du dataset actuel (si le conteneur tourne déjà) avant recréation
if docker exec otbr ot-ctl dataset active -x > "${INSTALL_DIR}/dataset-backup.txt" 2>/dev/null; then
    echo "    Dataset actuel sauvegardé dans ${INSTALL_DIR}/dataset-backup.txt"
else
    echo "    Aucun dataset existant à sauvegarder (première installation)"
fi
cd "$INSTALL_DIR"
docker compose up -d
echo "    Attente du démarrage de l'agent (20 s)..."
sleep 20
for i in $(seq 1 10); do
    STATE=$(docker exec otbr ot-ctl state 2>/dev/null || true)
    [[ "$STATE" == "disabled" || "$STATE" == "detached" ]] && break
    sleep 3
done
docker exec otbr ot-ctl version >/dev/null 2>&1 \
    || { docker logs otbr | tail -n 20; die "l'agent OTBR ne répond pas (RCP non détecté ?)"; }
echo "    RCP détecté, état : ${STATE:-disabled}"

# ------------------------- 7. Création du réseau Thread ---------------------
log "7/7 Formation du réseau Thread (uniquement si aucun n'existe déjà)"
# Un dataset déjà présent (RCP/agent démarrés précédemment) est conservé :
# une nouvelle formation créerait un NOUVEAU réseau (nouvelles clés, nouveau
# canal) et invaliderait les appareils Thread déjà appairés.
DATASET=$(docker exec otbr ot-ctl dataset active -x 2>/dev/null | grep -E '^[0-9a-f]{40,}$' || true)
if [[ -n "$DATASET" ]]; then
    echo "    Réseau Thread existant détecté : conservé."
    echo "    Dataset actif : ${DATASET}"
    STATE=$(docker exec otbr ot-ctl state 2>/dev/null || true)
    if [[ "$STATE" != "leader" ]]; then
        echo "    État '${STATE:-inconnu}' : relance de l'interface Thread..."
        docker exec otbr ot-ctl ifconfig up
        docker exec otbr ot-ctl thread start
    fi
else
    echo "    Aucun dataset actif : formation d'un nouveau réseau."
    docker exec -it otbr ot-ctl dataset init new
    docker exec -it otbr ot-ctl dataset commit active
    docker exec otbr    ot-ctl ifconfig up
    docker exec otbr    ot-ctl thread start
fi
echo "    Attente de l'élection du leader..."
for i in $(seq 1 20); do
    STATE=$(docker exec otbr ot-ctl state 2>/dev/null || true)
    [[ "$STATE" == "leader" ]] && break
    sleep 2
done

echo ""
echo "=============================================="
if [[ "$STATE" == "leader" ]]; then
    echo " OTBR opérationnel ! État : leader"
    echo "   - Interface web : http://$(hostname -I | awk '{print $1}'):${WEB_LISTEN_PORT}"
    echo "     (API REST locale : ${REST_LISTEN_ADDR}:${REST_LISTEN_PORT})"
    echo "   - CLI :           docker exec -it otbr ot-ctl"
    echo "   - Données :       ${DATA_DIR} (persistantes)"
    echo "   - Compose :       ${INSTALL_DIR}/docker-compose.yml"
    echo ""
    echo " Export du dataset (pour ajouter d'autres BR ou appareils) :"
    echo "   docker exec otbr ot-ctl dataset active -x"
else
    echo " État actuel : ${STATE:-inconnu}"
    echo " Diagnostics : docker logs otbr | tail -n 50"
fi
echo "=============================================="
