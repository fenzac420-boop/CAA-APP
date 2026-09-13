import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MaVoixApp(prefs: prefs));
}

class Word {
  final String id, label, search, category;
  final int? slot;
  final String? imageUrl;
  Word({required this.id, required this.label, required this.search, required this.category, this.slot, this.imageUrl});
  factory Word.fromJson(Map<String,dynamic> j) => Word(
    id: '${j['id']}', label: '${j['label']}', search: '${j['search'] ?? j['label']}',
    category: '${j['category'] ?? 'Autre'}', slot: j['slot'] as int?,
    imageUrl: j['imageUrl'] as String?
  );
}

class ArasaacService {
  Future<List<Word>> search(String q) async {
    if (q.trim().isEmpty) return [];
    final uri = Uri.parse('https://api.arasaac.org/v1/pictograms/fr/search/${Uri.encodeComponent(q.trim())}');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return [];
      final data = jsonDecode(r.body);
      if (data is! List) return [];
      return data.take(48).map((x) {
        final id = int.tryParse('${x['_id'] ?? x['id']}') ?? 0;
        final folder = (id ~/ 1000).toString();
        return Word(
          id: '$id', label: '${x['keywords'] is List && (x['keywords'] as List).isNotEmpty ? x['keywords'][0] : q}',
          search: q, category: 'Recherche',
          imageUrl: 'https://static.arasaac.org/pictograms/$folder/${id}_500.png'
        );
      }).toList();
    } catch (_) { return []; }
  }
}

class TtsService {
  final FlutterTts tts = FlutterTts();
  Future speak(String text, double rate) async {
    await tts.setLanguage('fr-FR');
    await tts.setSpeechRate(rate);
    await tts.setVolume(1);
    await tts.speak(text);
  }
}

class MaVoixApp extends StatefulWidget {
  final SharedPreferences prefs;
  const MaVoixApp({super.key, required this.prefs});
  @override State<MaVoixApp> createState() => _MaVoixAppState();
}
class _MaVoixAppState extends State<MaVoixApp> {
  int columns = 6;
  double speechRate = .48;
  bool dark = false;
  @override void initState() {
    super.initState();
    columns = widget.prefs.getInt('columns') ?? 6;
    speechRate = widget.prefs.getDouble('rate') ?? .48;
    dark = widget.prefs.getBool('dark') ?? false;
  }
  void save() {
    widget.prefs.setInt('columns', columns);
    widget.prefs.setDouble('rate', speechRate);
    widget.prefs.setBool('dark', dark);
  }
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'CAA 1.0',
    theme: ThemeData(useMaterial3:true, colorSchemeSeed: Colors.indigo, brightness: Brightness.light),
    darkTheme: ThemeData(useMaterial3:true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: HomeScreen(
      columns: columns, speechRate: speechRate,
      onSettings:(c,r,d){setState((){columns=c;speechRate=r;dark=d;});save();}
    )
  );
}

class HomeScreen extends StatefulWidget {
  final int columns; final double speechRate;
  final void Function(int,double,bool) onSettings;
  const HomeScreen({super.key, required this.columns, required this.speechRate, required this.onSettings});
  @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  final api=ArasaacService(), tts=TtsService();
  final searchCtrl=TextEditingController();
  final List<String> categories=['Cœur','Personnes','Actions','Nourriture','Émotions','Lieux','Social'];
  String category='Cœur';
  List<Word> results=[];
  List<Word> sentence=[];
  final favorites=<String>{};
  bool editing=false;
  final Map<String, List<Word>> categoryCache={};

  final core=[
    Word(id:'je',label:'Je',search:'je',category:'Cœur',slot:0),
    Word(id:'tu',label:'Tu',search:'tu',category:'Cœur',slot:1),
    Word(id:'veux',label:'veux',search:'vouloir',category:'Actions',slot:2),
    Word(id:'pas',label:'pas',search:'pas',category:'Cœur',slot:3),
    Word(id:'encore',label:'encore',search:'encore',category:'Cœur',slot:4),
    Word(id:'fini',label:'fini',search:'fini',category:'Émotions',slot:5),
    Word(id:'oui',label:'oui',search:'oui',category:'Cœur',slot:6),
    Word(id:'non',label:'non',search:'non',category:'Cœur',slot:7),
    Word(id:'aide',label:'aide',search:'aide',category:'Actions',slot:8),
    Word(id:'manger',label:'manger',search:'manger',category:'Actions',slot:9),
    Word(id:'boire',label:'boire',search:'boire',category:'Actions',slot:10),
    Word(id:'toilettes',label:'toilettes',search:'toilettes',category:'Lieux',slot:11),
  ];

  void add(Word w){setState(()=>sentence.add(w));}
  void removeLast(){if(sentence.isNotEmpty)setState(()=>sentence.removeLast());}
  Future speak(){return tts.speak(sentence.map((e)=>e.label).join(' '),widget.speechRate);}
  Future search(String q) async {
    if(q.trim().isEmpty){setState(()=>results=[]);return;}
    final r=await api.search(q);
    setState(()=>results=r);
  }

  List<Word> wordsForCategory(){
    if(category=='Cœur') return core;
    return core.where((w)=>w.category==category).toList();
  }

