import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FaceImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String?> saveFaceImage({
    required String imagePath,
    required String patientUid,
    required String faceId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final ref = _storage.ref().child('faces').child(patientUid).child('$faceId.jpg');

      final file = File(imagePath);
      if (!await file.exists()) {
        print("[FaceImage] Fichier image introuvable: $imagePath");
        return null;
      }

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print("[FaceImage] Image uploadée: $downloadUrl");
      return downloadUrl;

    } catch (e) {
      print("[FaceImage] Erreur upload: $e");
      return null;
    }
  }

  static Future<void> deleteFaceImage({
    required String patientUid,
    required String faceId,
  }) async {
    try {
      final ref = _storage.ref().child('faces').child(patientUid).child('$faceId.jpg');
      await ref.delete();
      print("[FaceImage] Image supprimée");
    } catch (e) {
      print("[FaceImage] Erreur suppression: $e");
    }
  }

  static Future<bool> deleteFace(String faceId, {String? patientUid}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final targetUid = patientUid ?? user?.uid;
      if (targetUid == null) return false;

      await deleteFaceImage(patientUid: targetUid, faceId: faceId);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('proches')
          .doc(faceId)
          .delete();

      print("[FaceImage] Proche supprimé: $faceId");
      return true;

    } catch (e) {
      print("[FaceImage] Erreur suppression: $e");
      return false;
    }
  }
}
