# validate-openthread-dependencies.sh

```bash
pi@rieux:~/gladys_openthread$ sudo ./validate-openthread-dependencies.sh 
==============================================
 Vérification des dépendances OTBR - 2026-11-10 22:31
==============================================

[1/4] Outils système et compilation RCP
  [OK]    git (git)
  [OK]    curl (curl)
  [OK]    make (build-essential)
  [OK]    python3 (python3)
  [OK]    pip3 (python3-pip)
  [OK]    arm-none-eabi-gcc (gcc-arm-none-eabi)
  [OK]    arm-none-eabi-objcopy (gcc-arm-none-eabi)
  [OK]    udevadm (udev)
  [OK]    fuser (psmisc)

[2/4] Outils de flashage
  [OK]    adafruit-nrfutil trouvé : /home/pi/gladys_openthread/venv/bin/adafruit-nrfutil
  [OK]    module python pyserial (paquet : python3-serial)

[3/4] Docker
  [OK]    docker installé (Docker version 29.9.3, build 5457199)
  [OK]    plugin docker compose
  [OK]    accès au daemon docker

[4/4] Conditions système
  [OK]    droits sudo disponibles
  [OK]    /dev/net/tun disponible
  [OK]    IPv6 non désactivé au boot
  [OK]    espace disque : 89338 Mo libres
  [OK]    RAM : 3795 Mo

==============================================
 Bilan : 19 OK, 0 paquet(s) apt manquant(s), 0 paquet(s) pip manquant(s), 0 autre(s) problème(s)
==============================================

>>> Toutes les dépendances sont en place : vous pouvez lancer validate-nrf52840.sh puis install-otbr.sh <<<

```