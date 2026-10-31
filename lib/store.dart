import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'providers.dart';

/// App-wide persisted state: history, favourites and settings.
class AppStore extends ChangeNotifier {
  late SharedPreferences _p;

  List<String> history = [];
  List<TorrentResult> favourites = [];
  Set<String> enabledProviders = allProviders.map((p) => p.id).toSet();
  Map<String, String> baseUrls = {};
  List<String> trackers = List.of(defaultTrackers);
  bool saveHistory = true;
  int minSeeders = 3;
  SortMode sort = SortMode.seeders;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    history = _p.getStringList('history') ?? [];
    favourites = (_p.getStringList('favourites') ?? [])
        .map((s) {
          try {
            return TorrentResult.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<TorrentResult>()
        .toList();
    final en = _p.getStringList('enabledProviders');
    if (en != null) enabledProviders = en.toSet();
    // Turn on sources added in app updates, without re-enabling ones the
    // user switched off.
    final allIds = allProviders.map((p) => p.id).toList();
    final known = _p.getStringList('knownProviders');
    if (known != null) {
      enabledProviders.addAll(allIds.where((id) => !known.contains(id)));
    } else if (en != null) {
      enabledProviders.addAll(allIds.where((id) =>
          !const ['apibay', 'yts', 'nyaa'].contains(id)));
    }
    _p.setStringList('knownProviders', allIds);
    _p.setStringList('enabledProviders', enabledProviders.toList());
    final bu = _p.getString('baseUrls');
    if (bu != null) {
      baseUrls = Map<String, String>.from(jsonDecode(bu) as Map);
    }
    trackers = _p.getStringList('trackers') ?? List.of(defaultTrackers);
    saveHistory = _p.getBool('saveHistory') ?? true;
    minSeeders = _p.getInt('minSeeders') ?? 3;
    sort = SortMode.values[(_p.getInt('sort') ?? 0).clamp(0, SortMode.values.length - 1)];
  }

  void addHistory(String q) {
    if (!saveHistory) return;
    history.remove(q);
    history.insert(0, q);
    if (history.length > 50) history = history.sublist(0, 50);
    _p.setStringList('history', history);
    notifyListeners();
  }

  void removeHistory(String q) {
    history.remove(q);
    _p.setStringList('history', history);
    notifyListeners();
  }

  void clearHistory() {
    history = [];
    _p.setStringList('history', history);
    notifyListeners();
  }

  bool isFavourite(TorrentResult r) =>
      favourites.any((f) => f.infoHash.toLowerCase() == r.infoHash.toLowerCase());

  void toggleFavourite(TorrentResult r) {
    if (isFavourite(r)) {
      favourites.removeWhere(
          (f) => f.infoHash.toLowerCase() == r.infoHash.toLowerCase());
    } else {
      favourites.insert(0, r);
    }
    _p.setStringList(
        'favourites', favourites.map((f) => jsonEncode(f.toJson())).toList());
    notifyListeners();
  }

  void setProviderEnabled(String id, bool on) {
    on ? enabledProviders.add(id) : enabledProviders.remove(id);
    _p.setStringList('enabledProviders', enabledProviders.toList());
    notifyListeners();
  }

  void setBaseUrl(String id, String url) {
    final u = url.trim();
    u.isEmpty ? baseUrls.remove(id) : baseUrls[id] = u;
    _p.setString('baseUrls', jsonEncode(baseUrls));
    notifyListeners();
  }

  void setTrackers(List<String> t) {
    trackers = t.where((e) => e.trim().isNotEmpty).map((e) => e.trim()).toList();
    _p.setStringList('trackers', trackers);
    notifyListeners();
  }

  void setSaveHistory(bool v) {
    saveHistory = v;
    _p.setBool('saveHistory', v);
    notifyListeners();
  }

  void setMinSeeders(int v) {
    minSeeders = v;
    _p.setInt('minSeeders', v);
    notifyListeners();
  }

  void setSort(SortMode s) {
    sort = s;
    _p.setInt('sort', s.index);
    notifyListeners();
  }
}
