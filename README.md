# Supervision centralisée Centreon sur infrastructure Proxmox

Projet BTS SIO option SISR — Épreuve E5 — Année 2025/2026
Réalisé en alternance chez APPIMAC (Saint-Germain-Laval).

## Présentation

Mise en place d'une plateforme de supervision centralisée pour une PME fictive de cinquante employés. Le projet a été mené en deux étapes : maquette VirtualBox pour valider la chaîne complète, puis migration vers une infrastructure physique Proxmox VE.

L'objectif était de superviser en temps réel les performances et la disponibilité d'un Active Directory et du pare-feu, avec un système d'alertes par mail et un tableau de bord centralisé pour les administrateurs.

## Stack technique

- Centreon (moteur de supervision, sur Debian 12)
- Proxmox VE (hyperviseur de production)
- Windows Server 2019 (Active Directory, supervisé via SNMP)
- OPNsense (pare-feu multi-VLAN, supervisé via SNMP)
- SNMP v2c
- msmtp (envoi de mails d'alerte via Gmail SMTP)
- VirtualBox (maquette initiale)

## Architecture

L'infrastructure repose sur un hyperviseur Proxmox VE physique qui héberge deux VMs : une VM Centreon sous Debian 12 qui assure la supervision, et une VM Windows Server 2019 qui joue le rôle de contrôleur de domaine et de cible supervisée. Un pare-feu OPNsense gère le routage entre VLAN et est lui-même supervisé.

Les machines surveillées remontent leurs métriques (CPU, mémoire, disques, processus, ping) en SNMP vers Centreon. Quand un seuil critique est franchi ou qu'un service tombe, Centreon déclenche une notification par mail via msmtp.

Détail dans [docs/architecture.md](docs/architecture.md).

## Fonctionnalités mises en œuvre

**Supervision SNMP de Windows Server.** Service SNMP installé sur Windows, communauté restreinte à l'IP de Centreon, règle pare-feu Windows pour autoriser UDP 161 entrant. Côté Centreon, ajout de l'hôte avec le template `OS-Windows-SNMP-custom`.

**Supervision SNMP d'OPNsense.** Activation du service SNMP sur OPNsense, ajout de l'hôte dans Centreon avec un template adapté.

**Alerting par mail.** Notifications de panne et de retour à la normale envoyées via msmtp, avec le SMTP de Gmail comme relais. Scripts Bash dédiés pour formater les mails de manière lisible.

**Tableau de bord centralisé.** Dashboard Centreon avec widgets Resource table, Status chart et Metrics graph pour suivre l'état global et les métriques des machines critiques.

Détail dans [docs/centreon-config.md](docs/centreon-config.md) et [docs/alerting.md](docs/alerting.md).

## Phases de déploiement

**Phase 1 — Maquette VirtualBox.** VMs OPNsense, Centreon et Windows Server 2019 dans un environnement isolé, pour valider la chaîne complète sans toucher à l'infrastructure de production.

**Phase 2 — Migration vers Proxmox.** Export OVA des VMs Centreon et Windows Server depuis VirtualBox, transfert SCP vers l'hyperviseur Proxmox VE, import via `qm importovf`, reconfiguration réseau.

Détail dans [docs/migration-proxmox.md](docs/migration-proxmox.md).

## Validation

Les tests fonctionnels prévus ont été validés :

- Centreon accessible depuis l'interface web après migration.
- Supervision Windows Server (Ping, CPU, Memory, Swap, Disk-C) en vert.
- Supervision OPNsense via SNMP fonctionnelle.
- Alerte mail "DOWN" reçue lors d'une panne provoquée (extinction de la VM cible).
- Mail "RECOVERY" reçu automatiquement après redémarrage.
- Mails de services UNKNOWN reçus lors de l'arrêt du service SNMP côté Windows.
- IP statique persistante au reboot via service systemd dédié.

## Documentation

- [Architecture et plan d'adressage](docs/architecture.md)
- [Configuration de Centreon](docs/centreon-config.md)
- [Alerting par mail (msmtp)](docs/alerting.md)
- [Migration VirtualBox vers Proxmox](docs/migration-proxmox.md)
- [Diagnostic et résolution d'incidents](docs/troubleshooting.md)

## Auteur

Antonin Gouhoury — Étudiant BTS SIO SISR, UTEC Melun.
[LinkedIn](https://linkedin.com/in/antonin-gouhoury) · gouhouryantonin@gmail.com

---

Projet scolaire mené en autonomie. Les noms de domaines, IP et identifiants présents dans la documentation sont fictifs ou propres à un environnement de maquette.
