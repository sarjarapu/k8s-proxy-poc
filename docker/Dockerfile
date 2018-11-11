FROM centos
LABEL author="Shyam Arjarapu" email="shyam.arjarapu@gmail.com"
COPY content/epel/epel.repo /etc/yum.repos.d/epel.repo
COPY content/epel/RPM-GPG-KEY-EPEL-7 /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
COPY content/ /opt/
RUN  yum install supervisor -y
# RUN microdnf --enablerepo=rhel-7-server-rpms --enablerepo=epel install supervisor --nodocs; \
#    microdnf clean all
# RUN  groupadd -r atlas-proxy && useradd -r -g atlas-proxy atlas-proxy
RUN  mkdir -p /opt/atlas-proxy \
     && chmod -R 0775 /opt \
     && mkdir -p /var/log/mongodb-mms-atlas-proxy \
     && chmod 0775 /var/log/mongodb-mms-atlas-proxy
# RUN  yum update -y && yum install -y supervisor
# RUN  chown -R atlas-proxy:atlas-proxy /opt/atlas-proxy
RUN  chmod +x /opt/atlas-proxy/mongodb-mms-atlas-proxy
CMD  supervisord -c /opt/supervisor/supervisord.conf
# SHELL ["/bin/bash", "-c"]