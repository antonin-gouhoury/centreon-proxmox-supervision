#!/bin/bash
# centreon-notify-service.sh
#
# Script de notification de service appelé par Centreon en cas de panne ou
# de retour à la normale. Construit un mail formaté à partir des variables
# Centreon passées en arguments, puis le transmet à msmtp.
#
# Emplacement  : /usr/local/bin/centreon-notify-service.sh
# Permissions  : chmod +x /usr/local/bin/centreon-notify-service.sh
#
# Configuration côté Centreon :
#   Configuration > Commands > Notifications > Add
#   Command Name : service-notify-by-email
#   Command Line :
#     /usr/local/bin/centreon-notify-service.sh \
#       "$NOTIFICATIONTYPE$" "$SERVICEDESC$" "$HOSTNAME$" \
#       "$HOSTADDRESS$" "$SERVICESTATE$" "$SERVICEOUTPUT$" \
#       "$LONGDATETIME$" "$ADMINEMAIL$"

NOTIFICATION_TYPE="$1"
SERVICE_DESC="$2"
HOSTNAME="$3"
HOSTADDRESS="$4"
SERVICE_STATE="$5"
SERVICE_OUTPUT="$6"
DATETIME="$7"
ADMIN_EMAIL="$8"

SUBJECT="ALERTE Centreon - ${HOSTNAME} / ${SERVICE_DESC} est ${SERVICE_STATE}"

BODY="Notification: ${NOTIFICATION_TYPE}
Service: ${SERVICE_DESC}
Hôte: ${HOSTNAME}
État: ${SERVICE_STATE}
IP: ${HOSTADDRESS}
Info: ${SERVICE_OUTPUT}
Date: ${DATETIME}"

printf "Subject: %s\n\n%s" "${SUBJECT}" "${BODY}" | /usr/bin/msmtp "${ADMIN_EMAIL}"
