import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameState.loadProgress();
  runApp(const ColorPuzzleApp());
}

enum TileShape { hexagon, square, triangle }

class ColorPuzzleApp extends StatelessWidget {
  const ColorPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hexagon Color',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF13111C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9A82DB),
          surface: Color(0xFF1E1B2E),
        ),
      ),
      home: const MainDashboardScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MODELOS DE DATOS
// -----------------------------------------------------------------------------
class PuzzleTile {
  final int id;
  final Color color;
  final bool isFixed;
  int currentPos;

  PuzzleTile({
    required this.id,
    required this.color,
    required this.isFixed,
    required this.currentPos,
  });
}

class LevelConfig {
  final int levelNumber;
  final String category;
  final int rows;
  final int cols;
  final Color cTopLeft;
  final Color cTopRight;
  final Color cBottomLeft;
  final Color cBottomRight;
  final TileShape shape;
  final int? timeLimitSeconds;
  final int? maxMoves;

  LevelConfig({
    required this.levelNumber,
    this.category = 'Clásico',
    required this.rows,
    required this.cols,
    required this.cTopLeft,
    required this.cTopRight,
    required this.cBottomLeft,
    required this.cBottomRight,
    this.shape = TileShape.hexagon,
    this.timeLimitSeconds,
    this.maxMoves,
  });
}

// -----------------------------------------------------------------------------
// ESTADO GLOBAL Y PERSISTENCIA LOCAL ÚNICA
// -----------------------------------------------------------------------------
class GameState {
  static Set<int> completedLevels = {};
  static Map<int, int> bestRecords = {};
  static List<List<Color>> paletteCollection = [];

  static int totalHints = 15;
  static int winStreak = 0;

  static Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? completedStr = prefs.getStringList('completed_levels');
    if (completedStr != null) {
      completedLevels = completedStr.map((e) => int.parse(e)).toSet();
    }
    totalHints = prefs.getInt('total_hints') ?? 15;
  }

  static Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('completed_levels', completedLevels.map((e) => e.toString()).toList());
    await prefs.setInt('total_hints', totalHints);
  }

  static Future<void> addCompleted(int levelNum, int moves, List<Color> palette) async {
    completedLevels.add(levelNum);
    if (!bestRecords.containsKey(levelNum) || moves < bestRecords[levelNum]!) {
      bestRecords[levelNum] = moves;
    }
    if (!paletteCollection.any((p) => p.toString() == palette.toString())) {
      paletteCollection.add(palette);
    }

    winStreak++;
    if (winStreak >= 5) {
      totalHints += 2;
      winStreak = 0;
    }
    await saveProgress();
  }

  static void resetStreak() {
    winStreak = 0;
  }
}

