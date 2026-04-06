import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class ScraperApi {
  static const String baseUrl = "https://www.muitohentai.com";
  
  // Headers originais copiados do seu Python
  static const Map<String, String> headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "pt-BR,pt;q=0.7",
    "Cookie": "ageVerified=true; lshentaipt=invalida;",
    "Referer": "https://www.muitohentai.com/"
  };

  // Headers específicos para imagens (Simula o seu img_proxy)
  static const Map<String, String> imageHeaders = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    "Cookie": "ageVerified=true; lshentaipt=invalida;",
    "Referer": "https://www.muitohentai.com/"
  };

  // Função que dribla o Lazy Loading buscando a imagem real
  static String _extrairImagemReal(var tag) {
    if (tag == null) return '';
    List<String> atributos = ['data-src', 'data-lazy-src', 'src'];
    for (String attr in atributos) {
      String? val = tag.attributes[attr];
      if (val != null && val.trim().isNotEmpty && !val.startsWith('data:image')) {
        if (val.startsWith('//')) return 'https:$val';
        if (val.startsWith('/')) return '$baseUrl$val';
        return val.trim();
      }
    }
    return '';
  }

  static Future<List<Map<String, dynamic>>> obterLista(String tipo, int pagina, {String busca = ""}) async {
    String url;
    if (busca.isNotEmpty) {
      String query = Uri.encodeComponent(busca);
      url = "$baseUrl/buscar/$query/${pagina > 1 ? '$pagina/' : ''}";
    } else {
      // Nova lógica com a categoria Sem Censura
      if (tipo == 'manga') {
        url = "$baseUrl/mangas/${pagina > 1 ? '$pagina/' : ''}";
      } else if (tipo == 'sem_censura') {
        url = "$baseUrl/genero/hentai-sem-censura/${pagina > 1 ? '$pagina/' : ''}";
      } else {
        url = "$baseUrl/hentai/${pagina > 1 ? '$pagina/' : ''}";
      }
    }
        
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      var document = parser.parse(response.body);
      var artigos = document.querySelectorAll('article.item');
      
      List<Map<String, dynamic>> lista = [];
      for (var art in artigos) {
        var aTag = art.querySelector('a');
        var imgTag = art.querySelector('img');
        var h3Tag = art.querySelector('h3');
        
        if (aTag != null && imgTag != null && h3Tag != null) {
          String link = aTag.attributes['href'] ?? '';
          if (!link.startsWith('http')) link = "$baseUrl$link";
          
          lista.add({
            "titulo": h3Tag.text.trim(),
            "imagem": _extrairImagemReal(imgTag),
            "link": link
          });
        }
      }
      return lista;
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> obterDetalhes(String urlInfo) async {
    try {
      final response = await http.get(Uri.parse(urlInfo), headers: headers);
      var document = parser.parse(response.body);
      String htmlPuro = response.body;

      String titulo = document.querySelector('h1')?.text.trim() ?? "Sem Título";
      
      String poster = "";
      // Tenta Meta Tag primeiro (como no seu Python)
      RegExp expMetaImg = RegExp(r'<meta property="og:image" content="(.*?)"');
      var matchMeta = expMetaImg.firstMatch(htmlPuro);
      if (matchMeta != null) {
        poster = matchMeta.group(1)!;
      } else {
        poster = _extrairImagemReal(document.querySelector('.poster img'));
      }
      if (poster.isNotEmpty && !poster.startsWith('http')) poster = "$baseUrl$poster";

      String sinopse = "Sinopse não disponível.";
      RegExp expMetaDesc = RegExp(r'<meta property="og:description" content="(.*?)"');
      var matchDesc = expMetaDesc.firstMatch(htmlPuro);
      if (matchDesc != null) {
        sinopse = matchDesc.group(1)!;
      } else {
        var sinopseDiv = document.querySelector('.wp-content');
        if (sinopseDiv != null) sinopse = sinopseDiv.text.trim();
      }

      List<Map<String, String>> episodios = [];
      for (var a in document.querySelectorAll('a')) {
        String href = a.attributes['href'] ?? '';
        if (href.contains('/episodios/') || href.contains('/capitulo-')) {
          String linkEp = href.startsWith('http') ? href : "$baseUrl$href";
          String nome = a.querySelector('span.c')?.text.trim() ?? a.text.trim();
          if (nome.length <= 2) nome = "Cap/Ep";
          
          if (!episodios.any((ep) => ep['url'] == linkEp)) {
            episodios.add({
              "nome": nome, 
              "url": linkEp,
              "tipo": href.contains('/episodios/') ? "video" : "manga"
            });
          }
        }
      }
      return {
        "titulo": titulo,
        "poster": poster,
        "sinopse": sinopse,
        "episodios": episodios.reversed.toList()
      };
    } catch (e) {
      return {};
    }
  }

  static Future<String?> extrairVideo(String urlEp) async {
    try {
      var respEp = await http.get(Uri.parse(urlEp), headers: headers);
      var docEp = parser.parse(respEp.body);
      
      String? playerUrl;
      for (var iframe in docEp.querySelectorAll('iframe')) {
        String src = iframe.attributes['src'] ?? '';
        if (src.contains('/players/p2/')) {
          playerUrl = src.startsWith('http') ? src : "$baseUrl$src";
          break;
        }
      }
      if (playerUrl == null) return null;

      var playerHeaders = Map<String, String>.from(headers);
      playerHeaders['Referer'] = urlEp;
      
      var respPlayer = await http.get(Uri.parse(playerUrl), headers: playerHeaders);
      RegExp exp = RegExp(r'src="(.*?p2\.php\?id=.*?)"');
      var match = exp.firstMatch(respPlayer.body);
      
      if (match != null) {
        String vid = match.group(1)!;
        return vid.startsWith('http') ? vid : "$baseUrl/players/p2/$vid";
      }
    } catch (e) {}
    return null;
  }

  static Future<List<String>> extrairManga(String urlCap) async {
    try {
      var resp = await http.get(Uri.parse(urlCap), headers: headers);
      // REGEX BLINDADA COM ASPAS TRIPLAS PARA O DART NÃO RECLAMAR DO SINAL DE MENOR/MAIOR
      RegExp exp = RegExp(r'''(https?://[^\s"'<>]+?\.(?:jpg|jpeg|png|webp)(?:\?[^\s"'<>]*)?)''', caseSensitive: false);
      var matches = exp.allMatches(resp.body);
      
      List<String> imgs = [];
      for (var m in matches) {
        String src = m.group(1)!.replaceAll('\\', '');
        if (!src.toLowerCase().contains("logo") && !src.toLowerCase().contains("icon") && !src.toLowerCase().contains("avatar") && !src.toLowerCase().contains("banner")) {
          if (!imgs.contains(src)) {
            imgs.add(src);
          }
        }
      }
      return imgs;
    } catch (e) {
      return [];
    }
  }
}
