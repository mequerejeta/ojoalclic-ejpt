#!/bin/bash
# Provisiona el services-box con servicios intencionalmente vulnerables (eJPT).
# Nativo: rsync(873), snmp(161), webdav(80). Docker: WordPress(8000), Shellshock(8080).
set +e
export DEBIAN_FRONTEND=noninteractive
echo "=== provision services-box $(date) ==="

apt-get update
apt-get install -y apache2 rsync snmpd snmp docker.io docker-compose curl wget
systemctl enable --now docker 2>/dev/null

# --- RSYNC anonimo sin auth (873) ---
cat >/etc/rsyncd.conf <<'EOF'
uid = nobody
gid = nogroup
use chroot = no
[public]
    path = /srv/rsync_public
    comment = public share (no auth)
    read only = false
    list = yes
EOF
mkdir -p /srv/rsync_public
echo "flag: rsync anonimo expuesto (eJPT lab)" >/srv/rsync_public/flag.txt
sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/' /etc/default/rsync 2>/dev/null
systemctl enable rsync; systemctl restart rsync
pgrep -x rsync >/dev/null || rsync --daemon --config=/etc/rsyncd.conf

# --- SNMP community public (161/udp) ---
cat >/etc/snmp/snmpd.conf <<'EOF'
agentAddress udp:161
rocommunity public
sysLocation "Lab eJPT"
sysContact admin@lab.local
EOF
systemctl enable snmpd; systemctl restart snmpd

# --- WebDAV sin auth (80 /webdav) ---
a2enmod dav dav_fs
mkdir -p /var/www/html/webdav && chown www-data:www-data /var/www/html/webdav
cat >/etc/apache2/conf-available/webdav.conf <<'EOF'
Alias /webdav /var/www/html/webdav
<Location /webdav>
    DAV On
</Location>
EOF
a2enconf webdav; systemctl restart apache2

# --- WordPress (8000) + Shellshock (8080) via Docker ---
mkdir -p /opt/lab
cat >/opt/lab/docker-compose.yml <<'EOF'
version: "3"
services:
  wp_db:
    image: mariadb:10.5
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
  wordpress:
    image: wordpress:5.0-apache
    restart: unless-stopped
    depends_on: [wp_db]
    ports: ["8000:80"]
    environment:
      WORDPRESS_DB_HOST: wp_db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_SITEURL','http://'.$$_SERVER['HTTP_HOST']);
        define('WP_HOME','http://'.$$_SERVER['HTTP_HOST']);
  wp_cli:
    image: wordpress:cli
    depends_on: [wordpress]
    environment:
      WORDPRESS_DB_HOST: wp_db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    entrypoint: sh -c "sleep 45; wp core install --url=http://localhost:8000 --title=LabWP --admin_user=admin --admin_password=password --admin_email=a@b.c --skip-email; wp user create bob bob@lab.local --role=author --user_pass=bob123; echo WP_READY"
  shellshock:
    build: /vagrant/provision/shellshock
    image: lab/shellshock
    restart: unless-stopped
    ports: ["8080:80"]
EOF
cd /opt/lab
docker-compose up -d wp_db wordpress wp_cli
docker-compose up -d shellshock || echo "WARN: shellshock build/pull fallo"

echo "=== fin. servicios: rsync:873 snmp:161 webdav:80/webdav wordpress:8000(admin:password) shellshock:8080/cgi-bin/vuln.cgi ==="
