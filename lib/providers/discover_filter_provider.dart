import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:equatable/equatable.dart';
import '../models/sort_by.dart';

part 'discover_filter_provider.g.dart';

class DiscoverFilterState extends Equatable {
  final SortBy sortBy;
  final String? prefecture;
  final Set<String> sizeRanges;
  final Set<String> squidTypes;
  final int? periodDays;
  final Set<String> weather;
  final Set<String> timeOfDay;

  const DiscoverFilterState({
    this.sortBy = SortBy.createdAt,
    this.prefecture,
    this.sizeRanges = const {},
    this.squidTypes = const {},
    this.periodDays,
    this.weather = const {},
    this.timeOfDay = const {},
  });

  DiscoverFilterState copyWith({
    SortBy? sortBy,
    String? prefecture,
    bool clearPrefecture = false,
    Set<String>? sizeRanges,
    Set<String>? squidTypes,
    int? periodDays,
    bool clearPeriodDays = false,
    Set<String>? weather,
    Set<String>? timeOfDay,
  }) {
    return DiscoverFilterState(
      sortBy: sortBy ?? this.sortBy,
      prefecture: clearPrefecture ? null : prefecture ?? this.prefecture,
      sizeRanges: sizeRanges ?? this.sizeRanges,
      squidTypes: squidTypes ?? this.squidTypes,
      periodDays: clearPeriodDays ? null : periodDays ?? this.periodDays,
      weather: weather ?? this.weather,
      timeOfDay: timeOfDay ?? this.timeOfDay,
    );
  }
  @override
  List<Object?> get props => [
        sortBy,
        prefecture,
        sizeRanges,
        squidTypes,
        periodDays,
        weather,
        timeOfDay,
      ];
}

@Riverpod(keepAlive: true)
class DiscoverFilterNotifier extends _$DiscoverFilterNotifier {
  @override
  DiscoverFilterState build() {
    return DiscoverFilterState();
  }

  void updateSortBy(SortBy newSortBy) {
    state = state.copyWith(sortBy: newSortBy);
  }

  void setPrefecture(String? p) {
    state = state.copyWith(prefecture: p, clearPrefecture: p == null);
  }

  void toggleSizeRange(String r) {
    final newSet = Set<String>.from(state.sizeRanges);
    if (newSet.contains(r)) {
      newSet.remove(r);
    } else {
      newSet.add(r);
    }
    state = state.copyWith(sizeRanges: newSet);
  }

  void toggleSquidType(String t) {
    final newSet = Set<String>.from(state.squidTypes);
    if (newSet.contains(t)) {
      newSet.remove(t);
    } else {
      newSet.add(t);
    }
    state = state.copyWith(squidTypes: newSet);
  }

  void setPeriod(int? d) {
    state = state.copyWith(periodDays: d, clearPeriodDays: d == null);
  }

  void toggleWeather(String w) {
    final newSet = Set<String>.from(state.weather);
    if (newSet.contains(w)) {
      newSet.remove(w);
    } else {
      newSet.add(w);
    }
    state = state.copyWith(weather: newSet);
  }

  void toggleTimeOfDay(String t) {
    final newSet = Set<String>.from(state.timeOfDay);
    if (newSet.contains(t)) {
      newSet.remove(t);
    } else {
      newSet.add(t);
    }
    state = state.copyWith(timeOfDay: newSet);
  }

  void resetFilters() {
    state = DiscoverFilterState();
  }
}
