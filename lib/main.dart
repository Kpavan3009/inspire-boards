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