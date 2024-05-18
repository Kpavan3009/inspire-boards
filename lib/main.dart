import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share/share.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

const String apiKey = 'v6W5jS4a0gXeK5_i0IocTRwFHh2uD6B2TWiphyLJm8c';
const String secretKey = 'HKxHRsnII598UUjGSA3mrDHeX1_Yih0SygsW1rug9MY';
const String baseUrl = 'https://api.unsplash.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(InspireBoard());
}

class InspireBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InspireBoard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return HomeFeedScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

 Future<void> _signInWithEmailAndPassword() async {
  // Navigate to the HomeFeedScreen without authentication
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => HomeFeedScreen()),
  );
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signInWithEmailAndPassword,
              child: Text('Login'),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
              child: Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

 Future<void> _signUpWithEmailAndPassword() async {
  try {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );
  } on FirebaseAuthException catch (e) {
    String errorMessage;
    switch (e.code) {
      case 'email-already-in-use':
        errorMessage = 'The email address is already in use by another account.';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email address.';
        break;
      case 'weak-password':
        errorMessage = 'The password is too weak.';
        break;
      default:
        errorMessage = 'An error occurred. Please try again.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred. Please try again.')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signUpWithEmailAndPassword,
              child: Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageData {
  final String id;
  final String url;
  final String description;
  final String originalUrl;

  ImageData({
    required this.id,
    required this.url,
    required this.description,
    required this.originalUrl,
  });

  ImageData copyWith({String? url}) {
    return ImageData(
      id: id,
      url: url ?? this.url,
      description: description,
      originalUrl: originalUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'description': description,
      'originalUrl': originalUrl,
    };
  }
}

class Collection {
  final String id;
  final String name;
  final List<ImageData> images;

  Collection({
    required this.id,
    required this.name,
    required this.images,
  });
}

class HomeFeedScreen extends StatefulWidget {
  @override
  _HomeFeedScreenState createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  List<ImageData> images = [];

  @override
  void initState() {
    super.initState();
    fetchImages();
  }

  Future<void> fetchImages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/photos/random?count=20'),
        headers: {'Authorization': 'Client-ID $apiKey'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          images = (jsonData as List)
              .map((imageData) => ImageData(
                    id: imageData['id'],
                    url: imageData['urls']['regular'],
                    description: imageData['description'] ?? '',
                    originalUrl: imageData['links']['html'],
                  ))
              .toList();
        });
      } else {
        throw Exception('Failed to load images');
      }
    } catch (e) {
      print('Error fetching images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            SizedBox(width: 8),
            Text('InspireBoard'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        itemCount: images.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ImageDetailsScreen(image: images[index]),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.network(
                    images[index].url,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(Icons.bookmark_border),
                                color: Colors.white,
                                onPressed: () {
                                  _saveForLater(images[index]);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.link),
                                color: Colors.white,
                                onPressed: () {
                                  _openOriginalPage(images[index].originalUrl);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.share),
                                color: Colors.white,
                                onPressed: () {
                                  _shareOnSocialMedia(images[index].url);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.more_vert),
                                color: Colors.white,
                                onPressed: () {
                                  _showMoreOptions(context, images[index]);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

Future<void> _saveForLater(ImageData image) async {
    final prefs = await SharedPreferences.getInstance();
    final savedImages = prefs.getStringList('savedImages') ?? [];
    savedImages.add(json.encode(image.toJson()));
    await prefs.setStringList('savedImages', savedImages);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image saved for later')),
    );
  }

  void _openOriginalPage(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _shareOnSocialMedia(String imageUrl) {
    Share.share('Check out this amazing image: $imageUrl');
  }

  void _showMoreOptions(BuildContext context, ImageData image) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Image Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageDetailsScreen(image: image),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.download),
              title: Text('Download Image'),
              onTap: () {
                _downloadImage(image.url);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/image.jpg');
    await file.writeAsBytes(bytes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image downloaded')),
    );
  }
}

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  List<ImageData> searchResults = [];

  void searchImages(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/search/photos?query=$query'),
        headers: {'Authorization': 'Client-ID $apiKey'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          searchResults = (jsonData['results'] as List)
              .map((imageData) => ImageData(
                    id: imageData['id'],
                    url: imageData['urls']['regular'],
                    description: imageData['description'] ?? '',
                    originalUrl: imageData['links']['html'],
                  ))
              .toList();
        });
      } else {
        throw Exception('Failed to search images');
      }
    } catch (e) {
      print('Error searching images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          onSubmitted: searchImages,
          decoration: InputDecoration(
            hintText: 'Search images',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      body: searchResults.isEmpty
          ? Center(child: Text('No search results'))
          : GridView.builder(
              itemCount: searchResults.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ImageDetailsScreen(image: searchResults[index]),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Image.network(
                          searchResults[index].url,
                          fit: BoxFit.cover,
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.bookmark_border),
                                      color: Colors.white,
                                      onPressed: () {
                                        _saveForLater(searchResults[index]);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.link),
                                      color: Colors.white,
                                      onPressed: () {
                                        _openOriginalPage(
                                            searchResults[index].originalUrl);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.share),
                                      color: Colors.white,
                                      onPressed: () {
                                        _shareOnSocialMedia(
                                            searchResults[index].url);
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.more_vert),
                                      color: Colors.white,
                                      onPressed: () {
                                        _showMoreOptions(
                                            context, searchResults[index]);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
 Future<void> _saveForLater(ImageData image) async {
    final prefs = await SharedPreferences.getInstance();
    final savedImages = prefs.getStringList('savedImages') ?? [];
    savedImages.add(json.encode(image.toJson()));
    await prefs.setStringList('savedImages', savedImages);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image saved for later')),
    );
  }

  void _openOriginalPage(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _shareOnSocialMedia(String imageUrl) {
    Share.share('Check out this amazing image: $imageUrl');
  }

  void _showMoreOptions(BuildContext context, ImageData image) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.info),
              title: Text('Image Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageDetailsScreen(image: image),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.download),
              title: Text('Download Image'),
              onTap: () {
                _downloadImage(image.url);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    final bytes = response.bodyBytes;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/image.jpg');
    await file.writeAsBytes(bytes);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
    content: Text('Image downloaded')),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Collection> collections = [];
  List<ImageData> uploadedImages = [];

  @override
  void initState() {
    super.initState();
    loadCollections();
    loadUploadedImages();
  }
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionData = prefs.getString('collections');

    if (collectionData != null) {
      final decodedData = json.decode(collectionData);
      setState(() {
        collections = (decodedData as List)
            .map((collectionData) => Collection(
                  id: collectionData['id'],
                  name: collectionData['name'],
                  images: (collectionData['images'] as List)
                      .map((imageData) => ImageData(
                            id: imageData['id'],
                            url: imageData['url'],
                            description: imageData['description'],
                            originalUrl: imageData['originalUrl'],
                          ))
                      .toList(),
                ))
            .toList();
      });
    }
  }

  Future<void> loadUploadedImages() async {
    final prefs = await SharedPreferences.getInstance();
    final uploadedImagesData = prefs.getString('uploadedImages');

    if (uploadedImagesData != null) {
      final decodedData = json.decode(uploadedImagesData);
      setState(() {
        uploadedImages = (decodedData as List)
            .map((imageData) => ImageData(
                  id: imageData['id'],
                  url: imageData['url'],
                  description: imageData['description'],
                  originalUrl: imageData['originalUrl'],
                ))
            .toList();
      });
    }
  }

  Future<void> saveCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionData = json.encode(collections.map((collection) => {
          'id': collection.id,
          'name': collection.name,
          'images': collection.images
              .map((image) => {
                    'id': image.id,
                    'url': image.url,
                    'description': image.description,
                    'originalUrl': image.originalUrl,
                  })
              .toList(),
        }).toList());
    await prefs.setString('collections', collectionData);
  }
 Future<void> saveUploadedImages() async {
    final prefs = await SharedPreferences.getInstance();
    final uploadedImagesData = json.encode(uploadedImages.map((image) => {
          'id': image.id,
          'url': image.url,
          'description': image.description,
          'originalUrl': image.originalUrl,
        }).toList());
    await prefs.setString('uploadedImages', uploadedImagesData);
  }

  void createCollection(String name) {
    setState(() {
      collections.add(Collection(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        images: [],
      ));
    });
    saveCollections();
  }

  void deleteCollection(String id) {
    setState(() {
      collections.removeWhere((collection) => collection.id == id);
    });
    saveCollections();
  }

  void addImageToCollection(ImageData image, String collectionId) {
    setState(() {
      collections
          .firstWhere((collection) => collection.id == collectionId)
          .images
          .add(image);
    });
    saveCollections();
  }

  void removeImageFromCollection(ImageData image, String collectionId) {
    setState(() {
      collections
          .firstWhere((collection) => collection.id == collectionId)
          .images
          .removeWhere((img) => img.id == image.id);
    });
    saveCollections();
  }

  void uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.getImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/uploaded_image.jpg');
      await file.writeAsBytes(bytes);
      final imageData = ImageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: file.path,
        description: '',
        originalUrl: '',
      );
      setState(() {
        uploadedImages.add(imageData);
      });
      saveUploadedImages();
    }
  }

  void getLocation() async {
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Location: Latitude ${position.latitude}, Longitude ${position.longitude}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                        'https://example.com/profile-image.jpg'), // Replace with actual profile image URL
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pavan Rikwith', // Replace with actual user name
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'kpavan3009@gmail.com', // Replace with actual user email
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Collections',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final collection = collections[index];
                return ListTile(
                  title: Text(collection.name),
                  subtitle: Text('${collection.images.length} images'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => deleteCollection(collection.id),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CollectionDetailsScreen(collection: collection),
                      ),
                    );
                  },
                );
              },
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Uploaded Images',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: uploadedImages.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemBuilder: (context, index) {
                final image = uploadedImages[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ImageDetailsScreen(image: image),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(image.url),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  String collectionName = '';
                  return AlertDialog(
                    title: Text('Create Collection'),
                    content: TextField(
                      onChanged: (value) {
                        collectionName = value;
                      },
                      decoration: InputDecoration(hintText: 'Collection Name'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          createCollection(collectionName);
                        },
                        child: Text('Create'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            child: Icon(Icons.camera_alt),
            onPressed: uploadImage,
          ),
          SizedBox(height: 16),
          FloatingActionButton(
            child: Icon(Icons.location_on),
            onPressed: getLocation,
          ),
        ],
      ),
    );
  }
}


