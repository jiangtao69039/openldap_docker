#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/slapd
chown openldap:openldap /run/slapd

exec /usr/sbin/slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d -d 0
