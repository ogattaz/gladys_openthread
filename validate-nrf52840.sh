#!/usr/bin/env bash
# =============================================================================
# validate-nrf52840.sh
# Validation pré-flashage du dongle nRF52840 (MakerDiary MDK USB Dongle)
# sur Raspberry Pi 4. À lancer AVANT install-otbr.sh.
#
# Usage :
#   chmod +x validate-nrf52840.sh
#   sudo ./validate-nrf52840.sh
#   sudo ./validate-nrf52840.sh --dfu   (vérifie aussi le mode DFU du dongle)
# =============================================================================
set -u

CHECK_DFU=0
[[ "${1:-}" == "--dfu" ]] && CHECK_DFU=1

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); echo "  [OK]    $*"; }
bad()  { FAIL=$((FAIL+1)); echo "  [ERREUR] $*"; }
warn() { WARN=$((WARN+1)); echo "  [ATTENTION] $*"; }

# Compteur de ports série détectés
FOUND_PORT=""

echo "=============================================="
echo " Validation dongle nRF52840 - $(date '+%Y-%m-%d %H:%M')"
echo "=============================================="

# --- 1. Privilèges root (accès /dev, udev, flashage) -------------------------
echo -e "\n[1/8] Privilèges"
if [[ $EUID -eq 0 ]]; then ok "script exécuté en root"; else bad "lancez avec sudo"; fi

# --- 2. Matériel : Raspberry Pi ----------------------------------------------
echo -e "\n[2/8] Plateforme"
if [[ -f /proc/device-tree/model ]] && grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
    ok "machine : $(tr -d '\0' < /proc/device-tree/model)"
else
    warn "ne semble pas être un Raspberry Pi (à vérifier)"
fi
ARCH=$(uname -m)
[[ "$ARCH" == "aarch64" || "$ARCH" == "armv7l" ]] && ok "architecture $ARCH" || warn "architecture inattendue : $ARCH"

# --- 3. Dongle présent sur le bus USB -----------------------------------------
echo -e "\n[3/8] Détection USB du dongle"
# nRF52840 : Nordic VID 1915, MakerDiary VID 2886, ou cdc_acm générique
USB_MATCH=$(lsusb 2>/dev/null | grep -iE "1915|nordic|2886|makerdiary|openthread" || true)
if [[ -n "$USB_MATCH" ]]; then
    ok "périphérique USB détecté : $(echo "$USB_MATCH" | head -n1)"
else
    # Le dongle peut être listé sans nom lisible
    warn "aucun VID Nordic/MakerDiary vu dans lsusb :"
    lsusb 2>/dev/null | sed 's/^/         /'
    warn "vérifiez que le dongle est bien inséré (port USB 2.0 recommandé, sans hub USB si possible)"
fi

# --- 4. Port série /dev/ttyACM* ----------------------------------------------
echo -e "\n[4/8] Port série"
for p in /dev/ttyACM*; do
    [[ -e "$p" ]] || continue
    FOUND_PORT="$p"
    ok "port série détecté : $p"
    # Le dongle doit être monté par le driver cdc_acm (pas cp210x = autre dongle)
    if dmesg 2>/dev/null | grep -i "cdc_acm" | grep -q "$(basename "$p")"; then
        ok "driver cdc_acm bien chargé pour $p (dongle nRF52840, USB CDC)"
    else
        warn "$p n'est pas monté par cdc_acm : est-ce vraiment le bon dongle ?"
    fi
done
if [[ -z "$FOUND_PORT" ]]; then
    bad "aucun /dev/ttyACM* trouvé. Débranchez/rebranchez le dongle et relancez."
fi

# --- 5. Port non occupé par un autre process ---------------------------------
echo -e "\n[5/8] Port libre"
if [[ -n "$FOUND_PORT" ]]; then
    if command -v fuser >/dev/null && fuser "$FOUND_PORT" >/dev/null 2>&1; then
        bad "$FOUND_PORT est déjà utilisé (fuser) : arrêtez zigbee2mqtt, otbr ou tout autre service qui occupe le port"
    else
        ok "$FOUND_PORT est libre"
    fi
fi

