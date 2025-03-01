import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';  // 引入音效播放套件

void main() {
  runApp(const GoGameApp());
}

class GoGameApp extends StatelessWidget {
  const GoGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Go !!! (9x9)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: Colors.grey[200],
        fontFamily: 'CustomFont',  // 使用自訂字體
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      home: const MainMenuScreen(),
    );
  }
}

/// 主選單畫面

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  // Create an AudioCache instance with the assets prefix.
  final AudioCache _audioCache = AudioCache(prefix: 'assets/');
  AudioPlayer? _backgroundPlayer;

  @override
  void initState() {
    super.initState();
    _playBackgroundMusic();
  }

  Future<void> _playBackgroundMusic() async {
    // Loop the background music indefinitely.
    _backgroundPlayer = await _audioCache.loop('background.mp3');
  }

  @override
  void dispose() {
    // Stop the background music when leaving this screen.
    _backgroundPlayer?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GO!!'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Go Game (9x9)',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoBoardScreen()),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Game"),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                showAboutDialog(
                  context: context,
                  applicationName: "Go Game (9x9)",
                  applicationVersion: "1.0",
                  applicationLegalese: "Copyright © 2025",
                );
              },
              icon: const Icon(Icons.info),
              label: const Text("About"),
            ),
          ],
        ),
      ),
    );
  }
}

/// 遊戲畫面
class GoBoardScreen extends StatefulWidget {
  const GoBoardScreen({super.key});

  @override
  State<GoBoardScreen> createState() => _GoBoardScreenState();
}

class _GoBoardScreenState extends State<GoBoardScreen> {
  static const int boardSize = 9;
  // 0: 空, 1: 黑, 2: 白
  List<List<int>> board =
      List.generate(boardSize, (_) => List.filled(boardSize, 0));
  // 保存上一局面供打劫檢查及悔棋
  List<List<int>> previousBoard = [];
  bool isBlackTurn = true;
  // 記錄哪些位置被標記為死棋
  Set<Point> deadStones = {};
  // 標記是否進入「標記死棋」模式
  bool markDeadMode = false;
  // 貼目數值（白棋加貼目）
  final double komi = 6.5;

  // 建立音效播放器，注意要確保 assets/move.mp3 已正確設定
  final AudioCache _audioCache = AudioCache(prefix: 'assets/');

  // 判斷 (x, y) 是否在棋盤範圍內
  bool _inBounds(int x, int y) {
    return x >= 0 && x < boardSize && y >= 0 && y < boardSize;
  }

  // 取得與 (x, y) 同色棋群及其所有氣（空鄰點）
  Map<String, dynamic> _getGroupAndLiberties(
      int x, int y, List<List<int>> boardState) {
    int stone = boardState[x][y];
    Set<Point> group = {};
    Set<Point> liberties = {};
    List<Point> stack = [Point(x, y)];
    while (stack.isNotEmpty) {
      Point p = stack.removeLast();
      if (group.contains(p)) continue;
      group.add(p);
      List<Point> neighbors = [
        Point(p.x - 1, p.y),
        Point(p.x + 1, p.y),
        Point(p.x, p.y - 1),
        Point(p.x, p.y + 1),
      ];
      for (var n in neighbors) {
        if (!_inBounds(n.x, n.y)) continue;
        if (boardState[n.x][n.y] == 0) {
          liberties.add(n);
        } else if (boardState[n.x][n.y] == stone && !group.contains(n)) {
          stack.add(n);
        }
      }
    }
    return {'group': group, 'liberties': liberties};
  }

