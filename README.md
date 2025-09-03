# 🚀 Smart Trip Planner

A sophisticated AI-powered travel planning application built with Flutter that leverages Google Gemini AI to create personalized trip itineraries through natural language conversations.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Google_Gemini-4285F4?style=for-the-badge&logo=google&logoColor=white)
![Isar](https://img.shields.io/badge/Isar-000000?style=for-the-badge&logo=data&logoColor=white)

## ✨ Features

### 🤖 AI-Powered Trip Planning
- **Natural Language Processing**: Communicate with Google Gemini AI to plan trips conversationally
- **Intelligent Itinerary Generation**: AI creates detailed, personalized travel plans
- **Contextual Recommendations**: Smart suggestions based on your preferences and constraints


- **Real-time Messaging**: Seamless conversation with AI for trip planning
- **Typing Animations**: Enhanced user experience with realistic typing indicators
- **Chat History Persistence**: All conversations saved using Isar database

### 🗺️ Geospatial Mapping
- **Google Maps Integration**: Interactive maps for route visualization
- **Location Services**: Coordinate-based location management
- **Waypoint Management**: Plan routes with multiple stops and destinations

### 📅 Comprehensive Itinerary Management
- **CRUD Operations**: Create, Read, Update, Delete trip plans
- **Temporal Scheduling**: Multi-day trip planning with time allocation
- **Activity Sequencing**: Optimized scheduling of activities and attractions
- **File-based Storage**: JSON format for persistent trip data storage

### 🏗️ Technical Excellence
- **Clean Architecture**: Repository pattern with dependency injection
- **Cross-platform**: Native Android and iOS deployment
- **Material Design**: Modern, intuitive user interface
- **State Management**: Efficient handling of complex application states

## 🛠️ Tech Stack

### Frontend
- **Flutter**: Cross-platform UI framework
- **Dart**: Programming language
- **Material Design**: UI component library

### Backend & APIs
- **Google Gemini AI**: Natural language processing and itinerary generation
- **Google Maps Link Creation**: Geospatial mapping and route services
- **Isar Database**: NoSQL database for chat history and local data

### Architecture
- **Clean Architecture**: Separation of concerns
- **Repository Pattern**: Data access abstraction
- **Dependency Injection**: Modular and testable code

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Google API Keys (Gemini AI, Maps)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Rvish-glitch/Smart_trip_planner.git
   cd Smart_trip_planner
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API Keys**
   Create a `.env` file in the root directory:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

### Build for Production

**Android APK:**
```bash
flutter build apk --release
```

**iOS (on macOS):**
```bash
flutter build ios --release
```

## 📱 Usage

1. **Start Planning**: Open the app and begin a conversation with the AI
2. **Describe Your Trip**: Tell the AI about your destination, duration, budget, and preferences
3. **Refine Itinerary**: Ask questions and make modifications through chat
4. **Save & Manage**: Store your trip plans for future reference
5. **View on Map**: Visualize your itinerary with interactive maps

## 🏗️ Project Structure

```
lib/
├── core/                    # Core utilities and services
│   ├── utils/              # Helper functions and utilities
│   └── services/           # Core application services
├── data/                   # Data layer
│   ├── datasources/        # API and external data sources
│   ├── models/            # Data models and entities
│   └── repositories/      # Data access repositories
├── presentation/          # Presentation layer
│   ├── screens/           # UI screens and pages
│   ├── widgets/           # Reusable UI components
│   └── services/          # UI-specific services
└── main.dart              # Application entry point
```

## 🔧 Configuration

### Environment Variables
The application requires the following environment variables:

- `GEMINI_API_KEY`: Your Google Gemini AI API key

### API Setup
1. **Google Gemini AI**: Obtain API key from [Google AI Studio](https://makersuite.google.com/app/apikey)



### Development Guidelines
- Follow Flutter best practices
- Write clean, documented code
- Add tests for new features
- Update documentation as needed

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


