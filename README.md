# Rapgate 🔥 — AI Calorie & Health Tracker

> **The smarter Cal AI alternative built specifically for Indian diets and daily fitness goals.**

[![Flutter](https://img.shields.io/badge/Flutter-3.32+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Backend-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Gemini 2.0 Flash](https://img.shields.io/badge/AI-Gemini%202.0%20Flash-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-Codemagic%20%26%20GitHub%20Actions-FF4081)](https://codemagic.io)

---

## 🌟 Why Rapgate?

Western calorie-tracking apps (like Cal AI and MyFitnessPal) fail in India because they assume meat-heavy diets, measure everything in grams, and miss hidden cooking fats. **Rapgate** solves this from the ground up:

* 📸 **Vision AI Food Scanner:** Point your phone camera at a plate of food (Roti, Dal, Sabzi, Biryani, Poha, Idli, Dosa) for instant calorie and macro detection powered by **Gemini 2.0 Flash**.
* 🍛 **Tadka & Cooking Oil Intelligence:** Accounts for unseen mustard oil, refined oil, and ghee absorbed during Indian cooking (+20% realistic fat buffer) so calories are never underestimated.
* 🎯 **Realistic Indian Macro Targets:** Based on clinically-validated Mifflin-St Jeor math, customized with sustainable protein targets ($1.2\text{--}1.5\text{ g/kg}$ body weight) achievable through paneer, dal, dahi, soya, and eggs.
* ✍️ **Natural Language Food Search:** Simply type meals in natural Hinglish or English (e.g. *"2 aloo parathas with a cup of curd"*) and let AI estimate exact macros.
* 📦 **Barcode & Nutrition Label Reader:** Instant barcode lookups with offline cache, plus OCR scanning of printed Nutrition Facts labels on packaged snacks.
* 🔥 **Daily Food Streaks:** Automatic database triggers keep you accountable and build consistency every day.
* 📧 **Passwordless Email OTP Login:** Instant 6-digit code verification via Supabase Auth and Resend SMTP — zero SMS delays.

---

## 📱 App Highlights & Architecture

```
┌────────────────────────────────────────────────────────┐
│                   RAPGATE ARCHITECTURE                 │
└────────────────────────────────────────────────────────┘
          │
          ├── 📱 Flutter Client (Android & iOS)
          │    ├── OLED Dark Mode UI (#0A0E14)
          │    ├── WeekStrip Date Picker & Daily Gauges
          │    ├── Cal AI-style Animated Scanner Frame
          │    └── Interactive Meal Details & Portion Editor
          │
          ├── ⚡ Supabase PostgreSQL Backend
          │    ├── Auth: Passwordless Email OTP (Resend SMTP)
          │    ├── Database: users, food_logs, streaks, local_products
          │    ├── Triggers: bump_food_streak auto-trigger
          │    └── RLS: Row-Level Security for user data isolation
          │
          └── 🧠 Edge Function: scan-food-image
               ├── Gemini 2.0 Flash Multimodal Vision
               ├── Indian Dish & Cooking Medium Knowledge
               └── Natural Language Text Nutrition Parser
```

---

## 🚀 Quick Start (Local Setup)

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.24+ or latest stable)
* Java 17+ (e.g. Microsoft OpenJDK 17)
* Android Studio / Command-line Android SDK

### 1. Clone the Repository
```bash
git clone https://github.com/gitworld08210/Rapgate.git
cd Rapgate
```

### 2. Install Dependencies
```bash
flutter create --platforms=android .
flutter pub get
```

### 3. Run on Device
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://hjxesslwvimpgxazwmep.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=CLOUDINARY_CLOUD_NAME=dxoqepdck \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=rapgate-dataset
```

---

## 📦 Building the Release APK

### Local Command (Single-Line)
Run this command from the repository root:
```bash
flutter build apk --release \
  --android-skip-build-dependency-validation \
  --dart-define=SUPABASE_URL=https://hjxesslwvimpgxazwmep.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key \
  --dart-define=CLOUDINARY_CLOUD_NAME=dxoqepdck \
  --dart-define=CLOUDINARY_UPLOAD_PRESET=rapgate-dataset
```

The compiled release APK will be located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## ☁️ Codemagic CI/CD (Free Tier)

This repository includes a pre-configured **`codemagic.yaml`** ready for Codemagic's Free Plan:
1. Log in to [codemagic.io](https://codemagic.io) using your GitHub account.
2. Add the **`Rapgate`** repository.
3. Select **Workflow:** `Rapgate Android Release`.
4. Click **Start build** — Codemagic uses an **Apple Mac mini M2** (`mac_mini_m2`) runner to build your release APK in ~4–6 minutes and delivers the download in the **Artifacts** tab.

---

## ⚙️ Backend & Supabase Configuration

### 1. Database Tables & Triggers
Migrations are located in `supabase/migrations/`:
* `001_initial_schema.sql`: Core schema (`users`, `food_logs`, `streaks`, `local_products`).
* `004_food_logs_streak_trigger.sql`: Trigger that increments daily streaks when a food log is created.

### 2. Resend SMTP Configuration
To enable high-speed, rate-limit-free email OTP delivery:
1. In your **Supabase Dashboard** ➡️ **Project Settings ⚙️** ➡️ **Authentication** ➡️ **SMTP Settings**:
   * **Host:** `smtp.resend.com`
   * **Port:** `465` (SSL) or `587` (TLS)
   * **User:** `resend`
   * **Password:** Your Resend API Key (`re_...`)
   * **Sender Email:** `onboarding@resend.dev` or your custom domain.
2. Under **Authentication ➡️ Email Templates ➡️ Magic Link**, set the Subject to:
   ```text
   Your Rapgate Verification Code: {{ .Token }}
   ```
   and display `{{ .Token }}` in the template body so users receive their 6-digit login OTP code.

---

## 📁 Project Structure

```text
Rapgate/
├── android/                 # Android native project & Gradle 8.12 wrapper
│   ├── app/build.gradle.kts # Android app configuration & SDK targets
│   └── settings.gradle.kts  # Plugin declarations & SDK path resolution
├── lib/
│   ├── models/              # UserModel, FoodLogModel, StreakModel
│   ├── providers/           # HealthProvider (reactive state & date switcher)
│   ├── screens/
│   │   ├── auth/            # Passwordless Email OTP Login
│   │   ├── food/            # Scanner, Food Details, Meal Diary, Text Search
│   │   ├── home/            # Dashboard, WeekStrip, Calorie Gauge, Streaks
│   │   ├── profile/         # Onboarding with Mifflin-St Jeor Goals
│   │   └── reports/         # Weekly & Monthly Aggregated Nutrition Graphs
│   ├── services/            # SupabaseClient, AuthService, FoodService, FirestoreService
│   └── utils/               # AppTheme (OLED dark palette), Indian Nutrition Helpers
├── supabase/
│   ├── functions/           # Edge Functions (scan-food-image with Gemini 2.0 Flash)
│   └── migrations/          # PostgreSQL migrations and trigger definitions
├── codemagic.yaml           # Codemagic Free Tier CI/CD pipeline
└── pubspec.yaml             # Flutter project manifest & dependencies
```

---

## 🛡️ License

This project is licensed under the MIT License — see the LICENSE file for details.
