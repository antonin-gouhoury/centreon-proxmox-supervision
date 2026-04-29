# Migration VirtualBox vers Proxmox

Une fois la maquette validée en VirtualBox, les VMs Centreon et Windows Server ont été migrées vers l'hyperviseur Proxmox VE de l'infrastructure physique. Cette page documente la procédure et les écueils rencontrés.

## Préparation des VMs avant export

Avant d'exporter, on vérifie l'absence de VirtualBox Guest Additions :

- Sur Windows Server, depuis Programmes et fonctionnalités.
- Sur Centreon (Debian), via les commandes de désinstallation correspondantes.

Sans ce nettoyage, on risque d'avoir des modules orphelins qui empêchent le boot ou ralentissent la VM dans le nouvel hyperviseur.

## Export OVA

Depuis VirtualBox : Fichier, Exporter l'appliance virtuelle, format OVF 1.0. L'opération produit un fichier `.ova` qui contient le disque virtuel et la configuration de la VM.

Pour ce projet, deux exports ont été réalisés : la VM Centreon (~2,3 Go) et la VM Windows Server avec Active Directory (~7,6 Go).

## Transfert vers Proxmox

Le fichier OVA est transféré vers Proxmox via SCP :

```
scp <fichier>.ova root@<ip_proxmox>:/var/lib/vz/template/
```

**Point d'attention.** Le premier essai vers `/tmp` a échoué : sur certaines installations Proxmox, `/tmp` est monté en `tmpfs` (en RAM) avec un espace très limité. Pour un fichier de 7,6 Go, c'est insuffisant. La solution consiste à transférer vers `/var/lib/vz/template/` qui dispose de l'espace disque réel.

## Import dans Proxmox

Une fois le fichier OVA sur Proxmox, on l'extrait puis on importe le disque dans une VM avec un ID libre :

```
ssh root@<ip_proxmox>
cd /var/lib/vz/template/
tar xvf <fichier>.ova
qm importovf <id_vm> <fichier>.ovf local-lvm --format qcow2
```

L'option `--format qcow2` produit un disque qcow2, format flexible qui supporte les snapshots. L'option `local-lvm` désigne le stockage de destination.

Après import, la VM apparaît dans l'interface Proxmox et peut être démarrée.

## Reconfiguration réseau

Après import, les VMs n'ont plus la bonne configuration réseau (l'ancienne IP de l'environnement VirtualBox n'est plus valide dans le VLAN INFRA de Proxmox).

### Sur la VM Centreon (Debian 12)

Cas délicat : `nmtui`, `nmcli` et les fichiers `network-scripts` sont absents sur la version utilisée de Debian 12. Les fichiers `.nmconnection` que j'ai essayé de créer ne persistaient pas non plus au reboot.

Solution adoptée : créer un service systemd dédié qui applique la configuration IP au démarrage.

```
cat > /etc/systemd/system/set-ip.service << 'EOF'
[Unit]
Description=Set static IP for ens18
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip addr add <IP>/24 dev ens18
ExecStart=/sbin/ip route add default via <GATEWAY>
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable set-ip.service
```

Au reboot suivant, le service réapplique automatiquement l'IP statique. Le fichier complet est versionné dans `configs/set-ip.service`.

### Sur la VM Windows Server

Configuration directe via les propriétés de la carte réseau Ethernet : nouvelle IP statique, masque, passerelle (l'interface OPNsense du VLAN INFRA), DNS préféré pointant sur lui-même (loopback) puisqu'il est contrôleur de domaine.

## Vérification post-migration

Une fois les VMs reconfigurées, on vérifie :

- **Connectivité réseau** : ping vers la passerelle, ping vers Internet (`ping 8.8.8.8`).
- **Service Centreon** : interface web accessible sur `http://<nouvelle_ip>/centreon`.
- **Active Directory** : connexion au domaine fonctionnelle, DNS répond.
- **Cohérence Centreon** : il faut mettre à jour l'IP du Windows Server dans la configuration Centreon (Configuration, Hosts, SRV-AD, Adresse) et exporter la nouvelle config au poller. Sinon Centreon supervise encore l'ancienne IP et tous les services restent en alerte.

## Bilan

La migration a été menée sans réinstallation complète des VMs. Les principaux points d'attention sont la persistance réseau sur Debian 12, la mise à jour de la configuration Centreon après changement d'IP, et le dimensionnement de `/tmp` côté Proxmox lors du transfert.
