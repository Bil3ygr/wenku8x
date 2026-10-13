// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wenku8x/service/volume_keys.dart';
import 'package:wenku8x/screen/reader/menu_bars/menu_catalog.dart';
import 'package:wenku8x/screen/reader/simulation_reader.dart';
import 'package:wenku8x/utils/flash.dart';
import 'package:wenku8x/screen/reader/menu_bars/menu_config.dart';
import 'package:wenku8x/screen/reader/menu_bars/menu_text.dart';
import 'package:wenku8x/screen/reader/menu_bars/menu_top.dart';
import 'package:wenku8x/screen/reader/menu_bars/progress_bar.dart';
import 'package:wenku8x/screen/reader/scroll_reader.dart';

import 'menu_bars/menu_bottom.dart';
import 'menu_bars/menu_theme.dart';
import 'reader_provider.dart';

class ReaderScreen extends StatefulHookConsumerWidget {
  const ReaderScreen(
      {required this.name, required this.aid, super.key, required this.cIndex});

  final String name;
  final String aid;
  final int cIndex;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  List<Chapter> catalog = [];
  String cachedText = '';
  @override
  Widget build(BuildContext context) {
    final provider = readerProvider((widget.name, widget.aid, widget.cIndex));
    final reader = ref.watch(provider);
    final loading = ref.watch(loadingProvider);
    final volumeTurn = reader.config.buttonScroll;
    final menuOpen = ref.watch(readerMenuStateProvider.select(
        (value) => value.parentMenuVisible || value.subMenusVisible));
    final simToken = useState(0);
    final simToNext = useState(true);

    useEffect(() {
      var lastMs = 0;
      void turn(bool toNext) {
        if (!ref.read(provider).config.buttonScroll) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastMs < 220) return;
        lastMs = now;
        if (ref.read(provider).config.simulationScroll) {
          simToNext.value = toNext;
          simToken.value++;
          return;
        }
        final notifier = ref.read(provider.notifier);
        if (toNext) {
          notifier.nextPage();
        } else {
          notifier.previousPage();
        }
      }

      VolumeKeys.listen((key) {
        if (key == "up") {
          turn(false);
        } else if (key == "down") {
          turn(true);
        }
      });

      bool onHardware(KeyEvent event) {
        final key = event.logicalKey;
        final isVolume = key == LogicalKeyboardKey.audioVolumeUp ||
            key == LogicalKeyboardKey.audioVolumeDown;
        if (!isVolume || !ref.read(provider).config.buttonScroll) return false;
        // 松开也要标成已处理，否则系统会在回放这次按键时弹出音量条。
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) return true;
        turn(key == LogicalKeyboardKey.audioVolumeDown);
        return true;
      }

      HardwareKeyboard.instance.addHandler(onHardware);
      return () {
        HardwareKeyboard.instance.removeHandler(onHardware);
        VolumeKeys.setIntercept(false);
      };
    }, const []);

    useEffect(() {
      VolumeKeys.setIntercept(volumeTurn).then((_) {}, onError: (Object e) {
        if (volumeTurn) Show.error("音量键翻页未生效：$e");
      });
      return null;
    }, [volumeTurn]);

    useEffect(() {
      Future(() {
        ref.read(loadingProvider.notifier).state = true;
      });
      Future.delayed(const Duration(milliseconds: 500)).then((value) async {
        ref.read(provider.notifier).init(context, widget.cIndex);
        await ref.read(provider.notifier).initCatalog();
        ref.read(provider.notifier).initPages();
      });
      return null;
    }, []);

    return Theme(
        data: reader.theme,
        child: Scaffold(
            body: Stack(
          children: [
            Listener(
                onPointerMove: ref.read(provider.notifier).onPointerMove,
                onPointerUp: ref.read(provider.notifier).onPointerUp,
                onPointerDown: ref.read(provider.notifier).onPointerDown,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top,
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ScrollReader(reader.pages,
                          ref.read(provider.notifier).pageController,
                          axis: reader.config.verticalScroll
                              ? Axis.vertical
                              : Axis.horizontal,
                          showContent: !reader.config.simulationScroll,
                          loadNext: ref.read(provider.notifier).loadNextChapter,
                          onPageScrollEnd:
                              ref.read(provider.notifier).onPageScrollEnd),
                      if (reader.config.simulationScroll)
                        SimulationReader(
                          pages: reader.pages,
                          controller:
                              ref.read(provider.notifier).pageController,
                          menuOpen: menuOpen,
                          onCommit:
                              ref.read(provider.notifier).commitSimulationTurn,
                          onMenu: () => ref
                              .read(readerMenuStateProvider.notifier)
                              .toggleInitialBars(),
                          turnToken: simToken.value,
                          turnToNext: simToNext.value,
                          onDismissMenu: () {
                            final menu = ref.read(readerMenuStateProvider);
                            final notifier =
                                ref.read(readerMenuStateProvider.notifier);
                            if (menu.subMenusVisible) {
                              notifier.dispatch(
                                menuCatalogVisible: false,
                                menuThemeVisible: false,
                                menuTextVisible: false,
                                menuConfigVisible: false,
                                menuTopVisible: true,
                                menuBottomVisible: true,
                              );
                            } else if (menu.parentMenuVisible) {
                              notifier.reset();
                            }
                          },
                        ),
                    ],
                  ),
                )),
            const MenuBottom(),
            ProgressBar(provider),
            MenuCatalog(provider),
            MenuTop(provider),
            MenuPalette(provider),
            MenuText(provider),
            MenuConfig(provider),
            if (loading)
              Container(
                color: Theme.of(context).colorScheme.background,
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: const Center(
                  child: SizedBox(
                      width: 96, height: 3, child: LinearProgressIndicator()),
                ),
              )
          ],
        )));
  }
}
