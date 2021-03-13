import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_automation_tools/all.dart';
import 'package:just_audio/just_audio.dart';

Socket server;
AudioPlayer player;

int playerIndex = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  player = AudioPlayer();
  server = await Socket.connect("ceylon.rooves.house", 9000);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool playing = false;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      pageRouteBuilder:
          <T>(RouteSettings settings, Widget Function(BuildContext) func) =>
              MaterialPageRoute<T>(builder: func),
      title: 'Flutter Demo',
      color: Colors.black,
      home: playing
          ? GameScreen(title: 'Flutter Demo Home Page')
          : TitleScreen(() => setState(() => playing = true)),
    );
  }
}

class TitleScreen extends StatelessWidget {
  final VoidCallback startGame;

  TitleScreen(this.startGame, {Key key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Wooden Doors",
          style: TextStyle(
            fontSize: 100,
            color: Colors.brown,
          ),
        ),
        CustomPaint(
          child: Container(
            width: 100,
            height: 100,
          ),
          painter: WorldDrawer(
            Size.square(1),
            [],
            [
              [0, 0, 2, 0],
            ],
            [20, 20],
            null,
          ),
        ),
        TextButton(
          onPressed: () {
            startGame();
          },
          child: Text("Start Game"),
        ),
      ],
    );
  }
}

class GameScreen extends StatefulWidget {
  GameScreen({Key /*?*/ key, this.title}) : super(key: key);

  final String title;

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  ImageInfo _imageInfo;
  void initState() {
    super.initState();
    ExactAssetImage('pixelart/button.png')
        .resolve(ImageConfiguration(bundle: rootBundle))
        .addListener(
      ImageStreamListener((ImageInfo imageInfo, bool syncronous) {
        setState(() {
          _imageInfo = imageInfo;
        });
      }),
    );
    final PacketBuffer buffer = PacketBuffer();
    server.add([playerIndex, 0]);
    server.listen((List<int> message) {
      buffer.add(message as Uint8List);
      if (buffer.available >= 16) {
        int playerCount = buffer.readInt64();
        int objectCount = buffer.readInt64();
        print(
            "(${buffer.available}) 3 + $playerCount * 2 + $objectCount * 4 + 2");
        buffer.rewind();
        if (buffer.available >=
            16 + 3 + playerCount * 2 + objectCount * 4 + 2) {
          buffer.readUint8List(16);
          setState(() {
            List<int> someData = buffer.readUint8List(3);
            size = someData.sublist(0, 2);
            if (lastLevelPlayed != someData[2]) {
              lastLevelPlayed = someData[2];
              String filename =
                  "audio/level_${lastLevelPlayed.toRadixString(2)}.mov";
              print("ASSET SETTING ($filename)");
              player
                  .setAsset(filename)
                  .then((Duration duration) => player.play());
            }
            rawPlayers = buffer.readUint8List(playerCount * 2);
            rawObjects = buffer.readUint8List(objectCount * 4);
            goal = buffer.readUint8List(2);
            buffer.checkpoint();
            print("hello...");
          });
        }
      }
    });
  }

  List<int> goal = [20, 20];
  List<int> size = [0, 0];
  int lastLevelPlayed = -1;

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
  List<List<int>> get objects {
    List<int> poses = rawObjects;
    List<List<int>> result = [];
    for (int i = 0; i < poses.length; i += 4) {
      print(poses.sublist(i, i + 4));
      result.add([poses[i], poses[i + 1], poses[i + 2], poses[i + 3]]);
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
          print("got $e");
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
              if (playerIndex > 0) playerIndex--;
              server.add([playerIndex, 0]);
              break;
            default:
              return false;
          }
          return true;
        },
        child: Scaffold(
          body: Stack(
            children: [
              Container(
                color: Colors.black,
                child: CustomPaint(
                  painter: WorldDrawer(
                    Size(size[0] / 1, size[1] / 1),
                    players,
                    objects,
                    goal,
                    _imageInfo,
                  ),
                  child: SizedBox.expand(),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      child: Text(
                        "WASD to move",
                        style: TextStyle(fontSize: 20),
                      ),
                      color: Colors.white.withAlpha(50),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorldDrawer extends CustomPainter {
  final List<Offset> players;
  final List<List<int>> objects;
  final List<int> goal;

  final Size size;

  WorldDrawer(
      this.size, this.players, this.objects, this.goal, this.buttonImageInfo);

  ImageInfo buttonImageInfo;

  @override
  void paint(Canvas canvas, Size totalSize) {
    Size worldSize = Size.square(totalSize.shortestSide);
    //print("$worldSize, $size");
    double circleRadius = worldSize.shortestSide / (size.longestSide * 2);

    var unitDim = (worldSize.height / size.longestSide);
    print(worldSize);
    if (size.longestSide > size.shortestSide)
      worldSize = size.width > size.height
          ? Size(worldSize.width, unitDim * size.shortestSide)
          : Size(unitDim * size.shortestSide, worldSize.height);
    //print("wSize: $worldSize, totSize: $totalSize");
    var topLeft = Offset((totalSize.width - worldSize.width) / 2,
        (totalSize.height - worldSize.height) / 2);
    print(worldSize);
    canvas.drawRect(topLeft & worldSize, Paint()..color = Colors.white70);
    //print(players);
    for (int i = 0; i < objects.length; i++) {
      Offset offset = Offset(objects[i][0] / 1, objects[i][1] / 1);
      drawObject(
          Size.square(circleRadius * 2),
          topLeft + (offset * circleRadius * 2),
          objects[i][2],
          objects[i][3],
          canvas);
    }
    canvas.drawRect(
      topLeft + (Offset(goal[0] / 1, goal[1] / 1) * circleRadius * 2) &
          Size.square(circleRadius * 2),
      Paint()..color = Colors.lightGreen,
    );
    for (int i = 0; i < players.length; i++) {
      Offset offset = players[i];
      Random r = Random(i);
      if (playerIndex == i) {
        //print("$topLeft, $circleRadius, $offset");
        canvas.drawCircle(
            topLeft +
                (offset * circleRadius * 2) +
                Offset(circleRadius, circleRadius),
            circleRadius - 20,
            Paint()..color = Colors.white);
      }
      canvas.drawCircle(
          topLeft +
              (offset * circleRadius * 2) +
              Offset(circleRadius, circleRadius),
          circleRadius - 21,
          Paint()
            ..color = Color.fromARGB(
                0xFF, r.nextInt(0xFF), r.nextInt(0xFF), r.nextInt(0xFF)));
    }
  }

  void drawObject(
      Size size, Offset pos, int type, int data, Canvas canvas) async {
    switch (type) {
      case 0:
        canvas.drawRect(
          pos & size,
          Paint()..color = Colors.black,
        );
        break;
      case 1:
        //canvas.drawOval(pos & size, Paint()..color=Colors.red);
        canvas.drawRect(pos - Offset(5, 5) & size + Offset(10, 10), Paint());
        paintImage(
            canvas: canvas,
            rect: pos & size,
            image: buttonImageInfo.image,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none);
        break;
      case 2:
        if (data == 0)
          canvas.drawLine(
              size.bottomCenter(pos),
              size.topCenter(pos),
              Paint()
                ..color = Colors.brown
                ..strokeWidth = 10);
        break;
      default:
        throw "Unsupported '$type' type of object";
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
