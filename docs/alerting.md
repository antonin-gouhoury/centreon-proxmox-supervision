# Alerting par mail (msmtp)

Quand Centreon détecte une panne ou un retour à la normale sur un hôte ou un service, il déclenche une notification. Plutôt que de configurer un serveur SMTP local complet, j'ai opté pour msmtp qui relaie les mails sortants vers Gmail.

## Pourquoi msmtp et pas Postfix

Postfix n'est pas disponible dans les dépôts standards de la version Debian utilisée par la VM Centreon. msmtp est plus léger, plus simple à configurer pour un usage de relais sortant uniquement, et suffisant pour les besoins du projet.

## Préparation du compte Gmail

Pour qu'un programme puisse s'authentifier sur le SMTP de Gmail, il faut générer un mot de passe d'application. Cela se fait dans le compte Google : Sécurité, Validation en deux étapes (qui doit être activée), Mots de passe d'application. Google génère alors une chaîne unique de 16 caractères qui sert de mot de passe pour msmtp.

Ce mot de passe d'application n'est pas le mot de passe principal du compte. Il peut être révoqué à tout moment depuis le compte Google sans toucher au reste, ce qui en fait une bonne pratique de sécurité.

## Installation

Sur la VM Centreon, on s'assure d'abord que la résolution DNS fonctionne (parfois absente après une migration depuis VirtualBox) :

```
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

Puis on installe les paquets :

```
apt-get update
apt-get install msmtp msmtp-mta mailutils -y
```

## Configuration

Le fichier `/etc/msmtprc` est créé avec la configuration suivante :

```
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/msmtp.log

account gmail
host smtp.gmail.com
port 587
from <adresse_expediteur>@gmail.com
user <adresse_expediteur>@gmail.com
password <mot_de_passe_application_16_chars>

account default : gmail
```

Les permissions du fichier sont restreintes parce qu'il contient un mot de passe :

```
chmod 600 /etc/msmtprc
```

## Test rapide

Un test d'envoi vérifie que la chaîne est fonctionnelle :

```
echo -e "Subject: Test\n\nTest" | msmtp <destinataire>@gmail.com
```

Le journal `/var/log/msmtp.log` confirme `exitcode=EX_OK` quand le mail est bien transmis.

## Intégration dans Centreon

Pour formater des mails plus lisibles, j'ai créé deux scripts Bash dédiés :

- `/usr/local/bin/centreon-notify-host.sh` pour les notifications d'hôtes (DOWN, RECOVERY).
- `/usr/local/bin/centreon-notify-service.sh` pour les notifications de services (CRITICAL, UNKNOWN, OK).

Ces scripts utilisent les variables Centreon (`$HOSTNAME$`, `$SERVICESTATE$`, `$NOTIFICATIONTYPE$`, etc.) pour construire un sujet et un corps de mail explicites.

Dans Centreon, deux nouvelles commandes sont créées dans Configuration, Commands, Notifications :

- `host-notify-by-email` qui appelle le script hôte et passe le mail à msmtp.
- `service-notify-by-email` qui appelle le script service.

Les contacts qui doivent recevoir les alertes sont ensuite configurés pour utiliser ces commandes (Configuration, Users, Contacts, Notifications).

## Tests fonctionnels

Trois scénarios ont été validés :

1. **Panne d'hôte.** Extinction de la VM Windows Server depuis Proxmox. Au bout de quelques minutes (le temps que Centreon passe en état HARD), un mail "ALERTE Centreon - SRV-AD est DOWN" est reçu, contenant l'IP, l'état et la date.

2. **Retour à la normale.** Redémarrage de la VM. Un mail "ALERTE Centreon - SRV-AD est UP" est reçu automatiquement.

3. **Panne de service.** Arrêt du service SNMP côté Windows. Plusieurs mails sont reçus pour les services CPU, Memory, Disk, Swap qui passent en UNKNOWN faute de réponse SNMP.

## Points d'attention

Le mot de passe d'application dans `msmtprc` doit être protégé. Les permissions `chmod 600` empêchent les autres utilisateurs de la VM de le lire.

Si Gmail détecte un volume anormal de mails sortants, il peut bloquer temporairement le compte. Pour une PME en production, on utilisera plutôt un service de mail transactionnel ou un relais SMTP interne.
