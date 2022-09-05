#!/bin/bash

# Monitors VMSS shutdown event, triggers agent shutdown

METADATA_ENDPOINT='http://169.254.169.254/metadata/scheduledevents?api-version=2020-07-01'

curl -s $METADATA_ENDPOINT -H 'Metadata: true' > /tmp/scheduledevents.json
grep -q "Terminate" /tmp/scheduledevents.json

if [ $? -eq 0 ]; then

  # Start agent shutdown
  /opt/stop.sh

  # Confirm event after agent shutdown:
  EventId=`jq -r '.Events[] | .EventId' /tmp/scheduledevents.json`
  curl -s -X POST $METADATA_ENDPOINT  -H 'Metadata: true' -d "{\"StartRequests\" : [{\"EventId\": \"${EventId}\"}]}"

fi

exit 0
