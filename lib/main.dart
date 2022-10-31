import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_automation_tools/all.dart';
import 'package:just_audio/just_audio.dart';

Socket server;
AudioPlayer player;

int playerIndex = 0;

List<String> levelNames = [
  "movement_intro",
  "button_intro",
  "double_button",
  "box_intro",
  "box_puzzle",
];

class WorldState {
  WorldState(this.size, this.players, this.objects, this.goal);
  final Size size; // fixed per level
  final List<Offset> players;
  final List<List<double>> objects;
  final List<int> goal; // fixed per level
}

bool playerMoving = false;

class WorldTween extends Tween<WorldState> {
  WorldTween(WorldState begin, WorldState end) : super(begin: begin, end: end);
  WorldState lerp(double t) {
    List<List<double>> objects = [];
    for (List<double> objectA in begin.objects) {
      if (!end.objects.any((List<double> tester) => tester[4] == objectA[4])) {
        objects.add(objectA);
        continue;
      }
      print("Animating $objectA");
      List<double> objectB = end.objects
          .singleWhere((List<double> tester) => tester[4] == objectA[4]);
      switch (objectB[2].toInt()) {
        case 0:
        case 1:
          print("lerping 0/1...");
          objects.add([
            lerpDouble(objectA[0], objectB[0], t),
            lerpDouble(objectA[1], objectB[1], t),
            objectB[2],
            0,
            objectB[4],
          ]);
          break;
        case 2:
          print("lerping 2... (${lerpDouble(objectA[3], objectB[3], t)})");
          objects.add([
            objectB[0],
            objectB[1],
            2,
            lerpDouble(objectA[3], objectB[3], t),
            objectB[4],
          ]);
          break;
        case 3:
          print(
              "lerping 3... (${lerpDouble(objectA[0], objectB[0], t)}, ${lerpDouble(objectA[1], objectB[1], t)},");
          objects.add([
            lerpDouble(objectA[0], objectB[0], t),
            lerpDouble(objectA[1], objectB[1], t),
            3,
            0,
            objectB[4]
          ]);
          break;
        case 4:
          print("lerping 4...");
          objects.add(objectB);
          break;
        default:
          throw "Unreckognized object type ${objectB[3]}";
      }
    }
    if (begin.players.length > playerIndex)
      print("${begin.players[playerIndex]} !=/== ${end.players[playerIndex]}");
    playerMoving = (begin.players.length > playerIndex) &&
        begin.players[playerIndex] != end.players[playerIndex];
    return WorldState(
      end.size,
      begin.players
          .map(
            (Offset x) => Offset.lerp(
              x,
              end.players[begin.players.indexOf(x)],
              t,
            ),
          )
          .toList(),
      objects,
      end.goal,
    );
  }
}

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
  bool playingGame = false;
  bool muted = false;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      pageRouteBuilder:
          <T>(RouteSettings settings, Widget Function(BuildContext) func) =>
              MaterialPageRoute<T>(builder: func),
      title: 'Flutter Demo',
      color: Colors.brown,
      home: Stack(
        children: [
          Material(
            child: IconButton(
              icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
              onPressed: () => setState(() => muted = !muted),
            ),
          ),
          playingGame
              ? GameScreen(title: 'Flutter Demo Home Page', muted: muted)
              : TitleScreen(() => setState(() => playingGame = true)),
        ],
      ),
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
            WorldState(
              Size.square(1),
              [Offset(20, 20)],
              [
                [0, 0, 2, 0],
              ],
              [20, 20],
            ),
            null,
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
  GameScreen({Key /*?*/ key, this.title, this.muted}) : super(key: key);

  final String title;
  final bool muted;

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  ImageInfo _buttonImageInfo;
  ImageInfo _crateImageInfo;
  void initState() {
    super.initState();
    ExactAssetImage('pixelart/button.png')
        .resolve(ImageConfiguration(bundle: rootBundle))
        .addListener(
      ImageStreamListener((ImageInfo imageInfo, bool syncronous) {
        setState(() {
          _buttonImageInfo = imageInfo;
        });
      }),
    );
    ExactAssetImage('pixelart/crate.png')
        .resolve(ImageConfiguration(bundle: rootBundle))
        .addListener(
      ImageStreamListener((ImageInfo imageInfo, bool syncronous) {
        setState(() {
          _crateImageInfo = imageInfo;
        });
      }),
    );
    final PacketBuffer buffer = PacketBuffer();
    server.add([playerIndex, 0]);
    server.listen((List<int> message) {
      //print("got message $message");
      buffer.add(message as Uint8List);
      if (buffer.available >= 16) {
        int playerCount = buffer.readInt64();
        int objectCount = buffer.readInt64();
        print(
            "(${buffer.available}) hopefully >= 3 + $playerCount * 2 + $objectCount * 4 + 2");
        buffer.rewind();
        if (buffer.available >=
            16 + 3 + playerCount * 2 + objectCount * 5 + 2) {
          //print("Yes, it is.");
          buffer.readUint8List(16);
          setState(() {
            List<int> someData = buffer.readUint8List(3);
            size = someData.sublist(0, 2);
            if (lastLevelPlayed != someData[2]) {
              lastLevelPlayed = someData[2];
              String filename = "audio/${levelNames[lastLevelPlayed - 1]}.mp3";
              //print("ASSET SETTING ($filename)");
              if (!widget.muted)
                player
                    .setAsset(filename)
                    .then((Duration duration) => player.play());
            }
            rawPlayers = buffer.readUint8List(playerCount * 2);
            rawObjects = buffer.readUint8List(objectCount * 5);
            goal = buffer.readUint8List(2);
            buffer.checkpoint();
            //print("hello...");
          });
        }
      }
    });
  }

  List<int> goal = [20, 20];
  List<int> size = [1, 1];
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
    for (int i = 0; i < poses.length; i += 5) {
      //print(poses.sublist(i, i + 5));
      result.add(
          [poses[i], poses[i + 1], poses[i + 2], poses[i + 3], poses[i + 4]]);
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
          if (!playerMoving) {
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
              case "n":
                server.add([playerIndex, 5]);
                break;
              case "r":
                server.add([playerIndex, 6]);
                break;
              default:
                return KeyEventResult.ignored;
            }
          } else
            print("$playerMoving");
          return KeyEventResult.handled;
        },
        child: Scaffold(
          body: Stack(
            children: [
              Container(
                color: Colors.brown,
                child: TweenAnimationBuilder(
                  duration: Duration(milliseconds: 500),
                  child: Container(),
                  onEnd: () => playerMoving = false,
                  tween: WorldTween(
                    WorldState(
                      Size(size[0] / 1, size[1] / 1),
                      players,
                      objects
                          .map((e1) => e1.map((e2) => e2 / 1).toList())
                          .toList(),
                      goal,
                    ),
                    WorldState(
                      Size(size[0] / 1, size[1] / 1),
                      players,
                      objects
                          .map((e1) => e1.map((e2) => e2 / 1).toList())
                          .toList(),
                      goal,
                    ),
                  ),
                  builder:
                      (BuildContext context, WorldState state, Widget widget) {
                    return CustomPaint(
                      painter: WorldDrawer(
                        state,
                        _buttonImageInfo,
                        _crateImageInfo,
                      ),
                      child: SizedBox.expand(),
                    );
                  },
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
  final WorldState state;
  final ImageInfo crateImageInfo;

  WorldDrawer(this.state, this.buttonImageInfo, this.crateImageInfo);

  final ImageInfo buttonImageInfo;

  @override
  void paint(Canvas canvas, Size totalSize) {
    Size size = state.size;
    List<List<double>> objects = state.objects;
    List<int> goal = state.goal;
    List<Offset> players = state.players;
    Size worldSize = Size.square(totalSize.shortestSide);
    //print("$worldSize, $size");
    double circleRadius = worldSize.shortestSide / (size.longestSide * 2);

    var unitDim = (worldSize.height / size.longestSide);
    //print(worldSize);
    if (size.longestSide > size.shortestSide)
      worldSize = size.width > size.height
          ? Size(worldSize.width, unitDim * size.shortestSide)
          : Size(unitDim * size.shortestSide, worldSize.height);
    //print("wSize: $worldSize, totSize: $totalSize");
    var topLeft = Offset((totalSize.width - worldSize.width) / 2,
        (totalSize.height - worldSize.height) / 2);
    //print(worldSize);
    canvas.drawRect(topLeft & worldSize, Paint()..color = Colors.white70);
    //print(players);
    for (int i = 0; i < objects.length; i++) {
      Offset offset = Offset(objects[i][0] / 1, objects[i][1] / 1);
      drawObject(
          Size.square(circleRadius * 2),
          topLeft + (offset * circleRadius * 2),
          objects[i][2].toInt(),
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
      } else {
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
    Random r = Random(playerIndex);
    //print("$players * $circleRadius * 2");
    canvas.drawCircle(
        topLeft +
            ((players.length > playerIndex
                    ? players[playerIndex]
                    : Offset.zero) *
                circleRadius *
                2) +
            Offset(circleRadius, circleRadius),
        circleRadius - 21,
        Paint()
          ..color = Color.fromARGB(
              0xFF, r.nextInt(0xFF), r.nextInt(0xFF), r.nextInt(0xFF)));
  }

  void drawObject(
      Size size, Offset pos, int type, double data, Canvas canvas) async {
    switch (type) {
      case 0:
        canvas.drawRect(
          pos & size,
          Paint()..color = Colors.brown,
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
        //print("data: $data");
        canvas.drawLine(
          size.topCenter(pos),
          size.center(pos) - Offset(0, data * size.height / 2),
          Paint()
            ..color = Colors.brown[900]
            ..strokeWidth = 10,
        );
        canvas.drawLine(
          size.bottomCenter(pos),
          size.center(pos) + Offset(0, data * size.height / 2),
          Paint()
            ..color = Colors.brown[900]
            ..strokeWidth = 10,
        );
        break;
      case 3:
        if (crateImageInfo == null) {
          canvas.drawRect(
            pos & size,
            Paint()..color = Colors.grey,
          );
        }
        paintImage(
            canvas: canvas,
            rect: pos & size,
            image: crateImageInfo?.image,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none);
        break;
      case 4:
        canvas.drawRect(
          pos & size,
          Paint()..color = Colors.black,
        );
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
