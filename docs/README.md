# AlzheCare - Documentation Technique

## 1. Présentation du Projet

**AlzheCare** est une application mobile Flutter destinée à l'aide et la surveillance des patients atteints de la maladie d'Alzheimer, développée pour connecter les patients avec leurs aidants (caregivers).

### Objectifs
- 🎯 **Surveillance continue** : Détection de chutes et alertes GPS
- 🔒 **Sécurité** : Authentification par PIN et biométrie
- 👨‍👩‍👧 **Lien familial** : Connexion patient-aidant en temps réel
- 🧠 **Stimulation cognitive** : Jeux de mémoire et quiz
- 📅 **Gestion** : Rappels et calendrier

---

## 2. Architecture

### Structure des dossiers
```
lib/
├── main.dart                    # Point d'entrée
├── sign_in_screen.dart          # Authentification
├── sign_up_screen.dart          # Inscription
│
├── patient_home_screen.dart    # Écran patient
├── caregiver_home_screen.dart  # Écran aidant (4 onglets)
│
├── Services (backend)
│   ├── face_recognition_service.dart   # Reconnaissance faciale
│   ├── fcm_service.dart                # Notifications Firebase
│   ├── geofencing_service.dart         # Géofencing
│   ├── continuous_background_service.dart # GPS
│   ├── app_security_service.dart       # Sécurité
│   └── reminder_notification_service.dart
│
├── Écrans patient
│   ├── patient_home_screen.dart
│   ├── lost_patient_screen.dart       # "Je suis perdu"
│   ├── urgent_call_screen.dart        # Appel d'urgence
│   ├── smart_recognition_screen.dart  # Reconnaissance faciale
│   └── game_menu_screen.dart           # Jeux cognitifs
│
└── Écrans aidant
    ├── caregiver_dashboard_tab.dart    # Tableau de bord
    ├── caregiver_map_tab.dart          # Carte en temps réel
    ├── caregiver_alerts_screen.dart    # Historique alertes
    └── caregiver_profile_tab.dart      # Profil & paramètres
```

### Base de données (Firestore)

```javascript
// Structure des utilisateurs
users/{uid}
├── name: string
├── email: string
├── role: "patient" | "caregiver"
├── linkedCaregivers: string[]  // Pour patient
├── linkedPatients: string[]     // Pour caregiver
├── inviteCode: string          // Code pour lier
├── fcmToken: string            // Notifications
├── createdAt: timestamp
│
├── proches/{faceId}            // Reconnaissance faciale
│   ├── name: string
│   ├── relation: string
│   ├── phoneNumber: string
│   ├── embedding: number[]    // Vecteur 128D (NON les photos)
│   ├── imageUrl: string       // URL Firebase Storage
│   └── createdAt: timestamp
│
├── reminders/{reminderId}
│   ├── title: string
│   ├── description: string
│   ├── date: timestamp
│   └── isCompleted: boolean
│
├── alerts/{alertId}
│   ├── type: "sos" | "fall" | "geofence"
│   ├── timestamp: timestamp
│   └── status: "pending" | "seen" | "resolved"
│
└── game_scores/{gameId}
    ├── score: number
    └── playedAt: timestamp

// Notifications globales
notifications/{notifId}
├── caregiverId: string
├── patientId: string
├── patientName: string
├── type: string
├── message: string
├── latitude: number
├── longitude: number
├── status: "pending" | "seen" | "resolved"
└── timestamp: timestamp
```

### Firebase Storage
```
faces/{patientUid}/{faceId}.jpg  // Photos des proches
```

---

## 3. Sécurité - Detail

### 3.1 Authentification (`AppSecurityService`)

L'application utilise deux méthodes d'authentification :

#### PIN Code (4-6 chiffres)
- **Stockage** : `FlutterSecureStorage` (chiffré Android Keystore)
- **Vérification** : Comparaison directe
- **Limitation** : 4-6 chiffres uniquement

#### Biométrie
- **Technologie** : `local_auth` (Android Fingerprint/Face ID)
- **Disponibilité** : Détection automatique
- **Stockage** : Configuration dans SecureStorage

```dart
// Dans app_security_service.dart
enum AuthMethod { none, biometric, pin }

// Configuration
static Future<bool> setupPIN(String pin)
static Future<bool> verifyPIN(String pin)
static Future<bool> enableBiometric(bool enable)
static Future<bool> authenticateWithBiometric()
```

### 3.2 Reconnaissance Faciale - Protection vie privée

