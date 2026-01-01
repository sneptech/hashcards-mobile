import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/fsrs/performance.dart';
import '../../core/services/deck_initializer.dart';
import 'collection_repository.dart';

// Events
sealed class CollectionEvent extends Equatable {
  const CollectionEvent();

  @override
  List<Object?> get props => [];
}

class LoadCollection extends CollectionEvent {
  final String directoryPath;

  const LoadCollection(this.directoryPath);

  @override
  List<Object?> get props => [directoryPath];
}

class CloseCollection extends CollectionEvent {
  const CloseCollection();
}

class InitializeAndLoadDefault extends CollectionEvent {
  const InitializeAndLoadDefault();
}

// States
sealed class CollectionState extends Equatable {
  const CollectionState();

  @override
  List<Object?> get props => [];
}

class CollectionInitial extends CollectionState {
  final String? defaultPath;
  
  const CollectionInitial({this.defaultPath});
  
  @override
  List<Object?> get props => [defaultPath];
}

class CollectionInitializing extends CollectionState {
  const CollectionInitializing();
}

class CollectionLoading extends CollectionState {
  const CollectionLoading();
}

class CollectionLoaded extends CollectionState {
  final Collection collection;
  final int totalCards;
  final int dueCards;
  final int newCards;

  const CollectionLoaded({
    required this.collection,
    required this.totalCards,
    required this.dueCards,
    required this.newCards,
  });

  @override
  List<Object?> get props =>
      [collection.directoryPath, totalCards, dueCards, newCards];
}

class CollectionError extends CollectionState {
  final String message;

  const CollectionError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class CollectionBloc extends Bloc<CollectionEvent, CollectionState> {
  final CollectionRepository repository;

  CollectionBloc({required this.repository}) : super(const CollectionInitializing()) {
    on<LoadCollection>(_onLoadCollection);
    on<CloseCollection>(_onCloseCollection);
    on<InitializeAndLoadDefault>(_onInitializeAndLoadDefault);
  }

  Future<void> _onInitializeAndLoadDefault(
    InitializeAndLoadDefault event,
    Emitter<CollectionState> emit,
  ) async {
    emit(const CollectionInitializing());
    
    try {
      // Initialize bundled decks and get default path
      final defaultPath = await DeckInitializer.initializeIfNeeded();
      
      // Check if there are decks to load
      final hasDecks = await DeckInitializer.hasDefaultDecks();
      
      if (hasDecks) {
        // Auto-load the default collection
        add(LoadCollection(defaultPath));
      } else {
        // No decks found, show initial screen with default path hint
        emit(CollectionInitial(defaultPath: defaultPath));
      }
    } catch (e) {
      // Initialization failed, show initial screen without default path
      emit(const CollectionInitial());
    }
  }

  Future<void> _onLoadCollection(
    LoadCollection event,
    Emitter<CollectionState> emit,
  ) async {
    emit(const CollectionLoading());

    try {
      final collection = await repository.loadCollection(event.directoryPath);

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final dueHashes = await collection.db.dueToday(todayDate);

      int newCards = 0;
      int dueCards = 0;

      for (final card in collection.cards) {
        final perf = await collection.db.getCardPerformanceOpt(card.hash);
        if (perf == null || perf is NewPerformance) {
          newCards++;
        } else if (dueHashes.contains(card.hash)) {
          dueCards++;
        }
      }

      emit(CollectionLoaded(
        collection: collection,
        totalCards: collection.cards.length,
        dueCards: dueCards,
        newCards: newCards,
      ));
    } catch (e) {
      emit(CollectionError(e.toString()));
    }
  }

  Future<void> _onCloseCollection(
    CloseCollection event,
    Emitter<CollectionState> emit,
  ) async {
    await repository.closeCollection();
    emit(const CollectionInitial());
  }
}
