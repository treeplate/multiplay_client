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
    server.listen((List<int> message) {
      buffer.add(message as Uint8List);
      if (buffer.available >= 16) {
        int playerCount = buffer.readInt64();
        int objectCount = buffer.readInt64();
        buffer.rewind();
        if (buffer.available >= 2 + playerCount * 2 + objectCount * 2 + 2) {
          buffer.readUint8List(16);
          setState(() {
            size = buffer.readUint8List(2);
            rawPlayers = buffer.readUint8List(playerCount * 2);
            rawObjects = buffer.readUint8List(objectCount * 2);
            goal = buffer.readUint8List(2);
            buffer.checkpoint();
          });
        }
      }
    });
  }

  List<int> goal = [20, 20];
  List<int> size = [0, 0];

  List<int> rawPlayers = [];
  List<Offset> get players {
    List<int> poses = rawPlayers;
    List<Offset> result = [];
    for (int i = 0; i < poses.length; i += 2) {
      result.add(Offset(poses[i] / 1, poses[i + 1] / 1));
    }
    return result;
  }

  List<int> rawObjects = [];
  List<Offset> get objects {
    List<int> poses = rawObjects;
    List<Offset> result = [];
    for (int i = 0; i < poses.length; i += 2) {
      result.add(Offset(poses[i] / 1, poses[i + 1] / 1));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: Focus(
        autofocus: true,
        onKey: (
          FocusNode x,
          RawKeyEvent e,
        ) {
          //print("got $e");
          switch (e.character) {
            case "d":
              server.add([playerIndex, 1]);
              break;
            case "a":
              server.add([playerIndex, 2]);
              break;
            case "s":
              server.add([playerIndex, 3]);
              break;
            case "w":
              server.add([playerIndex, 4]);
              break;
            case "+":
              playerIndex++;
              server.add([playerIndex, 0]);
              break;
            case "-":
              playerIndex--;
              server.add([playerIndex, 0]);
              break;
            default:
              return false;
          }
          return true;
        },
        child: Scaffold(
          body: Container(
            color: Colors.black,
            child: CustomPaint(
              painter: WorldDrawer(
                  Size(size[0] / 1, size[1] / 1), players, objects, goal),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class WorldDrawer extends CustomPainter {
  final List<Offset> players;
  final List<Offset> objects;
  final List<int> goal;

  final Size size;

  WorldDrawer(this.size, this.players, this.objects, this.goal);

  @override
  void paint(Canvas canvas, Size totalSize) {
    Size worldSize = Size.square(totalSize.shortestSide);
    //print("$worldSize, $size");
    double circleRadius = worldSize.shortestSide / (size.longestSide * 2);
    //print("wSize: $worldSize, totSize: $totalSize");
    var topLeft = Offset((totalSize.width - worldSize.width) / 2,
        (totalSize.height - worldSize.height) / 2);
    canvas.drawRect(topLeft & worldSize, Paint()..color = Colors.white70);
    //print(players);
    for (int i = 0; i < players.length; i++) {
      Offset offset = players[i];
      Random r = Random(i);
      if (playerIndex == i) {
        //print("$topLeft, $circleRadius, $offset");
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
    for (int i = 0; i < objects.length; i++) {
      Offset offset = objects[i];
      canvas.drawRect(
        topLeft + (offset * circleRadius * 2) & Size.square(circleRadius * 2),
        Paint()..color = Colors.black,
      );
    }
    canvas.drawRect(
      topLeft + (Offset(goal[0] / 1, goal[1] / 1) * circleRadius * 2) &
          Size.square(circleRadius * 2),
      Paint()..color = Colors.lightGreen,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
