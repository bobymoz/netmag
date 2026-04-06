import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:better_player/better_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
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
        options: Options(headers: ScraperApi.imageHeaders),
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

class WidgetFlutuanteDownload extends StatelessWidget {
  const WidgetFlutuanteDownload({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DownloadManager.showFloating,
      builder: (context, show, child) {
        if (!show) return const SizedBox.shrink();
        return Positioned(
          bottom: 20, right: 20,
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadScreen())),
            child: Container(
              width: 180, padding: const EdgeInsets.all(12),
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
                      const Expanded(child: Text("Baixando...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      GestureDetector(
                        onTap: () => DownloadManager.showFloating.value = false,
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
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
    );
  }
}

class HaremApp extends StatelessWidget {
  const HaremApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HAREM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: Colors.pinkAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const MainLayout(),
    );
  }
}

// ==== LAYOUT PRINCIPAL (INDEXED STACK CORRIGE ABAS) ====
class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

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
          // ISSO FAZ AS ABAS DE ANIME E MANGÁ FUNCIONAREM SEPARADAS!
          IndexedStack(
            index: _currentIndex,
            children: const [
              HomeTab(tipo: 'hentai'),
              HomeTab(tipo: 'manga'),
            ],
          ),
          const WidgetFlutuanteDownload(),
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

// ==== TELA DE CATÁLOGO ====
class HomeTab extends StatefulWidget {
  final String tipo;
  const HomeTab({Key? key, required this.tipo}) : super(key: key);

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int pagina = 1;
  String termoBusca = "";
  List<Map<String, dynamic>> itens = [];
  bool carregando = true;
  final TextEditingController _buscaController = TextEditingController();

  @override
  void initState() { super.initState(); _carregarDados(); }

  Future<void> _carregarDados({bool limpar = true}) async {
    if (limpar) setState(() { itens.clear(); pagina = 1; carregando = true; });
    else setState(() => carregando = true);
    
    var novos = await ScraperApi.obterLista(widget.tipo, pagina, busca: termoBusca);
    setState(() { itens.addAll(novos); carregando = false; });
  }

  void _fazerBusca(String texto) {
    termoBusca = texto;
    _carregarDados(limpar: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _buscaController,
            onSubmitted: _fazerBusca,
            decoration: InputDecoration(
              hintText: 'Buscar...',
              filled: true,
              fillColor: Colors.grey[900],
              prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54),
                onPressed: () { _buscaController.clear(); _fazerBusca(""); },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        
        Expanded(
          child: carregando && itens.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
              : itens.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text("Nenhum conteúdo encontrado.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _carregarDados(limpar: true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                            child: const Text("Tentar Novamente", style: TextStyle(color: Colors.white)),
                          )
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 8, mainAxisSpacing: 8),
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
                                  Text("Carregar\nmais", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        }
                        var item = itens[index];
                        String imgUrl = item['imagem'];
                        return GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalhesScreen(urlInfo: item['link']))),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              color: Colors.grey[900],
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (imgUrl.isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: imgUrl, 
                                      httpHeaders: ScraperApi.imageHeaders, // USANDO HEADERS CORRETOS
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent, strokeWidth: 2)),
                                      errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)),
                                    ),
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(colors: [Colors.black, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter)
                                      ),
                                      child: Text(
                                        item['titulo'], 
                                        maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
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
    String? vUrl = await ScraperApi.extrairVideo(ep['url']!);
    if (vUrl != null) DownloadManager.startDownload(vUrl, "${detalhes!['titulo']} - ${ep['nome']}");
  }

  @override
  Widget build(BuildContext context) {
    if (detalhes == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));

    return Scaffold(
      appBar: AppBar(title: Text(detalhes!['titulo'], maxLines: 1)),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                if (detalhes!['poster'] != '')
                  Container(
                    width: double.infinity,
                    height: 280,
                    decoration: const BoxDecoration(color: Colors.black87),
                    child: CachedNetworkImage(
                      imageUrl: detalhes!['poster'], 
                      httpHeaders: ScraperApi.imageHeaders, // USANDO HEADERS CORRETOS
                      fit: BoxFit.contain, 
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.pinkAccent)),
                    ),
                  ),
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
          const WidgetFlutuanteDownload(),
        ],
      ),
    );
  }
}

// ==== TELA DO PLAYER ====
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
      const BetterPlayerConfiguration(autoPlay: true, fullScreenByDefault: false, allowedScreenSleep: false, fit: BoxFit.contain),
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
    return Scaffold(backgroundColor: Colors.black, body: SafeArea(child: BetterPlayer(controller: _c)));
  }
}

// ==== LEITOR DE MANGÁ PROFISSIONAL ====
class LeitorScreen extends StatefulWidget {
  final List<String> imagens;
  const LeitorScreen({Key? key, required this.imagens}) : super(key: key);

  @override
  _LeitorScreenState createState() => _LeitorScreenState();
}

class _LeitorScreenState extends State<LeitorScreen> {
  int paginaAtual = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Pág $paginaAtual / ${widget.imagens.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: widget.imagens.length,
            onPageChanged: (index) => setState(() => paginaAtual = index + 1),
            builder: (c, i) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(widget.imagens[i], headers: ScraperApi.imageHeaders), // USANDO HEADERS CORRETOS
              initialScale: PhotoViewComputedScale.contained, 
              minScale: PhotoViewComputedScale.contained, 
              maxScale: PhotoViewComputedScale.covered * 3,
            ),
            scrollPhysics: const BouncingScrollPhysics(), 
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                margin: const EdgeInsets.symmetric(horizontal: 50),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.swipe_left, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text("Deslize para o lado para ler", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// ==== TELAS EXTRAS ====
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
          if (!isD) return const Center(child: Text("Nenhum download ativo.", style: TextStyle(color: Colors.grey)));
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(DownloadManager.currentFile, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ValueListenableBuilder<double>(
                  valueListenable: DownloadManager.progress,
                  builder: (c, prog, child) => LinearProgressIndicator(value: prog, minHeight: 10, color: Colors.pinkAccent, backgroundColor: Colors.grey[800]),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () { DownloadManager.cancel(); Navigator.pop(context); },
                  icon: const Icon(Icons.cancel, color: Colors.white), label: const Text("Cancelar", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
