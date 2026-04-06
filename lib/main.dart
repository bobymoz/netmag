import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:better_player/better_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'scraper_api.dart'; 

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const HaremApp());
}

// ==== GERENCIADOR GLOBAL DE DOWNLOAD ====
class DownloadManager {
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  static final ValueNotifier<double> progress = ValueNotifier(0.0);
  static final ValueNotifier<bool> showFloating = ValueNotifier(false);
  static String currentFile = "";
  static CancelToken? cancelToken;

  static void startDownload(String url, String name) async {
    isDownloading.value = true;
    showFloating.value = true;
    progress.value = 0.0;
    currentFile = name;
    cancelToken = CancelToken();

    try {
      var dir = await getExternalStorageDirectory();
      String savePath = "${dir!.path}/$name.mp4";
      await Dio().download(
        url, savePath,
        cancelToken: cancelToken,
        options: Options(headers: ScraperApi.headers),
        onReceiveProgress: (rec, total) {
          if (total != -1) progress.value = rec / total;
        },
      );
      isDownloading.value = false;
    } catch (e) {
      isDownloading.value = false;
    }
  }

  static void cancel() {
    cancelToken?.cancel();
    isDownloading.value = false;
    showFloating.value = false;
  }
}

class HaremApp extends StatelessWidget {
  const HaremApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAREM',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: Colors.pinkAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const MainLayout(),
    );
  }
}

// ==== LAYOUT PRINCIPAL COM BOTTOM NAV E WIDGET FLUTUANTE ====
class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final List<Widget> _telas = [const HomeTab(tipo: 'hentai'), const HomeTab(tipo: 'manga')];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/HAREM.png', height: 32, width: 32, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Text('HAREM', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoricoScreen())),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: DownloadManager.isDownloading,
            builder: (context, isD, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadScreen())),
                  ),
                  if (isD)
                    Positioned(
                      right: 8, top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                        child: const Text('1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    )
                ],
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          _telas[_currentIndex],
          
          ValueListenableBuilder<bool>(
            valueListenable: DownloadManager.showFloating,
            builder: (context, show, child) {
              if (!show) return const SizedBox.shrink();
              return Positioned(
                bottom: 20, right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadScreen())),
                  child: Container(
                    width: 160, padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.pinkAccent),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Baixando...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => DownloadManager.showFloating.value = false,
                              child: const Icon(Icons.close, size: 16, color: Colors.white54),
                            )
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<double>(
                          valueListenable: DownloadManager.progress,
                          builder: (context, prog, child) {
                            return LinearProgressIndicator(value: prog, backgroundColor: Colors.grey[800], color: Colors.pinkAccent);
                          },
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Animes'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Mangás'),
        ],
      ),
    );
  }
}

// ==== TELA DE CATÁLOGO COM CARROSEL ====
class HomeTab extends StatefulWidget {
  final String tipo;
  const HomeTab({Key? key, required this.tipo}) : super(key: key);

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int pagina = 1;
  List<Map<String, dynamic>> itens = [];
  bool carregando = true;

  @override
  void initState() { super.initState(); _carregarDados(); }

