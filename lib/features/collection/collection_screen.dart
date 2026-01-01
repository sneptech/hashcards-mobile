import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../drill/drill_screen.dart';
import 'collection_bloc.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hashcards')),
      body: BlocBuilder<CollectionBloc, CollectionState>(
        builder: (context, state) {
          return switch (state) {
            CollectionInitializing() => _buildInitializingView(),
            CollectionInitial(:final defaultPath) => _buildInitialView(context, defaultPath),
            CollectionLoading() => _buildLoadingView(),
            CollectionLoaded(
              :final collection,
              :final totalCards,
              :final dueCards,
              :final newCards
            ) =>
              _buildLoadedView(
                  context, collection, totalCards, dueCards, newCards),
            CollectionError(:final message) => _buildErrorView(context, message),
          };
        },
      ),
    );
  }

  Widget _buildInitializingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Setting up flashcards...'),
        ],
      ),
    );
  }

  Widget _buildInitialView(BuildContext context, String? defaultPath) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text('No collection loaded',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Select a folder containing your Markdown flashcards',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _pickDirectory(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Collection'),
            ),
            if (defaultPath != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  context.read<CollectionBloc>().add(LoadCollection(defaultPath));
                },
                icon: const Icon(Icons.home),
                label: const Text('Open Default (Documents/hashcards)'),
              ),
              const SizedBox(height: 16),
              Text(
                'Default location: $defaultPath',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading collection...'),
        ],
      ),
    );
  }

  Widget _buildLoadedView(
    BuildContext context,
    collection,
    int totalCards,
    int dueCards,
    int newCards,
  ) {
    final toReview = dueCards + newCards;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          collection.directoryPath.split('/').last,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          context.read<CollectionBloc>().add(const CloseCollection());
                        },
                        tooltip: 'Close collection',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    collection.directoryPath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total', value: '$totalCards')),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Due', value: '$dueCards')),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'New', value: '$newCards')),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: FilledButton.icon(
              onPressed: toReview > 0
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: context.read<CollectionBloc>(),
                            child: const DrillScreen(),
                          ),
                        ),
                      )
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(toReview > 0
                  ? 'Start Drilling ($toReview cards)'
                  : 'No cards due today'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load collection',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _pickDirectory(context),
              icon: const Icon(Icons.folder_open),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDirectory(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Flashcard Collection',
    );

    if (result != null && context.mounted) {
      context.read<CollectionBloc>().add(LoadCollection(result));
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
