import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wenku8x/http/api.dart';

class ChapterCacheState {
  const ChapterCacheState({
    this.cached = const <String>{},
    this.loading = const <String>{},
  });

  final Set<String> cached;
  final Set<String> loading;

  bool isCached(String cid) => cached.contains(cid);
  bool isLoading(String cid) => loading.contains(cid);
}

/// 一章一个正文文件。阅读预取和手动缓存都走这里。
class ChapterCacheNotifier extends FamilyNotifier<ChapterCacheState, String> {
  /// 按书号和章节号共用同一次请求，避免页面关掉后重新进来又下一次。
  static final Map<String, Future<String>> _jobs = {};
  final List<String> _queue = [];
  bool _draining = false;
  bool _alive = true;
  Directory? _dir;

  @override
  ChapterCacheState build(String arg) {
    _alive = true;
    ref.onDispose(() => _alive = false);
    Future(() => reload());
    return const ChapterCacheState();
  }

  Future<Directory> _bookDir() async {
    final existing = _dir;
    if (existing != null) return existing;
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory("${doc.path}/books/$arg");
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<void> reload() async {
    final dir = await _bookDir();
    final onDisk = <String>{};
    if (dir.existsSync()) {
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith(".txt")) continue;
        if (entity.lengthSync() == 0) continue;
        onDisk.add(_cidOf(entity.path));
      }
    }
    if (!_alive) return;
    final cached = {...onDisk};
    for (final cid in state.cached) {
      if (cached.contains(cid)) continue;
      final file = File("${dir.path}/$cid.txt");
      if (file.existsSync() && file.lengthSync() > 0) cached.add(cid);
    }
    final loading = {...state.loading}..removeAll(cached);
    state = ChapterCacheState(cached: cached, loading: loading);
  }

  String _cidOf(String path) {
    final name = path.replaceAll("\\", "/").split("/").last;
    final dot = name.lastIndexOf(".");
    return dot < 0 ? name : name.substring(0, dot);
  }

  void _setLoading(String cid, bool on) {
    if (!_alive) return;
    final loading = {...state.loading};
    if (on) {
      loading.add(cid);
    } else {
      loading.remove(cid);
    }
    state = ChapterCacheState(cached: state.cached, loading: loading);
  }

  void _setCached(String cid) {
    if (!_alive) return;
    final loading = {...state.loading}..remove(cid);
    final cached = {...state.cached}..add(cid);
    state = ChapterCacheState(cached: cached, loading: loading);
  }

  /// 有文件就直接读，没有就请求并写入。同一章不会重复请求。
  String _jobKey(String cid) => "$arg|$cid";

  Future<String> ensureText(String cid) {
    final key = _jobKey(cid);
    final pending = _jobs[key];
    if (pending != null) {
      return pending.then((text) {
        if (text.isNotEmpty) _setCached(cid);
        return text;
      });
    }
    final job = _ensure(cid);
    _jobs[key] = job;
    return job.whenComplete(() {
      if (identical(_jobs[key], job)) _jobs.remove(key);
    });
  }

  Future<String> _ensure(String cid) async {
    final dir = await _bookDir();
    final file = File("${dir.path}/$cid.txt");
    if (file.existsSync() && file.lengthSync() > 0) {
      _setCached(cid);
      return file.readAsStringSync();
    }
    _setLoading(cid, true);
    try {
      final text = (await API.getNovelContent(arg, cid)).toString();
      if (text.isEmpty) {
        _setLoading(cid, false);
        return text;
      }
      await file.writeAsString(text);
      _setCached(cid);
      return text;
    } catch (err) {
      _setLoading(cid, false);
      rethrow;
    }
  }

  /// 按顺序缓存。已经在本地或正在请求的章节会跳过。
  void cacheCids(List<String> cids) {
    for (final cid in cids) {
      if (cid.isEmpty || state.cached.contains(cid)) continue;
      if (_jobs.containsKey(_jobKey(cid)) || _queue.contains(cid)) continue;
      _queue.add(cid);
    }
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_alive && _queue.isNotEmpty) {
        final cid = _queue.removeAt(0);
        try {
          await ensureText(cid);
        } catch (_) {}
      }
    } finally {
      _draining = false;
      if (_alive && _queue.isNotEmpty) _drain();
    }
  }
}

final chapterCacheProvider = NotifierProvider.family<ChapterCacheNotifier,
    ChapterCacheState, String>(ChapterCacheNotifier.new);
