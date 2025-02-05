# TikBlok

A Minecraft-focused video sharing platform built with Flutter and Firebase.

## Features

- Video feed with curated Minecraft content
- User authentication and profiles
- Video interaction (likes, comments)
- Playlist management
- User subscriptions and notifications
- Social sharing

## Tech Stack

- **Frontend:** Flutter
- **Backend:** Firebase (Auth, Firestore, Storage, Functions)
- **Video Processing:** Firebase Cloud Functions with FFmpeg

## Getting Started

### Prerequisites

- Flutter SDK (latest version)
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js 18 or later

### Setup

1. Clone the repository:
```bash
git clone [repository-url]
cd app
```

2. Install Flutter dependencies:
```bash
flutter pub get
```

3. Set up Firebase:
```bash
# Login to Firebase
firebase login

# Initialize Firebase in the project
firebase init

# Select required features:
# - Authentication
# - Firestore
# - Storage
# - Functions
# - Hosting (optional)

# Deploy Firebase resources
firebase deploy
```

4. Set up Firebase Functions:
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

5. Run the app:
```bash
flutter run
```

## Development

- The app is configured for landscape orientation only
- Uses a dark theme with green accents
- Follows Material 3 design principles
- Firebase configuration is managed through CLI tools

## Documentation

See the `md/` directory for detailed documentation:
- `overview.md` - Project overview
- `implementation_plan.md` - Development roadmap
- `user-stories.md` - User stories and requirements
- `retro_and_plan.md` - Development retrospective and planning
