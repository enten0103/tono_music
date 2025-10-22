import 'package:flutter/material.dart';

class SearchPlaylistView extends StatelessWidget {
  const SearchPlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Playlist')),
      body: const Center(child: Text('Search Playlist View')),
    );
  }
}
