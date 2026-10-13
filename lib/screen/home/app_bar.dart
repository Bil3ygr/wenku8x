import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wenku8x/http/api.dart';
import 'package:wenku8x/screen/profile/profile_provider.dart';
import 'package:wenku8x/service/navigation.dart';

class HomeAppBar extends HookConsumerWidget implements PreferredSizeWidget {
  const HomeAppBar(
      {Key? key,
      required this.onSearchTap,
      required this.onAddTap,
      required this.onAvatarTap})
      : super(key: key);

  final Function() onSearchTap;
  final Function() onAddTap;
  final Function() onAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final colorScheme = getColorScheme(context);
    final avatarUpdater = ref.watch(avatarExistProvider);
    final avatarFile = useFuture(
      useMemoized(() async {
        final docDir = await getApplicationDocumentsDirectory();
        var file = File("${docDir.path}/avatar.jpg");
        return file.existsSync() ? file : null;
      }, [profile, avatarUpdater]),
    );

    useEffect(() {
      API.getUserInfo(ref);
      return null;
    }, []);
    return SafeArea(
        child: Padding(
            padding:
                const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Flexible(
                      flex: 1,
                      child: Container(
                        height: 42,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            color: colorScheme.surfaceVariant.withOpacity(0.5)),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onSearchTap,
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                "assets/svg/ic_topbar_search.svg",
                                width: 23,
                                height: 23,
                                colorFilter: ColorFilter.mode(
                                    colorScheme.secondary, BlendMode.srcIn),
                              ),
                              Expanded(
                                  child: Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text("搜索书名或作者",
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.secondary
                                            .withOpacity(0.8))),
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      tooltip: "发现",
                      onTap: onAddTap,
                      child: Icon(
                        Icons.explore_outlined,
                        size: 22,
                        color: colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      tooltip: "我的",
                      onTap: onAvatarTap,
                      child: _AvatarFace(
                        file: avatarFile.data,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Divider(
                    color: colorScheme.secondary.withOpacity(0.05),
                    height: 1,
                  ),
                )
              ],
            )));
  }

  @override
  Size get preferredSize => const Size.fromHeight(71);
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.child,
    required this.onTap,
    required this.tooltip,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = getColorScheme(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.secondaryContainer.withOpacity(0.65),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({required this.file, required this.color});

  final File? file;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.person, size: 22, color: color);
    if (file == null) return fallback;
    return Image.file(
      file!,
      width: 40,
      height: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
