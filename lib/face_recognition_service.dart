import 'dart:typed_data';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FaceRecognitionService {

  static Interpreter? _interpreter;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print("[FaceRecognition] Chargement du modele...");
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      _isInitialized = true;
      print("[FaceRecognition] Modele charge avec succes");
    } catch (e) {
      print("[FaceRecognition] Erreur chargement modele: $e");
    }
  }

  static List<double>? extractEmbedding(img.Image face) {
    if (_interpreter == null) {
      print("[FaceRecognition] Modele non initialise");
      return null;
    }

    try {
      final resized = img.copyResize(face, width: 112, height: 112);

      final input = List.generate(
        1,
            (_) => List.generate(
          112,
              (y) => List.generate(
            112,
                (x) {
              final pixel = resized.getPixel(x, y);

              // Extraction RGB compatible image 3.3.0
              final red = pixel.toInt() & 0xFF;
              final green = (pixel.toInt() >> 8) & 0xFF;
              final blue = (pixel.toInt() >> 16) & 0xFF;

              final r = (red / 255.0 - 0.5) / 0.5;
              final g = (green / 255.0 - 0.5) / 0.5;
              final b = (blue / 255.0 - 0.5) / 0.5;

              return [r, g, b];
            },
          ),
        ),
      );

      final output = List.filled(1 * 192, 0.0).reshape([1, 192]);
      _interpreter!.run(input, output);
      final embedding = List<double>.from(output[0]);

      print("[FaceRecognition] Embedding extrait: ${embedding.length} dimensions");
      return embedding;

    } catch (e) {
      print("[FaceRecognition] Erreur extraction embedding: $e");
      return null;
    }
  }

  static double calculateSimilarity(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) return 0.0;

    double sum = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      final diff = emb1[i] - emb2[i];
      sum += diff * diff;
    }

    final distance = sqrt(sum);
    final similarity = max(0.0, 1.0 - (distance / 2.0));

    return similarity;
  }

  // ─── Proches ───────────────────────────────────────────────────────────────

  static Future<bool> saveFace({
    required String name,
    required List<double> embedding,
    String? relation,
    String? phoneNumber,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('proches')
          .add({
        'name': name,
        'embedding': embedding,
        'relation': relation ?? '',
        'phoneNumber': phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("[FaceRecognition] Visage enregistre: $name");
      return true;

    } catch (e) {
      print("[FaceRecognition] Erreur sauvegarde: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> recognizeFace(List<double> embedding) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('proches')
          .get();

      if (snapshot.docs.isEmpty) {
        print("[FaceRecognition] Aucun proche enregistre");
        return null;
      }

      double bestSimilarity = 0.0;
      Map<String, dynamic>? bestMatch;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final savedEmbedding = List<double>.from(data['embedding']);

        final similarity = calculateSimilarity(embedding, savedEmbedding);

        print("[FaceRecognition] ${data['name']}: $similarity");

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestMatch = {
            'id': doc.id,
            'name': data['name'],
            'relation': data['relation'] ?? '',
            'phoneNumber': data['phoneNumber'] ?? '',
            'similarity': similarity,
          };
        }
      }

      if (bestSimilarity > 0.6) {
        print("[FaceRecognition] Reconnu: ${bestMatch!['name']} ($bestSimilarity)");
        return bestMatch;
      } else {
        print("[FaceRecognition] Aucune correspondance (meilleur: $bestSimilarity)");
        return null;
      }

    } catch (e) {
      print("[FaceRecognition] Erreur reconnaissance: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getSavedFaces() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('proches')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'],
          'relation': data['relation'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
        };
      }).toList();

    } catch (e) {
      print("[FaceRecognition] Erreur recuperation: $e");
      return [];
    }
  }

  static Future<bool> deleteFace(String id) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('proches')
          .doc(id)
          .delete();

      print("[FaceRecognition] Proche supprime: $id");
      return true;

    } catch (e) {
      print("[FaceRecognition] Erreur suppression: $e");
      return false;
    }
  }

  // ─── Login par visage ───────────────────────────────────────────────────────

  /// Enregistre le propre visage du patient dans la collection globale `face_logins`
  static Future<bool> saveSelfFaceEmbedding(List<double> embedding) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('face_logins')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'embedding': embedding,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[FaceRecognition] Visage de connexion enregistré: ${user.uid}');
      return true;
    } catch (e) {
      print('[FaceRecognition] Erreur enregistrement visage connexion: $e');
      return false;
    }
  }

  /// Identifie un patient pour la connexion en cherchant dans tous les visages de `face_logins`
  /// Pas besoin d'être authentifié pour appeler cette méthode.
  static Future<String?> recognizeFaceForLogin(List<double> embedding) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('face_logins')
          .get();

      if (snapshot.docs.isEmpty) {
        print('[FaceRecognition] Aucun visage de connexion enregistré');
        return null;
      }

      double bestSimilarity = 0.0;
      String? bestUid;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final saved = List<double>.from(data['embedding'] ?? []);
        final similarity = calculateSimilarity(embedding, saved);

        print('[FaceRecognition] Vérification login ${doc.id}: $similarity');

        if (similarity > bestSimilarity) {
          bestSimilarity = similarity;
          bestUid = data['uid'] as String?;
        }
      }

      if (bestSimilarity > 0.6) {
        print('[FaceRecognition] Login reconnu: $bestUid (score: $bestSimilarity)');
        return bestUid;
      }

      print('[FaceRecognition] Aucune correspondance login (meilleur: $bestSimilarity)');
      return null;
    } catch (e) {
      print('[FaceRecognition] Erreur reconnaissance login: $e');
      return null;
    }
  }
}