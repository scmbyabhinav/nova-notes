import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scheduled_post.dart';

/// Persists ORAH Connect drafts on this device only. No account or server needed.
class OrahScheduledPostStore {
  OrahScheduledPostStore._();
  static final instance = OrahScheduledPostStore._();

  static const _storageKey = 'orah_connect_scheduled_posts_v1';

  Future<List<ScheduledPost>> all() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_storageKey) ?? const <String>[];
    final posts = <ScheduledPost>[];
    for (final entry in raw) {
      try {
        posts.add(ScheduledPost.decode(entry));
      } on FormatException {
        // Ignore malformed legacy entries instead of breaking the scheduler.
      } on TypeError {
        // Ignore malformed entries and keep the remaining local drafts.
      }
    }
    posts.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return posts;
  }

  Future<void> save(ScheduledPost post) async {
    final preferences = await SharedPreferences.getInstance();
    final posts = await all();
    final next = posts.where((item) => item.id != post.id).toList()
      ..add(post);
    next.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    await preferences.setStringList(
      _storageKey,
      next.map((item) => item.encode()).toList(growable: false),
    );
  }

  Future<ScheduledPost?> getById(String id) async {
    for (final post in await all()) {
      if (post.id == id) return post;
    }
    return null;
  }

  Future<void> delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final posts = await all();
    await preferences.setStringList(
      _storageKey,
      posts.where((post) => post.id != id).map((post) => post.encode()).toList(),
    );
  }

  Future<void> markCompleted(String id) async {
    final post = await getById(id);
    if (post != null) await save(post.copyWith(completed: true));
  }
}
