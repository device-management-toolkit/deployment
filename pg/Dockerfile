FROM postgres:18@sha256:e3d24f6906d0760bf4da0dae872415391ededefad23fd471c47dc53b0ddf3c42
COPY pg_hba.conf /var/lib/postgresql/
RUN openssl req -new -x509 -days 365 -nodes -text -out /var/lib/postgresql/server.crt -keyout /var/lib/postgresql/server.key -subj "/CN=vprodemo.com"
RUN chmod 600 /var/lib/postgresql/server.key
RUN chown postgres:postgres /var/lib/postgresql/server.key