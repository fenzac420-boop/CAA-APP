import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Word {
  final String label;
  final String? imageUrl;
  const Word(this.label, {this.imageUrl});
}

class ArasaacService {
  static Future<List<Word>> search(String text) async {
    if (text.trim().isEmpty) return [];
    final uri = Uri.parse(
      'https://api.arasaac.org/v1/pictograms/fr/search/${Uri.encodeComponent(text.trim())}',
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      if (data is! List) return [];
      return data.take(80).map<Word>((e) {
        final id = e['_id'] ?? e['id'];
        final folder = id.toString().length > 3
            ? id.toString().substring(0, id.toString().length - 3)
            : id.toString();
        return Word(
          e['keywords'] is List && (e['keywords'] as List).isNotEmpty
              ? (e['keywords'] as List).first.toString()
              : text,
          imageUrl: 'https://static.arasaac.org/pictograms/$folder/${id}_500.png',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}

class TtsService {
  final FlutterTts tts = FlutterTts();
  Future<void> speak(String text, {double rate = .45}) async {
    await tts.setLanguage('fr-FR');
    await tts.setSpeechRate(rate);
    await tts.speak(text);
  }
}

void main() => runApp(const CaaApp());

class CaaApp extends StatefulWidget {
  const CaaApp({super.key});
  @override State<CaaApp> createState() => _CaaAppState();
}

class _CaaAppState extends State<CaaApp> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CAA 1.0',
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData.dark(useMaterial3: true),
    home: HomeScreen(onDarkChanged: (v) => setState(() => dark = v)),
  );
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<bool> onDarkChanged;
  const HomeScreen({super.key, required this.onDarkChanged});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final tts = TtsService();
  final search = TextEditingController();
  final List<String> sentence = [];
  final Set<String> favorites = {};
  int selectedCategory = 0;
  int columns = 6;
  double speechRate = .45;
  bool editing = false;
  List<Word> remote = [];

  final categories = const [
    ('Accueil', Icons.home_rounded),
    ('Cœur', Icons.star_rounded),
    ('Personnes', Icons.people_rounded),
    ('Actions', Icons.directions_run_rounded),
    ('Nourriture', Icons.restaurant_rounded),
    ('Émotions', Icons.favorite_rounded),
    ('Lieux', Icons.place_rounded),
    ('Social', Icons.forum_rounded),
    ('Objets', Icons.category_rounded),
  ];

  final Map<String, List<String>> words = {
    'Accueil': ['Je','Tu','veux','pas','encore','fini','oui','non','aide','bonjour','merci','s’il te plaît'],
    'Cœur': ['je','veux','pas','encore','plus','fini','oui','non','aide','j’aime','je n’aime pas'],
    'Personnes': ['maman','papa','enfant','bébé','ami','professeur','médecin','famille','femme','homme'],
    'Actions': ['manger','boire','dormir','jouer','aller','venir','prendre','donner','ouvrir','fermer','attendre','regarder'],
    'Nourriture': ['eau','pain','lait','pomme','banane','repas','gâteau','yaourt','pâtes','riz','jus','chocolat'],
    'Émotions': ['content','triste','fâché','peur','fatigué','mal','calme','heureux','surpris','stressé'],
    'Lieux': ['maison','école','toilettes','chambre','parc','magasin','hôpital','restaurant','voiture'],
    'Social': ['bonjour','au revoir','merci','s’il te plaît','pardon','oui','non','viens','stop','encore'],
    'Objets': ['téléphone','livre','ballon','chaise','table','lit','ordinateur','clé','vêtement','jouet'],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      columns = p.getInt('columns') ?? 6;
      speechRate = p.getDouble('rate') ?? .45;
      favorites.addAll(p.getStringList('favorites') ?? []);
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('columns', columns);
    await p.setDouble('rate', speechRate);
    await p.setStringList('favorites', favorites.toList());
  }

  void addWord(String w) {
    setState(() => sentence.add(w));
  }

  Future<void> speakSentence() async {
    await tts.speak(sentence.join(' '), rate: speechRate);
  }

  Future<void> searchArasaac(String q) async {
    final result = await ArasaacService.search(q);
    if (mounted) setState(() => remote = result);
  }

  @override
  Widget build(BuildContext context) {
    final cat = categories[selectedCategory].$1;
    final base = words[cat] ?? [];
    final items = cat == 'Cœur' ? words['Accueil']! : base;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CAA 1.0', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => setState(() => editing = !editing),
            icon: Icon(editing ? Icons.check_rounded : Icons.edit_rounded),
            tooltip: 'Modifier'),
          IconButton(onPressed: () => _settings(), icon: const Icon(Icons.settings_rounded)),
        ],
      ),
      body: Column(
        children: [
          _sentenceBar(),
          _searchBar(),
          Expanded(
            child: Row(
              children: [
                _categoryRail(),
                Expanded(child: _grid(items)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sentenceBar() => Container(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
    child: Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 74),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: sentence.isEmpty
              ? const Align(alignment: Alignment.centerLeft, child: Text('Touchez des pictogrammes pour construire une phrase', style: TextStyle(fontSize: 17)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: sentence.map((w) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(label: Text(w, style: const TextStyle(fontSize: 16)),
                      onDeleted: () => setState(() => sentence.remove(w))),
                  )).toList()),
                ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: sentence.isEmpty ? null : speakSentence,
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('Dire'),
          style: FilledButton.styleFrom(minimumSize: const Size(105, 58)),
        ),
        const SizedBox(width: 5),
        IconButton(
          onPressed: sentence.isEmpty ? null : () => setState(() => sentence.clear()),
          icon: const Icon(Icons.backspace_rounded),
          tooltip: 'Effacer',
        )
      ],
    ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    child: TextField(
      controller: search,
      textInputAction: TextInputAction.search,
      onSubmitted: searchArasaac,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Rechercher dans ARASAAC…',
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => searchArasaac(search.text),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  Widget _categoryRail() => SizedBox(
    width: 112,
    child: ListView.builder(
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final c = categories[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() { selectedCategory = i; remote = []; }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: i == selectedCategory ? Theme.of(context).colorScheme.primaryContainer : null,
              ),
              child: Column(children: [
                Icon(c.$2, size: 28),
                const SizedBox(height: 4),
                Text(c.$1, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        );
      },
    ),
  );

  Widget _grid(List<String> items) {
    final arasaac = remote;
    if (arasaac.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns.clamp(3, 10),
          crossAxisSpacing: 7, mainAxisSpacing: 7,
          childAspectRatio: .92,
        ),
        itemCount: arasaac.length,
        itemBuilder: (_, i) => _tile(arasaac[i].label, imageUrl: arasaac[i].imageUrl),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns.clamp(3, 10),
        crossAxisSpacing: 7, mainAxisSpacing: 7,
        childAspectRatio: .92,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _tile(items[i]),
    );
  }

  Widget _tile(String label, {String? imageUrl}) {
    final fav = favorites.contains(label);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => addWord(label),
        onLongPress: () => tts.speak(label, rate: speechRate),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 22),
                child: imageUrl == null
                  ? _emojiFor(label)
                  : Image.network(imageUrl, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _emojiFor(label)),
              ),
            ),
            Align(alignment: Alignment.bottomCenter,
              child: Padding(padding: const EdgeInsets.all(4),
                child: Text(label, textAlign: TextAlign.center, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)))),
            if (fav) const Positioned(top: 3, right: 3, child: Icon(Icons.star_rounded, size: 19)),
            if (editing) Positioned(top: 2, left: 2, child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                setState(() => fav ? favorites.remove(label) : favorites.add(label));
                await _save();
              },
              icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded),
            )),
          ],
        ),
      ),
    );
  }

  Widget _emojiFor(String w) {
    final e = {
      'manger':'🍽️','boire':'🥤','dormir':'😴','aide':'🆘','oui':'👍','non':'👎',
      'bonjour':'👋','merci':'🙏','maison':'🏠','école':'🏫','toilettes':'🚻',
      'content':'😀','triste':'😢','fâché':'😠','peur':'😨','fatigué':'😴',
      'eau':'💧','pomme':'🍎','pain':'🍞','maman':'👩','papa':'👨',
    }[w.toLowerCase()] ?? '🖼️';
    return FittedBox(child: Text(e, style: const TextStyle(fontSize: 52)));
  }

  Future<void> _settings() async {
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (context, setSheet) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Réglages CAA 1.0', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(children: [
            const Expanded(child: Text('Colonnes de pictogrammes')),
            DropdownButton<int>(value: columns, items: [4,5,6,7,8,9,10].map((n) => DropdownMenuItem(value:n, child:Text('$n'))).toList(),
              onChanged: (v) { if(v!=null){ setState(()=>columns=v); setSheet(()=>{}); _save(); }}),
          ]),
          Row(children: [
            const Expanded(child: Text('Vitesse de parole')),
            Expanded(child: Slider(value: speechRate, min:.25, max:.7, onChanged:(v){setState(()=>speechRate=v);setSheet(()=>{});}, onChangeEnd:(_)=>_save())),
          ]),
          SwitchListTile(
            title: const Text('Mode sombre'),
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (v) { widget.onDarkChanged(v); setSheet(()=>{}); },
          ),
          const SizedBox(height: 10),
        ]),
      )),
    );
  }
}
