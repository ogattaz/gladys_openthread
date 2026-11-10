# Gladys OpenThread Border Router (OTBR)

> **Solution complète pour déployer un OpenThread Border Router sur Raspberry Pi 4 avec dongle nRF52840**

Ce dépôt contient une suite de scripts automatisés pour installer, valider et maintenir un **OpenThread Border Router (OTBR)** sur un Raspberry Pi 4, utilisant un dongle **nRF52840** (MakerDiary MDK USB Dongle).

L'OTBR permet de connecter un réseau **Thread** (protocole IoT sans fil pour la domotique) à votre réseau IP local, et d'intégrer des appareils Thread avec des plateformes comme **Gladys** ou **Home Assistant**.

---

## 📋 Table des matières

- [Architecture et prérequis](#-architecture-et-prérequis)
- [Scripts disponibles](#-scripts-disponibles)
- [Guide d'installation](#-guide-dinstallation)
- [Vérification et validation](#-vérification-et-validation)
- [Configuration avancée](#-configuration-avancée)
- [Dépannage](#-dépannage)
- [Ressources utiles](#-ressources-utiles)

---

## 🏗️ Architecture et prérequis

### Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     Raspberry Pi 4                            │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────┐   │
│  │   Docker OTBR   │    │  Docker Gladys  │    │  Autres  │   │
│  │  Container      │    │  Container      │    │Services  │   │
│  │                 │    │                 │    │          │   │
│  │  - otbr-agent   │    │  - Gladys       │    │          │   │
│  │  - ot-rcp       │    │  - Plugins      │    │          │   │
│  │  - ot-web       │    │                 │    │          │   │
│  └────────┬────────┘    └─────────────────┘    └──────────┘   │
│           │                                                   │
│           ├────────────── USB ───────────────┐                │
│           ▼                                  ▼                │
│  ┌─────────────────┐            ┌─────────────────┐           │
│  │  nRF52840 Dongle│            │   Appareils     │           │
│  │  (RCP Firmware) │            │   Thread        │           │
│  │                 │            │   (Matter, etc.)│           │
│  │  /dev/nrf52840  │◄───────────┤   Réseau Thread │           │
│  └─────────────────┘            └─────────────────┘           │
└───────────────────────────────────────────────────────────────┘
                           │
                           ▼
                Réseau Thread (802.15.4) + IPv6
```

### Prérequis matériels

| Composant | Modèle                                              | Rôle |
|-----------|-----------------------------------------------------|------|
| **Carte** | Raspberry Pi 4 (ou supérieur)                       | Hôte Docker |
| **Dongle** | [MakerDiary nRF52840 USB Dongle](./doc/nRF52840.md) | Radio Thread (RCP) | 
| **Port** | USB 2.0 (direct, sans hub)                          | Connexion du dongle |

### Prérequis logiciels

- **Système d'exploitation** : Raspberry Pi OS (64-bit recommandé)
- **Espace disque** : ≥ 2 Go libres
- **Mémoire RAM** : ≥ 1 Go (900 Mo minimum pour la compilation)
- **Docker** : Docker Engine + Docker Compose plugin
- **Dépendances** : Voir [validate-openthread-dependencies.sh](#validate-openthread-dependenciessh)

---

## 📜 Scripts disponibles

### 1. `validate-openthread-dependencies.sh`

**Objectif** : Vérifier que toutes les dépendances système et logicielles sont installées.

**Fonctionnalités** :
- ✅ Vérification des outils de base (git, curl, make, python3, pip3)
- ✅ Vérification des outils de compilation (gcc-arm-none-eabi, objcopy)
- ✅ Vérification des outils de flashage (adafruit-nrfutil)
- ✅ Vérification de Docker et docker-compose
- ✅ Vérification des conditions système (IPv6, /dev/net/tun, espace disque, RAM)
- ✅ Détection des modules Python (pyserial)

**Usage** :
```bash
chmod +x validate-openthread-dependencies.sh
./validate-openthread-dependencies.sh
```

**Sortie** : Liste des paquets manquants avec les commandes d'installation à exécuter.

---

### 2. `validate-nrf52840.sh`

**Objectif** : Valider le dongle nRF52840 avant installation.

**Fonctionnalités** :
- ✅ Vérification des privilèges root
- ✅ Détection de la plateforme (Raspberry Pi)
- ✅ Détection USB du dongle (VID/PID Nordic ou MakerDiary)
- ✅ Vérification du port série (/dev/ttyACM*)
- ✅ Vérification que le port est libre (non utilisé par un autre service)
- ✅ Vérification des outils de flashage (adafruit-nrfutil)
- ✅ Vérification de l'environnement Docker
- ✅ Test du mode DFU (optionnel avec `--dfu`)

**Usage** :
```bash
chmod +x validate-nrf52840.sh
sudo ./validate-nrf52840.sh
# Pour tester le mode DFU :
sudo ./validate-nrf52840.sh --dfu
```

**Note** : Le mode DFU nécessite de brancher le dongle **en maintenant le bouton enfoncé** jusqu'à ce que la LED devienne verte.

---

### 3. `install-otbr.sh`

**Objectif** : Installation complète de l'OTBR (compilation, flashage, configuration, démarrage).

**Étapes effectuées** :
1. **Vérification des dépendances** (sans installation)
2. **Compilation du firmware RCP** depuis [openthread/ot-nrf528xx](https://github.com/openthread/ot-nrf528xx)
3. **Flashage du dongle** en mode DFU (sauf si `--already-flashed`)
4. **Création de la règle udev** pour un port stable `/dev/nrf52840`
5. **Génération de docker-compose.yml** avec configuration personnalisable
6. **Démarrage du conteneur OTBR**
7. **Formation du réseau Thread** (ou conservation d'un réseau existant)

**Options** :
- `--already-flashed` : Saute l'étape de flashage (dongle déjà flashé)

**Variables d'environnement** :
- `NRFUTIL_BIN` : Chemin vers adafruit-nrfutil (ex: `~/gladys_openthread/venv/bin/adafruit-nrfutil`)
- `INFRA_IF` : Interface réseau (ex: `eth0`, auto-détectée par défaut)
- `OT_WEB_LISTEN_ADDR` : Adresse d'écoute du web (0.0.0.0 par défaut)
- `OT_WEB_LISTEN_PORT` : Port du web (8090 par défaut)
- `OT_REST_LISTEN_ADDR` : Adresse de l'API REST (127.0.0.1 par défaut)
- `OT_REST_LISTEN_PORT` : Port de l'API REST (8081 par défaut)

**Usage** :
```bash
chmod +x install-otbr.sh
sudo ./install-otbr.sh
# Si le dongle est déjà flashé :
sudo ./install-otbr.sh --already-flashed
```

---

### 4. `validate-otbr.sh`

**Objectif** : Valider le bon fonctionnement d'un OTBR déjà installé.

**Fonctionnalités** :
- ✅ Vérification du conteneur Docker (en cours d'exécution, network_mode host)
- ✅ Détection du dongle RCP (/dev/nrf52840)
- ✅ Vérification de l'état OpenThread (leader attendu)
- ✅ Lecture du nom du réseau, canal et PAN ID
- ✅ Vérification du dataset Thread
- ✅ Vérification de l'interface wpan0 et adresses IPv6
- ✅ Vérification des services Border Router (Backbone Router, NAT64, DNS/SRP)
- ✅ Vérification des écoutes web (port 8090) et REST (port 8081)
- ✅ Détection de l'annonce mDNS (_meshcop._udp) pour la découverte Matter
- ✅ **Test de persistance** (optionnel avec `--persistence`) : Vérifie que le dataset survit à un redémarrage du conteneur

**Usage** :
```bash
chmod +x validate-otbr.sh
./validate-otbr.sh
# Pour tester la persistance (redémarre le conteneur) :
./validate-otbr.sh --persistence
```

---

## 🚀 Guide d'installation

### Étape 1 : Préparation du système

1. Mettez à jour votre système :
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. Installez Git :
   ```bash
   sudo apt install git -y
   ```

3. Clonez ce dépôt :
   ```bash
   git clone https://github.com/gladysassistant/gladys_openthread.git
   cd gladys_openthread
   ```

4. Rendez les scripts exécutables :
   ```bash
   chmod +x *.sh
   ```

---

### Étape 2 : Vérification des dépendances

Exécutez le script de validation des dépendances :
```bash
./validate-openthread-dependencies.sh
```
voir le [résultat de la validation](./doc/validate-openthread-dependencies.md)

Si des paquets sont manquants, installez-les avec :
```bash
sudo apt update
sudo apt install <paquets-manquants>
```

**Installation de adafruit-nrfutil** (recommandé) :
```bash
# Créez un environnement virtuel Python
python3 -m venv ~/gladys_openthread/venv
source ~/gladys_openthread/venv/bin/activate
pip install adafruit-nrfutil
```

---

### Étape 3 : Validation du dongle

1. Branchez le dongle nRF52840 sur un port USB 2.0 (sans hub)
2. Exécutez :
   ```bash
   sudo ./validate-nrf52840.sh
   ```
   Voir [le résultat de la validation](./doc/validate-nrf52840.md)

**Si le dongle n'est pas détecté** :
- Essayez un autre port USB
- Vérifiez avec `lsusb` que le dongle apparaît
- Essayez de débrancher/rebrancher le dongle

---

### Étape 4 : Installation de l'OTBR

Exécutez le script d'installation :
```bash
sudo NRFUTIL_BIN=~/gladys_openthread/venv/bin/adafruit-nrfutil ./install-otbr.sh
```

**Processus d'installation** :

1. **Compilation** : Le firmware RCP est compilé (quelques minutes)
2. **Flashage** :
   - Le script vous demandera de brancher le dongle **en mode DFU**
   - **Maintenez le bouton enfoncé** pendant le branchement
   - La LED doit être **verte** (mode DFU)
   - Relâchez le bouton après le branchement
3. **Règle udev** : Un alias stable `/dev/nrf52840` est créé
4. **Configuration Docker** : Fichier `docker-compose.yml` généré
5. **Démarrage** : Le conteneur OTBR démarre
6. **Réseau Thread** : Un nouveau réseau Thread est créé (ou un existant est conservé)

**Durée estimée** : 10-20 minutes (selon la vitesse de compilation)

Voir le [résultat de l'installation](./doc/install-otbr.md)

---

### Étape 5 : Vérification finale

Une fois l'installation terminée, vérifiez que tout fonctionne :
   ```bash
   ./validate-otbr.sh
   ```
   Voir le [résultat de la validation](./doc/validate-otbr.md)

Pour un test complet (incluant la persistance) :
   ```bash
   ./validate-otbr.sh --persistence
   ```
   Voir le [résultat de la validation](./doc/validate-otbr-persistence.md)

---

## ✅ Vérification et validation

### Accès à l'interface web

L'interface web de l'OTBR est accessible à l'adresse :
```
http://<IP_DU_PI>:8090
```

Remplacez `<IP_DU_PI>` par l'adresse IP de votre Raspberry Pi.

### Commandes utiles

| Commande | Description |
|----------|-------------|
| `docker exec -it otbr ot-ctl state` | Vérifier l'état (leader/attached/detached) |
| `docker exec -it otbr ot-ctl channel` | Voir le canal Thread |
| `docker exec -it otbr ot-ctl panid` | Voir le PAN ID |
| `docker exec -it otbr ot-ctl dataset active -x` | Voir le dataset actuel |
| `docker exec -it otbr ot-ctl router table` | Voir les routeurs Thread |
| `docker exec -it otbr ot-ctl bbr state` | Vérifier le Backbone Router |
| `docker exec -it otbr ot-ctl srp server state` | Vérifier le serveur SRP |
| `docker exec -it otbr ot-ctl nat64prefixes` | Voir les préfixes NAT64 |

### Vérification manuelle

1. **Conteneur Docker** :
   ```bash
   docker ps
   docker logs otbr
   ```

2. **Périphérique RCP** :
   ```bash
   ls -l /dev/nrf52840
   ```

3. **Interface wpan0** :
   ```bash
   ip link show wpan0
   ip -6 addr show wpan0
   ```

4. **Annonce mDNS** (pour Matter/Thread) :
   ```bash
   sudo apt install avahi-utils
   avahi-browse -rt _meshcop._udp
   ```

---

## ⚙️ Configuration avancée

### Personnalisation de docker-compose.yml

Le fichier généré par `install-otbr.sh` est situé dans `/opt/otbr/docker-compose.yml`.

**Exemple de personnalisation** :
```yaml
services:
  otbr:
    image: openthread/border-router
    container_name: otbr
    network_mode: host
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/nrf52840
      - /dev/net/tun
    volumes:
      - /opt/otbr/data:/data
    environment:
      - OT_RCP_DEVICE=spinel+hdlc+uart:///dev/nrf52840?uart-baudrate=115200
      - OT_INFRA_IF=eth0
      - OT_THREAD_IF=wpan0
      - OT_WEB_LISTEN_ADDR=0.0.0.0
      - OT_WEB_LISTEN_PORT=8090
      - OT_REST_LISTEN_ADDR=127.0.0.1
      - OT_REST_LISTEN_PORT=8081
```

**Redémarrage manuel** :
```bash
cd /opt/otbr
docker compose down
docker compose up -d
```

### Configuration IPv6

L'OTBR a besoin d'IPv6 pour fonctionner correctement. Si IPv6 est désactivé :

1. Vérifiez la ligne de commande du noyau :
   ```bash
   cat /proc/cmdline
   ```
   Si vous voyez `ipv6.disable=1`, supprimez-le de `/boot/cmdline.txt` et redémarrez.

2. Activez IPv6 dans Docker :
   ```bash
   sudo mkdir -p /etc/docker
   sudo bash -c 'echo "{ \"ipv6\": true, \"fixed-cidr-v6\": \"fd00:dead:beef::/64\" }" > /etc/docker/daemon.json'
   sudo systemctl restart docker
   ```

### Rejoindre un réseau Thread existant

Pour rejoindre un réseau Thread existant (au lieu d'en créer un nouveau) :

1. Obtenez le dataset du réseau existant :
   ```bash
   # Depuis un autre OTBR déjà configuré
   docker exec otbr ot-ctl dataset active -x
   ```

2. Configurez le dataset sur votre nouvel OTBR :
   ```bash
   docker exec -it otbr ot-ctl dataset set <dataset-hexa>
   docker exec -it otbr ot-ctl dataset commit active
   docker exec -it otbr ot-ctl ifconfig up
   docker exec -it otbr ot-ctl thread start
   ```

---

## 🐛 Dépannage

### Problèmes courants

| Problème | Solution |
|----------|----------|
| **Le dongle n'est pas détecté** | Vérifiez le port USB, essayez `lsusb`, débranchez/rebranchez |
| **Erreur de flashage** | Vérifiez que le dongle est en mode DFU (LED verte, bouton maintenu) |
| **Conteneur ne démarre pas** | Vérifiez `docker logs otbr`, vérifiez que `/dev/nrf52840` existe |
| **Pas d'adresse IPv6 sur wpan0** | Vérifiez que IPv6 est activé, redémarrez le conteneur |
| **État non leader** | Attendez quelques minutes, vérifiez `docker exec otbr ot-ctl state` |
| **Ports web/REST inaccessibles** | Vérifiez `ss -tln`, vérifiez les variables `OT_WEB_LISTEN_ADDR` |

### Logs de diagnostic

1. **Logs du conteneur OTBR** :
   ```bash
   docker logs otbr
   docker logs otbr --tail 100
   ```

2. **Logs du daemon Docker** :
   ```bash
   journalctl -u docker --no-pager -n 50
   ```

3. **Logs du noyau (pour le dongle)** :
   ```bash
   dmesg | tail -50
   dmesg | grep -i usb
   dmesg | grep -i cdc_acm
   ```

### Réinitialisation complète

Pour tout réinitialiser :

1. Arrêtez le conteneur :
   ```bash
   cd /opt/otbr
   docker compose down
   ```

2. Supprimez les données (si nécessaire) :
   ```bash
   sudo rm -rf /opt/otbr/data
   ```

3. Supprimez la règle udev :
   ```bash
   sudo rm /etc/udev/rules.d/99-nrf52840-otbr.rules
   sudo udevadm control --reload-rules
   ```

4. Reflashez le dongle :
   ```bash
   sudo ./install-otbr.sh
   ```

---

## 📚 Ressources utiles

### Documentation officielle

- [OpenThread Border Router Guide](https://openthread.io/guides/border-router)
- [OpenThread GitHub](https://github.com/openthread)
- [ot-nrf528xx Repository](https://github.com/openthread/ot-nrf528xx)
- [Docker OTBR Image](https://hub.docker.com/r/openthread/border-router)

### Outils complémentaires

- **nrfutil** : [Nordic Semiconductor nrfutil](https://github.com/NordicSemiconductor/pc-nrfutil)
- **adafruit-nrfutil** : [Adafruit fork](https://github.com/adafruit/Adafruit_nRF52_nrfutil) (recommandé)
- **avahi-utils** : Pour vérifier l'annonce mDNS (`sudo apt install avahi-utils`)

### Intégration avec Gladys

Pour intégrer l'OTBR avec Gladys :

1. Configurez le plugin Thread dans Gladys
2. Utilisez l'API REST de l'OTBR (port 8081) pour la communication
3. Le réseau Thread apparaîtra dans Gladys comme un nouveau réseau IoT

---

## 📝 Notes techniques

### Compilation du firmware

Le script `install-otbr.sh` compile le firmware avec les options suivantes :
- `OT_BOOTLOADER=USB` : Bootloader USB
- `OT_JOINER=ON` : Support du joiner (pour rejoindre un réseau existant)
- `OT_RCP_RESTORATION_MAX_COUNT=2` : **Critique** - Permet au RCP de conserver le dataset après redémarrage
- `OT_LOG_LEVEL=WARN` : Niveau de log réduit

**Important** : Sans `OT_RCP_RESTORATION_MAX_COUNT=2`, le dataset Thread est perdu à chaque redémarrage du conteneur, créant un nouveau réseau Thread.

### Mode DFU

Le dongle nRF52840 peut être flashé de deux manières :

1. **Mode UF2** (recommandé) : Le dongle apparaît comme un lecteur USB
   - Maintenez le bouton pendant le branchement
   - LED verte = mode DFU
   - Copiez le fichier `.uf2` sur le lecteur

2. **Mode DFU série** : Utilisation de `nrfutil` via le port série
   - Moins fiable sur certains systèmes
   - Nécessite `adafruit-nrfutil` pour éviter les erreurs

### Persistance des données

Les données sont persistées dans `/opt/otbr/data` :
- Configuration du réseau Thread
- Dataset actif
- Clés de chiffrement

**Attention** : La suppression de ce dossier réinitialisera complètement le réseau Thread.

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Veuillez ouvrir une **Issue** ou soumettre une **Pull Request** sur le dépôt.

### Structure du projet

```txt
gladys_openthread/
├── doc
├── README_fr.md                         # Ce fichier
├── install-otbr.sh                      # Installation complète
├── validate-openthread-dependencies.sh  # Vérification des dépendances
├── validate-nrf52840.sh                 # Validation du dongle
└── validate-otbr.sh                     # Validation de l'OTBR
```

---

## 📜 Historique des versions

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2024-11-10 | Version initiale avec support complet nRF52840 + Docker |

---

## 🔒 Licence

Ce projet est sous licence **MIT**. 

---

## 🙏 Remerciements

- [OpenThread](https://openthread.io/) pour le projet OpenThread
- [Gladys](https://gladysassistant.com/) pour l'intégration domotique
- [MakerDiary](https://makerdiary.com/) pour le dongle nRF52840
- La communauté OpenThread pour son support
