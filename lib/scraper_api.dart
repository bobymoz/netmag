import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class ScraperApi {
  static const String baseUrl = "https://www.muitohentai.com";
  
  // Headers para HTML (Com Cookie de maior de 18)
  static const Map<String, String> headers = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36",
    "Accept-Language": "pt-BR,pt;q=0.9",
    "Cookie": "ageVerified=true; lshentaipt=invalida;",
    "Referer": "https://www.muitohentai.com/"
  };

  // Headers limpos APENAS para imagens (Para o Cloudflare não bloquear)
  static const Map<String, String> imageHeaders = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36",
    "Referer": "https://www.muitohentai.com/"
  };

  // Função inteligente que foge do pixel transparente (Lazy Load)
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
      url = tipo == 'manga' 
          ? "$baseUrl/mangas/${pagina > 1 ? '$pagina/' : ''}"
          : "$baseUrl/hentai/${pagina > 1 ? '$pagina/' : ''}";
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

      String titulo = document.querySelector('h1')?.text.trim() ?? "Sem Título";
      
      String poster = "";
      var ogImg = document.querySelector('meta[property="og:image"]');
      if (ogImg != null && ogImg.attributes['content'] != null) {
        poster = ogImg.attributes['content']!;
      } else {
        poster = _extrairImagemReal(document.querySelector('.poster img'));
      }
      if (poster.isNotEmpty && !poster.startsWith('http')) poster = "$baseUrl$poster";

      String sinopse = document.querySelector('.wp-content')?.text.trim() ?? "Sinopse indisponível.";

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
      RegExp exp = RegExp(r'''(https?://[^\s"'<>]+?\.(?:jpg|jpeg|png|webp))''', caseSensitive: false);
      var matches = exp.allMatches(resp.body);
      
      List<String> imgs = [];
      for (var m in matches) {
        String src = m.group(1)!.replaceAll('\\', '');
        if (!src.toLowerCase().contains("logo") && !src.toLowerCase().contains("icon") && !imgs.contains(src)) {
          imgs.add(src);
        }
      }
      return imgs;
    } catch (e) {
      return [];
    }
  }
}
