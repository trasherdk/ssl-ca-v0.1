#!/usr/bin/env python3
import socket, ssl, sys, time

port = 587
rows = []
for i in range(20):
    t0 = time.monotonic()
    s = socket.create_connection(("84.246.247.252", port), 15)
    s.settimeout(10)
    f = s.makefile("rwb", buffering=0)
    f.readline()
    f.write(b"EHLO tit-pakchong.fumlersoft.dk\r\n")
    lines = []
    while True:
        line = f.readline()
        lines.append(line.decode("ascii", "replace").rstrip())
        if not line.startswith(b"250-"):
            break
    text = "\n".join(lines)
    size = next((ln for ln in lines if ln.startswith("250-SIZE")), "")
    rows.append(("TLS" if "STARTTLS" in text else "CLEAR", size, round(time.monotonic() - t0, 3), s.getsockname()[1]))
    f.write(b"QUIT\r\n")
    s.close()
    time.sleep(0.25)
print("EHLO")
for r in rows:
    print(f"{r[3]} {r[0]} {r[1]} {r[2]}s")
tls = sum(1 for r in rows if r[0] == "TLS")
clear = sum(1 for r in rows if r[0] == "CLEAR")
ctx = ssl.create_default_context(cafile="/etc/mail/certs/ca.crt")
s = socket.create_connection(("mail.fumlersoft.dk", port), 15)
f = s.makefile("rwb", buffering=0)
f.readline()
f.write(b"EHLO tit-pakchong.fumlersoft.dk\r\n")
offer = []
while True:
    line = f.readline()
    offer.append(line.decode("ascii", "replace").rstrip())
    if not line.startswith(b"250-"):
        break
handshake_ok = False
if not any(ln.startswith("250-STARTTLS") or ln == "250 STARTTLS" for ln in offer):
    size = next((ln for ln in offer if ln.startswith("250-SIZE")), "")
    print(f"no STARTTLS in EHLO ({size}); not starting TLS")
    f.write(b"QUIT\r\n")
    s.close()
else:
    f.write(b"STARTTLS\r\n")
    reply = f.readline().decode().rstrip()
    print("STARTTLS", reply)
    if reply.startswith("220"):
        try:
            ss = ctx.wrap_socket(s, server_hostname="mail.fumlersoft.dk")
            print("version", ss.version(), "cipher", ss.cipher()[0])
            cert = ss.getpeercert()
            print("subject", cert.get("subject"))
            ss.close()
            handshake_ok = True
        except ssl.SSLError as err:
            print(err)
            s.close()
    else:
        s.close()
print(f"{'ok' if clear == 0 and handshake_ok else 'not ok'} TLS={tls} CLEAR={clear}")
sys.exit(0 if clear == 0 and handshake_ok else 1)
