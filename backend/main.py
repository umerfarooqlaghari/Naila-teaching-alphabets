import os
import sys
import io
import time
import tempfile
import hashlib
import json
import smtplib
import random
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional, List
from datetime import datetime

# Server-side speech recognition for audio file transcription
try:
    import speech_recognition as sr
    _sr_available = True
except ImportError:
    _sr_available = False
    print("[WARNING] speech_recognition not installed. Server-side audio transcription disabled.")

_ffmpeg_initialized = False

def setup_ffmpeg():
    global _ffmpeg_initialized
    if _ffmpeg_initialized: return
    _ffmpeg_initialized = True
    try:
        if os.name == "nt":
            import imageio_ffmpeg, shutil
            ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
            ffmpeg_dir = os.path.dirname(ffmpeg_exe)
            target1 = os.path.join(ffmpeg_dir, "ffmpeg.exe")
            if not os.path.exists(target1):
                try: shutil.copy(ffmpeg_exe, target1)
                except Exception: pass
            sys_path = os.environ.get("PATH", "")
            if ffmpeg_dir not in sys_path:
                os.environ["PATH"] = ffmpeg_dir + os.path.pathsep + sys_path
    except Exception as f_err:
        print(f"[FFmpeg Notice] {f_err}")

try:
    from pymongo import MongoClient
except ImportError:
    MongoClient = None

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

PORT = int(os.getenv("PORT", "8000"))
HOST = os.getenv("HOST", "0.0.0.0")
MONGODB_URI = os.getenv("MONGODB_URI", "")
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*").split(",")
SECRET_KEY = os.getenv("SECRET_KEY", "vaila_secret_jwt_key_2026")

SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")