// -----------------------------------------------------------------------------
// 1. DASHBOARD PRINCIPAL (Con distribución de 5 tarjetas)
// -----------------------------------------------------------------------------
class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  late List<LevelConfig> classicLevels;
  late List<LevelConfig> challengeLevels;

  @override
  void initState() {
    super.initState();
    classicLevels = _generateMassiveLevels(300);
    challengeLevels = _generateChallengeLevels(30);
  }

  List<LevelConfig> _generateMassiveLevels(int total) {
    final List<LevelConfig> list = [];
    final Random rng = Random(12345);

    for (int i = 1; i <= total; i++) {
      int r, c;
      if (i <= 20) { r = c = 3; }
      else if (i <= 40) { r = c = 4; }
      else if (i <= 60) { r = c = 5; }
      else if (i <= 80) { r = c = 6; }
      else if (i <= 100) { r = c = 7; }
      else if (i <= 120) { r = c = 8; }
      else if (i <= 140) { r = c = 9; }
      else if (i <= 160) { r = c = 10; }
      else if (i <= 250) {
        int size = 11 + ((i - 161) ~/ 10);
        r = c = size.clamp(11, 19);
      } else {
        r = c = 20;
      }

      TileShape shape = TileShape.values[i % TileShape.values.length];

      Color c1 = Color.fromRGBO(rng.nextInt(255), rng.nextInt(180), rng.nextInt(255), 1);
      Color c2 = Color.fromRGBO(rng.nextInt(255), rng.nextInt(255), rng.nextInt(180), 1);
      Color c3 = Color.fromRGBO(rng.nextInt(180), rng.nextInt(255), rng.nextInt(255), 1);
      Color c4 = Color.fromRGBO(rng.nextInt(255), rng.nextInt(150), rng.nextInt(200), 1);

      list.add(LevelConfig(
        levelNumber: i,
        rows: r,
        cols: c,
        cTopLeft: c1,
        cTopRight: c2,
        cBottomLeft: c3,
        cBottomRight: c4,
        shape: shape,
      ));
    }
    return list;
  }

  List<LevelConfig> _generateChallengeLevels(int total) {
    final List<LevelConfig> list = [];
    final Random rng = Random(888);

    for (int i = 1; i <= total; i++) {
      int size = 4 + (i ~/ 6);
      list.add(LevelConfig(
        levelNumber: 800 + i,
        category: 'Desafío Limitado',
        rows: size,
        cols: size,
        cTopLeft: Color.fromRGBO(255, rng.nextInt(100), rng.nextInt(100), 1),
        cTopRight: Color.fromRGBO(rng.nextInt(100), 255, rng.nextInt(100), 1),
        cBottomLeft: Color.fromRGBO(rng.nextInt(100), rng.nextInt(100), 255, 1),
        cBottomRight: const Color(0xFFFFFF00),
        shape: TileShape.square,
        timeLimitSeconds: 40 + (size * 5),
        maxMoves: 15 + (size * 3),
      ));
    }
    return list;
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Hexagon Color",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFE8DEF8)),
        ),
        backgroundColor: const Color(0xFF1E1B2E),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              avatar: const Icon(Icons.lightbulb, color: Colors.amber, size: 18),
              label: Text("${GameState.totalHints}", style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF2B2541),
            ),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressMapWidget(),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Modos de Juego", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD0BCFF))),
                    Text("Racha: ${GameState.winStreak}/5 ⚡", style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // FILA 1: Clásico e Infinito
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 130,
                        child: _buildDashboardCard(
                          title: "Modo Clásico",
                          subtitle: "300 Niveles (3x3 a 20x20)",
                          icon: Icons.grid_on,
                          color: const Color(0xFF3B3355),
                          accentColor: const Color(0xFF9A82DB),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ClassicModeScreen(levels: classicLevels)));
                            _refresh();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 130,
                        child: _buildDashboardCard(
                          title: "Modo Infinito",
                          subtitle: "4 Pistas • Aleatorio continuo",
                          icon: Icons.all_inclusive,
                          color: const Color(0xFF2B2541),
                          accentColor: const Color(0xFFD0BCFF),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const InfiniteModeScreen()));
                            _refresh();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // FILA 2: Estaciones y Límite
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 130,
                        child: _buildDashboardCard(
                          title: "Modo Estaciones",
                          subtitle: "Primavera, Verano, Otoño, Invierno",
                          icon: Icons.eco,
                          color: const Color(0xFF254133),
                          accentColor: const Color(0xFF82DBA8),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const StationsModeScreen()));
                            _refresh();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 130,
                        child: _buildDashboardCard(
                          title: "Límite Tiempo/Movs",
                          subtitle: "Desafío con cronómetro",
                          icon: Icons.timer,
                          color: const Color(0xFF41252B),
                          accentColor: const Color(0xFFDB8282),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ClassicModeScreen(levels: challengeLevels)));
                            _refresh();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // FILA 3: Colección Abajo y Centrada
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: _buildDashboardCard(
                    title: "Colección de Paletas",
                    subtitle: "${GameState.paletteCollection.length} Paletas guardadas de tus victorias",
                    icon: Icons.palette,
                    color: const Color(0xFF3B253B),
                    accentColor: const Color(0xFFDB82C0),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaletteCollectionScreen())),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressMapWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B3355)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_graph, color: Color(0xFF9A82DB), size: 20),
                  SizedBox(width: 8),
                  Text("Mapa de Progreso General", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE8DEF8))),
                ],
              ),
              Text("${GameState.completedLevels.length} / 300", style: const TextStyle(fontSize: 12, color: Colors.white54))
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 45,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
              itemCount: 150,
              itemBuilder: (context, index) {
                bool isDone = GameState.completedLevels.contains(index + 1);
                return Container(
                  width: 12,
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFF9A82DB) : const Color(0xFF2B2541),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({required String title, required String subtitle, required IconData icon, required Color color, required Color accentColor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. MODO CLÁSICO Y DESAFÍOS
// -----------------------------------------------------------------------------
class ClassicModeScreen extends StatelessWidget {
  final List<LevelConfig> levels;
  const ClassicModeScreen({super.key, required this.levels});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Selección de Niveles (${levels.length})"), backgroundColor: const Color(0xFF1E1B2E)),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: levels.length,
            itemBuilder: (context, index) {
              final lvl = levels[index];
              final bool isDone = GameState.completedLevels.contains(lvl.levelNumber);

              return InkWell(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => GameEngineScreen(config: lvl)));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFF3B3355) : const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDone ? const Color(0xFF9A82DB) : const Color(0xFF2B2541)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${lvl.levelNumber}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDone ? const Color(0xFFD0BCFF) : Colors.white)),
                      Text("${lvl.rows}x${lvl.cols}", style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. MODO INFINITO
// -----------------------------------------------------------------------------
class InfiniteModeScreen extends StatefulWidget {
  const InfiniteModeScreen({super.key});

  @override
  State<InfiniteModeScreen> createState() => _InfiniteModeScreenState();
}

class _InfiniteModeScreenState extends State<InfiniteModeScreen> {
  int seed = 0;

  LevelConfig _generateRandomLevel() {
    final rng = Random(seed + 999);
    int size = 4 + rng.nextInt(3);
    return LevelConfig(
      levelNumber: seed + 1,
      rows: size,
      cols: size,
      cTopLeft: Color.fromRGBO(rng.nextInt(255), rng.nextInt(200), rng.nextInt(255), 1),
      cTopRight: Color.fromRGBO(rng.nextInt(255), rng.nextInt(255), rng.nextInt(200), 1),
      cBottomLeft: Color.fromRGBO(rng.nextInt(200), rng.nextInt(255), rng.nextInt(255), 1),
      cBottomRight: Color.fromRGBO(rng.nextInt(255), rng.nextInt(150), rng.nextInt(200), 1),
      shape: TileShape.values[rng.nextInt(TileShape.values.length)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameEngineScreen(
      config: _generateRandomLevel(),
      isInfiniteMode: true,
      onNextInfinite: () => setState(() => seed++),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. MODO ESTACIONES
// -----------------------------------------------------------------------------
class StationsModeScreen extends StatelessWidget {
  const StationsModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<LevelConfig> stations = [
      LevelConfig(
        levelNumber: 901, category: 'Primavera - Brotes', rows: 5, cols: 5,
        cTopLeft: const Color(0xFF85FFBD), cTopRight: const Color(0xFFFFFB7D),
        cBottomLeft: const Color(0xFF00B09B), cBottomRight: const Color(0xFF96C93D),
        shape: TileShape.hexagon,
      ),
      LevelConfig(
        levelNumber: 902, category: 'Verano - Sol Radiante', rows: 6, cols: 6,
        cTopLeft: const Color(0xFFFF4E50), cTopRight: const Color(0xFFF9D423),
        cBottomLeft: const Color(0xFFFF8008), cBottomRight: const Color(0xFFFFC837),
        shape: TileShape.square,
      ),
      LevelConfig(
        levelNumber: 903, category: 'Otoño - Hojas Secas', rows: 7, cols: 7,
        cTopLeft: const Color(0xFFD38312), cTopRight: const Color(0xFFA83279),
        cBottomLeft: const Color(0xFFBA5370), cBottomRight: const Color(0xFFF4E2D8),
        shape: TileShape.triangle,
      ),
      LevelConfig(
        levelNumber: 904, category: 'Invierno - Glacial', rows: 8, cols: 8,
        cTopLeft: const Color(0xFFE0EAFC), cTopRight: const Color(0xFFCFDEF3),
        cBottomLeft: const Color(0xFF4CA1AF), cBottomRight: const Color(0xFF2C3E50),
        shape: TileShape.hexagon,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Modo Estaciones")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: stations.length,
              itemBuilder: (context, index) {
                final st = stations[index];
                return Card(
                  color: const Color(0xFF1E1B2E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(st.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Cuadrícula ${st.rows}x${st.cols} • Forma: ${st.shape.name}"),
                    trailing: const Icon(Icons.play_arrow, color: Color(0xFF9A82DB)),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameEngineScreen(config: st))),
                  ),
                );
              },
          ),
        ),
      ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. COLECCIÓN DE PALETAS
// -----------------------------------------------------------------------------
class PaletteCollectionScreen extends StatelessWidget {
  const PaletteCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Colección de Paletas")),
      body: GameState.paletteCollection.isEmpty
          ? const Center(child: Text("¡Completa niveles para desbloquear paletas!"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: GameState.paletteCollection.length,
              itemBuilder: (context, index) {
                final palette = GameState.paletteCollection[index];
                return Card(
                  color: const Color(0xFF1E1B2E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: palette.map((c) => Container(width: 30, height: 30, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)))).toList(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Color(0xFF9A82DB)),
                          onPressed: () {
                            String hexs = palette.map((c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}').join(', ');
                            Clipboard.setData(ClipboardData(text: hexs));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copiado: $hexs")));
                          },
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// 6. MOTOR DEL JUEGO
// -----------------------------------------------------------------------------
class GameEngineScreen extends StatefulWidget {
  final LevelConfig config;
  final bool isInfiniteMode;
  final VoidCallback? onNextInfinite;

  const GameEngineScreen({
    super.key,
    required this.config,
    this.isInfiniteMode = false,
    this.onNextInfinite,
  });

  @override
  State<GameEngineScreen> createState() => _GameEngineScreenState();
}

class _GameEngineScreenState extends State<GameEngineScreen> {
  List<PuzzleTile> tiles = [];
  int? selectedIndex;
  int moves = 0;
  bool isWon = false;

  int maxHintsForThisLevel = 2;
  int hintsUsedThisGame = 0;
  Set<int> highlightedIndices = {};

  Timer? timer;
  int remainingSeconds = 0;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    maxHintsForThisLevel = max(2, widget.config.rows - 1);
    if (widget.isInfiniteMode) maxHintsForThisLevel = 4;
    _initBoard();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _initBoard() {
    timer?.cancel();
    isPaused = false;
    int total = widget.config.rows * widget.config.cols;
    List<PuzzleTile> generated = [];
    int idCounter = 0;

    for (int r = 0; r < widget.config.rows; r++) {
      double vFactor = r / (widget.config.rows - 1);
      Color leftColor = Color.lerp(widget.config.cTopLeft, widget.config.cBottomLeft, vFactor)!;
      Color rightColor = Color.lerp(widget.config.cTopRight, widget.config.cBottomRight, vFactor)!;

      for (int c = 0; c < widget.config.cols; c++) {
        double hFactor = c / (widget.config.cols - 1);
        Color finalColor = Color.lerp(leftColor, rightColor, hFactor)!;

        bool isCorner = (r == 0 && c == 0) ||
            (r == 0 && c == widget.config.cols - 1) ||
            (r == widget.config.rows - 1 && c == 0) ||
            (r == widget.config.rows - 1 && c == widget.config.cols - 1);

        generated.add(PuzzleTile(
          id: idCounter,
          color: finalColor,
          isFixed: isCorner,
          currentPos: idCounter,
        ));
        idCounter++;
      }
    }

    List<PuzzleTile> movable = generated.where((t) => !t.isFixed).toList();
    movable.shuffle(Random());

    int movableIdx = 0;
    tiles = [];
    for (int i = 0; i < total; i++) {
      if (generated[i].isFixed) {
        tiles.add(generated[i]);
      } else {
        PuzzleTile t = movable[movableIdx++];
        t.currentPos = i;
        tiles.add(t);
      }
    }

    moves = 0;
    hintsUsedThisGame = 0;
    highlightedIndices.clear();
    isWon = false;
    selectedIndex = null;

    if (widget.config.timeLimitSeconds != null) {
      remainingSeconds = widget.config.timeLimitSeconds!;
      _startTimer();
    }

    setState(() {});
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isPaused) {
        if (remainingSeconds > 0) {
          setState(() => remainingSeconds--);
        } else {
          t.cancel();
          _handleLoss("¡Se acabó el tiempo!");
        }
      }
    });
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
    });
  }

  void _useHint() {
    if (hintsUsedThisGame >= maxHintsForThisLevel) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Máximo $maxHintsForThisLevel pistas alcanzado para este nivel.")));
      return;
    }

    if (widget.isInfiniteMode && GameState.totalHints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tienes pistas disponibles.")));
      return;
    }

    int wrongIndex = -1;
    for (int i = 0; i < tiles.length; i++) {
      if (!tiles[i].isFixed && tiles[i].id != i) {
        wrongIndex = i;
        break;
      }
    }

    if (wrongIndex != -1) {
      int targetIndex = tiles.indexWhere((t) => t.id == wrongIndex);
      setState(() {
        if (widget.isInfiniteMode) GameState.totalHints--;
        hintsUsedThisGame++;
        highlightedIndices = {wrongIndex, targetIndex};
      });
      HapticFeedback.lightImpact();
    }
  }

  void _onTileTap(int index) {
    if (isWon || isPaused || tiles[index].isFixed) return;

    HapticFeedback.selectionClick();

    setState(() {
      if (selectedIndex == null) {
        selectedIndex = index;
      } else {
        PuzzleTile temp = tiles[selectedIndex!];
        tiles[selectedIndex!] = tiles[index];
        tiles[index] = temp;

        moves++;
        selectedIndex = null;
        highlightedIndices.clear();

        if (widget.config.maxMoves != null && moves > widget.config.maxMoves!) {
          _handleLoss("Límite de movimientos superado.");
          return;
        }

        _checkWin();
      }
    });
  }

  void _handleLoss(String reason) {
    timer?.cancel();
    GameState.resetStreak();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text("❌ Desafío Fallido"),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initBoard();
            },
            child: const Text("Reintentar"),
          )
        ],
      ),
    );
  }

  void _checkWin() {
    bool win = true;
    for (int i = 0; i < tiles.length; i++) {
      if (tiles[i].id != i) {
        win = false;
        break;
      }
    }

    if (win) {
      timer?.cancel();
      isWon = true;
      List<Color> palette = [widget.config.cTopLeft, widget.config.cTopRight, widget.config.cBottomLeft, widget.config.cBottomRight];
      GameState.addCompleted(widget.config.levelNumber, moves, palette);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Color> palette = [widget.config.cTopLeft, widget.config.cTopRight, widget.config.cBottomLeft, widget.config.cBottomRight];

    return Scaffold(
      backgroundColor: const Color(0xFF13111C),
      appBar: AppBar(
        title: Text(widget.isInfiniteMode ? "Modo Infinito" : "Nivel ${widget.config.levelNumber}"),
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.config.timeLimitSeconds != null)
            IconButton(
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
              onPressed: _togglePause,
            ),
          IconButton(
            icon: const Icon(Icons.lightbulb, color: Colors.amber),
            onPressed: _useHint,
            tooltip: "Pistas ($hintsUsedThisGame/$maxHintsForThisLevel)",
          )
        ],
      ),
      body: isPaused
          ? const Center(
              child: Text("⏸️ JUEGO EN PAUSA", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70)),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text("Movimientos: $moves ${widget.config.maxMoves != null ? '/ ${widget.config.maxMoves}' : ''}", style: const TextStyle(fontSize: 15, color: Color(0xFFD0BCFF))),
                      if (widget.config.timeLimitSeconds != null)
                        Text("⏳ ${remainingSeconds}s", style: const TextStyle(fontSize: 15, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ShapeGridWidget(
                          rows: widget.config.rows,
                          cols: widget.config.cols,
                          tiles: tiles,
                          selectedIndex: selectedIndex,
                          highlightedIndices: highlightedIndices,
                          shape: widget.config.shape,
                          onTileTap: _onTileTap,
                        ),
                      ),
                    ),
                  ),
                ),
                if (isWon) ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF9A82DB)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("✨ ¡Nivel Completado! ✨", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD0BCFF))),
                        const SizedBox(height: 6),
                        Text("Movimientos: $moves", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: palette.map((c) => Container(width: 24, height: 24, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)))).toList(),
                        ),
                        const SizedBox(height: 14),
                        if (widget.isInfiniteMode)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (widget.onNextInfinite != null) widget.onNextInfinite!();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9A82DB)),
                                child: const Text("Próximo Nivel ➔"),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Salir"),
                              ),
                            ],
                          )
                        else
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9A82DB), minimumSize: const Size(200, 40)),
                            child: const Text("Continuar"),
                          )
                      ],
                    ),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _initBoard,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reiniciar Tablero"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2B2541), foregroundColor: const Color(0xFFD0BCFF)),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// 7. RENDERIZADOR ADAPTATIVO SIN ZOOM
