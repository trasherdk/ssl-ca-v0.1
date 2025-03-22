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

# Construct email headers and body
boundary="--==_boundary_${RANDOM}_${RANDOM}=="

email_content="From: SSL CA Monitor <${from_address}>
Date: ${date_header}
Message-ID: ${message_id}
To: ${EMAIL}
Reply-To: ${from_address}
X-Mailer: SSL CA Monitor/1.0
X-Priority: 1
Precedence: high
Importance: High
Auto-Submitted: auto-generated
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary=\"${boundary}\"
Subject: SSL CA Test Email

--${boundary}
Content-Type: text/plain; charset=us-ascii

This is a test email from the SSL CA system.
Timestamp: $(date)
Hostname: ${hostname}
Message-ID: ${message_id}

--${boundary}
Content-Type: text/html; charset=us-ascii

<!DOCTYPE html>
<html>
<head>
<meta charset=\"utf-8\">
<style>
body { font-family: Arial, sans-serif; }
.message { padding: 20px; background: #f8f9fa; border-radius: 5px; }
.footer { color: #666; font-size: 12px; margin-top: 20px; }
</style>
</head>
<body>
<div class=\"message\">
<h2>SSL CA System Test Email</h2>
<p>This is a test email from the SSL CA system.</p>
<p><strong>Timestamp:</strong> $(date)</p>
<p><strong>Hostname:</strong> ${hostname}</p>
<p><strong>Message-ID:</strong> ${message_id}</p>
</div>
<div class=\"footer\">
This is an automated message from the SSL CA Monitor system.
</div>
</body>
</html>

--${boundary}--"

# Send the email with debug output
if echo -e "${email_content}" "\r\n.\r\n" | sendmail -i -v -d11.1,60.5,12.4,8.5,5.6,3.5,20.4,40.8,41.10,45.5,48.2,16.14,21.12,9.0,9.1,9.2,9.3,9.4,9.5,9.6,9.7,9.8,9.9 -f ssl-ca@asus.fumlersoft.dk "${EMAIL}" 2>&1; then
    echo "\nTest email queued successfully"
    echo "\nChecking mail queue..."
    mailq
    
    echo "\nChecking recent mail logs..."
    echo "Last 20 lines of maillog:"
    tail -n 20 /var/log/maillog
    
    echo "\nChecking for specific message in logs..."
    grep -i "${message_id}" /var/log/maillog
    
    echo "\nWaiting 5 seconds to check for delayed status..."
    sleep 5
    echo "\nMail queue after delay:"
    mailq
else
    echo "Error sending test email"
    exit 1
fi
