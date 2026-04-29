# Architecture et plan d'adressage

## Infrastructure cible

L'infrastructure de la PME fictive comprend un pare-feu OPNsense multi-VLAN, un hyperviseur Proxmox VE physique, et plusieurs serveurs et postes clients. Le projet a déployé sur cette infrastructure une plateforme de supervision Centreon capable de remonter en temps réel les métriques des machines critiques.

## Schéma logique

```
                          Internet
                              |
                    +-------------------+
                    |     OPNsense      |
                    | Pare-feu / Routeur|
                    +---------+---------+
                              |
              +---------------+---------------+
              |                               |
        VLAN INFRA                       VLAN Clients
              |
       +------+----------+
       |    Proxmox VE   |
       +--+----------+---+
          |          |
      +---+---+  +---+---+
      |Centreon|  |WinSrv |
      |Debian12|  | 2019  |
      |        |  |  AD   |
      +---+----+  +---+---+
          |           |
          |  SNMP v2c |
          +-----------+

          +---------------+
          | Gmail SMTP    |
          | (relais mail) |
          +---------------+
                ^
                | msmtp
                |
            (Centreon)
```

## Plan d'adressage anonymisé

Les valeurs réelles sont remplacées par des placeholders neutres dans la documentation publique du repo.

- WAN : `192.168.X.0/24` (IP privée non routable depuis Internet)
- VLAN INFRA (serveurs) : `192.168.A.0/24`, passerelle `192.168.A.254`
- VLAN DMZ : `192.168.B.0/24`, passerelle `192.168.B.254`
- VLAN Clients : `192.168.C.0/24`, passerelle `192.168.C.254`
- VLAN Management : `192.168.M.0/24`, passerelle `192.168.M.30`

## Architecture des machines virtuelles

| VM | Rôle | OS |
|---|---|---|
| Centreon | Serveur de supervision | Debian 12 |
| Windows Server 2019 | AD DS, DNS, cible supervisée | Windows Server 2019 |
| Client | Poste utilisateur de test | Debian 12 |

La VM Centreon dispose d'au moins 4 Go de RAM (avec swap) et 20 Go de disque. La VM Windows Server dispose de 4 Go de RAM et 50 Go de disque. Les deux sont rattachées au VLAN INFRA pour pouvoir échanger sans franchir le pare-feu.

## Flux supervisés

Centreon initie périodiquement des requêtes SNMP vers ses cibles sur le port UDP 161. Les cibles (Windows Server, OPNsense) répondent avec leurs métriques. Quand un seuil est franchi en mode HARD (après plusieurs tentatives consécutives), Centreon déclenche une notification.

La notification mail passe par msmtp installé sur la VM Centreon, qui relaie vers le SMTP authentifié de Gmail (port 587, TLS). Voir [alerting.md](alerting.md) pour le détail.

## Justification des choix d'architecture

**Déploiement progressif en deux étapes.** La maquette VirtualBox a permis de valider l'ensemble de la chaîne (SNMP, dashboard, alerting) en environnement isolé. La migration vers Proxmox s'est faite ensuite par export OVA, sans réinstallation, ce qui réduit le risque d'erreur de configuration.

**Choix de SNMP v2c.** Plus simple à mettre en place (pas de couple utilisateur/clé d'authentification à gérer) et acceptable dans un environnement maîtrisé où la communauté est restreinte par IP source au niveau du pare-feu Windows. Une évolution vers SNMP v3 (authentification + chiffrement) est listée comme perspective d'évolution dans le projet original.

**msmtp plutôt que Postfix.** Postfix n'est pas disponible dans les dépôts Debian 12 standards utilisés par la VM. msmtp est plus léger, plus simple à configurer pour un usage de relais sortant uniquement, et suffit largement pour envoyer les notifications.
