import 'package:flutter/material.dart';

class ColorPair {
    final Color mainColor;
    final Color? gradientColor;

    const ColorPair({required this.mainColor, required this.gradientColor});

    factory ColorPair.fromList(List<Color> colors) => ColorPair(mainColor: colors[0], gradientColor: colors.elementAtOrNull(1));

    List<Color> toList() {
        final colors = [
            mainColor,
        ];

        if (gradientColor != null) {
            colors.add(gradientColor!);
        }

        return colors;
    }
}

class ColorDots extends StatelessWidget {
    static const List<List<Color>> themeColorsOld = [
        [Colors.redAccent, Colors.orange],
        [Colors.green, Colors.lightGreenAccent],
        [Colors.blue, Colors.lightBlueAccent],
        [Colors.purple, Colors.pinkAccent],
        [Colors.yellow, Colors.amber],
        [Colors.teal, Colors.cyanAccent],
        [Colors.indigo, Colors.blueAccent],
        //[Colors.white, Colors.grey],
        //[Colors.black, Colors.black38]
    ];

    static const List<ColorPair> themeColors = [
        ColorPair(mainColor: Colors.redAccent, gradientColor: Colors.orangeAccent),
        ColorPair(mainColor: Colors.lightGreenAccent, gradientColor: Colors.green),
        ColorPair(mainColor: Colors.yellowAccent, gradientColor: Colors.yellow),
        ColorPair(mainColor: Colors.amberAccent, gradientColor: Colors.amber),
        ColorPair(mainColor: Colors.lightBlueAccent, gradientColor: Colors.blue),
        ColorPair(mainColor: Colors.purpleAccent, gradientColor: Colors.purple),
        ColorPair(mainColor: Colors.pinkAccent, gradientColor: Colors.pink),
        ColorPair(mainColor: Colors.tealAccent, gradientColor: Colors.teal),
        ColorPair(mainColor: Colors.indigoAccent, gradientColor: Colors.indigo)
    ];

    final List<ColorPair>? colors;
    final void Function(ColorPair pair) onColorSelect;

    const ColorDots({required this.onColorSelect, this.colors, super.key});

    @override
    Widget build(BuildContext context) => Wrap(
            children: (colors ?? themeColors).map(
                (color) => GestureDetector(
                    onTap: () {
                        onColorSelect(color);
                    },
                    child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                    colors: color.toList(),
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter
                                )
                            ),
                        )
                    )
                )
            ).toList(),
        );
}