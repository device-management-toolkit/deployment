FROM postgres:18@sha256:3a4264520e121176619f54ff867d12774bc81e95e7b84db58d63bccdb6144b81
COPY pg_hba.conf /var/lib/postgresql/
RUN openssl req -new -x509 -days 365 -nodes -text -out /var/lib/postgresql/server.crt -keyout /var/lib/postgresql/server.key -subj "/CN=vprodemo.com"
RUN chmod 600 /var/lib/postgresql/server.key
RUN chown postgres:postgres /var/lib/postgresql/server.key