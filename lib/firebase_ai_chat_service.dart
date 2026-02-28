import 'package:firebase_vertexai/firebase_vertexai.dart';

class FirebaseAIChatService {
  static GenerativeModel? _model;
  static ChatSession? _chatSession;

  /// Initialiser le modèle Firebase Vertex AI (pas besoin de clé API !)
  static void initialize() {
    if (_model != null) return;

    try {
      // Utilise Firebase directement - pas besoin de clé API !
      _model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.0-flash-exp',  // Nouveau modèle Gemini 2.0
        systemInstruction: Content.system('''
Tu es un assistant virtuel spécialisé dans l'accompagnement des aidants de patients atteints de la maladie d'Alzheimer.

Ton rôle :
- Fournir des conseils pratiques et bienveillants
- Expliquer les comportements liés à Alzheimer
- Suggérer des activités adaptées pour les patients
- Aider à gérer le stress des aidants
- Rappeler l'importance des routines et de la patience
- Être empathique et encourageant

Règles :
- Réponds en français
- Sois concis (2-3 paragraphes maximum)
- Reste positif et rassurant
- N'hésite pas à demander plus de détails si nécessaire
- Ne fais JAMAIS de diagnostic médical
- Recommande de consulter un médecin pour les questions médicales sérieuses

Contexte de l'app :
L'aidant utilise une app mobile appelée "AlzheCare" qui permet de suivre un patient Alzheimer en temps réel avec GPS, alertes, reconnaissance faciale, et rappels de médicaments.
'''),
      );

      print("[Firebase AI] Modèle initialisé avec succès");
    } catch (e) {
      print("[Firebase AI] Erreur initialisation: $e");
    }
  }

  /// Démarrer une nouvelle conversation
  static void startNewChat() {
    if (_model == null) initialize();

    _chatSession = _model!.startChat(history: [
      Content.text('Bonjour ! Je suis là pour t\'aider à prendre soin de ton proche atteint d\'Alzheimer. Comment puis-je t\'aider aujourd\'hui ?'),
      Content.model([TextPart('Bonjour ! Je suis ravi de pouvoir t\'accompagner. N\'hésite pas à me poser des questions sur la maladie, les comportements de ton proche, ou sur ton propre bien-être en tant qu\'aidant. Je suis là pour toi. ')])
    ]);

    print("[Firebase AI] Nouvelle conversation démarrée");
  }

  /// Envoyer un message et recevoir une réponse
  static Future<String> sendMessage(String userMessage) async {
    try {
      if (_chatSession == null) {
        startNewChat();
      }

      print("[Firebase AI] Envoi du message: $userMessage");

      final response = await _chatSession!.sendMessage(
        Content.text(userMessage),
      );

      final reply = response.text ?? "Désolé, je n'ai pas pu générer de réponse.";
      print("[Firebase AI] Réponse reçue: ${reply.substring(0, reply.length > 50 ? 50 : reply.length)}...");

      return reply;

    } catch (e) {
      print("[Firebase AI] Erreur: $e");

      if (e.toString().contains('PERMISSION_DENIED')) {
        return "Vertex AI n'est pas activé.\n\nVa sur Firebase Console → Vertex AI → Enable";
      } else if (e.toString().contains('QUOTA_EXCEEDED')) {
        return "Quota dépassé. Attends quelques minutes.";
      } else if (e.toString().contains('NOT_FOUND')) {
        return "Modèle non trouvé. Vérifie que Vertex AI est activé dans Firebase Console.";
      } else {
        return "Désolé, une erreur s'est produite. Peux-tu reformuler ta question ?\n\n(Erreur: ${e.toString().substring(0, 100)})";
      }
    }
  }

  /// Obtenir des suggestions de questions
  static List<String> getSuggestions() {
    return [
      "Comment gérer l'agitation le soir ?",
      "Quelles activités proposer ?",
      "Comment réagir aux oublis ?",
      "Conseils pour moi en tant qu'aidant",
      "Mon proche refuse de manger",
      "Il ne me reconnaît plus, que faire ?",
    ];
  }

  /// Réinitialiser la conversation
  static void resetChat() {
    _chatSession = null;
    print("[Firebase AI] Conversation réinitialisée");
  }

  /// Obtenir l'historique de la conversation
  static Iterable<Content> getHistory() {
    return _chatSession?.history ?? [];
  }
}