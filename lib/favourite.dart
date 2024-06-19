import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesPage extends StatelessWidget {
  int _currentIndex = 1;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to the home page when the user presses the back button
        Navigator.pop(context);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.blueGrey,
        body: _buildFavoritesList(),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return FutureBuilder<QuerySnapshot>(
      future: _fetchFavoriteSongs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16.0),
            child: Text('No favorite songs.'),
          );
        } else {
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var song =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildDismissibleListItem(context, song, index == 0);
            },
          );
        }
      },
    );
  }

  Widget _buildDismissibleListItem(
      BuildContext context, Map<String, dynamic>? song, bool isFirst) {
    if (song == null || song.isEmpty) {
      return Container();
    }

    return Dismissible(
      key: Key(song['Title'] ?? 'Unknown Title'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16.0),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await _deleteFavoriteSong(song['Title']);
      },
      child: Card(
        elevation: 3,
        margin: isFirst
            ? EdgeInsets.only(top: 25, bottom: 8, left: 16, right: 16)
            : EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ListTile(
          title: Text(
            song['Title'] ?? 'Unknown Title',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(song['Artist'] ?? 'Unknown Artist'),
          leading: _buildImageWidget(song['Image'] ?? 'Unknown Image'),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    final placeholderImage = AssetImage('assets/placeholder_image.png');

    return Image.network(
      imageUrl != null && imageUrl is String ? imageUrl : '',
      width: 50,
      height: 50,
      fit: BoxFit.cover,
    );
  }

  Future<QuerySnapshot> _fetchFavoriteSongs() async {
    return FirebaseFirestore.instance.collection('Favorites').get();
  }

  Future<void> _deleteFavoriteSong(String title) async {
    try {
      // Query for the document with the matching title
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Favorites')
          .where('Title', isEqualTo: title)
          .get();

      // Check if any matching documents were found
      if (querySnapshot.docs.isNotEmpty) {
        // Delete the first matching document
        await querySnapshot.docs.first.reference.delete();
      } else {
        // Handle the case where no matching document was found
        print('No matching document found with title: $title');
      }
    } catch (e) {
      print('Error deleting favorite song: $e');
      // Handle the error or provide a user-friendly message
    }
  }
}
