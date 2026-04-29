# Configuration de Centreon

## Installation

Centreon est installé sur une VM Debian 12 dédiée. La VM dispose d'au moins 4 Go de RAM, 20 Go de disque, et d'une partition swap.

Au premier démarrage, Centreon nécessite un espace swap. Si aucune partition swap n'a été créée à l'installation, on en provisionne une via un fichier swap : création avec `dd`, sécurisation des permissions avec `chmod 600`, formatage avec `mkswap`, activation avec `swapon`. La persistance au reboot s'obtient en ajoutant la ligne correspondante dans `/etc/fstab`.

## Premier accès et extensions

L'interface web de Centreon est accessible sur `http://<ip_centreon>/centreon`. Au premier accès, l'utilisateur `admin` permet de finaliser la configuration.

Les extensions essentielles sont installées depuis Administration, Extensions, Manager :

- **Centreon Plugin Packs Manager** pour gérer les packs de supervision.
- **OS-Windows-SNMP** pour superviser Windows Server.
- **OS-Linux-SNMP** pour superviser des machines Linux.
- **Base-Generic-SNMP** pour des cibles génériques comme un pare-feu.

## Préparation des cibles SNMP

### Windows Server

Le service SNMP n'est pas installé par défaut sur Windows Server. Il s'ajoute depuis le Gestionnaire de serveur, en cochant "Services SNMP" dans la liste des fonctionnalités.

Une fois installé, le service est configuré dans `Services` (services.msc) en éditant les propriétés du service SNMP, onglet Sécurité :

- Ajouter une communauté en lecture seule (par exemple `public`).
- Restreindre l'acceptation des paquets SNMP à l'IP du serveur Centreon uniquement.

Le pare-feu Windows doit également autoriser le trafic UDP 161 entrant en provenance du serveur Centreon. La règle se crée en ligne de commande :

```
netsh advfirewall firewall add rule name="SNMP-IN" protocol=UDP dir=in localport=161 action=allow
```

Le service SNMP est ensuite démarré : `net start snmp`.

### OPNsense

Sur OPNsense, le SNMP s'active depuis Services, SNMP. La communauté est définie à `public` (en lecture seule), et l'IP de Centreon est autorisée à effectuer des requêtes.

## Ajout d'un hôte dans Centreon

L'ajout d'un hôte se fait depuis Configuration, Hosts, Add. Pour Windows Server :

- Nom : libellé explicite (par exemple `SRV-AD`).
- Adresse IP : celle de la cible.
- Template : `OS-Windows-SNMP-custom` (du Plugin Pack).
- Communauté SNMP : `public`.
- Version SNMP : `2c`.

Le template Windows-SNMP applique automatiquement une série de services à superviser : Ping, CPU, Memory, Swap, Disk-C.

Pour OPNsense, on utilise plutôt le template `Net-Cisco-Standard-SNMP-custom` ou `Base-Generic-SNMP`.

## Application de la configuration

Toute modification de configuration nécessite ensuite un export et un redémarrage du moteur de supervision : Configuration, Pollers, Export configuration, en cochant "Restart Monitoring Engine", puis Export.

C'est une étape facile à oublier. Si on modifie un seuil ou un hôte sans relancer l'export, les changements ne sont pas pris en compte par le moteur.

## Tableau de bord

Un tableau de bord centralisé regroupe l'état global de l'infrastructure. Il est construit dans Home, Dashboards, en ajoutant des widgets :

- **Resource table** pour la liste des alertes actives.
- **Status chart** pour une vue camembert du nombre d'hôtes et de services par état (utilisée à la place de "Status grid" qui présente un bug avec les Host Groups sur la version utilisée).
- **Metrics graph** pour suivre l'évolution dans le temps de métriques précises (par exemple CPU et mémoire du SRV-AD).

Les hôtes sont regroupés dans un Host Group `Infrastructure` (SRV-AD + Centreon-central) pour faciliter la lecture des dashboards.

## Bonnes pratiques

L'organisation des hôtes en Host Groups facilite la lecture des dashboards et la configuration des notifications.

Les seuils warning/critical de chaque service doivent être ajustés en fonction du profil réel de la machine. Un faux positif récurrent finit par dévaluer toutes les alertes.
