#!/bin/bash
set -euxo pipefail

AWS_REGION="us-west-2"
DB_SECRET_ID="lab/rds/mysql"   # Secrets Manager secret name or ARN

dnf -y update || true
dnf -y install nginx python3 python3-pip jq
systemctl enable --now nginx

python3 -m pip install --upgrade pip || true
python3 -m pip install flask pymysql boto3

mkdir -p /opt/notesapp

cat >/opt/notesapp/app.py <<'PY'
import os, json, traceback
from flask import Flask, request
import boto3
import pymysql

REGION    = os.environ.get("AWS_REGION", "us-west-2")
SECRET_ID = os.environ.get("DB_SECRET_ID", "lab/rds/mysql")

app = Flask(__name__)

def get_secret():
    sm = boto3.client("secretsmanager", region_name=REGION)
    resp = sm.get_secret_value(SecretId=SECRET_ID)
    return json.loads(resp["SecretString"])

def conn():
    s = get_secret()
    host = s["host"]
    user = s["username"]
    pwd  = s["password"]
    port = int(s.get("port", 3306))
    return pymysql.connect(
        host=host, user=user, password=pwd, port=port,
        connect_timeout=5, autocommit=True
    )

@app.get("/")
def home():
    return (
        "EC2 → RDS Notes App\n"
        "Try:\n"
        "  /init\n"
        "  /add?note=first_note\n"
        "  /list\n"
    ), 200, {"Content-Type": "text/plain; charset=utf-8"}

@app.get("/init")
def init():
    try:
        c = conn()
        with c.cursor() as cur:
            cur.execute("CREATE DATABASE IF NOT EXISTS notes;")
            cur.execute("USE notes;")
            cur.execute("""
              CREATE TABLE IF NOT EXISTS notes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                note TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              );
            """)
        c.close()
        return "OK: initialized\n", 200, {"Content-Type": "text/plain; charset=utf-8"}
    except Exception as e:
        return (
            "ERROR /init:\n"
            f"{e}\n\n"
            + traceback.format_exc()
        ), 500, {"Content-Type": "text/plain; charset=utf-8"}

@app.route("/add", methods=["GET", "POST"])
def add():
    note = request.args.get("note") or request.form.get("note") or ""
    if not note:
        return "Missing ?note=\n", 400, {"Content-Type": "text/plain; charset=utf-8"}
    try:
        c = conn()
        with c.cursor() as cur:
            cur.execute("USE notes;")
            cur.execute("INSERT INTO notes (note) VALUES (%s)", (note,))
        c.close()
        return "OK: inserted\n", 200, {"Content-Type": "text/plain; charset=utf-8"}
    except Exception as e:
        return (
            "ERROR /add:\n"
            f"{e}\n\n"
            + traceback.format_exc()
        ), 500, {"Content-Type": "text/plain; charset=utf-8"}

@app.get("/list")
def list_notes():
    try:
        c = conn()
        with c.cursor() as cur:
            cur.execute("USE notes;")
            cur.execute("SELECT id, note, created_at FROM notes ORDER BY id DESC LIMIT 50;")
            rows = cur.fetchall()
        c.close()
        body = "\n".join([f"{r[0]} | {r[2]} | {r[1]}" for r in rows]) + "\n"
        return body, 200, {"Content-Type": "text/plain; charset=utf-8"}
    except Exception as e:
        return (
            "ERROR /list:\n"
            f"{e}\n\n"
            + traceback.format_exc()
        ), 500, {"Content-Type": "text/plain; charset=utf-8"}
PY

cat >/opt/notesapp/run.py <<'PY'
from app import app
app.run(host="127.0.0.1", port=5000)
PY

cat >/etc/systemd/system/notesapp.service <<SERVICE
[Unit]
Description=Flask Notes App
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/notesapp
Environment=AWS_REGION=${AWS_REGION}
Environment=DB_SECRET_ID=${DB_SECRET_ID}
ExecStart=/usr/bin/python3 /opt/notesapp/run.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now notesapp

# Nginx proxy (AL2023 default server includes /etc/nginx/default.d/*.conf)
mkdir -p /etc/nginx/default.d
rm -f /etc/nginx/conf.d/notesapp.conf || true

cat >/etc/nginx/default.d/notesapp.conf <<'NGINX'
location / {
  proxy_pass http://127.0.0.1:5000;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
}
NGINX

nginx -t

::contentReference[oaicite:0]{index=0}
