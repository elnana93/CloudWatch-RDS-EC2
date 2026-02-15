#!/bin/bash
set -euxo pipefail

AWS_REGION="us-west-2"
DB_SECRET_ID="lab/rds/mysql"   # Secrets Manager secret name or ARN
SSM_PREFIX="/lab1b/db"
LOG_GROUP="/lab1b/app"
APP_LOG="/var/log/app.log"

dnf -y update || true
dnf -y install nginx python3 python3-pip jq amazon-cloudwatch-agent
systemctl enable --now nginx

# --- Lab1b: CloudWatch Agent ships /var/log/app.log to CloudWatch Logs ---
touch "${APP_LOG}"
chmod 644 "${APP_LOG}"

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<JSON
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "${APP_LOG}",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
JSON

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

python3 -m pip install --upgrade pip || true
python3 -m pip install flask pymysql boto3

mkdir -p /opt/notesapp

cat >/opt/notesapp/app.py <<'PY'
import os, json, traceback, logging
from flask import Flask, request
import boto3
import pymysql

REGION    = os.environ.get("AWS_REGION", "us-west-2")
SECRET_ID = os.environ.get("DB_SECRET_ID", "lab/rds/mysql")
SSM_PREFIX = os.environ.get("SSM_PREFIX", "/lab1b/db")

APP_LOG = "/var/log/app.log"

app = Flask(__name__)

logging.basicConfig(
    filename=APP_LOG,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

def get_db_params():
    ssm = boto3.client("ssm", region_name=REGION)
    host = ssm.get_parameter(Name=f"{SSM_PREFIX}/host")["Parameter"]["Value"]
    port = int(ssm.get_parameter(Name=f"{SSM_PREFIX}/port")["Parameter"]["Value"])
    db   = ssm.get_parameter(Name=f"{SSM_PREFIX}/name")["Parameter"]["Value"]
    return host, port, db

def get_db_creds():
    sm = boto3.client("secretsmanager", region_name=REGION)
    resp = sm.get_secret_value(SecretId=SECRET_ID)
    s = json.loads(resp["SecretString"])
    return s["username"], s["password"]

def conn():
    try:
        host, port, db = get_db_params()
        user, pwd = get_db_creds()
        return pymysql.connect(
            host=host, user=user, password=pwd, port=port, database=db,
            connect_timeout=5, autocommit=True
        )
    except Exception as e:
        # IMPORTANT: metric filter looks for this token
        logging.error(f"DB_CONNECTION_FAILURE: {e}")
        raise

@app.get("/")
def home():
    return (
        "EC2 → RDS Notes App (Lab1b)\n"
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
        return ("ERROR /init:\n" f"{e}\n\n" + traceback.format_exc()), 500, {"Content-Type": "text/plain; charset=utf-8"}

@app.route("/add", methods=["GET", "POST"])
def add():
    note = request.args.get("note") or request.form.get("note") or ""
    if not note:
        return "Missing ?note=\n", 400, {"Content-Type": "text/plain; charset=utf-8"}
    try:
        c = conn()
        with c.cursor() as cur:
            cur.execute("INSERT INTO notes (note) VALUES (%s)", (note,))
        c.close()
        return "OK: inserted\n", 200, {"Content-Type": "text/plain; charset=utf-8"}
    except Exception as e:
        return ("ERROR /add:\n" f"{e}\n\n" + traceback.format_exc()), 500, {"Content-Type": "text/plain; charset=utf-8"}

@app.get("/list")
def list_notes():
    try:
        c = conn()
        with c.cursor() as cur:
            cur.execute("SELECT id, note, created_at FROM notes ORDER BY id DESC LIMIT 50;")
            rows = cur.fetchall()
        c.close()
        body = "\n".join([f"{r[0]} | {r[2]} | {r[1]}" for r in rows]) + "\n"
        return body, 200, {"Content-Type": "text/plain; charset=utf-8"}
    except Exception as e:
        return ("ERROR /list:\n" f"{e}\n\n" + traceback.format_exc()), 500, {"Content-Type": "text/plain; charset=utf-8"}
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
Environment=SSM_PREFIX=${SSM_PREFIX}
ExecStart=/usr/bin/python3 /opt/notesapp/run.py
Restart=always
RestartSec=3
StandardOutput=append:/var/log/app.log
StandardError=append:/var/log/app.log

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
systemctl reload nginx || true
