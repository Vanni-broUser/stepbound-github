import 'package:stepbound/core/core.dart';

/// Everything the game tells about one zombie type, in one place, so that
/// a new type cannot be half introduced. The first time one is met the
/// tutorial director's `introduceZombie` does all of it together:
///
/// 1. records the type in `Progress.knownZombies`, which a save keeps and
///    the book on the train reads (its card stops being "???");
/// 2. frames the zombie together with Mario;
/// 3. shows [lesson] with [portrait] over the text box, and gives the
///    camera back to Mario once it is dismissed.
///
/// [introducedOnSight] types get that the moment one is first on screen,
/// anywhere in the game. The others have a scene of their own, told by the
/// script of their place: the wanderer on the first street when it spots
/// Mario, the carabiniere in the barracks when one becomes aware of him.
final class ZombieLore {
  const ZombieLore({
    required this.name,
    required this.portrait,
    required this.lesson,
    required this.description,
    this.introducedOnSight = false,
  });

  /// Its name in the book.
  final String name;

  /// Shown over its lesson and on its card in the book.
  final String portrait;

  /// The line shown the first time it is met.
  final String lesson;

  /// Its card in the book.
  final String description;

  final bool introducedOnSight;
}

/// The zombie types the game has, in the order the book lists them.
const Map<EntityKind, ZombieLore> zombieLore = <EntityKind, ZombieLore>{
  EntityKind.wanderer: ZombieLore(
    name: 'Vagante',
    portrait: 'assets/story/portrait_wanderer.png',
    lesson:
        'I normali zombi vaganti faranno un passo verso di te ogni due passi '
        'tuoi',
    description:
        'Il più comune: fino a poco fa era una persona qualunque. Lento e '
        'goffo, fa un passo ogni due dei tuoi. Da solo si evita, in gruppo '
        'ti chiude la strada.',
  ),
  EntityKind.carabiniere: ZombieLore(
    name: 'Carabiniere',
    portrait: 'assets/story/portrait_carabiniere.png',
    lesson:
        'Gli zombi carabinieri possono raggiungerti a due celle di distanza '
        'grazie al loro manganello',
    description:
        'Porta ancora la divisa e stringe il manganello: ti colpisce fino a '
        'due celle di distanza. Si muove come un vagante, ma non lasciarlo '
        'avvicinare.',
  ),
  EntityKind.sprinter: ZombieLore(
    name: 'Veloce',
    portrait: 'assets/story/portrait_sprinter.png',
    lesson: 'Gli zombi veloci si muovono alla tua stessa velocità',
    description:
        'Si muove alla tua stessa velocità: correndo non lo semini. Ti vede '
        'e ti sente da più lontano degli altri.',
    introducedOnSight: true,
  ),
  EntityKind.mutilated: ZombieLore(
    name: 'Mutilato',
    portrait: 'assets/story/portrait_mutilated.png',
    lesson:
        'Gli zombi mutilati non possono inseguirti, ma se passi loro accanto '
        'ti mordono a ogni tuo passo. Giragli alla larga, o abbattili se ti '
        'sbarrano la strada',
    description:
        'Ha perso le gambe e non si rialza più da dove è caduto. Non ti '
        'insegue, ma è sveglio quanto un veloce: passagli accanto e ti morde '
        'a ogni passo. Tienilo a due celle di distanza, o sparagli se ti '
        'chiude il passaggio.',
    introducedOnSight: true,
  ),
  EntityKind.burning: ZombieLore(
    name: 'In fiamme',
    portrait: 'assets/story/portrait_burning.png',
    lesson:
        'Gli zombi in fiamme si muovono come i vaganti, ma ogni cella che '
        'lasciano prende fuoco e non potrai più attraversarla',
    description:
        'Brucia senza consumarsi. Lento come un vagante, ma ogni cella da '
        'cui si sposta resta in fiamme per sempre: nessuno ci passa più, '
        'nemmeno lui. Abbattilo prima che ti chiuda la strada del ritorno.',
    introducedOnSight: true,
  ),
  EntityKind.drunk: ZombieLore(
    name: 'Ubriaco',
    portrait: 'assets/story/portrait_drunk.png',
    lesson:
        'Gli zombi ubriachi barcollano a caso e non ti inseguono, ma se gli '
        'capiti accanto ti mordono. Occhio: la prossima barcollata può '
        'portarlo proprio da te',
    description:
        'Era già ubriaco quando è cambiato, e lo è ancora. Barcolla di '
        'continuo in una direzione a caso, al passo di un vagante, che ti '
        'abbia visto o no. Non ti insegue, ma se gli finisci accanto il morso '
        'arriva dritto.',
    introducedOnSight: true,
  ),
  EntityKind.cultist: ZombieLore(
    name: 'Cultista',
    portrait: 'assets/story/portrait_zombie_cultist.png',
    lesson:
        'Gli zombi cultisti si muovono come i vaganti, ma la loro massa '
        'muscolare richiede tre colpi di pistola per abbatterli',
    description:
        'La mutazione ha gonfiato il corpo oltre la tunica: il cappuccio è '
        'caduto sulle spalle, le vesti si sono strappate e vene gialle '
        'innaturali attraversano le braccia. Avanza al passo di un vagante, '
        'ma i primi due colpi non bastano: ne servono tre per abbatterlo.',
    introducedOnSight: true,
  ),
};
