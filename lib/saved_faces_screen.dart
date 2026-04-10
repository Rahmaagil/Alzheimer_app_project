import 'package:flutter/material.dart';
import 'theme.dart';
import 'face_recognition_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SavedFacesScreen extends StatefulWidget {
  final String? patientUid;

  const SavedFacesScreen({super.key, this.patientUid});

  @override
  State<SavedFacesScreen> createState() => _SavedFacesScreenState();
}

class _SavedFacesScreenState extends State<SavedFacesScreen> {
  List<Map<String, dynamic>> _faces = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFaces();
  }

  Future<void> _loadFaces() async {
    setState(() => _isLoading = true);
    final faces = await FaceRecognitionService.getSavedFaces(patientUid: widget.patientUid);
    setState(() {
      _faces = faces;
      _isLoading = false;
    });
  }

  Future<void> _deleteFace(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text("Supprimer ce proche ?"),
          ],
        ),
        content: Text("Voulez-vous supprimer $name ? Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Supprimer",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await FaceRecognitionService.deleteFace(id, patientUid: widget.patientUid);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Proche supprimé"), backgroundColor: Colors.green),
        );
        _loadFaces();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Proches enregistrés",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          AppDecorationWidgets.buildDecoCircles(),
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
              ),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _faces.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _faces.length,
              itemBuilder: (context, index) {
                final face = _faces[index];
                return _buildFaceCard(face);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.person_off,
                size: 60,
                color: Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Aucun proche enregistré",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5AAC),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Ajoutez des proches depuis le profil\npour qu'ils soient reconnus automatiquement",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Color(0xFFFFB74D), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Conseils: Bon éclairage et visage visible\naméliorent la reconnaissance",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceCard(Map<String, dynamic> face) {
    final imageUrl = face['imageUrl'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(Icons.person, color: Colors.white, size: 30),
                      errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  face['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5AAC),
                  ),
                ),
                if (face['relation'].isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    face['relation'],
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
                if (face['phoneNumber'].isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        face['phoneNumber'],
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteFace(face['id'], face['name']),
          ),
        ],
      ),
    );
  }
}