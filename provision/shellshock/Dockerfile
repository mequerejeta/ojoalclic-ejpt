# Shellshock (CVE-2014-6271) lab container: bash 4.3 vanilla (vulnerable) + CGI.
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y build-essential wget apache2 ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# Compila bash 4.3 sin parches (vulnerable a shellshock) y reemplaza /bin/bash
RUN wget -q http://ftp.gnu.org/gnu/bash/bash-4.3.tar.gz \
    && tar xzf bash-4.3.tar.gz \
    && cd bash-4.3 && ./configure --silent && make -s \
    && cp bash /bin/bash && cp bash /usr/local/bin/bash \
    && cd / && rm -rf bash-4.3*
RUN a2enmod cgid
COPY vuln.cgi /usr/lib/cgi-bin/vuln.cgi
RUN chmod +x /usr/lib/cgi-bin/vuln.cgi
EXPOSE 80
# crea el runtime dir + borra pid viejo antes de arrancar (evita crash-loop al reiniciar)
CMD ["/bin/bash","-c","mkdir -p /var/run/apache2; rm -f /var/run/apache2/apache2.pid; . /etc/apache2/envvars; exec /usr/sbin/apache2 -D FOREGROUND"]
