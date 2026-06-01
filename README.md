# 🐾 Risky Pets

An AI-powered Flutter mobile app that assesses health and zoonotic disease risks from animal interactions using Google Gemini and Firebase.

---

## 📱 What It Does

You take a photo of an animal, describe your interaction with it, and the app returns an instant AI-driven risk assessment — including the risk level, detected health flags, and step-by-step first-aid advice.

---

## ✨ Features

- **AI Risk Assessment** — Powered by Google Gemini 2.5 Flash; analyzes image + user inputs together
- **Interaction Details** — Select bite / scratch / touch, wound characteristics, and behavioral signs
- **Structured Results** — Risk level (LOW → CRITICAL), bite risk, health flags, assessment text, and medical advice
- **Scan History** — All scans saved to Firestore with image thumbnails and full detail view
- **Authentication** — Email/password and Google Sign-In via Firebase Auth
- **Guest Mode** — Use the app without an account; scans migrate automatically on sign-in
- **Dark Mode** — Persistent theme toggle via SharedPreferences
- **Profile Management** — Update username, email, and password from within the app

---

## 🗂 Project Structure

```
Risky-Pets/
├── Back-end/               # Python FastAPI backend
│   ├── main.py             # API endpoint
│   ├── inference.py        # Gemini agent logic
│   ├── schemas.py          # Pydantic response models
│   ├── requirements.txt
│   └── Dockerfile          # Deploys to Google Cloud Run
│
└── Risky-Pets/             # Flutter frontend
    └── lib/
        ├── main.dart           # App entry point & theme
        ├── base.dart           # Nav shell (drawer + app bar)
        ├── home.dart           # Assessment screen
        ├── history.dart        # Scan history
        ├── profile.dart        # User profile
        ├── settings.dart       # App settings
        ├── sign_in.dart        # Sign-in screen
        ├── sign_up.dart        # Sign-up screen
        ├── api_service.dart    # HTTP client + response models
        └── guest_id.dart       # Guest session management
```

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Python · FastAPI · Uvicorn |
| AI Model | Google Gemini 2.5 Flash (`google-genai`) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Hosting | Google Cloud Run |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `^3.11`
- Python `3.11+`
- A Firebase project with Auth, Firestore, and Storage enabled
- A Google Gemini API key

---

### Backend

```bash
cd Back-end
pip install -r requirements.txt
export GOOGLE_API_KEY=your_gemini_api_key
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`.  
To deploy to Cloud Run, use the provided `Dockerfile` and `deploy.sh`.

---

### Flutter App

```bash
cd Risky-Pets
flutter pub get
flutter run
```

> Make sure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) from your Firebase project are placed in the correct platform directories before running.

Update the API base URL in `lib/api_service.dart` if you are running the backend locally:

```dart
static const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator
```

---

## 🔌 API

### `POST /api/consult-agent/`

**Form fields:**

| Field | Type | Description |
|---|---|---|
| `file` | image | Photo of the animal (required) |
| `interaction_type` | string | `bite`, `scratch`, or `touch` |
| `broke_skin` | boolean | Whether skin was broken |
| `deep_puncture` | boolean | Whether wound is a deep puncture |
| `lesion_oozing` | boolean | Whether lesion is oozing/infected |
| `rabies_signs` | boolean | Aggression or drooling observed |
| `note` | string | Optional free-text note |

**Response:**

```json
{
  "animal_type": "Dog",
  "risk_level": "HIGH",
  "bite_risk_level": "High",
  "health_flags": [
    { "issue": "Possible rabies signs", "severity": "High" }
  ],
  "answer": "A dog with aggression and drooling bit you and broke the skin.",
  "advice": "1. Wash wound immediately with soap and water for 15 minutes.\n2. Seek emergency care.\n3. Report to animal control."
}
```

---

## 📋 Firestore Schema

Each scan document in the `scans` collection stores:

```
userId, isGuest, timestamp, imageUrl, note,
interactionType, brokeSkin, deepPuncture, lesionOozing, rabiesSigns,
riskLevel, detectedSpecies, biteRiskLevel, answer, userAction, healthFlags[]
```

---

## 📄 License

This project was developed for educational and research purposes.
