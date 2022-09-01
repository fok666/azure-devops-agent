#!/bin/bash

# Monitors VMSS shutdown event, triggers agent shutdown

curl -s 'http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01' -H 'Metadata: true' > /tmp/scheduledevents.json
grep -q "Terminate" /tmp/scheduledevents.json
if [ $? -eq 0 ]; then
  /opt/stop.sh  $1 $2 &
fi

exit 0
