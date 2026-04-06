import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:better_player/better_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'scraper_api.dart';

void main() {
  runApp(const JinocaFlixApp());
}

class JinocaFlixApp extends StatelessWidget {
  const JinocaFlixApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JinocaFlix',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: Colors.pinkAccent,
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      ),
      home: const CatalogoScreen(),
    );
  }
}

// ==================== TELA INICIAL (CATÁLOGO) ====================
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({Key? key}) : super(key: key);

  @override
  _CatalogoScreenState createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  String tipoAtual = 'hentai';
  int pagina = 1;
  List<Map<String, dynamic>> itens = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados({bool limpar = true}) async {
    if (limpar) {
      setState(() { itens.clear(); pagina = 1; carregando = true; });
    } else {
      setState(() { carregando = true; });
    }
    
    var novosItens = await ScraperApi.obterLista(tipoAtual, pagina);
    setState(() {
      itens.addAll(novosItens);
      carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JinocaFlix', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () { tipoAtual = 'hentai'; _carregarDados(); },
            child: Text('Animes', style: TextStyle(color: tipoAtual == 'hentai' ? Colors.pinkAccent : Colors.white)),
          ),
          TextButton(
            onPressed: () { tipoAtual = 'manga'; _carregarDados(); },
            child: Text('Mangás', style: TextStyle(color: tipoAtual == 'manga' ? Colors.pinkAccent : Colors.white)),
          ),
        ],
      ),
      body: itens.isEmpty && carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 0.7, crossAxisSpacing: 8, mainAxisSpacing: 8,
              ),
              itemCount: itens.length + 1,
              itemBuilder: (context, index) {
                if (index == itens.length) {
                  return IconButton(
                    icon: const Icon(Icons.add_circle, size: 50, color: Colors.pinkAccent),
                    onPressed: () { pagina++; _carregarDados(limpar: false); },
                  );
                }
                var item = itens[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalhesScreen(urlInfo: item['link']))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item['imagem'],
                      httpHeaders: ScraperApi.headers,
                      fit: BoxFit.cover,
                      // Removido o const problemático daqui:
                      placeholder: (context, url) => Container(color: Colors.grey),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==================== TELA DE DETALHES ====================
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
    ScraperApi.obterDetalhes(widget.urlInfo).then((dados) {
      setState(() => detalhes = dados);
    });
  }

  void _abrirConteudo(Map<String, String> ep) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    if (ep['tipo'] == 'video') {
      String? videoUrl = await ScraperApi.extrairVideo(ep['url']!);
      Navigator.pop(context); // fecha loading
      if (videoUrl != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videoUrl: videoUrl, titulo: ep['nome']!)));
      }
    } else {
      List<String> imagens = await ScraperApi.extrairManga(ep['url']!);
      Navigator.pop(context); // fecha loading
      if (imagens.isNotEmpty) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => LeitorMangaScreen(imagens: imagens)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (detalhes == null) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.pinkAccent)));

    return Scaffold(
      appBar: AppBar(title: Text(detalhes!['titulo'])),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (detalhes!['poster'] != '')
              CachedNetworkImage(
                imageUrl: detalhes!['poster'],
                httpHeaders: ScraperApi.headers,
                height: 250, fit: BoxFit.cover, width: double.infinity,
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(detalhes!['sinopse'], style: const TextStyle(color: Colors.grey)),
            ),
            const Divider(color: Colors.white24),
            ...List.generate((detalhes!['episodios'] as List).length, (index) {
              var ep = detalhes!['episodios'][index];
              return ListTile(
                leading: const Icon(Icons.play_circle_fill, color: Colors.pinkAccent),
                title: Text(ep['nome']),
                onTap: () => _abrirConteudo(ep),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ==================== TELA DO PLAYER DE VÍDEO ====================
class PlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String titulo;
  const PlayerScreen({Key? key, required this.videoUrl, required this.titulo}) : super(key: key);

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network, widget.videoUrl,
      headers: ScraperApi.headers, // BURLA A PROTEÇÃO DO VÍDEO
    );
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(autoPlay: true, fullScreenByDefault: true),
      betterPlayerDataSource: dataSource,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.titulo)),
      body: Center(
        child: AspectRatio(aspectRatio: 16 / 9, child: BetterPlayer(controller: _controller)),
      ),
    );
  }
}

// ==================== TELA DO LEITOR DE MANGÁ ====================
class LeitorMangaScreen extends StatelessWidget {
  final List<String> imagens;
  const LeitorMangaScreen({Key? key, required this.imagens}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Lendo Capítulo')),
      body: PhotoViewGallery.builder(
        itemCount: imagens.length,
        builder: (context, index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(imagens[index], headers: ScraperApi.headers), // BURLA PROTEÇÃO DA IMAGEM
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
        scrollPhysics: const BouncingScrollPhysics(),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