  Future<void> _carregarDados({bool limpar = true}) async {
    if (limpar) setState(() { itens.clear(); pagina = 1; carregando = true; });
    else setState(() => carregando = true);
    
    var novos = await ScraperApi.obterLista(widget.tipo, pagina);
    setState(() { itens.addAll(novos); carregando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty && carregando) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
    
    List<Map<String, dynamic>> carouselItems = itens.take(5).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (carouselItems.isNotEmpty) ...[
            CarouselSlider(
              options: CarouselOptions(height: 220.0, autoPlay: true, enlargeCenterPage: true, viewportFraction: 0.8),
              items: carouselItems.map((item) {
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalhesScreen(urlInfo: item['link']))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(imageUrl: item['imagem'], httpHeaders: ScraperApi.headers, fit: BoxFit.cover),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                          ),
                        ),
                        Positioned(
                          bottom: 10, left: 10, right: 10,
                          child: Text(item['titulo'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Últimos Lançamentos", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // <--- AQUI ESTÁ A CORREÇÃO: NOME CERTO COM CONST!
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: itens.length + 1,
            itemBuilder: (context, index) {
              if (index == itens.length) {
                return GestureDetector(
                  onTap: () { pagina++; _carregarDados(limpar: false); },
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_circle, size: 40, color: Colors.pinkAccent),
                        SizedBox(height: 8),
                        Text("Clique para carregar\nmais conteúdo", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }
              var item = itens[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalhesScreen(urlInfo: item['link']))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(imageUrl: item['imagem'], httpHeaders: ScraperApi.headers, fit: BoxFit.cover),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ==== TELA DE DETALHES ====
class DetalhesScreen extends StatefulWidget {
  final String urlInfo;
  const DetalhesScreen({Key? key, required this.urlInfo}) : super(key: key);

  @override
  _DetalhesScreenState createState() => _DetalhesScreenState();
}

class _DetalhesScreenState extends State<DetalhesScreen> {
  Map<String, dynamic>? detalhes;

  @override
  void initState() {
    super.initState();
    ScraperApi.obterDetalhes(widget.urlInfo).then((dados) => setState(() => detalhes = dados));
  }

  void _salvarHistorico(String nome) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> hist = prefs.getStringList('hist') ?? [];
    var data = jsonEncode({"titulo": detalhes!['titulo'], "ep": nome, "url": widget.urlInfo});
    hist.removeWhere((item) => item.contains(detalhes!['titulo']));
    hist.insert(0, data);
    prefs.setStringList('hist', hist);
  }

  void _abrir(Map<String, String> ep) async {
    _salvarHistorico(ep['nome']!);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    if (ep['tipo'] == 'video') {
      String? vUrl = await ScraperApi.extrairVideo(ep['url']!);
      Navigator.pop(context);
      if (vUrl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videoUrl: vUrl, titulo: ep['nome']!)));
    } else {
      List<String> imgs = await ScraperApi.extrairManga(ep['url']!);
      Navigator.pop(context);
      if (imgs.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (_) => LeitorScreen(imagens: imgs)));
    }
  }

  void _baixar(Map<String, String> ep) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    String? vUrl = await ScraperApi.extrairVideo(ep['url']!);
    Navigator.pop(context);
    if (vUrl != null) DownloadManager.startDownload(vUrl, "${detalhes!['titulo']} - ${ep['nome']}");
  }

  @override
  Widget build(BuildContext context) {
    if (detalhes == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));

    return Scaffold(
      appBar: AppBar(title: Text(detalhes!['titulo'], maxLines: 1)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (detalhes!['poster'] != '')
              CachedNetworkImage(imageUrl: detalhes!['poster'], httpHeaders: ScraperApi.headers, width: double.infinity, fit: BoxFit.contain, alignment: Alignment.topCenter),
            Padding(padding: const EdgeInsets.all(16.0), child: Text(detalhes!['sinopse'], style: const TextStyle(color: Colors.grey))),
            const Divider(color: Colors.white24),
            ...List.generate((detalhes!['episodios'] as List).length, (index) {
              var ep = detalhes!['episodios'][index];
              return ListTile(
                leading: Icon(ep['tipo'] == 'video' ? Icons.play_circle_fill : Icons.menu_book, color: Colors.pinkAccent),
                title: Text(ep['nome']),
                trailing: ep['tipo'] == 'video' ? IconButton(
                  icon: const Icon(Icons.download, color: Colors.white54),
                  onPressed: () => _baixar(ep),
                ) : null,
                onTap: () => _abrir(ep),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ==== TELA DO PLAYER (TELA CHEIA IMEDIATA) ====
class PlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String titulo;
  const PlayerScreen({Key? key, required this.videoUrl, required this.titulo}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late BetterPlayerController _c;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    BetterPlayerDataSource src = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network, widget.videoUrl,
      headers: ScraperApi.headers, 
    );
    _c = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true, 
        fullScreenByDefault: false, 
        allowedScreenSleep: false,
        fit: BoxFit.contain,
      ),
      betterPlayerDataSource: src,
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => DownloadManager.showFloating.value = false);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: BetterPlayer(controller: _c)),
    );
  }
}

// ==== TELAS EXTRAS (DOWNLOAD, HISTÓRICO, MANGÁ) ====
class LeitorScreen extends StatelessWidget {
  final List<String> imagens;
  const LeitorScreen({Key? key, required this.imagens}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Lendo')),
      body: PhotoViewGallery.builder(
        itemCount: imagens.length,
        builder: (c, i) => PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(imagens[i], headers: ScraperApi.headers),
          minScale: PhotoViewComputedScale.contained, maxScale: PhotoViewComputedScale.covered * 3,
        ),
        scrollPhysics: const BouncingScrollPhysics(), backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({Key? key}) : super(key: key);
  @override
  _HistoricoScreenState createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Map<String, dynamic>> hist = [];
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      List<String> list = prefs.getStringList('hist') ?? [];
      setState(() => hist = list.map((e) => jsonDecode(e) as Map<String, dynamic>).toList());
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Continuar Assistindo")),
      body: ListView.builder(
        itemCount: hist.length,
        itemBuilder: (c, i) => ListTile(
          leading: const Icon(Icons.history, color: Colors.pinkAccent),
          title: Text(hist[i]['titulo']), subtitle: Text("Último visto: ${hist[i]['ep']}"),
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DetalhesScreen(urlInfo: hist[i]['url']))),
        ),
      ),
    );
  }
}

class DownloadScreen extends StatelessWidget {
  const DownloadScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gerenciador de Downloads")),
      body: ValueListenableBuilder<bool>(
        valueListenable: DownloadManager.isDownloading,
        builder: (c, isD, child) {
          if (!isD) return const Center(child: Text("Nenhum download ativo."));
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(DownloadManager.currentFile, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ValueListenableBuilder<double>(
                  valueListenable: DownloadManager.progress,
                  builder: (c, prog, child) => LinearProgressIndicator(value: prog, minHeight: 10, color: Colors.pinkAccent),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () { DownloadManager.cancel(); Navigator.pop(context); },
                  icon: const Icon(Icons.cancel), label: const Text("Cancelar"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