⚠️ **Important** : L'application ne stocke PAS les photos des proches dans Firestore !

```
❌ INCORRECT : Photo complète stockée
✅ CORRECT   : Vecteur mathématique (embedding)
```

**Processus :**
1. Photo capturée via caméra
2. Détection du visage avec Google ML Kit
3. Extraction du vecteur 128D avec MobileFaceNet
4. **Seul le vecteur est stocké** dans Firestore
5. Photo supprimée de l'appareil
6. Version redimensionnée stockée dans Firebase Storage (pour affichage)

```dart
// Extraction de l'embedding
final embedding = FaceRecognitionService.extractEmbedding(faceImage);
// embedding = [0.123, -0.456, 0.789, ...] // 128 valeurs

// Comparaison (cosine distance)
double similarity = FaceRecognitionService.calculateSimilarity(emb1, emb2);
if (similarity > 0.6) {
  // Visage reconnu
}
```

### 3.3 Sessions et Timeouts

```dart
static void startSessionMonitoring()  // Vérifie toutes les 30s
static void resetSessionTimer()       // Reset sur activité
// Timeout configurable (défaut: 5 minutes)
```

### 3.4 Sécurité des données

| Donnée | Protection | Stockage |
|--------|------------|----------|
| PIN | Chiffré (Android Keystore) | SecureStorage |
| Embedding facial | Chiffré | Firestore |
| Photos proches | Règles Firestore | Firebase Storage |
| Localisation | Chiffrement TLS | Firestore |
| Auth Firebase | Firebase Auth | Firebase |

### 3.5 Règles Firestore suggérées

```javascript
rules_version = '2';
service cloud.firestore {
  match /users/{userId} {
    allow read, write: if request.auth != null && request.auth.uid == userId;
    
    match /proches/{faceId} {
      allow read: if request.auth != null;  // Pour le caregiver
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
  
  match /notifications/{notifId} {
    allow read: if request.auth != null && request.auth.uid == data.caregiverId;
    allow create: if request.auth != null;
  }
}
```

---

## 4. Services de Surveillance

### 4.1 GPS Continu (`ContinuousBackgroundService`)
- Service Android foreground
- Mise à jour toutes les 30 secondes
- Envoi vers Firestore en temps réel

### 4.2 Géofencing (`GeofencingService`)
- Zones de sécurité (domicile)
- Détection entrée/sortie
- Alerte automatique

### 4.3 Détection de Chute
- Capteur accelerometer (sensors_plus)
- Modèle ML TensorFlow (`fall_detection.tflite`)
- Seuil de détection configurable

### 4.4 Notifications (FCM)
- Firebase Cloud Messaging
- Notifications push en temps réel
- Actions rapides (voir position, appeler)

---

## 5. Modèles ML

### MobileFaceNet
- **Taille** : ~5MB
- **Vecteur** : 128 dimensions
- **Temps d'inférence** : ~100ms
- **Précision** : ~99%

### Fall Detection
- **Input** : 50 données accelerometer
- **Output** : probabilité de chute (0-1)
- **Seuil** : 0.85

---

## 6. Technologies Utilisées

| Catégorie | Technologie |
|-----------|-------------|
| Frontend | Flutter 3.x |
| Backend | Firebase (Auth, Firestore, Storage, Messaging) |
| ML | TensorFlow Lite, Google ML Kit |
| Local Auth | local_auth, flutter_secure_storage |
| Maps | flutter_map + OpenStreetMap |
| Notifications | flutter_local_notifications |
| Capteurs | sensors_plus |

---

## 7. Flux Utilisateur

### Patient
```
1. Connexion → PIN/Biométrie
2. Écran principal → Accès rapide aux fonctionnalités
3. SOS → Envoi alerte + position à tous les caregivers
4. Je suis perdu → Géolocalisation + notification
5. Mes proches → Reconnaissance faciale
6. Jeux → Stimulation cognitive
```

### Aidant (Caregiver)
```
1. Connexion → Tableau de bord
2. Carte → Position temps réel du patient
3. Alertes → Historique avec statistiques
4. Profil → Gestion patients, rappels, proches
```

---

## 8. Améliorations de Sécurité Futures

1. **Chiffrement des vecteurs** : Chiffrement AES avant stockage
2. **HONEYPOT** : Détection d'effraction
3. **Journal d'audit** : Logging des accès
4. **Auth multifactorielle** : 2FA complet
5. **Verouillage automatique** : Temps d'inactivité
6. **Anonymisation** : Option pour effacer données
