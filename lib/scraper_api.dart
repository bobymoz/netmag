import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';

class ScraperApi {
  static const String baseUrl = "https://www.muitohentai.com";
  
  static const Map<String, String> headers = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36",
    "Accept-Language": "pt-BR,pt;q=0.9",
    "Cookie": "ageVerified=true; lshentaipt=invalida;",
    "Referer": "https://www.muitohentai.com/"
  };

  static Future<List<Map<String, dynamic>>> obterLista(String tipo, int pagina) async {
    String url = tipo == 'manga' 
        ? "$baseUrl/mangas/${pagina > 1 ? '$pagina/' : ''}"
        : "$baseUrl/hentai/${pagina > 1 ? '$pagina/' : ''}";
        
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
            "imagem": imgTag.attributes['src'] ?? imgTag.attributes['data-src'] ?? '',
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
      var ogImg = document.querySelector('meta[property="og:image"]');
      if (ogImg != null) {
        poster = ogImg.attributes['content'] ?? '';
      } else {
        var posterImg = document.querySelector('.poster img');
        poster = posterImg?.attributes['data-src'] ?? posterImg?.attributes['src'] ?? '';
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
      RegExp exp = RegExp(r'(https?://[^\s"\'<>]+?\.(?:jpg|jpeg|png|webp))');
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
