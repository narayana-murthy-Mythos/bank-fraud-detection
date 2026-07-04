"""Notification queue worker.

Polls the notification_queue table every 5 seconds and processes any
unprocessed events (prints them; swap send_email for real delivery).
"""

import os
import time

import psycopg2
from dotenv import load_dotenv

load_dotenv()

conn = psycopg2.connect(
    host=os.getenv("DB_HOST", "localhost"),
    database=os.getenv("DB_NAME", "frauddb"),
    user=os.getenv("DB_USER", "postgres"),
    password=os.getenv("DB_PASSWORD", ""),
    port=int(os.getenv("DB_PORT", "5432")),
)

conn.autocommit = True
cursor = conn.cursor()


def send_email(account_id, message):
    print(f"[EMAIL SENT] Account: {account_id} | Message: {message}")


print("Notification worker started — polling every 5s (Ctrl+C to stop)")

while True:
    cursor.execute("""
        SELECT notification_id, account_id, message
        FROM notification_queue
        WHERE processed = false
        ORDER BY created_at
    """)

    rows = cursor.fetchall()

    for notification_id, account_id, message in rows:
        send_email(account_id, message)

        cursor.execute("""
            UPDATE notification_queue
            SET processed = true
            WHERE notification_id = %s
        """, (notification_id,))

    time.sleep(5)
