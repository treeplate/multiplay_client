import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:home_automation_tools/all.dart';

Socket server;

int playerIndex = 0;

Future<void> main() async {
  server = await Socket.connect("ceylon.rooves.house", 9000);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

List<String> buttons = ["right", "left", "down", "up"];

class MyHomePage extends StatefulWidget {
  MyHomePage({Key /*?*/ key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  _MyHomePageState() {
    final PacketBuffer buffer = PacketBuffer();
    server.add([playerIndex, 0]);
    server.listen((List<int> imessage) {
      print("packet $imessage");
      buffer.add(imessage as Uint8List);
      if (buffer.available > 7) {
        print("avail: ${buffer.available}.");
        int size = buffer.readInt64();
        buffer.checkpoint();
        print("avail: ${buffer.available} (size $size).");
        while (buffer.available >= size) {
          print("avail: ${buffer.available}.");
          message = buffer.readUint8List(size);
          print("messag" + message.toString());
          buffer.checkpoint();
        }
      }
      setState(() {});
    });
  }

  List<int> message = [0, 0];
  List<Offset> get players {
    print("msg" + message.toString());
    List<int> poses = message.sublist(2, message.length);
    print("poses: " + poses.toString());
    List<Offset> result = [];
    for (int i = 0; i < poses.length; i += 2) {
      result.add(Offset(poses[i] / 1, poses[i + 1] / 1));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
                  4,
                  (i) => TextButton(
                    onPressed: () {
                      server.add([playerIndex, i + 1]);
                    },
                    child: Text(buttons[i]),
                  ),
                ) +
                [
                  TextButton(
                    onPressed: () {
                      playerIndex++;
                      server.add([playerIndex, 0]);
                    },
                    child: Text("Increment player index"),
                  ),
                  TextButton(
                    onPressed: () {
                      if(playerIndex>0) {
                        playerIndex--;
                        server.add([playerIndex, 0]);
                      }
                    },
                    child: Text("Decrement player index"),
                  ),
                ],
          ),
          Expanded(
            child: Container(
              color: Colors.black,
              child: CustomPaint(
                painter:
                    WorldDrawer(Size(message[0] / 1, message[1] / 1), players),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorldDrawer extends CustomPainter {
  final List<Offset> players;

  final Size size;

  WorldDrawer(this.size, this.players);

  @override
  void paint(Canvas canvas, Size totalSize) {
    Size worldSize = Size.square(totalSize.shortestSide);
    double circleRadius = worldSize.shortestSide / (size.longestSide * 2);
    print("wSize: $worldSize, totSize: $totalSize");
    var topLeft = Offset((totalSize.width - worldSize.width) / 2,
        (totalSize.height - worldSize.height) / 2);
    canvas.drawRect(topLeft & worldSize, Paint()..color = Colors.green);
    print(players);
    for (int i = 0; i < players.length; i++) {
      Offset offset = players[i];
      Random r = Random(i);
      if (playerIndex == i) {
        canvas.drawCircle(
            topLeft +
                (offset * circleRadius * 2) +
                Offset(circleRadius, circleRadius),
            circleRadius + 1,
            Paint()..color = Colors.white);
      }
      canvas.drawCircle(
          topLeft +
              (offset * circleRadius * 2) +
              Offset(circleRadius, circleRadius),
          circleRadius,
          Paint()
            ..color = Color.fromARGB(
                0xFF, r.nextInt(0xFF), r.nextInt(0xFF), r.nextInt(0xFF)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
