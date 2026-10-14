import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wenku8x/screen/reader/reader_provider.dart';
import 'package:wenku8x/service/chapter_cache.dart';

class CacheSheet extends HookConsumerWidget {
  const CacheSheet({
    super.key,
    required this.aid,
    required this.catalog,
    required this.currentIndex,
  });

  final String aid;
  final List<Chapter> catalog;
  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(chapterCacheProvider(aid));
    final selected = useState<Set<int>>(<int>{});
    final scheme = Theme.of(context).colorScheme;
    final rows = catalogEntries(catalog);
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    void selectIndexes(Iterable<int> indexes) {
      final next = {...selected.value};
      for (final index in indexes) {
        final cid = catalog[index].cid;
        if (cache.isCached(cid) || cache.isLoading(cid)) continue;
        next.add(index);
      }
      selected.value = next;
    }

    List<int> volumeIndexes(int from) {
      if (catalog.isEmpty) return [];
      final current = from.clamp(0, catalog.length - 1);
      final volume = catalog[current].volume;
      var start = current;
      while (start > 0 && catalog[start - 1].volume == volume) {
        start--;
      }
      var end = current;
      while (end + 1 < catalog.length && catalog[end + 1].volume == volume) {
        end++;
      }
      return [for (var i = start; i <= end; i++) i];
    }

    final chosen = selected.value
        .where((index) =>
            index >= 0 &&
            index < catalog.length &&
            !cache.isCached(catalog[index].cid) &&
            !cache.isLoading(catalog[index].cid))
        .length;

    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "缓存章节",
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text("未缓存的全部"),
                  onPressed: () =>
                      selectIndexes([for (var i = 0; i < catalog.length; i++) i]),
                ),
                ActionChip(
                  label: const Text("本卷"),
                  onPressed: () => selectIndexes(volumeIndexes(currentIndex)),
                ),
                ActionChip(
                  label: const Text("当前到卷末"),
                  onPressed: () {
                    final indexes = volumeIndexes(currentIndex);
                    final current = currentIndex.clamp(0, catalog.length - 1);
                    selectIndexes(indexes.where((index) => index >= current));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row.isHeader) {
                  final indexes = <int>[];
                  for (var i = index + 1; i < rows.length; i++) {
                    if (rows[i].isHeader) break;
                    indexes.add(rows[i].chapterIndex);
                  }
                  final pending = indexes
                      .where((i) =>
                          !cache.isCached(catalog[i].cid) &&
                          !cache.isLoading(catalog[i].cid))
                      .toList();
                  final allOn = pending.isNotEmpty &&
                      pending.every(selected.value.contains);
                  final someOn = pending.any(selected.value.contains);
                  return InkWell(
                    onTap: pending.isEmpty
                        ? null
                        : () {
                            final next = {...selected.value};
                            if (allOn) {
                              next.removeAll(pending);
                            } else {
                              next.addAll(pending);
                            }
                            selected.value = next;
                          },
                    child: Container(
                      color: scheme.primary.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: pending.isEmpty
                                ? true
                                : (allOn ? true : (someOn ? null : false)),
                            tristate: true,
                            onChanged: pending.isEmpty
                                ? null
                                : (value) {
                                    final next = {...selected.value};
                                    if (value == true) {
                                      next.addAll(pending);
                                    } else {
                                      next.removeAll(pending);
                                    }
                                    selected.value = next;
                                  },
                          ),
                          Expanded(
                            child: Text(
                              row.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final chapterIndex = row.chapterIndex;
                final chapter = catalog[chapterIndex];
                final cached = cache.isCached(chapter.cid);
                final loading = cache.isLoading(chapter.cid);
                final checked = cached || selected.value.contains(chapterIndex);
                return InkWell(
                  onTap: cached || loading
                      ? null
                      : () {
                          final next = {...selected.value};
                          if (next.contains(chapterIndex)) {
                            next.remove(chapterIndex);
                          } else {
                            next.add(chapterIndex);
                          }
                          selected.value = next;
                        },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 16),
                    child: Row(
                      children: [
                        Checkbox(
                          value: checked,
                          onChanged: cached || loading
                              ? null
                              : (value) {
                                  final next = {...selected.value};
                                  if (value == true) {
                                    next.add(chapterIndex);
                                  } else {
                                    next.remove(chapterIndex);
                                  }
                                  selected.value = next;
                                },
                        ),
                        Expanded(
                          child: Text(
                            chapter.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: scheme.onSurface, fontSize: 14),
                          ),
                        ),
                        if (loading || cached)
                          Text(
                            loading ? "缓存中" : "已缓存",
                            style: TextStyle(
                                color: scheme.secondary, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "已选 $chosen 章",
                    style: TextStyle(color: scheme.onSurface, fontSize: 14),
                  ),
                ),
                FilledButton(
                  onPressed: chosen == 0
                      ? null
                      : () {
                          final cids = <String>[];
                          for (final index in selected.value) {
                            if (index < 0 || index >= catalog.length) continue;
                            final cid = catalog[index].cid;
                            if (cache.isCached(cid) || cache.isLoading(cid)) {
                              continue;
                            }
                            cids.add(cid);
                          }
                          ref
                              .read(chapterCacheProvider(aid).notifier)
                              .cacheCids(cids);
                          Navigator.of(context).pop();
                        },
                  child: const Text("开始缓存"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
