# validate-nrf52840.sh

```bash
pi@rieux:~/gladys_openthread$ sudo ./validate-nrf52840.sh
==============================================
 Validation dongle nRF52840 - 2026-11-10 22:32
==============================================

[1/8] Privilèges
  [OK]    script exécuté en root

[2/8] Plateforme
  [OK]    machine : Raspberry Pi 4 Model B Rev 1.2
  [OK]    architecture aarch64

[3/8] Détection USB du dongle
  [OK]    périphérique USB détecté : Bus 001 Device 027: ID 1915:cafe Nordic Semiconductor ASA nRF528xx OpenThread Device

[4/8] Port série
  [OK]    port série détecté : /dev/ttyACM0
  [OK]    driver cdc_acm bien chargé pour /dev/ttyACM0 (dongle nRF52840, USB CDC)

[5/8] Port libre
  [OK]    /dev/ttyACM0 est libre

[6/8] Outils de flashage
  [OK]    adafruit-nrfutil trouvé : /home/pi/gladys_openthread/venv/bin/adafruit-nrfutil
  [ATTENTION] ot-rcp.zip absent : il sera construit par install-otbr.sh

[7/8] Environnement hôte
  [OK]    Docker installé (Docker version 29.9.3, build 5457199)
  [OK]    plugin docker compose OK
  [OK]    espace disque : 89338 Mo libres
  [OK]    RAM suffisante
  [OK]    IPv6 non désactivé au boot
  [OK]    /dev/net/tun disponible

[8/8] Mode DFU : non testé (relancez avec --dfu pour le vérifier)

==============================================
 Bilan : 14 OK, 1 avertissement(s), 0 erreur(s)
==============================================
 >>> Dongle prêt : vous pouvez lancer install-otbr.sh <<<
```