import 'dart:io';
import 'dart:math';

import 'package:assignment661/bottom_navi.dart';
import 'package:assignment661/favourite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List? _outputs;
  File? _image;
  bool _loading = false;
  int _selectedIndex = 0;
  PageController _pageController = PageController(initialPage: 0);

  // Added variable to control button enable/disable

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @override
  void initState() {
    super.initState();
    _loading = true;

    loadModel().then((value) {
      setState(() {
        _loading = false;
      });
    });
  }

  loadModel() async {
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/labels.txt",
    );
  }

  pickImage() async {
    try {
      // Attempt to open the image picker
      final XFile? image =
          await ImagePicker().pickImage(source: ImageSource.camera);

      // If the image picker was canceled or closed, do nothing
      if (image == null) return;

      setState(() {
        _loading = true;
        _image = File(image.path);
      });

      classifyImage(_image!, context);
    } catch (e) {
      // Handle the exception, if necessary
      print('Error picking image: $e');
    }
  }

  classifyImage(File image, BuildContext context) async {
    var output = await Tflite.runModelOnImage(
      path: image.path,
      numResults: 2,
      threshold: 0.5,
      imageMean: 127.5,
      imageStd: 127.5,
    );
    setState(() {
      _loading = false;
      _outputs = output!;
    });

    if (_outputs != null) {
      String predictedLabel = _outputs![0]["label"];

      // Retrieve recommended song from Firebase Firestore
      //fetchRecommendedSong(predictedLabel, context);
    }
  }

  void fetchRecommendedSong(String label, BuildContext context) async {
    try {
      CollectionReference collection;
      label = label.trim().toLowerCase();
      // Determine the collection based on the predicted label
      if (label.toLowerCase() == '0 happy') {
        collection = _firestore.collection('Happy Songs');
      } else if (label.toLowerCase() == '1 sad') {
        collection = _firestore.collection('Sad Songs');
      } else {
        print('Unknown label: $label');
        return;
      }

      // Fetch song data from the appropriate collection
      QuerySnapshot<Object?> snapshot = await collection.get();
      print('Fetched song data');

      if (snapshot.docs.isNotEmpty) {
        // Song data found, use it as needed
        int randomIndex = Random().nextInt(snapshot.docs.length);
        String recommendedSongTitle = snapshot.docs[randomIndex]['Title'];
        String recommendedSongSinger = snapshot.docs[randomIndex]['Artist'];
        String imageFilePath = snapshot.docs[randomIndex]['Image'];

        // Display a pop-up with the recommended song
        _showRecommendedSongPopup(
          context,
          recommendedSongTitle,
          recommendedSongSinger,
          imageFilePath,
        );
      } else {
        print('No song found for label: $label');
      }
    } catch (e) {
      print('Error retrieving recommended song: $e');
    }
  }

  void _showRecommendedSongPopup(
    BuildContext context,
    String recommendedSongTitle,
    String recommendedSongSinger,
    String imageFilePath,
  ) {
    try {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          bool isFavorite = false;
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              title: Text('Recommended Song'),
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    imageFilePath,
                    height: 100, // Set the desired height
                    width: 100, // Set the desired width
                    fit: BoxFit.cover,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                            child: Text(
                          'Title: $recommendedSongTitle',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        )),
                        Text('Artist: $recommendedSongSinger'),
                      ],
                    ),
                  )
                ],
              ),
              actions: [
                // Favorite button
                TextButton(
                  onPressed: () async {
                    // Toggle favorite status
                    setState(() {
                      isFavorite = !isFavorite;
                    });
                    // Save or remove the song from the Favorites collection
                    await handleFavorite(
                      recommendedSongTitle,
                      recommendedSongSinger,
                      imageFilePath,
                      isFavorite,
                    );
                  },
                  child: Text(isFavorite
                      ? 'Remove from Favorites'
                      : 'Add to Favorites'),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the pop-up
                  },
                  child: Text('Close'),
                ),
              ],
            );
          });
        },
      );
    } catch (e) {
      print('Error showing pop-up: $e');
    }
  }

  Future<void> handleFavorite(
    String title,
    String artist,
    String imageFilePath,
    bool isFavorite,
  ) async {
    try {
      // Check if the "Favorites" collection exists
      final QuerySnapshot<Object?> favoritesCollectionCheck =
          await _firestore.collection('Favorites').limit(1).get();
      // Create "Favorites" collection if it doesn't exist
      if (favoritesCollectionCheck.docs.isEmpty) {
        print('Favorites collection does not exist.');
      }
      // Determine the collection based on the favorite status
      CollectionReference collection =
          _firestore.collection(isFavorite ? 'Favorites' : 'OtherCollection');

      // Check if the song is already in the collection based on its title and artist
      QuerySnapshot<Object?> snapshot = await collection
          .where('Title', isEqualTo: title)
          .where('Artist', isEqualTo: artist)
          .get();

      // Add or remove the song based on the conditions
      if (snapshot.docs.isEmpty && isFavorite) {
        // Song not in Favorites, add it
        await collection.add({
          'Title': title,
          'Artist': artist,
          'Image': imageFilePath,
        });
      } else if (snapshot.docs.isNotEmpty && !isFavorite) {
        // Song in Favorites, remove it
        await collection.doc(snapshot.docs.first.id).delete();
      }
    } catch (e) {
      print('Error handling favorite: $e');
    }
  }

  void _showInfoPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Info'),
          content: Text(
            'Click on the camera button, show a thumbs up if youre happy, and a thumbs down if youre sad. Then,  press the Show Recommended Song button, to get your song!',
            textAlign: TextAlign.justify,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: PageView(
        controller: _pageController,
        children: [
          Builder(
            builder: (BuildContext builderContext) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(30, 70, 30, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF1D3D6C).withOpacity(0.8),

                        // Adjust the background color and opacity as needed
                        borderRadius: BorderRadius.circular(
                            10), // Adjust the border radius for rounded corners
                      ),
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good Day!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w100),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Whats your mood today?',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w400),
                                ),
                              ),
                              SizedBox(width: 1),
                              IconButton(
                                onPressed: () {
                                  _showInfoPopup(context);
                                },
                                icon: Icon(
                                  Icons.info_outline,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),
                    _loading
                        ? Container(
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(),
                          )
                        : Container(
                            width: MediaQuery.of(context).size.width,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: MediaQuery.of(context).size.width,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Card(
                                        elevation:
                                            5, // Adjust the elevation for the shadow effect
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              10), // Adjust the border radius
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: _image == null
                                              ? Container()
                                              : Image.file(
                                                  _image!,
                                                  height:
                                                      200, // Set the desired height
                                                  width:
                                                      200, // Set the desired width
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  height: 20,
                                ),
                                _outputs != null
                                    ? Column(
                                        children: [
                                          SizedBox(
                                            height: 20,
                                          ),
                                          Text('You are currently feeling...',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w100)),
                                          SizedBox(
                                            height: 20,
                                          ),
                                          Text(
                                            "${_outputs?[0]["label"].toString().split(' ').last}",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20.0,
                                                fontStyle: FontStyle.italic),
                                          ),
                                          SizedBox(
                                            height: 40,
                                          ),
                                          Builder(builder:
                                              (BuildContext buildContext) {
                                            return ElevatedButton(
                                              onPressed: _outputs != null
                                                  ? () {
                                                      // Button action when pressed
                                                      fetchRecommendedSong(
                                                        _outputs![0]["label"]
                                                            .toString()
                                                            .toLowerCase()
                                                            .trim(),
                                                        context,
                                                      );
                                                    }
                                                  : null,
                                              child:
                                                  Text('Show Recommended Song'),
                                            );
                                          }),
                                        ],
                                      )
                                    : Container()
                              ],
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
          FavoritesPage(),
        ],
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        height: 75.0,
        width: 75.0,
        child: FittedBox(
          child: FloatingActionButton(
            onPressed: () {
              pickImage();
            },
            backgroundColor: Color(0xFF1D3D6C),
            child: Icon(
              Icons.camera,
              color: Colors.white,
            ),
            elevation: 10, // Adjust the elevation for the shadow effect
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0), // Make it round
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigation(
        selectedIndex: _selectedIndex,
        onTabChange: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        },
      ),
    );
  }
}
