# Vaila Teaching App - Python Backend API

FastAPI service powering the speech recognition and pronunciation evaluation system for partially deaf children.

## Features
- **Phonetics Evaluation Engine**: Evaluates speech accuracy against target alphabets.
- **Accuracy Thresholding**: Checks if accuracy meets the 90%-100% threshold.
- **Session Analytics**: Serves stats to the Next.js Admin Dashboard.

## Setup & Run

1. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Run server**:
   ```bash
   python main.py
   # OR
   uvicorn main:app --reload --port 8000
   ```

3. **API Documentation**:
   Access `http://localhost:8000/docs` for Swagger UI.
