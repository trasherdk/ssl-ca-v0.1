#!/bin/bash

# Source environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Get hostname for From address
hostname=$(hostname -f)
from_address="ssl-ca@${hostname}"
date_header=$(date "+%a, %d %b %Y %H:%M:%S %z")
message_id="<$(date +%Y%m%d%H%M%S).$$@${hostname}>"

echo "Sending test email..."
echo "From: ${from_address}"
echo "To: ${EMAIL}"
echo "Date: ${date_header}"

# Construct and send test email
if echo -e "From: SSL CA Monitor <${from_address}>\nDate: ${date_header}\nMessage-ID: ${message_id}\nTo: ${EMAIL}\nReply-To: ${from_address}\nX-Mailer: SSL CA Test Script\nSubject: SSL CA Test Email\n\nThis is a test email from the SSL CA system.\nTimestamp: $(date)\nHostname: ${hostname}" | sendmail -i -v -f"${from_address}" "${EMAIL}"; then
    echo "Test email queued successfully"
    echo "Checking mail queue..."
    mailq
else
    echo "Error sending test email"
    exit 1
fi
