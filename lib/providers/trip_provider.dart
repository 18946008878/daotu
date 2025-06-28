import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../db/db_helper.dart';

class TripProvider with ChangeNotifier {
  List<Trip> _trips = [];
  List<Trip> get trips => _trips;

  int _page = 1;
  final int _pageSize = 20;
  bool hasMore = true;
  bool isLoading = false;

  // 分页加载（重置）
  Future<void> loadTrips({bool reset = true}) async {
    if (reset) {
      _page = 1;
      _trips = [];
      hasMore = true;
    }
    isLoading = true;
    notifyListeners();
    final newTrips = await DBHelper().getTripsPaged(_page, _pageSize);
    if (reset) {
      _trips = newTrips;
    } else {
      _trips.addAll(newTrips);
    }
    hasMore = newTrips.length == _pageSize;
    isLoading = false;
    notifyListeners();
  }

  // 加载更多
  Future<void> loadMoreTrips() async {
    if (!hasMore || isLoading) return;
    _page++;
    await loadTrips(reset: false);
  }

  Future<void> addTrip(Trip trip) async {
    await DBHelper().insertTrip(trip);
    await loadTrips();
  }

  Future<void> deleteTrip(int id) async {
    await DBHelper().deleteTrip(id);
    await loadTrips();
  }

  Future<void> updateTrip(Trip trip) async {
    await DBHelper().updateTrip(trip);
    await loadTrips();
  }
}