// -----------------------------------------------------------------------------
class ShapeGridWidget extends StatelessWidget {
  final int rows;
  final int cols;
  final List<PuzzleTile> tiles;
  final int? selectedIndex;
  final Set<int> highlightedIndices;
  final TileShape shape;
  final Function(int index) onTileTap;

  const ShapeGridWidget({
    super.key,
    required this.rows,
    required this.cols,
    required this.tiles,
    required this.selectedIndex,
    required this.highlightedIndices,
    required this.shape,
    required this.onTileTap,
  });

  @override
  Widget build(BuildContext context) {
    double size = cols <= 4 ? 42.0 : (cols <= 7 ? 32.0 : (cols <= 12 ? 20.0 : 12.0));

    if (shape == TileShape.square) {
      return Container(
        width: cols * (size * 1.6),
        height: rows * (size * 1.6),
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 3, mainAxisSpacing: 3),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            final t = tiles[index];
            final isSelected = selectedIndex == index;
            final isHighlighted = highlightedIndices.contains(index);

            return GestureDetector(
              onTap: () => onTileTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: t.color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.white : (isHighlighted ? Colors.amber : Colors.transparent),
                    width: isSelected || isHighlighted ? 3 : 0,
                  ),
                ),
                child: t.isFixed ? const Center(child: CircleAvatar(radius: 2.5, backgroundColor: Colors.white70)) : null,
              ),
            );
          },
        ),
      );
    }

    double width = cols * (size * 1.732) + size;
    double height = rows * (size * 1.5) + size;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: List.generate(tiles.length, (index) {
          int r = index ~/ cols;
          int c = index % cols;

          double xOffset = c * (size * 1.732) + (r % 2 == 1 ? (size * 0.866) : 0);
          double yOffset = r * (size * 1.5);

          final tile = tiles[index];
          final isSelected = selectedIndex == index;
          final isHighlighted = highlightedIndices.contains(index);

          return Positioned(
            left: xOffset,
            top: yOffset,
            child: GestureDetector(
              onTap: () => onTileTap(index),
              child: CustomPaint(
                size: Size(size * 1.732, size * 2),
                painter: ShapePainter(
                  color: tile.color,
                  isSelected: isSelected,
                  isHighlighted: isHighlighted,
                  isFixed: tile.isFixed,
                  radius: size,
                  shape: shape,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ShapePainter extends CustomPainter {
  final Color color;
  final bool isSelected;
  final bool isHighlighted;
  final bool isFixed;
  final double radius;
  final TileShape shape;

  ShapePainter({
    required this.color,
    required this.isSelected,
    required this.isHighlighted,
    required this.isFixed,
    required this.radius,
    required this.shape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();

    if (shape == TileShape.triangle) {
      path.moveTo(center.dx, center.dy - radius);
      path.lineTo(center.dx + radius, center.dy + radius);
      path.lineTo(center.dx - radius, center.dy + radius);
      path.close();
    } else {
      for (int i = 0; i < 6; i++) {
        double angle = (pi / 3) * i - (pi / 6);
        double x = center.dx + radius * cos(angle);
        double y = center.dy + radius * sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
    }

    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (isSelected) {
      final borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3;
      canvas.drawPath(path, borderPaint);
    } else if (isHighlighted) {
      final borderPaint = Paint()..color = Colors.amber..style = PaintingStyle.stroke..strokeWidth = 3.5;
      canvas.drawPath(path, borderPaint);
    } else if (isFixed) {
      final dotPaint = Paint()..color = Colors.white70;
      canvas.drawCircle(center, radius > 15 ? 3.0 : 1.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected || oldDelegate.isHighlighted != isHighlighted || oldDelegate.isFixed != isFixed;
  }
}