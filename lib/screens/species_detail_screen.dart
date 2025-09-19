import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/model_service.dart';
import '../services/image_service.dart';

class SpeciesDetailScreen extends StatefulWidget {
  final SpeciesPrediction prediction;

  const SpeciesDetailScreen({
    super.key,
    required this.prediction,
  });

  @override
  State<SpeciesDetailScreen> createState() => _SpeciesDetailScreenState();
}

class _SpeciesDetailScreenState extends State<SpeciesDetailScreen> {
  String? _imageUrl;
  ImageAttribution? _imageAttribution;
  bool _isLoadingImage = true;
  String _description = '';
  String _scientificName = '';
  String? _wikipediaText;
  bool _isLoadingWikipedia = false;

  @override
  void initState() {
    super.initState();
    _loadSpeciesInfo();
  }

  void _loadSpeciesInfo() {
    // Use scientific name from the prediction directly
    _scientificName = widget.prediction.scientificName ?? '';

    // Generate description based on species type
    _description = _generateDescription(widget.prediction.speciesName, _scientificName);

    // Load species image
    _loadSpeciesImage();

    // Load Wikipedia content for biological species
    if (_scientificName.isNotEmpty) {
      _loadWikipediaText();
    }
  }

  String _generateDescription(String speciesName, String scientificName) {
    if (scientificName.isNotEmpty) {
      // It's a biological species
      if (_isLikelyBird(speciesName, scientificName)) {
        return 'This is a bird species that was detected in the audio recording. '
               'The classification was made using acoustic analysis of the recorded sound. '
               'Bird songs and calls are unique to each species and can be used for identification. '
               'This detection represents the model\'s best prediction based on the audio patterns analyzed.';
      } else {
        return 'This appears to be a biological species detected in the audio recording. '
               'The classification was made using acoustic analysis of recorded sounds. '
               'Many animals produce distinctive vocalizations that can be used for species identification. '
               'This detection represents the model\'s analysis of the audio patterns.';
      }
    } else {
      // It's a non-biological sound
      final cleanName = speciesName.replaceAll('_', ' ').toLowerCase();
      return 'This appears to be a non-biological sound: "$cleanName". '
             'The audio classification model detected acoustic patterns consistent with this type of sound. '
             'The model can identify various environmental sounds, musical instruments, and other audio sources '
             'in addition to biological species.';
    }
  }

  bool _isLikelyBird(String speciesName, String scientificName) {
    // Basic heuristics to determine if it's likely a bird
    // This could be enhanced with a more comprehensive database lookup
    final birdGenera = [
      'Turdus', 'Corvus', 'Parus', 'Falco', 'Buteo', 'Accipiter', 'Strix', 'Bubo',
      'Picus', 'Dendrocopos', 'Hirundo', 'Delichon', 'Anas', 'Ardea', 'Passer',
      'Fringilla', 'Carduelis', 'Erithacus', 'Phylloscopus', 'Sylvia', 'Motacilla',
      'Anthus', 'Lanius', 'Emberiza', 'Alauda', 'Garrulus', 'Pica', 'Sturnus',
      'Columba', 'Streptopelia', 'Cuculus', 'Upupa', 'Alcedo', 'Merops', 'Coracias'
    ];

    final genus = scientificName.split(' ').first;
    return birdGenera.contains(genus);
  }

  void _loadSpeciesImage() async {
    setState(() {
      _isLoadingImage = true;
    });

    try {
      final imageResult = await ImageService.getImageWithAttribution(
        widget.prediction.speciesName,
        _scientificName.isNotEmpty ? _scientificName : null,
      );

      setState(() {
        _imageUrl = imageResult.imageUrl;
        _imageAttribution = imageResult.attribution;
        _isLoadingImage = false;
      });
    } catch (e) {
      setState(() {
        _imageUrl = null;
        _imageAttribution = null;
        _isLoadingImage = false;
      });
    }
  }

  void _loadWikipediaText() async {
    setState(() {
      _isLoadingWikipedia = true;
    });

    try {
      final wikipediaText = await ImageService.getWikipediaText(_scientificName);
      setState(() {
        _wikipediaText = wikipediaText;
        _isLoadingWikipedia = false;
      });
    } catch (e) {
      setState(() {
        _wikipediaText = null;
        _isLoadingWikipedia = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.prediction.speciesName),
        backgroundColor: Color(0xFF549342),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Species Image
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoadingImage
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              final icon = ImageService.getSpeciesIcon(_scientificName, widget.prediction.speciesName);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      icon,
                                      style: const TextStyle(fontSize: 64),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ImageService.getSpeciesIcon(_scientificName, widget.prediction.speciesName),
                                style: const TextStyle(fontSize: 64),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No image available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),

            // Image Attribution
            if (_imageAttribution != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.photo, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final url = _imageAttribution!.sourceUrl ?? _imageAttribution!.licenseUrl;
                          if (url != null) {
                            _launchUrl(url);
                          }
                        },
                        child: Text(
                          'Image: ${_imageAttribution!.source}${_imageAttribution!.license != null ? ' (${_imageAttribution!.license})' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: (_imageAttribution!.sourceUrl != null || _imageAttribution!.licenseUrl != null)
                                ? Colors.blue[700]
                                : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                            decoration: (_imageAttribution!.sourceUrl != null || _imageAttribution!.licenseUrl != null)
                                ? TextDecoration.underline
                                : null,
                          ),
                        ),
                      ),
                    ),
                    if (_imageAttribution!.licenseUrl != null ||
                        _imageAttribution!.sourceUrl != null)
                      Icon(Icons.open_in_new, size: 14, color: Colors.blue[700]),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Species Name and Confidence
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.prediction.speciesName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_scientificName.isNotEmpty && _scientificName != widget.prediction.speciesName)
                        Text(
                          _scientificName,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(widget.prediction.confidence),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(widget.prediction.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Wikipedia Information (for biological species)
            if (_scientificName.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.article, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'About This Species',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingWikipedia)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_wikipediaText != null) ...[
                        Text(
                          _wikipediaText!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.language, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  final url = 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(_scientificName)}';
                                  _launchUrl(url);
                                },
                                child: Text(
                                  'Source: Wikipedia (CC BY-SA 3.0)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                    fontStyle: FontStyle.italic,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            Icon(Icons.open_in_new, size: 14, color: Colors.blue[700]),
                          ],
                        ),
                      ] else
                        Text(
                          'No additional information available from Wikipedia.',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Detection Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Detection Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _description,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Technical Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.science, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Technical Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Confidence Score', '${(widget.prediction.confidence * 100).toStringAsFixed(2)}%'),
                    _buildDetailRow('Model Index', '${widget.prediction.index}'),
                    _buildDetailRow('Classification Type', _scientificName.isNotEmpty ? 'Biological Species' : 'Environmental Sound'),
                    if (_scientificName.isNotEmpty)
                      _buildDetailRow('Scientific Name', _scientificName),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) {
      return Colors.green;
    } else if (confidence >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}