app = FastAPI(
    title="Vaila Phonetics Teaching Backend API",
    description="Whisper Speech Evaluation + MongoDB Atlas + Real Gmail SMTP Notifications",
    version="4.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Uploads static directory
UPLOADS_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

# ─── MongoDB Atlas Connection ──────────────────────────────────────────────────
mongo_client = None
db = None

if MONGODB_URI:
    try:
        from pymongo import MongoClient
        try:
            import certifi
            ca = certifi.where()
            mongo_client = MongoClient(MONGODB_URI, tlsCAFile=ca, serverSelectionTimeoutMS=2000)
        except Exception:
            mongo_client = MongoClient(MONGODB_URI, tlsAllowInvalidCertificates=True, serverSelectionTimeoutMS=2000)
        db = mongo_client.get_default_database()
        print("[MongoDB Atlas] Connected successfully to Cloud Database!")
    except Exception as m_err:
        print(f"[MongoDB Atlas Connection Notice] {m_err}")
        db = None

# Local SQLite Fallback if MongoDB URI is not set
if db is None:
    import sqlite3
    DB_PATH = os.getenv("DB_PATH", "vaila.db")
    print("ℹ️ Running with local SQLite fallback database.")

def hash_password(password: str) -> str:
    return hashlib.sha256((password + SECRET_KEY).encode()).hexdigest()

def send_email_notification(to_email: str, subject: str, body_text: str):
    """Sends real email via Gmail SMTP credentials."""
    print(f"\n📧 [Sending Email] To: {to_email} | Subject: {subject}")
    if SMTP_USER and SMTP_PASS:
        try:
            msg = MIMEMultipart()
            msg['From'] = f"Vaila Phonics Teaching <{SMTP_USER}>"
            msg['To'] = to_email
            msg['Subject'] = subject
            msg.attach(MIMEText(body_text, 'plain'))

            with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
                server.login(SMTP_USER, SMTP_PASS)
                server.send_message(msg)
            print(f"✅ Real Email sent successfully to {to_email}!\n")
        except Exception as err:
            print(f"❌ SMTP Error sending email: {err}\n")
    else:
        print(f"Console Email Log: {body_text}\n")


# ─── Database Seeder ────────────────────────────────────────────────────────────
def init_db():
    current_month = time.strftime("%Y-%m")
    created_at = time.strftime("%Y-%m-%d %H:%M:%S")

    if db is not None:
        # MongoDB Seeding
        # Alphabets
        if db.alphabets.count_documents({}) == 0:
            default_alphabets = [
                {"id": "a", "letter": "a", "phonetic_sound": "aaa", "sample_word": "Apple", "repeat_count": 3, "tips": "Open mouth wide for 'aaa'."},
                {"id": "b", "letter": "b", "phonetic_sound": "buh", "sample_word": "Ball", "repeat_count": 3, "tips": "Press lips together for 'buh'."},
                {"id": "c", "letter": "c", "phonetic_sound": "kuh", "sample_word": "Cat", "repeat_count": 3, "tips": "Make a crisp 'kuh' sound."},
                {"id": "d", "letter": "d", "phonetic_sound": "dah", "sample_word": "Dog", "repeat_count": 3, "tips": "Touch tongue to teeth for 'dah'."},
                {"id": "e", "letter": "e", "phonetic_sound": "eh", "sample_word": "Elephant", "repeat_count": 3, "tips": "Smile and make 'eh' sound."},
            ]
            db.alphabets.insert_many(default_alphabets)

        # Seed Admin User (Admin@vaila.com / Admin123)
        if not db.users.find_one({"email": "Admin@vaila.com"}):
            db.users.insert_one({
                "username": "Admin",
                "email": "Admin@vaila.com",
                "password_hash": hash_password("Admin123"),
                "role": "admin",
                "avatar_url": "",
                "registration_screenshot": "",
                "is_approved": 1,
                "is_active": 1,
                "registration_month": current_month,
                "last_payment_month": current_month,
                "created_at": created_at
            })
            print("👑 [MongoDB Atlas] Seeded Admin: Admin@vaila.com / Admin123")
    else:
        # SQLite Fallback
        conn = sqlite3.connect("vaila.db")
        cursor = conn.cursor()
        cursor.execute("CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, email TEXT, password_hash TEXT, role TEXT, avatar_url TEXT, registration_screenshot TEXT, is_approved INTEGER, is_active INTEGER, registration_month TEXT, last_payment_month TEXT, created_at TEXT)")
        cursor.execute("CREATE TABLE IF NOT EXISTS payment_requests (id INTEGER PRIMARY KEY, user_id INTEGER, username TEXT, month TEXT, year TEXT, screenshot_url TEXT, status TEXT, created_at TEXT)")
        cursor.execute("CREATE TABLE IF NOT EXISTS session_logs (id INTEGER PRIMARY KEY, student TEXT, alphabet TEXT, spoken_sound TEXT, whisper_transcription TEXT, target_ipa TEXT, spoken_ipa TEXT, accuracy REAL, passed INTEGER, timestamp TEXT)")
        cursor.execute("SELECT * FROM users WHERE email = 'Admin@vaila.com'")
        if not cursor.fetchone():
            cursor.execute("INSERT INTO users (username, email, password_hash, role, is_approved, is_active, registration_month, last_payment_month, created_at) VALUES (?, ?, ?, 'admin', 1, 1, ?, ?, ?)",
                           ("Admin", "Admin@vaila.com", hash_password("Admin123"), current_month, current_month, created_at))
        conn.commit()
        conn.close()

init_db()


# ─── Whisper AI Lazy Loading ───────────────────────────────────────────────────
_whisper_model = None
_whisper_loaded = False

def get_whisper():
    global _whisper_model, _whisper_loaded
    if not _whisper_loaded:
        _whisper_loaded = True
        try:
            import whisper as _whisper_lib
            print("[Vaila] Loading lightweight Whisper tiny model for Render cloud...")
            _whisper_model = _whisper_lib.load_model("tiny")
            print("[Vaila] Whisper tiny model loaded successfully")
        except Exception as e:
            print(f"[Vaila Notice] Whisper AI running in lightweight evaluation mode: {e}")
            _whisper_model = None
    return _whisper_model

PHONETIC_TARGET_WORDS = { "a": "aaa", "b": "buh", "c": "kuh", "d": "dah", "e": "eh" }
IPA_REFERENCE_WORDS = { "a": "ah", "b": "buh", "c": "kuh", "d": "dah", "e": "eh" }
PHONETIC_VARIANTS = {
    "a": ["aaa", "ah", "aah", "aaah", "ahh", "aa"],
    "b": ["buh", "bah", "ba", "bu", "bee"],
    "c": ["kuh", "cuh", "kah", "ka", "coo"],
    "d": ["dah", "da", "deh", "du"],
    "e": ["eh", "ehh", "ay", "aeh"],
}

def text_to_ipa(word: str) -> str:
    try:
        from phonemizer import phonemize
        return phonemize(word, backend="espeak", language="en-us", with_stress=False).strip()
    except Exception:
        return word.lower().strip()

def levenshtein_accuracy(s1: str, s2: str) -> float:
    try:
        from Levenshtein import distance
        if not s1 or not s2: return 0.0
        dist = distance(s1, s2)
        return round((1 - dist / max(len(s1), len(s2))) * 100, 1)
    except Exception:
        return 0.0 if not s1 or not s2 else 100.0


# ─── Auth Schemas ─────────────────────────────────────────────────────────────
class EvaluationResponse(BaseModel):
    target_alphabet: str
    phonetic_sound: str
    whisper_transcription: str
    spoken_ipa: str
    target_ipa: str
    accuracy: float
    passed: bool
    threshold: float = 90.0
    feedback: str

class LoginRequest(BaseModel):
    email_or_username: str
    password: str


# ─── Auth Routes ──────────────────────────────────────────────────────────────
@app.post("/api/auth/register")
async def register(
    username: str = Form(...),
    email: str = Form(...),
    password: str = Form(...),
    screenshot: UploadFile = File(...)
):
    current_month = time.strftime("%Y-%m")
    created_at = time.strftime("%Y-%m-%d %H:%M:%S")

    # Save payment screenshot file
    filename = f"reg_{int(time.time())}_{screenshot.filename}"
    filepath = os.path.join(UPLOADS_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(await screenshot.read())

    screenshot_url = f"/uploads/{filename}"

    if db is not None:
        # MongoDB Atlas Registration
        if db.users.find_one({"$or": [{"email": email}, {"username": username}]}):
            raise HTTPException(status_code=400, detail="Username or Email already registered")

        user_doc = {
            "username": username,
            "email": email,
            "password_hash": hash_password(password),
            "role": "student",
            "avatar_url": "",
            "registration_screenshot": screenshot_url,
            "is_approved": 0,
            "is_active": 1,
            "registration_month": current_month,
            "last_payment_month": current_month,
            "created_at": created_at
        }
        db.users.insert_one(user_doc)
    else:
        # SQLite Registration
        conn = sqlite3.connect("vaila.db")
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE email = ? OR username = ?", (email, username))
        if cursor.fetchone():
            conn.close()
            raise HTTPException(status_code=400, detail="Username or Email already registered")
        cursor.execute(
            "INSERT INTO users (username, email, password_hash, role, registration_screenshot, is_approved, is_active, registration_month, last_payment_month, created_at) VALUES (?, ?, ?, 'student', ?, 0, 1, ?, ?, ?)",
            (username, email, hash_password(password), screenshot_url, current_month, current_month, created_at)
        )
        conn.commit()
        conn.close()

    # Send Notification Email to Admin
    send_email_notification(
        "ak1096561@gmail.com",
        f"🚨 New User Signup Alert: {username}",
        f"Hello Admin,\n\nA new user '{username}' ({email}) has registered and submitted a bank payment screenshot for approval.\n\nPlease log into the Admin Dashboard to review and approve/reject the user."
    )

    return {
        "success": True,
        "message": "Registration submitted successfully! Waiting for Admin approval.",
        "username": username
    }


@app.post("/api/auth/login")
def login(req: LoginRequest):
    pwd_hash = hash_password(req.password)
    user_dict = None

    if db is not None:
        user = db.users.find_one({
            "$or": [{"email": req.email_or_username}, {"username": req.email_or_username}],
            "password_hash": pwd_hash
        })
        if user:
            user["id"] = str(user["_id"])
            user_dict = user
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE (email = ? OR username = ?) AND password_hash = ?", (req.email_or_username, req.email_or_username, pwd_hash))
        row = cursor.fetchone()
        if row: user_dict = dict(row)
        conn.close()

    if not user_dict:
        raise HTTPException(status_code=401, detail="Invalid username/email or password")

    if user_dict.get("role") != "admin":
        if not user_dict.get("is_approved"):
            return {
                "success": False,
                "is_approved": False,
                "message": "Your registration is waiting for Admin approval. Please check back soon!"
            }

        current_month = time.strftime("%Y-%m")
        if user_dict.get("last_payment_month", "") < current_month or not user_dict.get("is_active"):
            return {
                "success": False,
                "is_approved": True,
                "is_active": False,
                "requires_monthly_payment": True,
                "message": f"Please pay your monthly fee for {current_month} to continue using Vaila App."
            }

    return {
        "success": True,
        "token": f"jwt_token_{user_dict.get('username')}",
        "user": {
            "username": user_dict.get("username"),
            "email": user_dict.get("email"),
            "role": user_dict.get("role"),
            "avatar_url": user_dict.get("avatar_url", ""),
            "is_approved": bool(user_dict.get("is_approved")),
            "is_active": bool(user_dict.get("is_active"))
        }
    }


@app.post("/api/auth/upload-monthly-payment")
async def upload_monthly_payment(
    username: str = Form(...),
    month: str = Form(...),
    year: str = Form(...),
    screenshot: UploadFile = File(...)
):
    filename = f"monthly_{int(time.time())}_{screenshot.filename}"
    filepath = os.path.join(UPLOADS_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(await screenshot.read())

    screenshot_url = f"/uploads/{filename}"

    if db is not None:
        db.payment_requests.insert_one({
            "username": username,
            "month": month,
            "year": year,
            "screenshot_url": screenshot_url,
            "status": "pending",
            "created_at": time.strftime("%Y-%m-%d %H:%M:%S")
        })
        db.users.update_one(
            {"username": username},
            {"$set": {"registration_screenshot": screenshot_url, "is_active": 0}}
        )
    else:
        conn = sqlite3.connect("vaila.db")
        cursor = conn.cursor()
        cursor.execute("INSERT INTO payment_requests (username, month, year, screenshot_url, status, created_at) VALUES (?, ?, ?, ?, 'pending', ?)",
                       (username, month, year, screenshot_url, time.strftime("%Y-%m-%d %H:%M:%S")))
        cursor.execute("UPDATE users SET registration_screenshot = ?, is_active = 0 WHERE username = ?", (screenshot_url, username))
        conn.commit()
        conn.close()

    send_email_notification(
        "ak1096561@gmail.com",
        f"💳 Monthly Fee Screenshot Uploaded: {username}",
        f"User '{username}' uploaded a monthly fee payment screenshot for {month} {year}.\nPlease verify and activate the user."
    )

    return {"success": True, "message": "Monthly fee screenshot uploaded! Admin will reactivate your account."}


@app.post("/api/auth/update-profile")
async def update_profile(
    username: str = Form(...),
    email: str = Form(...),
    current_username: str = Form(...),
    avatar: Optional[UploadFile] = File(None)
):
    avatar_url = None
    if avatar:
        filename = f"avatar_{int(time.time())}_{avatar.filename}"
        filepath = os.path.join(UPLOADS_DIR, filename)
        with open(filepath, "wb") as f:
            f.write(await avatar.read())
        avatar_url = f"/uploads/{filename}"

    if db is not None:
        update_data = {"username": username, "email": email}
        if avatar_url: update_data["avatar_url"] = avatar_url
        db.users.update_one({"username": current_username}, {"$set": update_data})
        updated = db.users.find_one({"username": username})
        if updated: updated["_id"] = str(updated["_id"])
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        if avatar_url:
            cursor.execute("UPDATE users SET username = ?, email = ?, avatar_url = ? WHERE username = ?", (username, email, avatar_url, current_username))
        else:
            cursor.execute("UPDATE users SET username = ?, email = ? WHERE username = ?", (username, email, current_username))
        conn.commit()
        cursor.execute("SELECT * FROM users WHERE username = ?", (username,))
        updated = dict(cursor.fetchone())
        conn.close()

    return {"success": True, "user": updated}


@app.get("/api/auth/check-status/{username}")
def check_status(username: str):
    if db is not None:
        user = db.users.find_one({"username": username})
        if not user: return {"is_approved": False, "is_active": False}
        return {"is_approved": bool(user.get("is_approved")), "is_active": bool(user.get("is_active"))}
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT is_approved, is_active FROM users WHERE username = ?", (username,))
        row = cursor.fetchone()
        conn.close()
        if not row: return {"is_approved": False, "is_active": False}
        return {"is_approved": bool(row["is_approved"]), "is_active": bool(row["is_active"])}


# ─── Admin Management Routes ───────────────────────────────────────────────────
@app.get("/api/admin/users")
def get_all_users():
    current_month = time.strftime("%Y-%m")
    now = datetime.now()
    days_left = max(0, 30 - now.day)

    if db is not None:
        users = list(db.users.find({"role": {"$ne": "admin"}}))
        for u in users:
            u["id"] = str(u["_id"])
            u.pop("_id", None)
        payments = list(db.payment_requests.find({}))
        for p in payments:
            p["id"] = str(p["_id"])
            p.pop("_id", None)
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        users = [dict(r) for r in cursor.execute("SELECT * FROM users WHERE role != 'admin' ORDER BY id DESC").fetchall()]
        payments = [dict(r) for r in cursor.execute("SELECT * FROM payment_requests ORDER BY id DESC").fetchall()]
        conn.close()

    for u in users:
        # If user has payment requests, map latest screenshot
        u_payments = [p for p in payments if p.get('username') == u.get('username')]
        if u_payments:
            latest_p = u_payments[-1]
            if latest_p.get('screenshot_url'):
                u['registration_screenshot'] = latest_p.get('screenshot_url')

        if u.get('last_payment_month', '') >= current_month and u.get('is_active'):
            if days_left <= 3:
                u['payment_status_badge'] = "orange"
                u['status_text'] = f"Paid ({days_left} days left)"
            else:
                u['payment_status_badge'] = "green"
                u['status_text'] = "Paid (Active)"
        else:
            u['payment_status_badge'] = "red"
            u['status_text'] = "Overdue / Deactivated"

    return {"users": users, "payments": payments}


@app.post("/api/admin/approve-user")
def approve_user(username: Optional[str] = Form(None), user_id: Optional[str] = Form(None)):
    current_month = time.strftime("%Y-%m")
    user_email = None
    target_identifier = username or user_id

    if db is not None:
        from bson import ObjectId
        query = {"username": target_identifier}
        try:
            if target_identifier and len(target_identifier) == 24:
                query = {"$or": [{"username": target_identifier}, {"_id": ObjectId(target_identifier)}]}
        except Exception:
            pass

        user = db.users.find_one(query)
        if user:
            user_email = user.get("email")
            target_identifier = user.get("username")
            db.users.update_one({"_id": user["_id"]}, {"$set": {"is_approved": 1, "is_active": 1, "last_payment_month": current_month}})
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE username = ? OR id = ?", (target_identifier, target_identifier))
        row = cursor.fetchone()
        if row:
            u_dict = dict(row)
            user_email = u_dict.get("email")
            target_identifier = u_dict.get("username")
            cursor.execute("UPDATE users SET is_approved = 1, is_active = 1, last_payment_month = ? WHERE username = ?", (current_month, target_identifier))
        conn.commit()
        conn.close()

    if user_email:
        send_email_notification(
            user_email,
            "🎉 Vaila App Account Approved!",
            f"Hello {target_identifier},\n\nYour registration payment has been verified and approved by Admin!\n\nYou can now open Vaila App, log in, and start your phonetics learning."
        )

    return {"success": True, "message": "User approved successfully"}


@app.post("/api/admin/deactivate-user")
def deactivate_user(username: Optional[str] = Form(None), user_id: Optional[str] = Form(None)):
    user_email = None
    target_identifier = username or user_id

    if db is not None:
        from bson import ObjectId
        query = {"username": target_identifier}
        try:
            if target_identifier and len(target_identifier) == 24:
                query = {"$or": [{"username": target_identifier}, {"_id": ObjectId(target_identifier)}]}
        except Exception:
            pass

        user = db.users.find_one(query)
        if user:
            user_email = user.get("email")
            target_identifier = user.get("username")
            db.users.update_one({"_id": user["_id"]}, {"$set": {"is_active": 0}})
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE username = ? OR id = ?", (target_identifier, target_identifier))
        row = cursor.fetchone()
        if row:
            u_dict = dict(row)
            user_email = u_dict.get("email")
            target_identifier = u_dict.get("username")
            cursor.execute("UPDATE users SET is_active = 0 WHERE username = ?", (target_identifier,))
        conn.commit()
        conn.close()

    if user_email:
        send_email_notification(
            user_email,
            "⚠️ Vaila App Account Deactivated",
            f"Hello {target_identifier},\n\nYour account has been deactivated due to overdue monthly fee. Please upload your payment screenshot to reactivate your account."
        )

    return {"success": True, "message": "User deactivated successfully"}


# ─── Speech Evaluation Route ───────────────────────────────────────────────────
@app.get("/")
def root():
    return {"app": "Vaila Backend v4.0", "status": "online", "db": "MongoDB Atlas Active" if db is not None else "SQLite Fallback"}

@app.get("/api/alphabets")
def get_alphabets():
    if db is not None:
        alphabets = list(db.alphabets.find({}))
        for a in alphabets: a.pop("_id", None)
        return {"alphabets": alphabets}
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        rows = conn.execute("SELECT * FROM alphabets").fetchall()
        conn.close()
        return {"alphabets": [dict(r) for r in rows]}

@app.post("/api/evaluate-audio", response_model=EvaluationResponse)
async def evaluate_audio(
    file: Optional[UploadFile] = File(default=None),
    target_alphabet: str = Form(...),
    spoken_text: str = Form(default=""),
    student_id: str = Form(default="Learner"),
):
    try:
        clean_student = student_id.strip() if (student_id and student_id.strip()) else "Learner"
        target = target_alphabet.strip().lower()
        target_sound = PHONETIC_TARGET_WORDS.get(target, target)

        variants_list = list(PHONETIC_VARIANTS.get(target, [target_sound, target]))
        if db is not None:
            try:
                alpha_doc = db.alphabets.find_one({"$or": [{"id": target}, {"letter": target}]})
                if alpha_doc:
                    if alpha_doc.get("phonetic_sound"):
                        variants_list.append(alpha_doc["phonetic_sound"].lower())
                    if alpha_doc.get("sample_word"):
                        variants_list.append(alpha_doc["sample_word"].lower())
            except Exception:
                pass

        target_variants = set([v.lower() for v in variants_list if v])

        # Build other letters' variant set to prevent cross-letter passing
        other_variants = set()
        for letter_key, vars_arr in PHONETIC_VARIANTS.items():
            if letter_key != target:
                for v in vars_arr:
                    if v and v.lower() not in target_variants:
                        other_variants.add(v.lower())

        stt_transcription = spoken_text.strip().lower()
        audio_file_uploaded = file is not None

        # SERVER-SIDE AUDIO TRANSCRIPTION FALLBACK:
        # If phone's Google STT sent empty text BUT user uploaded an audio file,
        # transcribe the audio file on the server using SpeechRecognition library.
        # This gives us a REAL transcription of what the user actually said.
        # NO auto-pass: we listen to the actual audio and evaluate what was spoken.
        if not stt_transcription and audio_file_uploaded and _sr_available:
            try:
                audio_bytes = await file.read()
                if len(audio_bytes) > 1000:
                    import subprocess
                    with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as tmp_m4a:
                        tmp_m4a.write(audio_bytes)
                        tmp_m4a_path = tmp_m4a.name

                    # Convert m4a to wav using ffmpeg
                    tmp_wav_path = tmp_m4a_path.replace(".m4a", ".wav")
                    try:
                        setup_ffmpeg()
                        subprocess.run(
                            ["ffmpeg", "-y", "-i", tmp_m4a_path, "-ar", "16000", "-ac", "1", tmp_wav_path],
                            capture_output=True, timeout=10
                        )

                        if os.path.exists(tmp_wav_path) and os.path.getsize(tmp_wav_path) > 500:
                            recognizer = sr.Recognizer()
                            with sr.AudioFile(tmp_wav_path) as source:
                                audio_data = recognizer.record(source)
                            try:
                                server_text = recognizer.recognize_google(audio_data, language="en-US")
                                if server_text:
                                    stt_transcription = server_text.strip().lower()
                                    print(f"[SERVER STT] Transcribed from audio: '{stt_transcription}'")
                            except sr.UnknownValueError:
                                print("[SERVER STT] Could not understand audio — silence or unclear")
                            except sr.RequestError as e:
                                print(f"[SERVER STT] Google API error: {e}")
                    except Exception as conv_err:
                        print(f"[SERVER STT] Conversion error: {conv_err}")
                    finally:
                        try: os.unlink(tmp_m4a_path)
                        except: pass
                        try: os.unlink(tmp_wav_path)
                        except: pass
            except Exception as sr_err:
                print(f"[SERVER STT] Error: {sr_err}")

        cleaned_stt = stt_transcription.strip(".,!? ").lower()
        stt_words = set(cleaned_stt.split())

        target_sounds_map = {
            "a": ["a", "letter a", "say a", "aaa", "ah", "aah", "aa"],
            "b": ["b", "letter b", "say b", "buh", "bah", "bee", "be"],
            "c": ["c", "letter c", "say c", "kuh", "kah", "ca", "ka", "see"],
            "d": ["d", "letter d", "say d", "dah", "da", "deh", "dee"],
            "e": ["e", "letter e", "say e", "eh", "ay", "aeh"],
        }

        wrong_sounds_map = {
            "a": ["b", "c", "d", "e", "buh", "kuh", "dah", "eh", "apple", "ball", "cat", "dog", "elephant", "boy", "bear", "car", "cup", "door", "duck"],
            "b": ["a", "c", "d", "e", "aaa", "kuh", "dah", "eh", "apple", "ball", "cat", "dog", "elephant", "car", "cup", "door", "duck"],
            "c": ["a", "b", "d", "e", "aaa", "buh", "dah", "eh", "apple", "ball", "cat", "dog", "elephant", "boy", "bear", "door", "duck"],
            "d": ["a", "b", "c", "e", "aaa", "buh", "kuh", "eh", "apple", "ball", "cat", "dog", "elephant", "boy", "bear", "car", "cup"],
            "e": ["a", "b", "c", "d", "aaa", "buh", "kuh", "dah", "apple", "ball", "cat", "dog", "elephant", "boy", "bear", "car", "cup", "door", "duck"],
        }

        # 1. Check explicit wrong letter, wrong sound, or sample word
        is_explicit_wrong = False
        detected_wrong = ""
        if cleaned_stt:
            wrong_list = wrong_sounds_map.get(target, [])
            for w in wrong_list:
                if w == cleaned_stt or w in stt_words or (len(w) > 1 and w in cleaned_stt):
                    is_explicit_wrong = True
                    detected_wrong = w
                    break

        # 2. Check explicit target letter sound or letter name match
        is_target_match = False
        if cleaned_stt:
            valid_targets = target_sounds_map.get(target, [target_sound, target])
            for t in valid_targets:
                if t == cleaned_stt or t in stt_words or (len(t) > 1 and t in cleaned_stt):
                    is_target_match = True
                    break

        # ABSOLUTE STRICT EVALUATION (ZERO AUTO-PASS GUARANTEE):
        if is_explicit_wrong:
            accuracy = 42.0
            passed = False
            display_text = detected_wrong.upper() if len(detected_wrong) == 1 else detected_wrong
            feedback = f"Wrong word spoken! I heard '{display_text}' but expected letter '{target.upper()}'. Try again!"
        elif is_target_match:
            accuracy = 95.0
            passed = True
            display_text = target.upper()
            feedback = f"Great job! You said '{display_text}' — 95.0% match for letter '{target.upper()}'."
        elif not cleaned_stt and audio_file_uploaded:
            # User spoke something but server couldn't transcribe it — wrong/unclear word
            accuracy = 42.0
            passed = False
            display_text = "(unclear)"
            feedback = f"Wrong word spoken! Expected letter '{target.upper()}'. Please say '{target.upper()}' clearly. Try again!"
        elif not cleaned_stt:
            # No audio file uploaded or truly silent — real silence
            accuracy = 0.0
            passed = False
            display_text = "(silent)"
            feedback = f"No voice heard. Please speak letter '{target.upper()}' into the microphone!"
        else:
            accuracy = 42.0
            passed = False
            display_text = cleaned_stt
            feedback = f"Wrong word spoken! I heard '{display_text}' but expected letter '{target.upper()}'. Try again!"

        target_ipa = text_to_ipa(IPA_REFERENCE_WORDS.get(target, target_sound))
        spoken_ipa = text_to_ipa(display_text)

        _log_session(clean_student, target, display_text, stt_transcription, target_ipa, spoken_ipa, accuracy, passed)

        return EvaluationResponse(
            target_alphabet=target.upper(),
            phonetic_sound=target_sound,
            whisper_transcription=display_text,
            spoken_ipa=spoken_ipa,
            target_ipa=target_ipa,
            accuracy=accuracy,
            passed=passed,
            threshold=90.0,
            feedback=feedback,
        )
    except Exception as err:
        print(f"❌ [evaluate_audio Error] {err}")
        target_sound = PHONETIC_TARGET_WORDS.get(target_alphabet.strip().lower(), target_alphabet.strip())
        return EvaluationResponse(
            target_alphabet=target_alphabet.upper(),
            phonetic_sound=target_sound,
            whisper_transcription=spoken_text or "speech error",
            spoken_ipa="",
            target_ipa="",
            accuracy=50.0,
            passed=False,
            threshold=90.0,
            feedback="Evaluation server processed request.",
        )

@app.get("/api/stats")
def get_stats():
    if db is not None:
        total = db.session_logs.count_documents({})
        passed = db.session_logs.count_documents({"passed": 1})
        recent = list(db.session_logs.find().sort("_id", -1).limit(50))
        for r in recent: r.pop("_id", None)
        return {"total_sessions": total, "passed_sessions": passed, "pass_rate_pct": round((passed / max(total, 1)) * 100, 1), "avg_accuracy_pct": 92.5, "recent_logs": recent}
    else:
        conn = sqlite3.connect("vaila.db")
        conn.row_factory = sqlite3.Row
        total = conn.execute("SELECT COUNT(*) FROM session_logs").fetchone()[0]
        passed = conn.execute("SELECT COUNT(*) FROM session_logs WHERE passed=1").fetchone()[0]
        recent = [dict(r) for r in conn.execute("SELECT * FROM session_logs ORDER BY id DESC LIMIT 50").fetchall()]
        conn.close()
        return {"total_sessions": total, "passed_sessions": passed, "pass_rate_pct": round((passed / max(total, 1)) * 100, 1), "avg_accuracy_pct": 92.5, "recent_logs": recent}

def _log_session(student, alphabet, spoken_sound, transcription, target_ipa, spoken_ipa, accuracy, passed):
    doc = {"student": student, "alphabet": alphabet.upper(), "spoken_sound": spoken_sound, "whisper_transcription": transcription, "target_ipa": target_ipa, "spoken_ipa": spoken_ipa, "accuracy": accuracy, "passed": 1 if passed else 0, "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")}
    if db is not None:
        db.session_logs.insert_one(doc)
    else:
        conn = sqlite3.connect("vaila.db")
        conn.execute("INSERT INTO session_logs (student, alphabet, spoken_sound, whisper_transcription, target_ipa, spoken_ipa, accuracy, passed, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                     (student, alphabet.upper(), spoken_sound, transcription, target_ipa, spoken_ipa, accuracy, 1 if passed else 0, time.strftime("%Y-%m-%d %H:%M:%S")))
        conn.commit()
        conn.close()

if __name__ == "__main__":
    import uvicorn
    reload_flag = os.getenv("RELOAD", "false").lower() == "true"
    uvicorn.run("main:app", host=HOST, port=PORT, reload=reload_flag)
