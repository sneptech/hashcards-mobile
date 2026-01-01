import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/collection/collection_bloc.dart';
import 'features/collection/collection_repository.dart';
import 'features/collection/collection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final collectionRepository = CollectionRepository();

  runApp(
    RepositoryProvider<CollectionRepository>.value(
      value: collectionRepository,
      child: BlocProvider<CollectionBloc>(
        create: (context) => CollectionBloc(repository: collectionRepository)
          ..add(const InitializeAndLoadDefault()),
        child: const HashcardsApp(),
      ),
    ),
  );
}

class HashcardsApp extends StatelessWidget {
  const HashcardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hashcards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const CollectionScreen(),
    );
  }
}
