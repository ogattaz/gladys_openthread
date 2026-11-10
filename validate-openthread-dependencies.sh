#!/usr/bin/env bash
# =============================================================================
# validate-openthread-dependencies.sh
# Vérifie que toutes les dépendances requises par install-otbr.sh sont en place.
# Ne modifie RIEN : en cas de manquant, il liste les commandes à lancer
# (c'est vous qui les exécutez), puis termine en erreur.
#
# Usage :
#   chmod +x validate-openthread-dependencies.sh
#   ./validate-openthread-dependencies.sh        (pas besoin de sudo)
# =============================================================================
set -u

MISSING_APT=()   # paquets apt manquants
MISSING_PIP=()   # paquets pip manquants
OTHER_ERRORS=()  # problèmes non liés à un paquet
PASS=0

ok()  { PASS=$((PASS+1)); echo "  [OK]    $*"; }
miss(){ echo "  [MANQUE] $*"; }

# --- Testeurs -----------------------------------------------------------------
# has_cmd <binaire> <paquet apt> : si le binaire n'existe pas, note le paquet
has_cmd() {
    if command -v "$1" >/dev/null 2>&1; then ok "$1 ($2)"; else miss "$1 -> paquet : $2"; MISSING_APT+=("$2"); fi
}

echo "=============================================="
echo " Vérification des dépendances OTBR - $(date '+%Y-%m-%d %H:%M')"
echo "=============================================="

# --- 1. Outils de base et build du firmware -----------------------------------
echo -e "\n[1/4] Outils système et compilation RCP"
has_cmd git                 git
has_cmd curl                curl
has_cmd make                build-essential
has_cmd python3             python3
has_cmd pip3                python3-pip
has_cmd arm-none-eabi-gcc       gcc-arm-none-eabi
has_cmd arm-none-eabi-objcopy   gcc-arm-none-eabi
has_cmd udevadm             udev
has_cmd fuser               psmisc

# --- 2. Outils de flashage -----------------------------------------------------
echo -e "\n[2/4] Outils de flashage"
# Résolution : adafruit-nrfutil (Python 3, recommandé) ou nrfutil (Python 2 !)
# Sur Debian 12, nrfutil 5.x du pip ne fonctionne pas en Python 3 (bug iteritems)
NRFUTIL_BIN="${NRFUTIL_BIN:-$(command -v adafruit-nrfutil || command -v nrfutil || true)}"
if [[ -z "$NRFUTIL_BIN" ]]; then
    # Home de l'utilisateur appelant (sudo ou pas)
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
    warn "nrfutil trouvé ($NRFUTIL_BIN) mais la version pip 5.x est incompatible Python 3 (bug iteritems)"
    echo "         Préférez adafruit-nrfutil :"
    echo "           ~/gladys_openthread/venv/bin/pip install adafruit-nrfutil"
else
    miss "outil de flashage introuvable"
    echo "         Installez adafruit-nrfutil dans le venv :"
    echo "           ~/gladys_openthread/venv/bin/pip install adafruit-nrfutil"
    MISSING_PIP+=("adafruit-nrfutil (dans un venv)")
fi
if python3 -c "import serial" 2>/dev/null; then
    ok "module python pyserial (paquet : python3-serial)"
else
    miss "pyserial -> paquet : python3-serial"
    MISSING_APT+=("python3-serial")
fi

# --- 3. Docker -----------------------------------------------------------------
echo -e "\n[3/4] Docker"
if command -v docker >/dev/null 2>&1; then
    ok "docker installé ($(docker --version 2>/dev/null || echo 'version inconnue'))"
    if docker compose version >/dev/null 2>&1; then
        ok "plugin docker compose"
    else
        miss "plugin docker compose -> paquet : docker-compose-v2"
        MISSING_APT+=("docker-compose-v2")
    fi
    if [[ $EUID -eq 0 ]] || groups | grep -qw docker; then
        ok "accès au daemon docker"
    else
        miss "utilisateur hors groupe docker (lancez le script d'installation avec sudo)"
    fi
else
    miss "docker -> paquet : docker.io"
    MISSING_APT+=("docker.io")
    miss "plugin docker compose -> paquet : docker-compose-v2"
    MISSING_APT+=("docker-compose-v2")
fi

# --- 4. Conditions système requises par le conteneur OTBR ----------------------
echo -e "\n[4/4] Conditions système"
[[ $EUID -eq 0 ]] || groups | grep -qw sudo \
    && ok "droits sudo disponibles" \
    || OTHER_ERRORS+=("pas de droits sudo : impossible d'exécuter install-otbr.sh")
[[ -e /dev/net/tun ]] && ok "/dev/net/tun disponible" \
                    || OTHER_ERRORS+=("/dev/net/tun absent (nécessaire au conteneur OTBR)")
grep -q "ipv6.disable=1" /proc/cmdline 2>/dev/null \
    && OTHER_ERRORS+=("IPv6 désactivé au boot : supprimez ipv6.disable=1 de /boot/cmdline.txt") \
    || ok "IPv6 non désactivé au boot"
FREE_MB=$(df -Pm / | awk 'NR==2 {print $4}')
[[ "$FREE_MB" -ge 2048 ]] && ok "espace disque : ${FREE_MB} Mo libres" \
                          || OTHER_ERRORS+=("espace disque insuffisant : ${FREE_MB} Mo (< 2 Go)")
MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
[[ "$MEM_MB" -ge 900 ]] && ok "RAM : ${MEM_MB} Mo" \
                       || OTHER_ERRORS+=("RAM insuffisante : ${MEM_MB} Mo (< 900 Mo, compilation du firmware risquée)")

# --- Bilan et commandes à lancer ------------------------------------------------
echo -e "\n=============================================="
echo " Bilan : $PASS OK, ${#MISSING_APT[@]} paquet(s) apt manquant(s), ${#MISSING_PIP[@]} paquet(s) pip manquant(s), ${#OTHER_ERRORS[@]} autre(s) problème(s)"
echo "=============================================="

if [[ ${#MISSING_APT[@]} -gt 0 ]]; then
    # Déduplication en conservant l'ordre
    UNIQUE_APT=()
    for p in "${MISSING_APT[@]}"; do
        [[ " ${UNIQUE_APT[*]:-} " != *" $p "* ]] && UNIQUE_APT+=("$p")
    done
    echo -e "\nPaquets apt manquants, à lancer :"
    echo "  sudo apt update"
    echo "  sudo apt install ${UNIQUE_APT[*]}"
fi
if [[ ${#MISSING_PIP[@]} -gt 0 ]]; then
    UNIQUE_PIP=()
    for p in "${MISSING_PIP[@]}"; do
        [[ " ${UNIQUE_PIP[*]:-} " != *" $p "* ]] && UNIQUE_PIP+=("$p")
    done
    echo -e "\nPaquets pip manquants, à lancer :"
    echo "  pip3 install ${UNIQUE_PIP[*]}"
fi
if [[ ${#OTHER_ERRORS[@]} -gt 0 ]]; then
    echo -e "\nAutres problèmes à corriger :"
    for e in "${OTHER_ERRORS[@]}"; do echo "  - $e"; done
fi

if [[ ${#MISSING_APT[@]} -eq 0 && ${#MISSING_PIP[@]} -eq 0 && ${#OTHER_ERRORS[@]} -eq 0 ]]; then
    echo -e "\n>>> Toutes les dépendances sont en place : vous pouvez lancer validate-nrf52840.sh puis install-otbr.sh <<<"
    exit 0
fi
echo -e "\n>>> Corrigez les points ci-dessus puis relancez ce script <<<"
exit 1
