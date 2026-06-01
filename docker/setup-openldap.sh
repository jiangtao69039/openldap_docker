#!/usr/bin/env bash
set -euo pipefail

LDAP_SUFFIX="${LDAP_SUFFIX:-dc=example,dc=com}"
LDAP_ROOT_DN="${LDAP_ROOT_DN:-cn=admin,dc=example,dc=com}"
LDAP_ROOT_PASSWORD="${LDAP_ROOT_PASSWORD:-admin123}"
LDAP_TEST_USER_UID="${LDAP_TEST_USER_UID:-testuser}"
LDAP_TEST_USER_PASSWORD="${LDAP_TEST_USER_PASSWORD:-testpass}"

mkdir -p /var/lib/ldap /etc/ldap/slapd.d /run/slapd
chown -R openldap:openldap /var/lib/ldap /etc/ldap/slapd.d /run/slapd
chmod 700 /run/slapd

/usr/sbin/slaptest -u -F /etc/ldap/slapd.d

/usr/sbin/slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d

cleanup() {
    pkill -x slapd >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in $(seq 1 30); do
    if ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config -LLL dn >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

ROOT_PW_HASH="$(slappasswd -s "${LDAP_ROOT_PASSWORD}")"
DATABASE_DN="$(ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config -LLL '(&(objectClass=olcDatabaseConfig)(olcSuffix=*))' dn | awk '/^dn: / {print substr($0, 5); exit}')"

cat >/tmp/set-domain.ldif <<EOF
dn: ${DATABASE_DN}
changetype: modify
replace: olcSuffix
olcSuffix: ${LDAP_SUFFIX}
-
replace: olcRootDN
olcRootDN: ${LDAP_ROOT_DN}
-
replace: olcRootPW
olcRootPW: ${ROOT_PW_HASH}
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/set-domain.ldif

cat >/tmp/base-and-user.ldif <<EOF
dn: ${LDAP_SUFFIX}
objectClass: top
objectClass: dcObject
objectClass: organization
o: Example Org
dc: example

dn: ${LDAP_ROOT_DN}
objectClass: organizationalRole
cn: admin
description: Directory Admin

dn: ou=users,${LDAP_SUFFIX}
objectClass: organizationalUnit
ou: users

dn: uid=${LDAP_TEST_USER_UID},ou=users,${LDAP_SUFFIX}
objectClass: inetOrgPerson
cn: Test User
sn: User
uid: ${LDAP_TEST_USER_UID}
mail: ${LDAP_TEST_USER_UID}@example.com
userPassword: ${LDAP_TEST_USER_PASSWORD}
EOF

ldapadd -x -D "${LDAP_ROOT_DN}" -w "${LDAP_ROOT_PASSWORD}" -f /tmp/base-and-user.ldif

ldapsearch -x -D "${LDAP_ROOT_DN}" -w "${LDAP_ROOT_PASSWORD}" -b "${LDAP_SUFFIX}" -LLL dn >/dev/null
ldapwhoami -x -D "uid=${LDAP_TEST_USER_UID},ou=users,${LDAP_SUFFIX}" -w "${LDAP_TEST_USER_PASSWORD}" >/dev/null

rm -f /tmp/set-domain.ldif /tmp/base-and-user.ldif
cleanup
trap - EXIT
