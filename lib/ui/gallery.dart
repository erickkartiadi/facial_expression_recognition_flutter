/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../helper/image_classification_helper.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  ImageClassificationHelper? imageClassificationHelper;
  img.Image? image;
  Map<String, double>? classification;
  File? imageFile;


  var inferenceTime = 0;
  var inferenceTimeTotal = 0;
  var count = 0;

  double inferenceTimeAverage = 0;

  @override
  void initState() {
    imageClassificationHelper = ImageClassificationHelper();
    imageClassificationHelper!.initHelper();
    super.initState();
  }

  void cleanResult() {
    setState(() {
      inferenceTime = 0;
      inferenceTimeTotal = 0;
      inferenceTimeAverage = 0;
      image = null;
      classification = null;
      imageFile = null;
    });
  }

  void handleButtonPressed() async {
    List<String> labels = [
      "angry",
      "disgusted",
      "fearful",
      "happy",
      "neutral",
      "sad",
      "surprised"
    ];

    List<String> selectedImagesPath = [];

    for (var label in labels) {
      final folderPath = "assets/images/test/$label/";
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final imagesPath = assetManifest
          .listAssets()
          .where((string) => string.startsWith(folderPath))
          .toList();

      // select 5 random images path
      final random = Random();
      const max = 5;
      for (var i = 0; i < max; i++) {
        final randomIndex = random.nextInt(imagesPath.length);
        selectedImagesPath.add(imagesPath[randomIndex]);
        imagesPath.removeAt(randomIndex);
      }
    }



    var tempDir = (await getTemporaryDirectory());
    tempDir.deleteSync(recursive: true);
    tempDir = await tempDir.create(recursive: true);

    cleanResult();

    for (var imagePath in selectedImagesPath) {
      await processImage(imagePath, tempDir.path);
    }

    setState(() {
      inferenceTimeAverage = inferenceTimeTotal / selectedImagesPath.length;
    });
  }

  // Process picked image
  Future<void> processImage(String imagePath, String tempDir) async {
    final byteData = await rootBundle.load(imagePath);
    final file = File('$tempDir/$imagePath');

    await file.create(recursive: true);
    await file.writeAsBytes(byteData.buffer
        .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    final imageByte = file.readAsBytesSync();
    image = img.decodeImage(imageByte);

    final Stopwatch watch = Stopwatch()..start(); // Create a stopwatch
    classification = await imageClassificationHelper?.inferenceImage(image!);
    watch.stop(); // Stop the stopwatch

    setState(() {
      imagePath = imagePath;
      imageFile = file;

      inferenceTime = watch.elapsedMilliseconds;
      inferenceTimeTotal += inferenceTime;
    });
  }

  @override
  void dispose() {
    imageClassificationHelper?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton.icon(
                onPressed: handleButtonPressed,
                style: ButtonStyle(
                  foregroundColor:
                      MaterialStateProperty.all<Color>(Colors.green),
                ),
                icon: const Icon(
                  Icons.play_arrow,
                  size: 48,
                ),
                label: const Text("Start"),
              ),
              TextButton.icon(
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all<Color>(Colors.red),
                ),
                onPressed: () {
                  cleanResult();
                },
                icon: const Icon(
                  Icons.refresh,
                  size: 48,
                ),
                label: const Text("Reset"),
              ),
            ],
          ),
          const Divider(color: Colors.black),
          Expanded(
              child: Stack(
            alignment: Alignment.center,
            children: [
              if (imageFile != null)
                Image.file(
                  imageFile!,
                  fit: BoxFit.cover,
                  width: 400,
                  height: 400,
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(),
                  if (image != null) ...[
                    // Show model information
                    if (imageClassificationHelper?.inputTensor != null)
                      Text(
                        'Input: (shape: ${imageClassificationHelper?.inputTensor.shape} type: '
                        '${imageClassificationHelper?.inputTensor.type})',
                      ),
                    if (imageClassificationHelper?.outputTensor != null)
                      Text(
                        'Output: (shape: ${imageClassificationHelper?.outputTensor.shape} '
                        'type: ${imageClassificationHelper?.outputTensor.type})',
                      ),
                    const SizedBox(height: 8),
                    // Show picked image information
                    // Text('Num channels: ${image?.numChannels}'),
                    // Text('Bits per channel: ${image?.bitsPerChannel}'),
                    // Text('Height: ${image?.height}'),
                    // Text('Width: ${image?.width}'),
                    Text('Inference time: $inferenceTime'),
                    Text('Inference time total: $inferenceTimeTotal'),
                    Text('Inference time average: $inferenceTimeAverage'),
                  ],
                  const Spacer(),
                  // Show classification result
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        if (classification != null)
                          ...(classification!.entries.toList()
                                ..sort(
                                  (a, b) => a.value.compareTo(b.value),
                                ))
                              .reversed
                              .take(3)
                              .map(
                                (e) => Container(
                                  padding: const EdgeInsets.all(8),
                                  color: Colors.white,
                                  child: Row(
                                    children: [
                                      Text(e.key),
                                      const Spacer(),
                                      Text(e.value.toStringAsFixed(2))
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          )),
        ],
      ),
    );
  }
}
