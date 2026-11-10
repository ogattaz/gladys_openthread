# install-otbr.sh

```bash
(venv) pi@rieux:~/gladys_openthread$ sudo ./install-otbr.sh 

:: 1/7 Vérification des dépendances (aucune installation ici)
Synchronizing state of docker.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install enable docker

:: 2/7 Compilation du firmware OpenThread RCP (quelques minutes)
++ dirname ./script/bootstrap
+ ./script/../openthread/script/bootstrap
+++ dirname ./script/../openthread/script/bootstrap
++ cd ./script/../openthread/script/..
++ pwd
+ repo_dir=/opt/otbr/firmware/ot-nrf528xx/openthread
+ readonly repo_dir
+ INSTALL_FORMAT_TOOLS=0
+ LLVM_MAJOR_VERSION=19
+ main
+ git submodule update --init --recursive
+ install_packages
+ PM=source
+ command -v apt-get
/usr/bin/apt-get
+ PM=apt
+ install_packages_apt
+ echo 'Installing toolchain dependencies...'
Installing toolchain dependencies...
+ sudo apt-get update
Atteint :1 http://deb.debian.org/debian bookworm InRelease
Atteint :2 http://deb.debian.org/debian-security bookworm-security InRelease                                                             
Réception de :3 http://deb.debian.org/debian bookworm-updates InRelease [55,4 kB]                                                        
Réception de :4 http://archive.raspberrypi.com/debian bookworm InRelease [54,9 kB]                                                              
Réception de :5 http://deb.debian.org/debian bookworm-backports InRelease [59,4 kB]                                                             
Atteint :6 https://download.docker.com/linux/debian bookworm InRelease                                                                            
Réception de :7 http://archive.raspberrypi.com/debian bookworm/main arm64 Packages [587 kB]                   
Réception de :8 http://archive.raspberrypi.com/debian bookworm/main armhf Packages [590 kB]
1 347 ko réceptionnés en 2s (780 ko/s)                      
Lecture des listes de paquets... Fait
+ sudo DEBIAN_FRONTEND=noninteractive apt-get --no-install-recommends install -y g++ lsb-release cmake ninja-build shellcheck expect libgtest-dev libgmock-dev python3-pip python3-venv
Lecture des listes de paquets... Fait
Construction de l'arbre des dépendances... Fait
Lecture des informations d'état... Fait      
g++ est déjà la version la plus récente (4:12.2.0-3).
lsb-release est déjà la version la plus récente (12.0-1).
cmake est déjà la version la plus récente (3.25.1-1).
ninja-build est déjà la version la plus récente (1.11.1-2~deb12u1).
shellcheck est déjà la version la plus récente (0.9.0-1).
expect est déjà la version la plus récente (5.45.4-2+b1).
libgtest-dev est déjà la version la plus récente (1.12.1-0.2).
libgmock-dev est déjà la version la plus récente (1.12.1-0.2).
python3-pip est déjà la version la plus récente (23.0.1+dfsg-1+rpt1).
python3-venv est déjà la version la plus récente (3.11.2-1+b1).
Les paquets suivants ont été installés automatiquement et ne sont plus nécessaires :
  avahi-utils chromium-browser chromium-browser-l10n chromium-codecs-ffmpeg-extra chromium-sandbox edid-decode gir1.2-handy-1 gir1.2-packagekitglib-1.0 gir1.2-polkit-1.0 liba52-0.7.4 libbasicusageenvironment1 libcamera0.0.3 libcamera0.1 libcamera0.2
  libgroupsock8 liblivemedia77 libmpeg2-4 libqt5qmlworkerscript5 libqt5quickcontrols2-5 libqt5quicktemplates2-5 libslirp0 libssl1.1 libwpe-1.0-1 libwpebackend-fdo-1.0-1 linux-headers-6.1.0-rpi7-common-rpi linux-headers-6.12.109+rpt-common-rpi
  linux-headers-6.12.109+rpt-rpi-2712 linux-headers-6.12.109+rpt-rpi-v8 linux-headers-6.6.20+rpt-common-rpi linux-headers-6.6.31+rpt-common-rpi linux-headers-6.6.31+rpt-rpi-2712 linux-headers-6.6.31+rpt-rpi-v8 linux-image-6.12.109+rpt-rpi-2712
  linux-image-6.12.109+rpt-rpi-v8 linux-image-6.6.31+rpt-rpi-2712 linux-image-6.6.31+rpt-rpi-v8 linux-kbuild-6.1 linux-kbuild-6.12.109+rpt linux-kbuild-6.6.20+rpt linux-kbuild-6.6.31+rpt lxplug-network python3-gi-cairo python3-v4l2
  qml-module-qtgraphicaleffects qml-module-qtquick-controls2 qml-module-qtquick-layouts qml-module-qtquick-templates2 qml-module-qtquick-window2 qml-module-qtquick2 slirp4netns
Veuillez utiliser « sudo apt autoremove » pour les supprimer.
0 mis à jour, 0 nouvellement installés, 0 à enlever et 2 non mis à jour.
+ echo 'Installing GNU Arm Embedded Toolchain...'
Installing GNU Arm Embedded Toolchain...
++ lsb_release -is
+ PLATFORM=Debian
++ arch
+ ARCH=aarch64
+ '[' Debian = Raspbian ']'
+ '[' Debian = Ubuntu ']'
+ '[' Debian '!=' Raspbian ']'
+ '[' 0 = 1 ']'
+ echo 'bootstrap completed successfully.'
bootstrap completed successfully.
+ OT_CMAKE_NINJA_TARGET=
+ NRF_PLATFORMS=(nrf52811 nrf52833 nrf52840)
+ readonly NRF_PLATFORMS
+ NRF_BUILD_TYPES=(UART_trans USB_trans SPI_trans_NCP RTT_trans soft_crypto soft_crypto_threading)
+ readonly NRF_BUILD_TYPES
++ pwd
+ OT_SRCDIR=/opt/otbr/firmware/ot-nrf528xx
+ readonly OT_SRCDIR
+ OT_OPTIONS=("-DCMAKE_BUILD_TYPE=MinSizeRel" "-DBUILD_TESTING=OFF" "-DOT_PLATFORM=external" "-DOT_SLAAC=ON")
+ readonly OT_OPTIONS
+ main nrf52840 USB_trans -DOT_BOOTLOADER=USB -DOT_JOINER=ON -DOT_RCP_RESTORATION_MAX_COUNT=2 -DOT_LOG_LEVEL=WARN
+ [[ 6 == 0 ]]
+ local platform=nrf52840
+ echo nrf52811 nrf52833 nrf52840
+ grep -wq nrf52840
+ [[ 6 == 1 ]]
+ local nrf_build_type=USB_trans
+ echo UART_trans USB_trans SPI_trans_NCP RTT_trans soft_crypto soft_crypto_threading
+ grep -wq USB_trans
+ shift
+ shift
+ local_options=()
+ local local_options
+ options=('-DCMAKE_BUILD_TYPE=MinSizeRel' '-DBUILD_TESTING=OFF' '-DOT_PLATFORM=external' '-DOT_SLAAC=ON')
+ local options
+ case "${platform}" in
+ local_options+=("-DCMAKE_TOOLCHAIN_FILE=src/${platform}/arm-none-eabi.cmake")
+ case "${nrf_build_type}" in
+ options+=("${local_options[@]}" "-DOT_USB=ON" "-DOT_EXTERNAL_MBEDTLS=nordicsemi-mbedtls")
+ options+=("$@")
+ build -DNRF_PLATFORM=nrf52840 -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -DOT_PLATFORM=external -DOT_SLAAC=ON -DCMAKE_TOOLCHAIN_FILE=src/nrf52840/arm-none-eabi.cmake -DOT_USB=ON -DOT_EXTERNAL_MBEDTLS=nordicsemi-mbedtls -DOT_BOOTLOADER=USB -DOT_JOINER=ON -DOT_RCP_RESTORATION_MAX_COUNT=2 -DOT_LOG_LEVEL=WARN
+ local builddir=build
+ mkdir -p build
+ cd build
+ cmake -GNinja -DOT_COMPILE_WARNING_AS_ERROR=ON -DNRF_PLATFORM=nrf52840 -DCMAKE_BUILD_TYPE=MinSizeRel -DBUILD_TESTING=OFF -DOT_PLATFORM=external -DOT_SLAAC=ON -DCMAKE_TOOLCHAIN_FILE=src/nrf52840/arm-none-eabi.cmake -DOT_USB=ON -DOT_EXTERNAL_MBEDTLS=nordicsemi-mbedtls -DOT_BOOTLOADER=USB -DOT_JOINER=ON -DOT_RCP_RESTORATION_MAX_COUNT=2 -DOT_LOG_LEVEL=WARN /opt/otbr/firmware/ot-nrf528xx
-- OpenThread Source Directory: /opt/otbr/firmware/ot-nrf528xx/openthread
-- OT_APP_CLI=ON
-- OT_APP_NCP=ON
-- OT_APP_RCP=ON
-- OT_FTD=ON
-- OT_MTD=ON
-- OT_RCP=ON
-- - - - - - - - - - - - - - - - - 
-- OpenThread ON/OFF/Unspecified Configs
-- OT_15_4=""
-- OT_ANDROID_NDK=""
-- OT_ANYCAST_LOCATOR=""
-- OT_ASSERT=""
-- OT_BACKBONE_ROUTER=""
-- OT_BACKBONE_ROUTER_MULTICAST_ROUTING=""
-- OT_BLE_TCAT=""
-- OT_BORDER_ADMITTER=""
-- OT_BORDER_AGENT=""
-- OT_BORDER_AGENT_EPSKC=""
-- OT_BORDER_AGENT_ID=""
-- OT_BORDER_AGENT_MESHCOP_SERVICE=""
-- OT_BORDER_AGENT_TRACKER=""
-- OT_BORDER_AGENT_TXT_DATA_PARSER=""
-- OT_BORDER_ROUTER=""
-- OT_BORDER_ROUTING=""
-- OT_BORDER_ROUTING_DHCP6_PD=""
-- OT_BORDER_ROUTING_DHCP6_PD_CLIENT=""
-- OT_BORDER_ROUTING_COUNTERS=""
-- OT_BORDER_ROUTING_MULTI_AIL_DETECTION=""
-- OT_CHANNEL_MANAGER=""
-- OT_CHANNEL_MANAGER_CSL=""
-- OT_CHANNEL_MONITOR=""
-- OT_CHANNEL_MONITOR_AUTO_START=""
-- OT_COAP=""
-- OT_COAP_BLOCK=""
-- OT_COAP_OBSERVE=""
-- OT_COAPS=""
-- OT_COMMISSIONER=""
-- OT_CSL_AUTO_SYNC=""
-- OT_CSL_DEBUG=""
-- OT_CSL_RECEIVER=""
-- OT_CSL_RECEIVER_LOCAL_TIME_SYNC=""
-- OT_DATASET_UPDATER=""
-- OT_DEVICE_PROP_LEADER_WEIGHT=""
-- OT_DHCP6_CLIENT=""
-- OT_DHCP6_SERVER=""
-- OT_DIAGNOSTIC=""
-- OT_DNS_CLIENT=""
-- OT_DNS_CLIENT_BIND_UDP_THREAD_NETIF=""
-- OT_DNS_CLIENT_OVER_TCP=""
-- OT_DNS_DSO=""
-- OT_DNS_UPSTREAM_QUERY=""
-- OT_DNSSD_DISCOVERY_PROXY=""
-- OT_DNSSD_SERVER=""
-- OT_DYNAMIC_STORE_FRAME_AHEAD_COUNTER=""
-- OT_ECDSA=""
-- OT_EXTERNAL_HEAP=""
-- OT_FIREWALL=""
-- OT_HISTORY_TRACKER=""
-- OT_IP6_FRAGM=""
-- OT_IP6_INIT_ADDR_POOL=""
-- OT_JAM_DETECTION=""
-- OT_JOINER=ON --> OPENTHREAD_CONFIG_JOINER_ENABLE=1
-- OT_LINK_METRICS_INITIATOR=""
-- OT_LINK_METRICS_MANAGER=""
-- OT_LINK_METRICS_SUBJECT=""
-- OT_LINK_RAW=""
-- OT_LOG_LEVEL_DYNAMIC=""
-- OT_MAC_ALLOW_INCOMPLETE_RX_ENH_ACK=""
-- OT_MAC_FILTER=""
-- OT_MDNS=""
-- OT_MDNS_VERBOSE=""
-- OT_MDNS_VERBOSE_STATE=""
-- OT_MESH_DIAG=""
-- OT_MESSAGE_USE_HEAP=""
-- OT_MLE_LONG_ROUTES=""
-- OT_MLR=""
-- OT_MULTIPAN_RCP=""
-- OT_MULTIPLE_INSTANCE=""
-- OT_NAT64_BORDER_ROUTING=""
-- OT_NAT64_TRANSLATOR=""
-- OT_NEIGHBOR_DISCOVERY_AGENT=""
-- OT_NETDATA_PUBLISHER=""
-- OT_NETDIAG_CLIENT=""
-- OT_NETDIAG_VENDOR_INFO=""
-- OT_OPERATIONAL_DATASET_AUTO_INIT=""
-- OT_OTNS=""
-- OT_PING_SENDER=ON --> OPENTHREAD_CONFIG_PING_SENDER_ENABLE=1
-- OT_PLATFORM_BOOTLOADER_MODE=""
-- OT_PLATFORM_DNSSD=""
-- OT_PLATFORM_KEY_REF=""
-- OT_PLATFORM_LOG_CRASH_DUMP=""
-- OT_PLATFORM_NETIF=""
-- OT_PLATFORM_POWER_CALIBRATION=""
-- OT_PLATFORM_TCP=""
-- OT_PLATFORM_UDP=""
-- OT_REFERENCE_DEVICE=""
-- OT_SEEKER=""
-- OT_SERVICE=""
-- OT_SETTINGS_RAM=""
-- OT_SLAAC=ON --> OPENTHREAD_CONFIG_IP6_SLAAC_ENABLE=1
-- OT_SNTP_CLIENT=""
-- OT_SRP_ADV_PROXY=""
-- OT_SRP_CLIENT=""
-- OT_SRP_SERVER=""
-- OT_SRP_SERVER_FAST_START_MODE=""
-- OT_STEERING_DATA=""
-- OT_TCP=""
-- OT_TIME_SYNC=""
-- OT_TREL=""
-- OT_TREL_MANAGE_DNSSD=""
-- OT_TX_BEACON_PAYLOAD=""
-- OT_TX_QUEUE_STATS=""
-- OT_UDP_FORWARD=""
-- OT_UPTIME=""
-- OT_VERHOEFF_CHECKSUM=""
-- OT_WAKE_INITIATOR=""
-- OT_WAKE_LISTENER=""
-- OT_SPINEL_CP_RESET_FAIL_CALLBACK_ENABLE=""
-- - - - - - - - - - - - - - - - - 
-- OT_PLATFORM="external"
-- OT_CRYPTO_LIB=""
-- OT_CRYPTO_CCM_ONE_SHOT=""
-- OT_THREAD_VERSION="1.4" -> OPENTHREAD_CONFIG_THREAD_VERSION=OT_THREAD_VERSION_1_4
-- OT_LOG_LEVEL="WARN" --> OPENTHREAD_CONFIG_LOG_LEVEL=OT_LOG_LEVEL_WARN
-- OT_LOG_OUTPUT=""
-- OT_VENDOR_NAME=""
-- OT_VENDOR_MODEL=""
-- OT_VENDOR_SW_VERSION=""
-- OT_BORDER_AGENT_SERVICE_NAME=""
-- OT_POWER_SUPPLY=""
-- OT_BORDER_ROUTING_DHCP6_PD_MIN_LIFETIME=""
-- OT_LOG_MAX_SIZE=""
-- OT_MAC_CSL_REQUEST_AHEAD_US=""
-- OT_MLE_MAX_CHILDREN=""
-- OT_RCP_RESTORATION_MAX_COUNT="2" --> OPENTHREAD_SPINEL_CONFIG_RCP_RESTORATION_MAX_COUNT=2
-- OT_RCP_TIME_SYNC_INTERVAL=""
-- OT_RCP_TX_WAIT_TIME_SECS=""
-- OT_VENDOR_OUI=""
-- OpenThread CMake build type: MinSizeRel
-- Package Name: OPENTHREAD
-- Setting default package version: v2026.11.0-57-g3f51b9486
-- Package Version: v2026.11.0-57-g3f51b9486
-- Configuring done
-- Generating done
-- Build files have been written to: /opt/otbr/firmware/ot-nrf528xx/build
+ [[ -n '' ]]
+ ninja
[19/935] cd /opt/otbr/firmware/ot-nrf528xx/build/openthread && /usr/bin/cmake -DLIST="OPENTHREAD_CONFIG_JOINER_ENABLE=1;OPENTH...rf52840-config-check.h";MBEDTLS_CONFIG_FILE="nrf-config.h"" -P /opt/otbr/firmware/ot-nrf528xx/openthread/etc/cmake/print.cmak
OPENTHREAD_CONFIG_JOINER_ENABLE=1
OPENTHREAD_CONFIG_PING_SENDER_ENABLE=1
OPENTHREAD_CONFIG_IP6_SLAAC_ENABLE=1
OPENTHREAD_CONFIG_THREAD_VERSION=OT_THREAD_VERSION_1_4
OPENTHREAD_CONFIG_LOG_LEVEL=OT_LOG_LEVEL_WARN
OPENTHREAD_SPINEL_CONFIG_RCP_RESTORATION_MAX_COUNT=2
OPENTHREAD_CONFIG_ENABLE_BUILTIN_MBEDTLS=0
OPENTHREAD_CONFIG_ENABLE_BUILTIN_MBEDTLS_MANAGEMENT=1
PACKAGE_NAME=OPENTHREAD
OPENTHREAD_PLATFORM_POSIX=0
OPENTHREAD_PLATFORM_NEXUS=0
OPENTHREAD_CONFIG_NCP_INFRA_IF_ENABLE=0
OPENTHREAD_CONFIG_NCP_DNSSD_ENABLE=0
OPENTHREAD_CONFIG_NCP_CLI_STREAM_ENABLE=0
OPENTHREAD_CONFIG_NCP_HDLC_ENABLE=1
OPENTHREAD_PLATFORM_CORE_CONFIG_FILE=openthread-core-nrf52840-config.h
OPENTHREAD_CORE_CONFIG_PLATFORM_CHECK_FILE=openthread-core-nrf52840-config-check.h
MBEDTLS_USER_CONFIG_FILE=nrf52840-mbedtls-config.h
USB_CDC_AS_SERIAL_TRANSPORT=1
APP_USBD_NRF_DFU_TRIGGER_ENABLED=1
OPENTHREAD_CORE_CONFIG_PLATFORM_CHECK_FILE=openthread-core-nrf52840-config-check.h
MBEDTLS_CONFIG_FILE=nrf-config.h
[935/935] Linking CXX executable bin/ot-ncp-mtd
+ cd /opt/otbr/firmware/ot-nrf528xx
Zip created at /opt/otbr/firmware/ot-rcp.zip

:: 3/7 Flashage du dongle
>>> Branchez le dongle en MAINTENANT LE BOUTON APPUYÉ (LED verte = mode DFU) <<<
    Appuyez sur Entrée quand c'est fait... 
    Recherche du bootloader (max 30 s) :  trouvé !
    Bootloader UF2 détecté (lecteur /dev/sdb) : flashage par copie .uf2
Converted to uf2, output size: 153088, start address: 0x1000
Wrote 153088 bytes to ot-rcp.uf2
    Flashage UF2 effectué, le dongle a redémarré sur le nouveau firmware.

:: 4/7 Règle udev : alias stable /dev/nrf52840
    Rebranchez le dongle puis appuyez sur Entrée... 
    Recherche du port du dongle (max 30 s) :  trouvé ! (/dev/ttyACM0)
    Activation de /dev/nrf52840 (max 15 s) : OK (VID=1915 PID=cafe)

:: 5/7 Génération de la configuration Docker
    Interface backbone : eth0

:: 6/7 Démarrage du conteneur OTBR
    Aucun dataset existant à sauvegarder (première installation)
[+] up 1/1
 ✔ Container otbr Started                                                                                                                                                                                                                                  0.2s
    Attente du démarrage de l'agent (20 s)...
    RCP détecté, état : leader
Done

:: 7/7 Formation du réseau Thread (uniquement si aucun n'existe déjà)
    Aucun dataset actif : formation d'un nouveau réseau.
Done
Done
Done
Done
    Attente de l'élection du leader...

==============================================
 État actuel : leader
Done
 Diagnostics : docker logs otbr | tail -n 50
==============================================
```