import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wenku8x/screen/reader/menu_bars/progress_bar_provider.dart';
import '../reader_provider.dart';

class ProgressBar extends StatefulHookConsumerWidget {
  const ProgressBar(this.provider, {super.key});
  final dynamic provider;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<ProgressBar> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final bottomPos = useState(-height);
    final state = ref.watch(
        readerMenuStateProvider.select((value) => value.progressVisible));
    final bottomHeight = ref.watch(
        readerMenuStateProvider.select((value) => value.bottomBarHeight));
    final progress = ref.watch(progressProvider);
    final reader = ref.watch(widget.provider);
    final dragging = useState(false);
    final dragPage = useState(0);
    final pendingPage = useRef<int?>(null);
    final jumpTimer = useRef<Timer?>(null);
    final scheme = Theme.of(context).colorScheme;
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        bottomPos.value = -context.findRenderObject()!.paintBounds.size.height;
      });
      return () {
        jumpTimer.value?.cancel();
      };
    }, []);

    final total = progress.totalPages < 1 ? 1 : progress.totalPages;
    final savedPage = progress.currentIndex.clamp(0, total - 1);
    final shown = dragging.value ? dragPage.value.clamp(0, total - 1) : savedPage;
    final hasPrev = reader.cIndex > 0;
    final hasNext = reader.catalog.isNotEmpty &&
        reader.cIndex < reader.catalog.length - 1;

    void jump(int page) {
      ref.read(widget.provider.notifier).jumpToPage(page);
    }

    void arm(int page) {
      pendingPage.value = page;
      if (jumpTimer.value != null) return;
      jumpTimer.value = Timer(const Duration(milliseconds: 200), () {
        jumpTimer.value = null;
        if (!context.mounted) return;
        final target = pendingPage.value;
        if (target != null) jump(target);
      });
    }

    void finish(int page) {
      jumpTimer.value?.cancel();
      jumpTimer.value = null;
      pendingPage.value = null;
      dragging.value = false;
      jump(page);
    }

    return AnimatedPositioned(
        duration: const Duration(milliseconds: 200),
        left: 0,
        bottom: state ? bottomHeight : bottomPos.value,
        child: Container(
            color: scheme.surface,
            width: MediaQuery.of(context).size.width,
            padding:
                const EdgeInsets.only(left: 4, right: 4, bottom: 4, top: 4),
            child: Row(
              children: [
                _chapterButton(
                  context,
                  label: "上一章",
                  enabled: hasPrev,
                  onPressed: () => ref
                      .read(widget.provider.notifier)
                      .jumpToIndex(reader.cIndex - 1),
                ),
                Expanded(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${shown + 1} / $total",
                      style: TextStyle(color: scheme.onSurface, fontSize: 12),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: scheme.outline,
                        inactiveTrackColor: scheme.background,
                        trackHeight: 16,
                        valueIndicatorColor: Colors.transparent,
                        tickMarkShape: SliderTickMarkShape.noTickMark,
                        overlayColor: Colors.transparent,
                        overlayShape: SliderComponentShape.noOverlay,
                        thumbColor: scheme.surface,
                        thumbShape: const RoundSliderThumbShape(
                          disabledThumbRadius: 8,
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        min: 0,
                        max: total <= 1 ? 1 : (total - 1).toDouble(),
                        value: total <= 1 ? 0 : shown.toDouble(),
                        divisions: total <= 1 ? null : total - 1,
                        onChanged: total <= 1
                            ? null
                            : (value) {
                                final page = value.round();
                                dragging.value = true;
                                dragPage.value = page;
                                arm(page);
                              },
                        onChangeEnd: total <= 1
                            ? null
                            : (value) {
                                finish(value.round());
                              },
                      ),
                    ),
                  ],
                )),
                _chapterButton(
                  context,
                  label: "下一章",
                  enabled: hasNext,
                  onPressed: () => ref
                      .read(widget.provider.notifier)
                      .jumpToIndex(reader.cIndex + 1),
                ),
              ],
            )));
  }
}

Widget _chapterButton(
  BuildContext context, {
  required String label,
  required bool enabled,
  required VoidCallback onPressed,
}) {
  final scheme = Theme.of(context).colorScheme;
  return TextButton(
    onPressed: enabled ? onPressed : null,
    style: TextButton.styleFrom(
      foregroundColor: scheme.onSurface,
      disabledForegroundColor: scheme.secondary,
    ),
    child: Text(label),
  );
}
