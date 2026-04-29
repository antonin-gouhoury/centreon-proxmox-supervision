# Diagnostic et résolution d'incidents

Cette page documente les incidents rencontrés lors du déploiement, leur diagnostic et les solutions appliquées. Tous les cas sont issus du déroulement réel du projet.

## Swap manquant sur la VM Centreon

À la première installation, Centreon affichait une erreur sur le partitionnement et certains de ses services refusaient de démarrer correctement.

La VM avait été provisionnée sans partition swap. Sur Debian, certaines opérations de Centreon nécessitent du swap pour fonctionner correctement.

La solution a consisté à créer un fichier swap de 1 Go avec `dd if=/dev/zero of=/swapfile bs=1M count=1024`, à sécuriser les permissions avec `chmod 600`, à formater avec `mkswap`, à activer avec `swapon`, puis à pérenniser au reboot via une ligne dans `/etc/fstab`.

À retenir : toujours provisionner du swap, même petit, sur les VMs qui hébergent des services qui peuvent connaître des pics mémoire.

## Transfert SCP vers /tmp en échec

Lors du premier essai de transfert SCP du fichier OVA vers Proxmox, le transfert vers `/tmp` échouait.

`/tmp` était monté en `tmpfs` (en RAM) avec un espace trop limité pour un fichier de 7,6 Go.

Solution : transférer plutôt vers `/var/lib/vz/template/` qui dispose de l'espace disque réel.

À retenir : avant un gros transfert, vérifier l'espace disponible sur la cible avec `df -h`.

## DNS HS après migration depuis VirtualBox

Après la migration de la VM Centreon vers Proxmox, `apt-get update` échouait avec des erreurs de résolution DNS.

Le fichier `/etc/resolv.conf`, qui contient les serveurs DNS à utiliser, était vide après l'import.

Solution rapide : ajouter un DNS public (`echo "nameserver 8.8.8.8" > /etc/resolv.conf`). Cette ligne doit ensuite être pérennisée pour ne pas être perdue au reboot.

À retenir : à chaque migration entre hyperviseurs, vérifier `/etc/resolv.conf` parmi les premiers points de contrôle.

## IP non persistante au reboot sur Debian 12

Sur Debian 12, `nmtui`, `nmcli` et les fichiers `network-scripts` sont absents par défaut. Les fichiers `.nmconnection` que j'ai essayé de créer ne persistaient pas non plus au reboot.

Solution adoptée : créer un service systemd personnalisé qui applique la configuration au démarrage. Le contenu du fichier `/etc/systemd/system/set-ip.service` est versionné dans `configs/set-ip.service`.

À retenir : quand les outils standards ne fonctionnent pas, systemd offre une solution propre et persistante. Un service unit de quelques lignes peut remplacer un script à exécuter manuellement.

## Postfix introuvable dans les dépôts

L'installation de Postfix échouait avec un message indiquant que le paquet n'était pas disponible.

Postfix est absent des dépôts Debian 12 standards utilisés par la VM. Tentative initiale avec `dnf` qui a échoué (Debian utilise `apt-get`, pas `dnf`).

Solution : utiliser `msmtp` à la place, qui est disponible dans les dépôts standards et suffit pour un usage de relais sortant. Voir [alerting.md](alerting.md) pour la configuration complète.

À retenir : Debian utilise `apt-get` (pas `dnf` ni `yum`). Quand un paquet attendu n'est pas disponible, chercher une alternative plus légère qui couvre le besoin réel.

## snmptrapd ne persiste pas au reboot

Le démon `snmptrapd` (utilisé par Centreon pour recevoir les traps SNMP entrantes) refusait de démarrer automatiquement au reboot. `systemctl enable snmptrapd` retournait une erreur "Refusing to operate on alias name or linked unit file".

Le service était marqué `static` dans systemd, ce qui empêche un `enable` direct.

Solution : créer un fichier override systemd dans `/etc/systemd/system/snmptrapd.service.d/override.conf` qui force l'activation au démarrage. Voir `configs/snmptrapd-override.conf`.

À retenir : systemd permet d'ajuster un service livré par un paquet sans modifier les fichiers du paquet, via le mécanisme des `.d/override.conf`.

## SNMP timeout côté Centreon

Après avoir installé et configuré le service SNMP sur Windows Server, Centreon affichait tous les services en `UNKNOWN: SNMP Table Request: Timeout`.

Le pare-feu Windows bloquait par défaut le trafic UDP 161 entrant, même si le service écoutait correctement.

Solution : ajouter explicitement une règle de pare-feu Windows qui autorise UDP 161 entrant.

```
netsh advfirewall firewall add rule name="SNMP-IN" protocol=UDP dir=in localport=161 action=allow
```

À retenir : un service qui écoute ne signifie pas que le trafic peut l'atteindre. Le pare-feu local peut bloquer silencieusement. En cas de timeout, vérifier d'abord la règle pare-feu côté cible.

## Mails d'alerte vides

Les premières notifications mail arrivaient avec un sujet correct mais un corps de mail vide. Les variables Centreon (`$HOSTNAME$`, `$SERVICESTATE$`, etc.) ne s'interpolaient pas correctement quand on utilisait la commande de notification par défaut.

Le problème venait des règles d'échappement dans la commande Centreon : certains caractères spéciaux dans la chaîne de format perdaient leur sens à travers les couches d'exécution.

Solution : externaliser le formatage du mail dans un script Bash dédié (`/usr/local/bin/centreon-notify-host.sh`). Centreon appelle le script en lui passant les variables en arguments, et le script construit le mail localement avant de le passer à msmtp. Plus aucun problème d'échappement.

À retenir : quand une commande inline devient complexe avec beaucoup d'échappements, la passer dans un script séparé évite des heures de débogage. Un script versionné est aussi plus facile à maintenir.

## Widget "Status grid" vide

Le widget de tableau de bord "Status grid" devait afficher une grille des hôtes du Host Group `Infrastructure`. Malgré une configuration correcte (Host Group sélectionné, hôtes membres bien présents), le widget affichait obstinément "No host found".

Bug connu sur la version de Centreon utilisée.

Solution : remplacer le widget par "Status chart", qui présente l'information sous forme de camembert plutôt que de grille, et qui fonctionne correctement avec les Host Groups.

À retenir : ne pas s'acharner sur un widget qui ne fonctionne pas si une alternative équivalente existe.
