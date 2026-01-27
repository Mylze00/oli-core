import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class RequestProductPage extends StatefulWidget {
  const RequestProductPage({super.key});

  @override
  State<RequestProductPage> createState() => _RequestProductPageState();
}

class _RequestProductPageState extends State<RequestProductPage> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _uploadedFileName;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _uploadedFileName = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header avec gradient bleu
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                backgroundColor: const Color(0xFF1E7DBA),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1E7DBA), Color(0xFF1565C0)],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(height: 20),
                            const Text(
                              'PLACE DE MARCHÉ B2B',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Centralisez vos besoins\nd\'achat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Identifiez les meilleurs partenaires et comparez\nles offres en un clic.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Cartes de catégories
                            Row(
                              children: [
                                _buildCategoryCard('Sur-mesure\nTechnique', Icons.settings),
                                const SizedBox(width: 12),
                                _buildCategoryCard('Identité de\nMarque', Icons.storefront),
                                const SizedBox(width: 12),
                                _buildCategoryCard('Volumes de\nGros', Icons.inventory_2),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 50,
                    ),
                  ),
                ],
              ),

              // Formulaire principal
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card principale du formulaire
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'De quoi avez-vous besoin ?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Champ de description
                              TextField(
                                controller: _descriptionController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Décrivez votre besoin en détail...\nEx: "500 stations de charge solaires avec installation"',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: const Color(0xFF1E7DBA).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: const Color(0xFF1E7DBA).withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1E7DBA),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF1E7DBA).withOpacity(0.02),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              const Text(
                                'Ou importez un cahier des charges',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Zone de dépôt
                              GestureDetector(
                                onTap: _pickFile,
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF1E7DBA).withOpacity(0.3),
                                      width: 2,
                                      style: BorderStyle.solid,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFF1E7DBA).withOpacity(0.02),
                                  ),
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    children: [
                                      Icon(
                                        _uploadedFileName == null 
                                            ? Icons.add_circle_outline 
                                            : Icons.check_circle,
                                        size: 48,
                                        color: _uploadedFileName == null
                                            ? Colors.grey.shade300
                                            : const Color(0xFF00BA7C),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _uploadedFileName ?? 
                                        'Cliquez pour importer une photo',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _uploadedFileName == null
                                              ? Colors.grey.shade500
                                              : const Color(0xFF1A1A1A),
                                          fontStyle: _uploadedFileName == null 
                                              ? FontStyle.italic 
                                              : FontStyle.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Section Processus
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.orange,
                                width: 4,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.only(left: 12),
                          child: const Text(
                            'PROCESSUS DE COTATION',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Étapes du processus
                        _buildProcessStep(
                          1,
                          'Publiez vos critères',
                          'Détaillez vos quantités, délais et spécificités techniques.',
                        ),
                        const SizedBox(height: 24),
                        _buildProcessStep(
                          2,
                          'Analysez les offres',
                          'Recevez jusqu\'à 15 propositions qualifiées sous 24h.',
                        ),
                        const SizedBox(height: 24),
                        _buildProcessStep(
                          3,
                          'Finalisez la transaction',
                          'Négociez en direct et sécurisez votre approvisionnement.',
                        ),
                        
                        const SizedBox(height: 100), // Espace pour le bouton sticky
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Bouton sticky en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Obtenez des offres compétitives immédiatement.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Action d'envoi de demande
                        if (_descriptionController.text.isEmpty && _uploadedFileName == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez décrire votre besoin ou importer un fichier'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Demande envoyée avec succès !'),
                            backgroundColor: Color(0xFF00BA7C),
                          ),
                        );
                        
                        // Retour à l'accueil après un court délai pour laisser lire le message
                        Future.delayed(const Duration(seconds: 1), () {
                          if (mounted) Navigator.pop(context);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Envoyer ma demande',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String label, IconData icon) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1E7DBA),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessStep(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
