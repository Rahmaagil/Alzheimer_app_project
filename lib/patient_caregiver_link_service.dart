import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service de liaison automatique Patient ↔ Suiveur
/// Basé sur le numéro de téléphone
class PatientCaregiverLinkService {

  /// Lier automatiquement le patient au suiveur
  /// Appelé quand le patient enregistre le téléphone de son proche
  static Future<bool> linkPatientToCaregiver({
    required String patientUid,
    required String caregiverPhone,
  }) async {
    try {
      print("[Link] Liaison patient $patientUid avec téléphone $caregiverPhone");

      // 1. Chercher le suiveur avec ce numéro
      final caregiverQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('phone', isEqualTo: caregiverPhone)
          .limit(1)
          .get();

      if (caregiverQuery.docs.isEmpty) {
        print("[Link] Aucun suiveur trouvé avec ce numéro");
        return false;
      }

      final caregiverUid = caregiverQuery.docs.first.id;
      print("[Link] Suiveur trouvé: $caregiverUid");

      // 2. Mettre à jour le suiveur
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .update({
        'linkedPatient': patientUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      // 3. Mettre à jour le patient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .update({
        'linkedCaregiver': caregiverUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      print("[Link] Liaison créée avec succès");
      return true;

    } catch (e) {
      print("[Link] Erreur liaison: $e");
      return false;
    }
  }

  /// Vérifier si un patient est lié à un suiveur
  static Future<bool> isLinked(String patientUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      final linkedCaregiver = doc.data()?['linkedCaregiver'];
      return linkedCaregiver != null;
    } catch (e) {
      print("[Link] Erreur vérification: $e");
      return false;
    }
  }

  /// Récupérer l'UID du suiveur lié
  static Future<String?> getLinkedCaregiverId(String patientUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      return doc.data()?['linkedCaregiver'] as String?;
    } catch (e) {
      print("[Link] Erreur récupération suiveur: $e");
      return null;
    }
  }

  /// Récupérer l'UID du patient lié
  static Future<String?> getLinkedPatientId(String caregiverUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      return doc.data()?['linkedPatient'] as String?;
    } catch (e) {
      print("[Link] Erreur récupération patient: $e");
      return null;
    }
  }

  /// Délier patient et suiveur
  static Future<void> unlinkPatientCaregiver(String patientUid) async {
    try {
      final caregiverId = await getLinkedCaregiverId(patientUid);

      if (caregiverId != null) {
        // Supprimer la liaison côté suiveur
        await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .update({
          'linkedPatient': FieldValue.delete(),
        });
      }

      // Supprimer la liaison côté patient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .update({
        'linkedCaregiver': FieldValue.delete(),
      });

      print("[Link] Liaison supprimée");
    } catch (e) {
      print("[Link] Erreur suppression: $e");
    }
  }
}
































































