class CollectionDetailsScreen extends StatelessWidget {
  final Collection collection;

  const CollectionDetailsScreen({Key? key, required this.collection})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        centerTitle: true,
      ),
      body: GridView.builder(
        itemCount: collection.images.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          final image = collection.images[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageDetailsScreen(image: image),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                image.url,
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}

class ImageDetailsScreen extends StatelessWidget {
  final ImageData image;

  const ImageDetailsScreen({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Details'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Image.network(
              image.url,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  image.description,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Save to Collection'),
                          content: FutureBuilder<List<Collection>>(
                            future: _getCollections(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final collections = snapshot.data!;
                                return ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: collections.length,
                                  itemBuilder: (context, index) {
                                    final collection = collections[index];
                                    return ListTile(
                                      title: Text(collection.name),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _addImageToCollection(
                                            context, image, collection.id);
                                      },
                                    );
                                  },
                                );
                              } else {
                                return CircularProgressIndicator();
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  child: Text('Save to Collection'),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Share.share('Check out this amazing image: ${image.url}');
                  },
                  child: Text('Share'),
                ),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    launch(image.originalUrl);
                  },
                  child: Text('Visit Original Source'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
  Future<List<Collection>> _getCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionData = prefs.getString('collections');
    if (collectionData != null) {
      final decodedData = json.decode(collectionData);
      return (decodedData as List)
          .map((collectionData) => Collection(
                id: collectionData['id'],
                name: collectionData['name'],
                images: (collectionData['images'] as List)
                    .map((imageData) => ImageData(
                          id: imageData['id'],
                          url: imageData['url'],
                          description: imageData['description'],
                          originalUrl: imageData['originalUrl'],
                        ))
                    .toList(),
              ))
          .toList();
    }
    return [];
  }

  void _addImageToCollection(
      BuildContext context, ImageData image, String collectionId) async {
    final prefs = await SharedPreferences.getInstance();
    final collectionData = prefs.getString('collections');
    if (collectionData != null) {
      final decodedData = json.decode(collectionData);
      final collections = (decodedData as List)
          .map((collectionData) => Collection(
                id: collectionData['id'],
                name: collectionData['name'],
                images: (collectionData['images'] as List)
                    .map((imageData) => ImageData(
                          id: imageData['id'],
                          url: imageData['url'],
                          description: imageData['description'],
                          originalUrl: imageData['originalUrl'],
                        ))
                    .toList(),
              ))
          .toList();
      final collection =
          collections.firstWhere((collection) => collection.id == collectionId);
      collection.images.add(image);
      final updatedCollectionData = json.encode(collections.map((collection) => {
            'id': collection.id,
            'name': collection.name,
            'images': collection.images
                .map((image) => {
                      'id': image.id,
                      'url': image.url,
                      'description': image.description,
                      'originalUrl': image.originalUrl,
                    })
                .toList(),
          }).toList());
      await prefs.setString('collections', updatedCollectionData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image added to collection')),
      );
    }
  }
}
