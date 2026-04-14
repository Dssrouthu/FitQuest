# FitQuest: Gamified Fitness Platform

FitQuest is a comprehensive, gamified fitness application designed to turn your fitness journey into an epic RPG adventure. Whether you're a Recruit just starting out or a High Council member overseeing guilds, FitQuest provides the tools, motivation, and AI-powered insights to help you reach your goals.

## 🚀 Key Features

### 🧙 Gamification & RPG Mechanics
- **Player Classes**: Choose your path as a **Vanguard**, **Assassin**, **Ranger**, or **Mage**.
- **Leveling System**: Earn **XP** by completing workouts, nutrition goals, and quests.
- **Coin Economy**: Earn **FitCoins** to spend in the Coach's Shop or on Super Coach services.
- **Quests**:
  - **Solo Quests**: Personalized challenges assigned by your coach.
  - **Daily Quests**: Recurring tasks for consistency (Workouts & Nutrition).
  - **Co-Op Quests**: Team up with your **Guild** to reach collective goals (e.g., 1 Million Steps).
  - **Community Quests**: Global challenges for all players.

### 🤖 AI-Powered Coaching
- **AI Coach**: Receive real-time interventions, progressive overload tips, and form correction.
- **Body Scan Analysis**: Upload physique photos for AI-driven body fat estimation and physique observations (powered by Google Gemini).
- **The Anvil**: Track your **Muscle Volume** (Weight × Reps) across major muscle groups to visualize your growth.
- **Battle Rhythm**: Master your timing during workouts to earn XP multipliers.
- **Ghost Duel**: Compare your exercise pose data against benchmarks or other users.
- **Voice Runes**: Record voice notes during your sets for later review or coach feedback.

### 🏋️ Advanced Workout Tracking
- **Workout Builder**: Coaches can design intricate multi-day workout plans.
- **Live Heartbeat**: Real-time activity status (Idle, Walking, Working Out) for team visibility.
- **Detailed Logging**: Support for regular sets, warm-ups, drop sets, and cardio metrics (Speed/Incline).
- **Exercise Database**: A curated library of exercises with muscle group targeting and difficulty levels.

### 🥗 Nutrition & Diet Management
- **The Pantry**: A custom food library managed by coaches.
- **Diet Plans**: Structured meal plans with daily macro targets (Protein, Carbs, Fats).
- **Meal Completion**: Track your meals via photo uploads.
- **Supplement Logs**: Stay on top of your daily supplement routine.
- **Weekly Schedule**: Sync your diet with your training days.

### 🏛️ Hierarchical Coaching System
- **Recruit**: The athlete/player.
- **Guild Master (Coach)**: Manages a roster of recruits, creates plans, and assigns quests.
- **Super Coach**: Supervises Guild Masters and offers premium services.
- **High Council**: Platform administrators.

---

## 🛠️ Tech Stack

- **Backend**: Django 6.0 (Python), Django REST Framework, SimpleJWT, PostgreSQL.
- **Frontend**: Flutter (Dart) for Android and iOS.
- **AI Integration**: Google Gemini API (Generative AI).
- **Storage**: Cloudinary (Media/Images), WhiteNoise (Static Files).
- **Infrastructure**: Gunicorn, Docker-ready.

---

## ⚙️ Setup & Installation

### Backend (Django)
1. Clone the repository.
2. Create a virtual environment: `python -m venv venv`
3. Activate the environment: `venv\Scripts\activate` (Windows) or `source venv/bin/activate` (Mac/Linux).
4. Install dependencies: `pip install -r requirements.txt`
5. Create a `.env` file based on `.env.example` and fill in your credentials.
6. Run migrations: `python manage.py migrate`
7. Start the server: `python manage.py runserver`

### Frontend (Flutter)
1. Navigate to `fitquest_app/`.
2. Install dependencies: `flutter pub get`
3. Update `baseUrl` in `lib/services/api_service.dart` to point to your backend.
4. Run the app: `flutter run`

---

## 🛡️ Security Note
Never commit your `.env` file or hardcode API keys. Always use environment variables for sensitive data like `SECRET_KEY`, `DATABASE_URL`, and `GEMINI_API_KEY`.

---

## 📜 License
This project is licensed under the MIT License - see the LICENSE file for details.
