FROM eclipse-temurin:21-jre
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip \
 && curl -L -o /tmp/sqlcl.zip https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip \
 && unzip -q /tmp/sqlcl.zip -d /opt && rm /tmp/sqlcl.zip \
 && apt-get purge -y curl unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*
ENV PATH="/opt/sqlcl/bin:${PATH}"
ENTRYPOINT ["sql"]