  // 判斷兩局面是否相同（用於打劫判斷）
  bool _boardsEqual(List<List<int>> a, List<List<int>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      for (int j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  // 在指定的交叉點 (i, j) 落子（正常下子流程）
  void _placeStoneAt(int i, int j) {
    if (board[i][j] != 0) return; // 該交叉點已有棋子

    // 備份局面（用於打劫檢查）
    List<List<int>> boardBeforeMove =
        board.map((row) => List<int>.from(row)).toList();

    setState(() {
      board[i][j] = isBlackTurn ? 1 : 2;
      // 落子後，若該點曾標記為死棋，清除標記
      deadStones.remove(Point(i, j));

      int currentStone = board[i][j];
      int opponentStone = currentStone == 1 ? 2 : 1;

      // 播放下棋音效
      _audioCache.play('sound.m4a');

      // 檢查鄰近對手棋群，若無氣則捕捉
      List<Point> adjacent = [
        Point(i - 1, j),
        Point(i + 1, j),
        Point(i, j - 1),
        Point(i, j + 1),
      ];
      for (var p in adjacent) {
        if (_inBounds(p.x, p.y) && board[p.x][p.y] == opponentStone) {
          var groupInfo = _getGroupAndLiberties(p.x, p.y, board);
          Set<Point> liberties = groupInfo['liberties'];
          if (liberties.isEmpty) {
            // 捕捉：移除該棋群所有棋子，並清除死棋標記
            Set<Point> group = groupInfo['group'];
            for (var pt in group) {
              board[pt.x][pt.y] = 0;
              deadStones.remove(pt);
            }
          }
        }
      }

      // 檢查己方棋群是否有氣（自殺判斷）
      var ownGroupInfo = _getGroupAndLiberties(i, j, board);
      if ((ownGroupInfo['liberties'] as Set<Point>).isEmpty) {
        board = boardBeforeMove;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("不允許自殺動作！")),
        );
        return;
      }

      // 檢查打劫規則：若新局面與上一局面相同則不合法
      if (previousBoard.isNotEmpty && _boardsEqual(board, previousBoard)) {
        board = boardBeforeMove;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("違反打劫規則！")),
        );
        return;
      }

      // 合法走步：保存前一局面並換手
      previousBoard = boardBeforeMove;
      isBlackTurn = !isBlackTurn;
    });
  }

  // 悔棋：回到上一局面
  void _undoMove() {
    if (previousBoard.isNotEmpty) {
      setState(() {
        board = previousBoard;
        isBlackTurn = !isBlackTurn;
        previousBoard = [];
        // 清除所有死棋標記（悔棋後可能需要重新標記）
        deadStones.clear();
      });
    }
  }

  // 重新開始：重設所有參數
  void _restartGame() {
    setState(() {
      board = List.generate(boardSize, (_) => List.filled(boardSize, 0));
      previousBoard = [];
      isBlackTurn = true;
      deadStones.clear();
      markDeadMode = false;
    });
  }

  // 切換「標記死棋」模式：進入此模式後，點擊棋盤上有棋子的交叉點將切換死活狀態
  void _toggleMarkDeadMode() {
    setState(() {
      markDeadMode = !markDeadMode;
    });
  }

  // 利用 flood fill 算法計算空點區域（不考慮死棋），此處仍採用原有簡化邏輯
  Map<int, int> _calculateTerritory() {
    int blackTerritory = 0;
    int whiteTerritory = 0;
    List<List<bool>> visited =
        List.generate(boardSize, (_) => List.filled(boardSize, false));

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == 0 && !visited[i][j]) {
          List<Point> region = [];
          Set<int> adjacentColors = {};

          void dfs(int x, int y) {
            if (x < 0 || x >= boardSize || y < 0 || y >= boardSize) return;
            if (visited[x][y]) return;
            if (board[x][y] != 0) {
              // 僅計算活棋（非死棋）
              if (!deadStones.contains(Point(x, y))) {
                adjacentColors.add(board[x][y]);
              }
              return;
            }
            visited[x][y] = true;
            region.add(Point(x, y));
            dfs(x - 1, y);
            dfs(x + 1, y);
            dfs(x, y - 1);
            dfs(x, y + 1);
          }

          dfs(i, j);
          if (adjacentColors.length == 1) {
            if (adjacentColors.contains(1)) {
              blackTerritory += region.length;
            } else if (adjacentColors.contains(2)) {
              whiteTerritory += region.length;
            }
          }
        }
      }
    }
    return {1: blackTerritory, 2: whiteTerritory};
  }

  // 計算死棋數量：根據 deadStones 集合
  Map<int, int> _calculateDeadStones() {
    int deadBlack = 0;
    int deadWhite = 0;
    for (var pt in deadStones) {
      if (board[pt.x][pt.y] == 1) {
        deadBlack++;
      } else if (board[pt.x][pt.y] == 2) {
        deadWhite++;
      }
    }
    return {1: deadBlack, 2: deadWhite};
  }

  // 顯示最終得分，採用日式計分方式：
  // 黑棋得分 = 活棋目數（歸屬黑棋） + 死白棋數
  // 白棋得分 = 活棋目數（歸屬白棋） + 死黑棋數 + komi
  void _showWinner() {
    Map<int, int> territory = _calculateTerritory();
    Map<int, int> deadCount = _calculateDeadStones();
    int blackScore = territory[1]! + deadCount[2]!;
    int whiteScore = territory[2]! + deadCount[1]! + komi.toInt();

    String result = blackScore > whiteScore
        ? '黑棋獲勝！($blackScore vs $whiteScore)'
        : blackScore < whiteScore
            ? '白棋獲勝！($whiteScore vs $blackScore)'
            : '平局！';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("比賽結束"),
        content: Text(result),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _restartGame();
              },
              child: const Text("重新開始"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 使用 LayoutBuilder 計算棋盤尺寸，並以 CustomPaint 畫出棋盤與棋子
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Go Game (9x9)',
          style: TextStyle(fontSize: 28),
          ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double boardPadding = 20.0;
                double size = constraints.maxWidth;
                return GestureDetector(
                  onTapUp: (details) {
                    RenderBox box =
                        context.findRenderObject() as RenderBox;
                    Offset localPos =
                        box.globalToLocal(details.globalPosition);
                    double dx = localPos.dx - boardPadding;
                    double dy = localPos.dy - boardPadding;
                    double drawSize = size - 2 * boardPadding;
                    double cellSpacing = drawSize / (boardSize - 1);
                    // 若進入標記死棋模式，點擊有棋子的交叉點切換死棋狀態
                    int j = (dx / cellSpacing).round();
                    int i = (dy / cellSpacing).round();
                    if (i >= 0 && i < boardSize && j >= 0 && j < boardSize) {
                      if (markDeadMode && board[i][j] != 0) {
                        setState(() {
                          Point pt = Point(i, j);
                          if (deadStones.contains(pt)) {
                            deadStones.remove(pt);
                          } else {
                            deadStones.add(pt);
                          }
                        });
                      } else {
                        _placeStoneAt(i, j);
                      }
                    }
                  },
                  child: CustomPaint(
                    size: Size(size, size),
                    painter: BoardPainter(
                      board: board,
                      boardSize: boardSize,
                      boardPadding: boardPadding,
                      deadStones: deadStones,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // 控制按鈕列
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _undoMove,
                  icon: const Icon(Icons.undo),
                  label: const Text("悔棋"),
                ),
                ElevatedButton.icon(
                  onPressed: _showWinner,
                  icon: const Icon(Icons.flag),
                  label: const Text("結算"),
                ),
                ElevatedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("重新開始"),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleMarkDeadMode,
                  icon: Icon(markDeadMode
                      ? Icons.check_box
                      : Icons.check_box_outline_blank),
                  label:
                      Text(markDeadMode ? "退出Tag死棋" : "Tag死棋"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  final List<List<int>> board;
  final int boardSize;
  final double boardPadding;
  final Set<Point> deadStones;
  BoardPainter({
    required this.board,
    required this.boardSize,
    required this.boardPadding,
    required this.deadStones,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double drawSize = size.width - 2 * boardPadding;
    double cellSpacing = drawSize / (boardSize - 1);

    // 畫棋盤背景
    Rect boardRect =
        Rect.fromLTWH(boardPadding, boardPadding, drawSize, drawSize);
    Paint backgroundPaint = Paint()..color = Colors.brown[100]!;
    canvas.drawRect(boardRect, backgroundPaint);

    // 畫棋盤線
    Paint linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;
    // 垂直線
    for (int i = 0; i < boardSize; i++) {
      double x = boardPadding + i * cellSpacing;
      canvas.drawLine(
          Offset(x, boardPadding), Offset(x, boardPadding + drawSize), linePaint);
    }
    // 水平線
    for (int i = 0; i < boardSize; i++) {
      double y = boardPadding + i * cellSpacing;
      canvas.drawLine(
          Offset(boardPadding, y), Offset(boardPadding + drawSize, y), linePaint);
    }
    
    // 畫星位：9x9 棋盤標準星位（0 索引）： (2,2), (2,6), (4,4), (6,2), (6,6)
    List<Point> stars = [
      Point(2, 2),
      Point(2, 6),
      Point(4, 4),
      Point(6, 2),
      Point(6, 6),
    ];
    Paint starPaint = Paint()..color = Colors.black;
    double starRadius = cellSpacing * 0.08;
    for (var star in stars) {
      Offset center = Offset(
        boardPadding + star.y * cellSpacing,
        boardPadding + star.x * cellSpacing,
      );
      canvas.drawCircle(center, starRadius, starPaint);
    }

    // 畫棋子
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != 0) {
          Offset center = Offset(
              boardPadding + j * cellSpacing,
              boardPadding + i * cellSpacing);
          Paint stonePaint = Paint()
            ..color = board[i][j] == 1 ? Colors.black : Colors.white;
          canvas.drawCircle(center, cellSpacing * 0.4, stonePaint);
          // 白棋增加黑邊框
          if (board[i][j] == 2) {
            Paint borderPaint = Paint()
              ..color = Colors.black
              ..style = PaintingStyle.stroke;
            canvas.drawCircle(center, cellSpacing * 0.4, borderPaint);
          }
          // 如果該位置被標記為死棋，則在棋子上畫一個紅色 X
          if (deadStones.contains(Point(i, j))) {
            Paint xPaint = Paint()
              ..color = Colors.red
              ..strokeWidth = 2.0;
            double offset = cellSpacing * 0.4;
            canvas.drawLine(
                Offset(center.dx - offset, center.dy - offset),
                Offset(center.dx + offset, center.dy + offset),
                xPaint);
            canvas.drawLine(
                Offset(center.dx - offset, center.dy + offset),
                Offset(center.dx + offset, center.dy - offset),
                xPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 輔助類別：用於儲存棋盤上交叉點的座標，方便比對
class Point {
  final int x;
  final int y;
  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}