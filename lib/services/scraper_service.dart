import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';

class ScraperService {
  static const String baseUrl = "https://www.muitohentai.com";
  
  // Headers mágicos para fingir que somos um navegador mobile legítimo
  static const Map<String, String> headers = {
    "User-Agent": "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36",
    "Accept-Language": "pt-BR,pt;q=0.9",
    "Cookie": "ageVerified=true; lshentaipt=invalida;",
    "Referer": "https://www.muitohentai.com/"
  };

  // 1. PEGAR O CATÁLOGO (Substitui a home do clone da Netflix)
  static Future<List<Map<String, dynamic>>> obterLista({int pagina = 1}) async {
    final url = Uri.parse(pagina > 1 ? "$baseUrl/hentai/$pagina/" : "$baseUrl/hentai/");
    
    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        var document = html_parser.parse(response.body);
        var artigos = document.querySelectorAll('article.item.tvshows');
        List<Map<String, dynamic>> resultados = [];

        for (var artigo in artigos) {
          var aTag = artigo.querySelector('a');
          var imgTag = artigo.querySelector('img');
          var h3Tag = artigo.querySelector('h3');

          if (aTag != null && imgTag != null && h3Tag != null) {
            String link = aTag.attributes['href'] ?? '';
            if (!link.startsWith('http')) link = "$baseUrl$link";

            resultados.add({
              "titulo": h3Tag.text.trim(),
              "imagem": imgTag.attributes['src'] ?? '',
              "link": link
            });
          }
        }
        return resultados;
      }
    } catch (e) {
      print("Erro ao obter lista: $e");
    }
    return [];
  }

  // 2. PEGAR EPISÓDIOS (Quando clica no card)
  static Future<List<Map<String, String>>> obterEpisodios(String urlInfo) async {
    try {
      final response = await http.get(Uri.parse(urlInfo), headers: headers);
      if (response.statusCode == 200) {
        var document = html_parser.parse(response.body);
        List<Map<String, String>> episodios = [];
        
        var links = document.querySelectorAll('a');
        for (var a in links) {
          String href = a.attributes['href'] ?? '';
          if (href.contains('/episodios/')) {
            String linkCompleto = href.startsWith('http') ? href : "$baseUrl$href";
            
            var spanC = a.querySelector('span.c');
            String nome = spanC != null ? spanC.text.trim() : a.text.trim();
            
            // Evita duplicatas
            if (!episodios.any((ep) => ep['url'] == linkCompleto)) {
               episodios.add({"nome": nome, "url": linkCompleto});
            }
          }
        }
        return episodios.reversed.toList(); // Ordem 1, 2, 3...
      }
    } catch (e) {
      print("Erro ao obter episódios: $e");
    }
    return [];
  }

  // 3. A MÁGICA: EXTRAIR O .MP4 DO PLAYER
  static Future<String?> extrairVideo(String urlEpisodio) async {
    try {
      // Entra no episódio
      var respEp = await http.get(Uri.parse(urlEpisodio), headers: headers);
      var docEp = html_parser.parse(respEp.body);
      
      String? playerUrl;
      for (var iframe in docEp.querySelectorAll('iframe')) {
        String src = iframe.attributes['src'] ?? '';
        if (src.contains('/players/p2/')) {
          playerUrl = src.startsWith('http') ? src : "$baseUrl$src";
          break;
        }
      }

      if (playerUrl == null) return null;

      // Entra no iframe disfarçado (Mandando o Referer correto)
      var iframeHeaders = Map<String, String>.from(headers);
      iframeHeaders['Referer'] = urlEpisodio;
      
      var respPlayer = await http.get(Uri.parse(playerUrl), headers: iframeHeaders);
      
      // Regex para achar o p2.php ou .mp4
      RegExp exp = RegExp(r'src="(.*?p2\.php\?id=.*?)"');
      var match = exp.firstMatch(respPlayer.body);
      
      if (match != null) {
        String videoLink = match.group(1)!;
        if (!videoLink.startsWith('http')) {
          videoLink = "$baseUrl/players/p2/$videoLink";
        }
        return videoLink; // ESTE É O LINK FINAL DO VÍDEO!
      }
    } catch (e) {
      print("Erro ao extrair vídeo: $e");
    }
    return null;
  }
}