# --- 6. Outils de flashage disponibles ----------------------------------------
echo -e "\n[6/8] Outils de flashage"
# adafruit-nrfutil (Python 3) recommandé ; nrfutil 5.x pip casse en Python 3
NRFUTIL_BIN="${NRFUTIL_BIN:-$(command -v adafruit-nrfutil || command -v nrfutil || true)}"
if [[ -z "$NRFUTIL_BIN" ]]; then
    REAL_HOME="$HOME"
    [[ -n "${SUDO_USER:-}" ]] && REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
    for c in "$REAL_HOME/gladys_openthread/venv/bin/adafruit-nrfutil" \
             "$REAL_HOME/gladys_openthread/venv/bin/nrfutil" \
             /home/*/gladys_openthread/venv/bin/adafruit-nrfutil; do
        if [[ -x "$c" ]]; then NRFUTIL_BIN="$c"; break; fi
    done
fi
if [[ -n "$NRFUTIL_BIN" ]] && basename "$NRFUTIL_BIN" | grep -q adafruit; then
    ok "adafruit-nrfutil trouvé : $NRFUTIL_BIN"
elif [[ -n "$NRFUTIL_BIN" ]]; then
    warn "nrfutil trouvé ($NRFUTIL_BIN) mais incompatible Python 3 (bug iteritems)"
    warn "installez plutôt : ~/gladys_openthread/venv/bin/pip install adafruit-nrfutil"
else
    warn "outil de flashage introuvable (adafruit-nrfutil conseillé)"
    warn "installez-le via validate-openthread-dependencies.sh avant install-otbr.sh"
fi
# Le paquet DFU sera fourni par le script d'installation
[[ -f ot-rcp.zip ]] && ok "paquet firmware ot-rcp.zip présent dans le dossier courant" \
                    || warn "ot-rcp.zip absent : il sera construit par install-otbr.sh"

# --- 7. Docker et système -----------------------------------------------------
echo -e "\n[7/8] Environnement hôte"
command -v docker >/dev/null 2>&1 && ok "Docker installé ($(docker --version))" \
                                    || warn "Docker absent (installez-le via validate-openthread-dependencies.sh)"
command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && ok "plugin docker compose OK" \
                                    || warn "plugin docker compose absent ou non testé"
FREE_MB=$(df -Pm / | awk 'NR==2 {print $4}')
[[ "$FREE_MB" -ge 2048 ]] && ok "espace disque : ${FREE_MB} Mo libres" \
                           || warn "espace disque faible : ${FREE_MB} Mo (< 2 Go)"
MEM_OK=$(free -m | awk '/^Mem:/ {print ($2 >= 900) ? 1 : 0}')
[[ "$MEM_OK" == "1" ]] && ok "RAM suffisante" || warn "RAM < 900 Mo, compilation du firmware risquée"
grep -q ipv6.disable=1 /proc/cmdline 2>/dev/null && bad "IPv6 désactivé au boot (/proc/cmdline) : requis pour Thread" \
                                                       || ok "IPv6 non désactivé au boot"
[[ -e /dev/net/tun ]] && ok "/dev/net/tun disponible" || warn "/dev/net/tun absent"

# --- 8. Mode DFU (option --dfu) ----------------------------------------------
if [[ $CHECK_DFU -eq 1 ]]; then
    echo -e "\n[8/8] Mode DFU du dongle"
    echo "  >>> Branchez le dongle en MAINTENANT LE BOUTON APPUYÉ, la LED doit être VERTE <<<"
    read -rp "  Appuyez sur Entrée quand c'est fait... " _
    # En mode DFU, le bootloader expose un port série USB (pas d'application)
    if dmesg 2>/dev/null | tail -n 20 | grep -qiE "dfu|bootloader|cdc_acm"; then
        ok "le bootloader DFU a bien été détecté dans les logs noyau : flashage possible"
    else
        bad "aucun périphérique DFU détecté : réessayez (bouton bien maintenu pendant tout le branchement)"
    fi
else
    echo -e "\n[8/8] Mode DFU : non testé (relancez avec --dfu pour le vérifier)"
fi

# --- Bilan --------------------------------------------------------------------
echo -e "\n=============================================="
echo " Bilan : $PASS OK, $WARN avertissement(s), $FAIL erreur(s)"
echo "=============================================="
if [[ $FAIL -gt 0 ]]; then
    echo " >>> Corrigez les erreurs avant de lancer install-otbr.sh <<<"
    exit 1
fi
echo " >>> Dongle prêt : vous pouvez lancer install-otbr.sh <<<"
exit 0
