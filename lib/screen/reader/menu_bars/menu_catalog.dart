import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:wenku8x/service/chapter_cache.dart';

import '../reader_provider.dart';
import 'cache_sheet.dart';

const _chapterExtent = 46.0;
const _headerExtent = 36.0;

class MenuCatalog extends StatefulHookConsumerWidget {
  const MenuCatalog(this.provider, {super.key});
  final dynamic provider;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MenuCatalogState();
}

class _MenuCatalogState extends ConsumerState<MenuCatalog>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final bottomPos = useState(-height);
    final scrollController = useScrollController(keepScrollOffset: true);
    final reader = ref.watch(widget.provider);
    final state = ref.watch(
        readerMenuStateProvider.select((value) => value.menuCatalogVisible));
    final bottomHeight = ref.watch(
        readerMenuStateProvider.select((value) => value.bottomBarHeight));
    final rows = catalogEntries(reader.catalog);
    final cache = ref.watch(chapterCacheProvider(reader.aid));
    useEffect(() {
      if (state) {
        ref.read(chapterCacheProvider(reader.aid).notifier).reload();
      }
      return null;
    }, [state, reader.aid]);
    useEffect(() {
      if (!state || rows.isEmpty) return null;
      var attempts = 0;
      void center() {
        if (!scrollController.hasClients) return;
        final position = scrollController.position;
        var top = 0.0;
        for (final row in rows) {
          if (row.chapterIndex == reader.cIndex) break;
          top += row.isHeader ? _headerExtent : _chapterExtent;
        }
        final target =
            top - (position.viewportDimension - _chapterExtent) / 2;
        final max = position.maxScrollExtent;
        // 列表还没量完高度时，滚动范围是 0，再等一帧。
        if (max <= 0 && top > 0 && attempts < 4) {
          attempts++;
          WidgetsBinding.instance.addPostFrameCallback((_) => center());
          return;
        }
        scrollController.jumpTo(target.clamp(0.0, max));
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => center());
      return null;
    }, [state, reader.cIndex, reader.catalog.length]);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        bottomPos.value = -context.findRenderObject()!.paintBounds.size.height;
      });
      return null;
    }, []);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      left: 0,
      bottom: state ? bottomHeight : bottomPos.value,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - bottomHeight - 64),
        width: MediaQuery.of(context).size.width,
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "目录",
                      style: TextStyle(
                          color: scheme.onBackground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: reader.catalog.isEmpty
                        ? null
                        : () {
                            final theme = Theme.of(context);
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: scheme.surface,
                              builder: (sheetContext) {
                                return Theme(
                                  data: theme,
                                  child: SizedBox(
                                    height: MediaQuery.of(sheetContext)
                                            .size
                                            .height *
                                        0.78,
                                    child: CacheSheet(
                                      aid: reader.aid,
                                      catalog: reader.catalog,
                                      currentIndex: reader.cIndex,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                    child: const Text("缓存"),
                  ),
                ],
              ),
            ),
            Expanded(
                child: MediaQuery.removePadding(
                    removeTop: true,
                    removeBottom: true,
                    context: context,
                    child: ListView.builder(
                        physics: const ClampingScrollPhysics(),
                        controller: scrollController,
                        itemCount: rows.length,
                        itemExtentBuilder: (index, _) => rows[index].isHeader
                            ? _headerExtent
                            : _chapterExtent,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          if (row.isHeader) {
                            return Container(
                              height: _headerExtent,
                              alignment: Alignment.centerLeft,
                              color: scheme.primary.withOpacity(0.08),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                row.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: scheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          final chapterIndex = row.chapterIndex;
                          final chapter = reader.catalog[chapterIndex];
                          final selected = chapterIndex == reader.cIndex;
                          return InkWell(
                            onTap: () {
                              ref
                                  .read(widget.provider.notifier)
                                  .jumpToIndex(chapterIndex);
                            },
                            child: SizedBox(
                              height: _chapterExtent,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chapter.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: selected
                                                ? scheme.primary
                                                : scheme.onBackground,
                                            fontSize: 13,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400),
                                      ),
                                    ),
                                    if (cache.isLoading(chapter.cid) ||
                                        cache.isCached(chapter.cid))
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8),
                                        child: Text(
                                          cache.isLoading(chapter.cid)
                                              ? "缓存中"
                                              : "已缓存",
                                          style: TextStyle(
                                              color: scheme.secondary,
                                              fontSize: 11),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        })))
          ],
        ),
      ),
    );
  }
}
