# Vaila Phonics Teaching Application (Flutter + Python FastAPI + Next.js)

A complete phonetics learning application for partially deaf children to learn and pronounce phonetics (A–Z) with **OpenAI Whisper AI** evaluation.

---

## Technical Stack & Architecture

```
c:\Users\abc\Desktop\Alphabets\
├── backend/               # Python FastAPI + OpenAI Whisper AI + SQLite
│   ├── main.py            # Whisper evaluation, phonemizer, Levenshtein edit distance
│   ├── requirements.txt   # FastAPI, Uvicorn, Python-Multipart
│   └── README.md
│
├── admin-dashboard/       # Next.js Admin Dashboard for Session Logs & Analytics
│   ├── app/
│   ├── package.json
│   └── README.md
│
└── frontend/              # Flutter Mobile App (Converted 1-to-1 from Vaila RN App)
    ├── lib/
    │   ├── screens/vaila_home_screen.dart   # Dark theme #0f172a UI, card shake, 3x audio loop
    │   └── main.dart
    └── pubspec.yaml
```

---

## Features
1. **3× Phonetic Sound Playback**: Tap card to hear the phonetic sound 3 times (`aaa`, `buh`, `kuh`, `dah`, `eh`) with live count banner (`1 of 3...`).
2. **12s Detection Window**: Automatic sound detection (`-40 dB` threshold metering) when the child speaks.
3. **OpenAI Whisper Speech Evaluation**: Audio recorded and posted to Python FastAPI `/api/evaluate-audio`.
4. **Card Shake & Error Haptics**: Triggers horizontal card shake animation & vibration on failure.
5. **Score & Feedback Card**: Displays accuracy %, transcription, and pass/fail feedback card.
6. **Next Alphabet Navigation**: Unlocks `NEXT ➔` button on successful pronunciation.

---

## How to Run

### 1. Start Python FastAPI Backend Server
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```
*Server runs at `http://localhost:8000`*

### 2. Start Next.js Admin Dashboard
```bash
cd admin-dashboard
npm install
npm run dev
```
*Dashboard runs at `http://localhost:3000`*

### 3. Start Flutter Mobile App
```bash
cd frontend
flutter run
```
