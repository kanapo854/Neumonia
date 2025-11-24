import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class ResultsScreen extends StatefulWidget {
  final XFile image;

  const ResultsScreen({
    super.key,
    required this.image,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _results;
  String? _error;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImageAndSend();
  }

  Future<void> _loadImageAndSend() async {
    try {
      // Leer los bytes de la imagen
      _imageBytes = await widget.image.readAsBytes();
      await _sendImageToApi();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar la imagen: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendImageToApi() async {
    try {
      final url = Uri.parse('https://modelotesis.onrender.com/predecir');
      
      // Crear la petición multipart
      var request = http.MultipartRequest('POST', url);
      
      // Agregar el archivo de imagen usando los bytes
      var imageFile = http.MultipartFile.fromBytes(
        'file',
        _imageBytes!,
        filename: 'image.jpeg',
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(imageFile);
      
      // Agregar headers
      request.headers['accept'] = 'application/json';
      
      print('Enviando imagen a la API...');
      
      // Enviar la petición
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print('Respuesta recibida: ${response.statusCode}');
      print('Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _results = _processApiResponse(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error al procesar la imagen.\nCódigo: ${response.statusCode}\nRespuesta: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error: $e');
      print('Stack: $stackTrace');
      setState(() {
        _error = 'Error de conexión: $e\n\nEsto puede deberse a:\n• Problema CORS en el servidor\n• Conexión a internet\n• Servidor no disponible\n\nPrueba usar la app móvil en lugar de web.';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _processApiResponse(dynamic apiData) {
    // Procesar la respuesta de la API
    final clasePredicha = apiData['clase_predicha'] ?? 'UNKNOWN';
    final hasPneumonia = clasePredicha == 'PNEUMONIA';
    final confianza = apiData['confianza'] ?? 0.0;
    final confidence = (confianza * 100).toInt();

    return {
      'diagnosis': hasPneumonia ? 'Neumonía Detectada' : 'Normal',
      'confidence': confidence,
      'hasPneumonia': hasPneumonia,
      'details': hasPneumonia
          ? 'Se detectaron patrones compatibles con neumonía en la radiografía.'
          : 'La radiografía no muestra signos evidentes de neumonía.',
      'recommendation': hasPneumonia
          ? 'Se recomienda consultar con un médico especialista para un diagnóstico completo.'
          : 'Continuar con seguimiento médico regular.',
      'rawData': apiData, // Guardar datos originales para depuración
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Resultados de Evaluación'),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text(
                'Analizando imagen...',
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _loadImageAndSend();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final results = _results!;
    final bool hasPneumonia = results['hasPneumonia'];
    final int confidence = results['confidence'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultados de Evaluación'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen analizada
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _imageBytes != null
                        ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.memory(
                              _imageBytes!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Resultado principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: hasPneumonia
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: hasPneumonia ? Colors.red : Colors.green,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    hasPneumonia ? Icons.warning : Icons.check_circle,
                    size: 60,
                    color: hasPneumonia ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    results['diagnosis'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: hasPneumonia ? Colors.red[700] : Colors.green[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Confianza: $confidence%',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Barra de confianza
            const Text(
              'Nivel de Confianza',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: confidence / 100,
                minHeight: 20,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  hasPneumonia ? Colors.red : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Filtro Grad-CAM
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.purple),
                        SizedBox(width: 10),
                        Text(
                          'Filtro Grad-CAM',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/filtro_gamp.jpg',
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Detalles
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          'Detalles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      results['details'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Recomendación
            Card(
              elevation: 2,
              color: Colors.amber.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medical_services, color: Colors.orange),
                        SizedBox(width: 10),
                        Text(
                          'Recomendación',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      results['recommendation'],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Botón de nueva evaluación
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Nueva Evaluación',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Disclaimer
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este resultado es una evaluación preliminar. Consulte siempre con un profesional médico.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
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
}
