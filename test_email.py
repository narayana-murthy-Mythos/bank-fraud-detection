"""Quick SMTP sanity check — sends a test email to yourself using .env creds."""

import os
import smtplib
from email.mime.text import MIMEText

from dotenv import load_dotenv

load_dotenv()

SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")

msg = MIMEText("This is a test email from the Bank Fraud Detection project.")
msg["From"] = SMTP_USER
msg["To"] = SMTP_USER
msg["Subject"] = "[TEST] Bank Fraud Detection SMTP check"

with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
    server.starttls()
    server.login(SMTP_USER, SMTP_PASSWORD)
    server.send_message(msg)

print(f"✅ Test email sent to {SMTP_USER}")
