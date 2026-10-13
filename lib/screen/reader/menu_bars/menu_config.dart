import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wenku8x/utils/flash.dart';

import '../reader_provider.dart';

class MenuConfig extends StatefulHookConsumerWidget {
  const MenuConfig(this.provider, {super.key});
  final dynamic provider;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MenuConfigState();
}

class _MenuConfigState extends ConsumerState<MenuConfig>
    with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final bottomPos = useState(-height);

    // final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final state = ref.watch(
        readerMenuStateProvider.select((value) => value.menuConfigVisible));
    final bottomHeight = ref.watch(
        readerMenuStateProvider.select((value) => value.bottomBarHeight));
    final config = ref.watch(widget.provider.select((value) => value.config));
    final notifier = ref.read(widget.provider.notifier);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        bottomPos.value = -context.findRenderObject()!.paintBounds.size.height;
      });
      return null;
    }, []);
    return AnimatedPositioned(
        duration: const Duration(milliseconds: 200),
        left: 0,
        bottom: state ? bottomHeight : bottomPos.value,
        child: Container(
            color: Theme.of(context).colorScheme.surface,
            width: MediaQuery.of(context).size.width,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, left: 18),
                child: Text(
                  "设置",
                  style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.bold),
                ),
              ),
              GridView.extent(
                shrinkWrap: true,
                padding: const EdgeInsets.only(left: 8, right: 8, top: 24),
                maxCrossAxisExtent: 110,
                children: [
                  buildConfigButton(
                      label: "平移翻页",
                      icon: const Icon(
                        Icons.vertical_split_outlined,
                      ),
                      enabled: config.horizontalScroll,
                      onPressed: () =>
                          notifier.updateConfig(horizontalScroll: true)),
                  buildConfigButton(
                    label: "滚动翻页",
                    icon: const Icon(
                      Icons.horizontal_split_outlined,
                    ),
                    enabled: config.verticalScroll,
                    onPressed: () =>
                        notifier.updateConfig(verticalScroll: true),
                  ),
                  buildConfigButton(
                      label: "静默翻页",
                      icon: const Icon(
                        Icons.swipe_right_outlined,
                      ),
                      enabled: config.flickScroll,
                      onPressed: () => notifier.updateConfig(flickScroll: true)),
                  buildConfigButton(
                      icon: const Icon(
                        Icons.auto_stories_outlined,
                      ),
                      label: "仿真翻页",
                      enabled: config.simulationScroll,
                      onPressed: () =>
                          notifier.updateConfig(simulationScroll: true)),
                  buildConfigButton(
                      label: "音量键翻页",
                      icon: const Icon(
                        Icons.architecture_outlined,
                      ),
                      enabled: config.buttonScroll,
                      onPressed: () => notifier.updateConfig(
                          buttonScroll: !config.buttonScroll)),
                  buildConfigButton(
                      label: "全局下一页",
                      icon: const Icon(
                        Icons.bolt_outlined,
                      ),
                      disabled: true,
                      enabled: false),
                  buildConfigButton(
                      label: "全屏显示",
                      icon: const Icon(
                        Icons.aspect_ratio,
                      ),
                      disabled: true,
                      enabled: false),
                  buildConfigButton(
                      icon: const Icon(
                        Icons.local_library_outlined,
                      ),
                      label: "屏幕常亮",
                      disabled: true,
                      enabled: false)
                ],
              ),
            ])));
  }

  buildConfigButton(
      {required String label,
      required Widget icon,
      Function()? onPressed,
      enabled = false,
      notWork = false,
      disabled = false}) {
    final scheme = Theme.of(context).colorScheme;
    // 选中时图标落在主色圆底上，文字仍画在面板底色上，不能跟面板用同一种颜色。
    final iconColor = disabled
        ? scheme.secondary.withOpacity(0.35)
        : enabled
            ? scheme.onPrimary
            : scheme.secondary;
    final labelColor = disabled
        ? scheme.secondary.withOpacity(0.35)
        : enabled
            ? scheme.primary
            : scheme.secondary;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: enabled
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.background,
            child: IconButton(
              onPressed: disabled
                  ? null
                  : () {
                      if (notWork) {
                        Show.error("本功能暂未开放");
                        return;
                      }
                      onPressed?.call();
                    },
              iconSize: 24,
              icon: icon,
              color: iconColor,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: labelColor),
            ),
          )
        ],
      ),
    );
  }
}
