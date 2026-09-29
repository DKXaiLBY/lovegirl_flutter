import 'package:flutter/material.dart';

import 'polaroid_theme.dart';

/// 拍立得背面（v3.38 复刻返工）：显影后的 POD 层是亮面黑色+印刷小字，
/// 参考图三款背面版式逐元素还原：
/// - classic：实物黑背（警示印字+白色手写留言居中）
/// - tape：顶部 "Don't put in mouth." 印字带 + 白色留言 + 底部 BACK FOR YOU 印字带
/// - letter：米白信笺（褶皱纸）+ PRESENTED BY BACK + 红字留言 + 右下彩蛋小印字
/// - film：纯黑+左右竖排橙色胶片印字（BACK PORTRA 400/编号/▲）+ 白色小字留言
class PolaroidBack extends StatelessWidget {
  final PolaroidTheme theme;
  final String message;

  /// film 背面中央嵌的照片（负片感），可空
  final Widget? photo;

  const PolaroidBack({
    super.key,
    required this.theme,
    required this.message,
    this.photo,
  });

  @override
  Widget build(BuildContext context) {
    final msg = message.trim();
    return switch (theme) {
      PolaroidTheme.classic => _classicBack(msg),
      PolaroidTheme.tape => _tapeBack(msg),
      PolaroidTheme.letter => _letterBack(msg),
      PolaroidTheme.film => _filmBack(msg),
    };
  }

  /// POD 纹理背景（黑/米白两种），替代平涂——真实质感的来源
  Widget _textureBg({required bool dark, required Widget child}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.9,
          child: Image(
            image: AssetImage(dark
                ? 'assets/images/deco/polaroid_back_dark.png'
                : 'assets/images/deco/polaroid_back_cream.png'),
            fit: BoxFit.cover,
          ),
        ),
        child,
      ],
    );
  }

  // ---------- classic：实物 POD 黑背 ----------
  Widget _classicBack(String msg) {
    return _textureBg(
      dark: true,
      child: Column(
        children: [
          // 警示印字条
          Container(
            height: 20,
            alignment: Alignment.center,
            child: const Text(
              'Do not cut, bend or shake.  ·  Keep away from children.  ·',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 7.5,
                letterSpacing: 1.2,
                color: Color(0xFF6E6E72),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Text(
                  msg.isEmpty ? '—' : msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.7,
                    color: Color(0xFFD6D6DA),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ---------- tape：印字带×2 + 白色留言 ----------
  Widget _tapeBack(String msg) {
    return _textureBg(
      dark: true,
      child: Column(
        children: [
          // 顶部警示印字带
          Container(
            height: 26,
            color: const Color(0xFFB9B9BF),
            child: const Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.report_rounded,
                              size: 12, color: Color(0xFF3A3A3E)),
                          SizedBox(width: 4),
                          Text(
                            "Don't put in mouth.  Don't put in mouth.  Don't put in mouth.",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF3A3A3E),
                            ),
                          ),
                          Icon(Icons.report_rounded,
                              size: 12, color: Color(0xFF3A3A3E)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 中央留言
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Text(
                  msg.isEmpty ? '—' : msg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.75,
                    color: Color(0xFFE4E4E8),
                  ),
                ),
              ),
            ),
          ),
          // 底部 BACK FOR YOU 印字带
          Container(
            height: 34,
            color: const Color(0xFFB9B9BF),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('BACK',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF3A3A3E),
                                    height: 1.1)),
                            Text('FOR YOU',
                                style: TextStyle(
                                    fontSize: 7,
                                    letterSpacing: 1.5,
                                    color: Color(0xFF3A3A3E),
                                    height: 1.2)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- letter：米白信笺 + 红字 ----------
  Widget _letterBack(String msg) {
    return _textureBg(
      dark: false,
      child: Stack(
        children: [
          // 纸张褶皱：两条斜向高光（简化褶皱感）
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.18, 0.22, 0.6, 0.66, 1.0],
                    colors: [
                      const Color(0xFFF7F4EE),
                      const Color(0xFFFDFAF3),
                      const Color(0xFFEFEAE0),
                      const Color(0xFFF7F4EE),
                      const Color(0xFFFDFBF6),
                      const Color(0xFFF3EFE7),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 18),
              // 顶部打字机印字
              const Center(
                child: Text(
                  'P R E S E N T E D   B Y   B A C K',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Color(0xFFA39A8E),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Center(
                    child: Text(
                      msg.isEmpty ? '—' : msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.7,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC0453E),
                      ),
                    ),
                  ),
                ),
              ),
              // 右下彩蛋印字
              const Padding(
                padding: EdgeInsets.only(right: 10, bottom: 8),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'THIS IS NOT KODAK FILM - B -',
                    style: TextStyle(
                      fontSize: 6,
                      letterSpacing: 1,
                      color: Color(0xFFB7AFA4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- film：胶片边印字 + 嵌照片负片 ----------
  Widget _filmBack(String msg) {
    return Container(
      color: const Color(0xFF0A0A0B),
      child: Row(
        children: [
          // 左侧竖排印字
          SizedBox(
            width: 22,
            child: const RotatedBox(
              quarterTurns: -1,
              child: Text(
                'BACK PORTRA 400   ·   BACK PORTRA 400   ·',
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: Color(0xFFC87F3B),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 中央嵌照片（负片感：降饱和+压暗）
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            0.25, 0.25, 0.25, 0, 0.02, //
                            0.22, 0.24, 0.24, 0, 0.02, //
                            0.22, 0.22, 0.26, 0, 0.03, //
                            0, 0, 0, 1, 0,
                          ]),
                          child: photo ?? const SizedBox.expand(),
                        ),
                      ),
                      // 照片上的白色小字留言
                      Align(
                        alignment: const Alignment(-0.6, -0.55),
                        child: Text(
                          msg.isEmpty ? '' : msg,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.6,
                            color: const Color(0xFFDDDDDD)
                                .withAlpha(msg.isEmpty ? 0 : 230),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 底部小印字行
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '42   ·   43   ·   20.42   ·   ▲',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 3,
                      color: Color(0xFFC87F3B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 右侧竖排印字+三角
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const Expanded(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      'BACK PORTRA 400   ·   BACK PORTRA 400   ·',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 2,
                        color: Color(0xFFC87F3B),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('▲',
                      style: TextStyle(fontSize: 8, color: Color(0xFFC87F3B))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
