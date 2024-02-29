import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

class PreviewPage extends StatefulWidget {
  const PreviewPage({Key? key, required this.picture}) : super(key: key);

  final XFile picture;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  bool isLoading = false;
  String returnedResponse = '';
  Future<Uint8List> getBytesFromAsset(String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    return bytes.buffer.asUint8List();
  }

  Future<Uint8List> compressCapturedFile(File file) async {
    var result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      numberOfRetries: 8,
      quality: 50,
    );
    print(file.lengthSync());
    print(result!.length);
    return result;
  }

  Future detectMealItem() async {
    setState(() {
      returnedResponse = '';
      isLoading = true;
    });
    try {
      final model = GenerativeModel(
        model: 'gemini-1.0-pro-vision-latest',
        apiKey: {your_api_key},
      );

      const prompt =
          '''list all food items with calories and quantity of each item you seeing in image.
                                    quantity should be accurate accoring to the image.
                                     items must be listed in json format as a list:
                                    {item_name,quantity in the image,calories in the quantity(that is in the image)}
                                    follow the format in every reponse. only return items list no other text
                                    here is the sample item for json list:
                                    {"item_name": "edamame","quantity": "50g","calories": "36"}.
                                    if any meal item not found in the attached picture then return an empty list only like this [].
                                    ''';
      print('Prompt: $prompt');
      Uint8List img = await compressCapturedFile(File(widget.picture.path));
      // Uint8List img = await getBytesFromAsset('assets/img.jpg');
      // print(img);
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', img),
        ])
      ];

      final response = await model.generateContent(content);

      print(response.text.toString());
      mealsData = jsonDecode(response.text.toString());
      if (mealsData.isEmpty) {
        returnedResponse = 'No meal found in the image';
      }
      print(mealsData);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print(e);
      returnedResponse = 'Error Ocurred: Try Again.';
      setState(() {
        isLoading = false;
      });
    }
  }

  List<dynamic> mealsData = [];

  @override
  Widget build(BuildContext context) {
    // picture.readAsBytes();
    return Scaffold(
        appBar: AppBar(
          title: const Text('Preview Page'),
          toolbarHeight: 80,
          actions: [
            isLoading
                ? const Padding(
                    padding: EdgeInsets.all(5.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : MaterialButton(
                    onPressed: () {
                      detectMealItem();
                    },
                    color: Colors.green,
                    shape: const StadiumBorder(),
                    child: const Text('Perform AI Detection'),
                  ),
          ],
        ),
        body: SingleChildScrollView(
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                const SizedBox(height: 15),
                // Image.asset(
                //   'assets/img.jpg',
                //   fit: BoxFit.cover,
                //   width: 250,
                //   height: 300,
                // ),
                Image.file(
                  File(widget.picture.path),
                  fit: BoxFit.cover,
                  width: 250,
                  height: 250,
                ),
                const SizedBox(height: 25),
                // Text(widget.picture.name),

                // const SizedBox(height: 25),
                if (mealsData.isEmpty)
                  Text(
                    returnedResponse,
                    style: const TextStyle(fontSize: 20.0),
                  ),
                if (mealsData.isNotEmpty)
                  DataTable(
                    columns: const [
                      DataColumn(
                          label: Text(
                        'Item Name',
                        style: TextStyle(
                            fontSize: 15.0, fontWeight: FontWeight.w700),
                      )),
                      DataColumn(
                          label: Text(
                        'Quantity',
                        style: TextStyle(
                            fontSize: 15.0, fontWeight: FontWeight.w700),
                      )),
                      DataColumn(
                          label: Text(
                        'Calories',
                        style: TextStyle(
                            fontSize: 15.0, fontWeight: FontWeight.w700),
                      )),
                    ],
                    rows: mealsData
                        .map((item) => DataRow(
                              cells: [
                                DataCell(Text(
                                  item["item_name"],
                                  style: const TextStyle(fontSize: 15.0),
                                )),
                                DataCell(Text(
                                  item["quantity"].toString(),
                                  style: const TextStyle(fontSize: 15.0),
                                )), // Convert quantity to string for display
                                DataCell(Text(
                                  item["calories"].toString(),
                                  style: const TextStyle(fontSize: 15.0),
                                )), // Convert calories to string for display
                              ],
                            ))
                        .toList(),
                  )
              ])),
        ));
  }
}
