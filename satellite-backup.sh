#!/bin/bash

# Custom script for backup the Satellite/Capsules
# Report bugs to rober@redhat.com

# Usage of the script
# In normal mode, only the config files are backup it

usage(){
  SCRIPT=$(basename $0)

  printf ""
  printf "=================================================================\n" >&2
  printf "Usage: ${SCRIPT} [options] <backup directory>\n" >&2
  printf "\n" >&2
  printf "Options:\n" >&2
  printf "\n" >&2
  printf "    -h                Show usage\n" >&2
  printf "    -d                Backup the Mongo and Postgresql Databases\n" >&2
  printf "    -p                Backup the Pulp Data\n" >&2
  printf "    -a                Backup all\n" >&2
  printf "=================================================================\n" >&2
  exit 1
}

## Define the getops for the script
while getopts ":a:d:p:h" opt
do
    case $opt in
        a)
            DB="true"
            PULP_DATA="true"
            shift
            ;;
        d)
            DB="true"
            shift
            ;;
        p)
            PULP_DATA="true"
            shift
            ;;
        h)
            usage
            ;;
        *)
            echo "invalid argument: '${OPTARG}'"
            usage
            exit 1
            ;;
    esac
done

# Set the files for backup

# Config files for the Satellite
CONFIGS=(
    /etc/candlepin
    /etc/elasticsearch
    /etc/foreman
    /etc/foreman-proxy
    /etc/gutterball
    /etc/hammer
    /etc/httpd
    /etc/katello
    /etc/katello-installer
    /etc/pki/content
    /etc/pki/katello
    /etc/pki/katello-certs-tools
    /etc/pki/pulp
    /etc/pki/tls/certs/katello-node.crt
    /etc/pki/tls/certs/pulp_consumers_ca.crt
    /etc/pki/tls/certs/pulp_ssl_cert.crt
    /etc/pki/tls/private/katello-node.key
    /etc/pulp
    /etc/puppet
    /etc/qpid
    /etc/qpid-dispatch
    /etc/sysconfig/elasticsearch
    /etc/sysconfig/tomcat*
    /etc/tomcat*
    /root/ssl-build
    /var/lib/foreman
    /var/lib/katello
    /var/lib/candlepin
    /var/www/html/pub
    /opt/repos/rhel/7/7.0/x86_64/deployment/
    /opt/repos/rhel/7/7.0/x86_64/collectd/
    /opt/repos/rhel/7/7.0/x86_64/packages/
)

# Config files for the Capsules
CONFIGS_CAPS=(
    /etc/hammer
    /etc/httpd
    /etc/capsule-installer/
    /etc/pki/katello
    /etc/pki/katello-certs-tools
    /etc/pki/pulp
    /etc/pulp
    /etc/puppet
    /etc/qpid
    /etc/qpid-dispatch
    /root/ssl-build
    /var/www/html/pub
    /var/lib/dhcpd/
    /var/lib/tftpboot/uefi/
    /etc/dhcp/
)

# Set the proper dateformat for the backup files
datefor=`date +%Y%m%d`
mongodir="/var/lib/mongodb/"
elasticsearch="/var/lib/elasticsearch/"
pgsql="/var/lib/pgsql/"

# Set the debug mode
if [[ "${DEBUG_SCRIPT}" == "TRUE" ]]; then
    set -x
else
    set +x
fi

# Error control
if [[ -z $1 ]]; then
  echo "--> ERROR: Please specify an backup directory <--"
  usage
  exit 1
fi

# requirements
function reqs (){
  echo ""
  echo "## Welcome to the backup tool for Satellite/Capsule ##"
  umask 0027
  BDIR=${1}_${datefor}
  if [[ -d $BDIR ]]; then
    echo "--> WARNING! The directory $BDIR exists! <--"
    exit 1
  fi
  mkdir -p $BDIR
  chgrp postgres $BDIR
  chmod 770 $BDIR
  cd $BDIR
  echo ""
  echo "= Creating backup folder $BDIR ... ="
  echo ""
}

function backup (){
  # Stop services
  echo "= Stop the Satellite services ... ="
  katello-service stop
  service postgresql stop
  echo ""

  # Detect if this is a Satellite or a Capsule
  if [[ -d "$elasticsearch" ]]; then
    echo "= Backing up Satellite config files... ="
    tar --selinux -czvf ${datefor}_config_files.tar.gz ${CONFIGS[*]} &> /dev/null
    echo "Done."
    echo ""
  else
    echo "= Backing up Capsule config files... ="
    tar --selinux -czvf ${datefor}_config_files.tar.gz ${CONFIGS_CAPS[*]} &> /dev/null
    echo "Done."
    echo ""
  fi

  if [[ ${DB} == "true" ]]; then
    if [[ -d "$elasticsearch" ]]; then
      echo "= Backing up Elastic Search data... ="
      tar --selinux -czvf ${datefor}_elastic_data.tar.gz /var/lib/elasticsearch &> /dev/null
      [[ $? -ne 0 ]] && echo "Failed!" && exit 1
      echo "Done."
      echo ""
    fi

    if [[ -d "$pgsql" ]]; then
      echo "= Backing up Postgres db... ="
      tar --selinux -czvf ${datefor}_pgsql_data.tar.gz /var/lib/pgsql/data/ &> /dev/null
      [[ $? -ne 0 ]] && echo "Failed!" && exit 1
      echo "Done."
      echo ""
    fi

    if [[ -d "$mongodir" ]]; then
      echo "= Backing up Mongo db... ="
      tar --selinux -czvf ${datefor}_mongo_data.tar.gz /var/lib/mongodb/ --exclude=mongod.lock /var/lib/mongodb/ &> /dev/null
      [[ $? -ne 0 ]] && echo "Failed!" && exit 1
      echo "Done."
      echo ""
    fi
  fi

  if [[ ${PULP_DATA} == "true" ]]; then
    echo "= Backing up Pulp data... ="
    tar --selinux -czvf ${datefor}_pulp_data.tar.gz /var/lib/pulp/ /var/www/pub/ &> /dev/null
    [[ $? -ne 0 ]] && echo "Failed!" && exit 1
    echo "Done."
    echo ""
  fi

  # Start services
  echo "= Starting the Satellite services ... ="
  service postgresql restart
  katello-service restart
  echo ""
}

# Entry point
reqs $1
backup

echo ""
echo ""
echo "## BACKUP Complete, contents can be found in: $BDIR ##"
echo ""
echo ""
