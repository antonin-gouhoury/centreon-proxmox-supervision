#!/bin/bash
# centreon-notify-host.sh
#
# Script de notification d'hôte appelé par Centreon en cas de panne ou
# de retour à la normale. Construit un mail formaté à partir des variables
# Centreon passées en arguments, puis le transmet à msmtp.
#
# Emplacement  : /usr/local/bin/centreon-notify-host.sh
# Permissions  : chmod +x /usr/local/bin/centreon-notify-host.sh
#
# Configuration côté Centreon :
#   Configuration > Commands > Notifications > Add
#   Command Name : host-notify-by-email
#   Command Line :
#     /usr/local/bin/centreon-notify-host.sh \
#       "$NOTIFICATIONTYPE$" "$HOSTNAME$" "$HOSTSTATE$" \
#       "$HOSTADDRESS$" "$HOSTOUTPUT$" "$LONGDATETIME$" \
#       "$ADMINEMAIL$"

NOTIFICATION_TYPE="$1"
HOSTNAME="$2"
HOSTSTATE="$3"
HOSTADDRESS="$4"
HOSTOUTPUT="$5"
DATETIME="$6"
ADMIN_EMAIL="$7"

SUBJECT="ALERTE Centreon - ${HOSTNAME} est ${HOSTSTATE}"

BODY="Notification: ${NOTIFICATION_TYPE}
Hôte: ${HOSTNAME}
État: ${HOSTSTATE}
IP: ${HOSTADDRESS}
Info: ${HOSTOUTPUT}
Date: ${DATETIME}"

printf "Subject: %s\n\n%s" "${SUBJECT}" "${BODY}" | /usr/bin/msmtp "${ADMIN_EMAIL}"
