import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'face_camera_screen.dart';

class CaregiverAddFaceScreen extends StatefulWidget {
  final String? patientUid;
  final String? patientName;

  const CaregiverAddFaceScreen({
    Key? key,
    this.patientUid,
    this.patientName,
  }) : super(key: key);

  @override
  State<CaregiverAddFaceScreen> createState() => _CaregiverAddFaceScreenState();
}

class _CaregiverAddFaceScreenState extends State<CaregiverAddFaceScreen> {
  bool _isProcessing = false;

  Future<void> _captureFace() async {
    setState(() => _isProcessing = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FaceCameraScreen(isRegistrationMode: true),
      ),
    );

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Visage du patient ajouté avec succès'),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ajouter visage du patient'),
        backgroundColor: Color(0xFF4A90E2),
      ),
      body: _isProcessing
          ? Center(child: CircularProgressIndicator())
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.face,
                  size: 100,
                  color: Color(0xFF4A90E2),
                ),
                SizedBox(height: 32),
                Text(
                  'Enregistrer le visage du patient',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5AAC),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'Demandez au patient de regarder la caméra.\n\n'
                      'Assurez un bon éclairage et que le patient soit bien visible.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _captureFace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Capturer le visage',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}