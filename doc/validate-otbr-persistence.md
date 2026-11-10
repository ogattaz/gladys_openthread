# validate-otbr.sh --persistence

```bash
pi@rieux:~/gladys_openthread$ sudo ./validate-otbr.sh --persistence
:: Validation OTBR (10/11/2026 21:44:51)

===== 1/8 Conteneur Docker =====
  [OK]   conteneur 'otbr' en cours d'exécution
  [OK]   network_mode : host
  [OK]   image : openthread/border-router

===== 2/8 Dongle RCP (/dev/nrf52840) =====
  [OK]   périphérique /dev/nrf52840 présent
  [OK]   RCP détecté par l'agent : OPENTHREAD/v2026.11.0-57-g3f51b9486; NRF52840; Nov 10 2026 21:34:57

===== 3/8 État OpenThread =====
  [OK]   état : leader (le routeur de bordure dirige le réseau Thread)
  [OK]   réseau Thread : 'OpenThread-35ac', canal 11, panid 0x35ac
        Table des routeurs Thread :
          | ID | RLOC16 | Next Hop | Path Cost | LQ In | LQ Out | Age | Extended MAC     | Link |
          +----+--------+----------+-----------+-------+--------+-----+------------------+------+
          |  4 | 0x1000 |       63 |         0 |     0 |      0 |   0 | ba69f5b3d57fa32a |    0 |
          

===== 4/8 Dataset Thread et interface wpan0 =====
  [OK]   dataset actif présent (212 caractères hexa)
        0e080000000000010000000300000b35060004001fffe00208ae6e4127e7621c630708fdfb72c2e02fdd790510f7c106fc79f35310a4cc7f882653c9b3030f4f70656e5468726561642d33356163010235ac041065cc105d86ec60291c9bb466fc7e08150c0402a0f7f8
  [OK]   interface wpan0 présente sur le host
  [OK]   wpan0 : 8 adresses IPv6 (OMR + ML)
          fdfb:72c2:e02f:dd79:0:ff:fe00:fc11/64
          fdfb:72c2:e02f:dd79:0:ff:fe00:fc38/64
          fdfb:72c2:e02f:dd79:0:ff:fe00:fc10/64
          fdfb:72c2:e02f:dd79:0:ff:fe00:fc00/64
          fdfb:72c2:e02f:dd79:0:ff:fe00:1000/64
          fdfb:72c2:e02f:dd79:101d:e4fa:e7fc:1018/64
          fdec:28d3:e29a:1:a713:f9e1:907a:40e4/64

===== 5/8 Services Border Router =====
  [OK]   Backbone Router : Primary
  [OK]   serveur SRP : running
  [ATTENTION] préfixe NAT64 illisible ou non publié (commande nat64prefixes absente de cette version d'ot-ctl ? vérifiez : docker exec otbr ot-ctl nat64prefix)
  [OK]   service DNS : actif
  [OK]   données réseau Thread publiées (12 entrées)

===== 6/8 Ports d'écoute (web 8090 / REST 8081 / border agent 49153) =====
  [OK]   interface web : écoute 0.0.0.0:8090 (joignable depuis le LAN)
  [OK]   API REST : écoute 127.0.0.1:8081
  [OK]   Border Agent : UDP 49153 en écoute (appairage MeshCoP)

===== 7/8 Annonce mDNS _meshcop._udp sur le LAN =====
  [OK]   service _meshcop._udp publié sur le LAN (découverte par les contrôleurs Matter/Thread possible)

===== 8/8 Persistance du dataset Thread =====
  Redémarrage du conteneur...
  Attente du retour à l'état leader (max 120 s) : .....
  [OK]   état leader restauré après redémarrage
  [OK]   dataset IDENTIQUE après redémarrage : le réseau Thread est persistant

==============================================
 Bilan : 20 OK, 0 échec(s), 1 avertissement(s)
==============================================
```