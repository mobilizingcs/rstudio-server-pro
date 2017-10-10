#!/bin/bash

LICENSE_KEY=${LICENSE_KEY:-0}
SUPERUSERS=${SUPERUSERS:-0}
FRAME_ORIGIN=${FRAME_ORIGIN:-none}

# how frequently to sync.
SYNC=${SYNC:-0}
SYNC_SECONDS=${SYNC_SECONDS:-120}
DB_HOST=${DB_HOST:-db}

sync() {
while true
do
  # wait for mysql to start
  echo -n "ensuring mysql is available before syncing..."
  while ! nc -w 1 $DB_HOST 3306 &> /dev/null
  do
    sleep 1
  done
  echo "done."
  rm -f /tmp/account_sync.db
  /usr/bin/ruby /sync.rb
  sleep $SYNC_SECONDS
done
}

rstudio() {
  grep -q -F "www-frame-origin=$FRAME_ORIGIN" /etc/rstudio/rserver.conf || echo "www-frame-origin=$FRAME_ORIGIN" >> /etc/rstudio/rserver.conf
  if [ "$SUPERUSERS" != "0" ]
  then
    for USERNAME in $SUPERUSERS; do
      echo ${USERNAME}:dummy::::/home/${USERNAME}:/bin/nologin | newusers
      useradd -G rstudio-superusers ${USERNAME}
    done
  fi
  if [ "$LICENSE_KEY" != "0" ]
  then
    /usr/lib/rstudio-server/bin/rstudio-server license-manager activate $LICENSE_KEY
  fi
  echo "Starting rstudio server..."
  /usr/lib/rstudio-server/bin/rserver --server-daemonize 0
}

deactivate() {
  echo "Deactivating license..."
  /usr/lib/rstudio-server/bin/rstudio-server license-manager deactivate >/dev/null 2>&1
}

# only starts sync if sync is enabled
if [ $SYNC == 1 ]
then
  sync & sync_pid=${!}
fi
rstudio & rstudio_pid=${!}

trap "{ deactivate; kill $sync_pid; kill $rstudio_pid; exit 0; }" SIGTERM SIGINT

while true
do
  tail -f /dev/null & wait ${!}
done