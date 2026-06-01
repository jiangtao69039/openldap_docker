FROM debian:bookworm-slim

ENV LDAP_SUFFIX="dc=example,dc=com" \
    LDAP_ROOT_DN="cn=admin,dc=example,dc=com" \
    LDAP_ROOT_PASSWORD="admin123" \
    LDAP_TEST_USER_UID="testuser" \
    LDAP_TEST_USER_PASSWORD="testpass"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends slapd ldap-utils && \
    rm -rf /var/lib/apt/lists/*

COPY docker/setup-openldap.sh /usr/local/bin/setup-openldap.sh
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/setup-openldap.sh /usr/local/bin/entrypoint.sh && \
    /usr/local/bin/setup-openldap.sh

EXPOSE 389

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
