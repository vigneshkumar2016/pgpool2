#!/usr/bin/env bash
#-------------------------------------------------------------------
# test script for cert authentication for: frontend <--> Pgpool-II.
#
source $TESTLIBS
TESTDIR=testdir
PSQL=$PGBIN/psql
PG_CTL=$PGBIN/pg_ctl
export PGDATABASE=test

# Generate certifications
./cert.sh

dir=`pwd`
SSL_KEY=$dir/server.key
SSL_CRT=$dir/server.crt
ROOT_CRT=$dir/root.crt
FRONTEND_KEY=$dir/frontend.key
FRONTEND_CRT=$dir/frontend.crt

rm -fr $TESTDIR
mkdir $TESTDIR
cd $TESTDIR

# create test environment. Number of backend node is 1 is enough.
echo -n "creating test environment..."
$PGPOOL_SETUP -m s -n 1 || exit 1
echo "done."

dir=`pwd`

echo "ssl = on" >> etc/pgpool.conf
echo "ssl_key = '$SSL_KEY'" >> etc/pgpool.conf
echo "ssl_cert = '$SSL_CRT'" >> etc/pgpool.conf
echo "ssl_ca_cert = '$ROOT_CRT'" >> etc/pgpool.conf
echo "enable_pool_hba = on" >> etc/pgpool.conf

# allow to access IPv6 localhost
echo "hostssl	all	    all		127.0.0.1/32          cert" >> etc/pool_hba.conf
echo "hostssl	all	    all		::1/128          cert" >> etc/pool_hba.conf

sed -i "/^host.*trust$/d" etc/pool_hba.conf

source ./bashrc.ports

./startall

export PGPORT=$PGPOOL_PORT

wait_for_pgpool_startup

export PGSSLCERT=$FRONTEND_CRT
export PGSSLKEY=$FRONTEND_KEY

$PSQL -h localhost -c "select 1" test

grep "SSL certificate authentication for user" log/pgpool.log|grep successful
if [ $? != 0 ];then
    echo "Checking cert auth between Pgpool-II and frontend failed."
    ./shutdownall
    exit 1
fi

echo "Checking cert auth between Pgpool-II and frontend was ok."

./shutdownall
exit 0