  void createPicto(){
    final label=TextEditingController();
    final symbol=TextEditingController(text:'⭐');
    showDialog(context:context,builder:(_)=>AlertDialog(
      title:const Text('Créer un pictogramme'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:label,decoration:const InputDecoration(labelText:'Nom du pictogramme')),
        TextField(controller:symbol,decoration:const InputDecoration(labelText:'Symbole / emoji')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),
        FilledButton(onPressed:(){
          if(label.text.trim().isNotEmpty){
            final w=Word(id:'custom_${DateTime.now().millisecondsSinceEpoch}',label:label.text.trim(),search:label.text.trim(),category:category);
            setState(()=>categoryCache.putIfAbsent('Mes pictos',()=>[]).add(w));
          }
          Navigator.pop(context);
        },child:const Text('Ajouter'))
      ],
    ));
  }

  @override Widget build(BuildContext context){
    final isDesktop=MediaQuery.of(context).size.width>800;
    final base=searchCtrl.text.isEmpty?wordsForCategory():results;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAA 1.0',style:TextStyle(fontWeight:FontWeight.w800)),
        actions:[
          IconButton(tooltip:'Créer un pictogramme',onPressed:createPicto,icon:const Icon(Icons.add_photo_alternate_outlined)),
          IconButton(tooltip:'Édition',onPressed:()=>setState(()=>editing=!editing),icon:Icon(editing?Icons.check:Icons.edit_outlined)),
          IconButton(tooltip:'Réglages',onPressed:()=>showSettings(context),icon:const Icon(Icons.settings_outlined)),
        ],
      ),
      body: Column(children:[
        _sentenceBar(),
        _searchBar(),
        SizedBox(height:54,child:ListView.separated(
          padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
          scrollDirection:Axis.horizontal,itemCount:categories.length,
          separatorBuilder:(_,__)=>const SizedBox(width:7),
          itemBuilder:(_,i){final c=categories[i];return ChoiceChip(label:Text(c),selected:category==c,onSelected:(_){setState((){category=c;searchCtrl.clear();results=[];});});}
        )),
        Expanded(child:GridView.builder(
          padding:const EdgeInsets.fromLTRB(10,4,10,20),
          gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:isDesktop?widget.columns:((widget.columns).clamp(3,6)),
            crossAxisSpacing:9,mainAxisSpacing:9,childAspectRatio:.88),
          itemCount:base.length,
          itemBuilder:(_,i)=>_picto(base[i])
        ))
      ])
    );
  }

  Widget _sentenceBar()=>Container(
    margin:const EdgeInsets.fromLTRB(10,8,10,4),padding:const EdgeInsets.all(8),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant),color:Theme.of(context).colorScheme.surfaceContainerHighest),
    child:Row(children:[
      Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        if(sentence.isEmpty) const Padding(padding:EdgeInsets.all(10),child:Text('Touchez des pictogrammes pour construire une phrase')),
        ...sentence.map((w)=>Padding(padding:const EdgeInsets.only(right:5),child:Chip(label:Text(w.label))))
      ]))),
      IconButton(onPressed:removeLast,icon:const Icon(Icons.backspace_outlined)),
      FilledButton.icon(onPressed:sentence.isEmpty?null:speak,icon:const Icon(Icons.volume_up),label:const Text('Parler'))
    ])
  );

  Widget _searchBar()=>Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),child:TextField(
    controller:searchCtrl,onChanged:search,
    decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Rechercher un pictogramme…',suffixIcon:searchCtrl.text.isEmpty?null:IconButton(onPressed:(){searchCtrl.clear();setState(()=>results=[]);},icon:const Icon(Icons.clear)),filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))
  ));

  Widget _picto(Word w){
    return InkWell(onTap:()=>add(w),onLongPress:()=>setState(()=>favorites.add(w.id)),borderRadius:BorderRadius.circular(18),child:Container(
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),border:Border.all(color:Theme.of(context).colorScheme.outlineVariant),color:Theme.of(context).colorScheme.surface),
      child:Stack(children:[
        Center(child:Padding(padding:const EdgeInsets.fromLTRB(6,7,6,30),child:w.imageUrl!=null?Image.network(w.imageUrl!,fit:BoxFit.contain,errorBuilder:(_,__,___)=>_fallback(w)): _fallback(w))),
        Positioned(left:5,right:5,bottom:5,child:Text(w.label,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700))),
        if(favorites.contains(w.id)) const Positioned(right:5,top:5,child:Icon(Icons.star,size:18))
      ])
    ));
  }

  Widget _fallback(Word w)=>Container(
    alignment:Alignment.center,
    child:Text(_emoji(w.label),style:const TextStyle(fontSize:42))
  );
  String _emoji(String s){
    final x=s.toLowerCase();
    if(x.contains('manger'))return '🍽️'; if(x.contains('boire'))return '🥤'; if(x.contains('toilet'))return '🚻';
    if(x.contains('aide'))return '🆘'; if(x.contains('oui'))return '👍'; if(x.contains('non'))return '👎';
    if(x.contains('cœur')||x.contains('je'))return '❤️'; if(x.contains('fini'))return '✅'; if(x.contains('encore'))return '🔁';
    return '💬';
  }

  void showSettings(BuildContext context){
    int c=widget.columns; double r=widget.speechRate; bool d=Theme.of(context).brightness==Brightness.dark;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(
      title:const Text('Réglages'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('Colonnes : $c'),Slider(min:3,max:8,divisions:5,value:c.toDouble(),onChanged:(v)=>setD(()=>c=v.round())),
        Text('Vitesse de parole : ${r.toStringAsFixed(2)}'),Slider(min:.25,max:.7,value:r,onChanged:(v)=>setD(()=>r=v)),
        SwitchListTile(value:d,onChanged:(v)=>setD(()=>d=v),title:const Text('Mode sombre')),
        const Divider(),const Text('Accès : tactile, souris et clavier',style:TextStyle(fontSize:13))
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Annuler')),FilledButton(onPressed:(){widget.onSettings(c,r,d);Navigator.pop(context);},child:const Text('Enregistrer'))]
    )));
  }
}
