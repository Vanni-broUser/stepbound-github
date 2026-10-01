// The original words of the game. Every other language translates this
// file: see lib/l10n/language.dart.
// ignore_for_file: lines_longer_than_80_chars

import 'package:stepbound/core/core.dart';
import 'package:stepbound/l10n/strings.dart';

final class ItalianStrings implements Strings {
  const ItalianStrings();

  // Shared by many screens
  @override
  String get back => 'INDIETRO';
  @override
  String get no => 'NO';
  @override
  String get ok => 'OK';
  @override
  String get shareReport => 'CONDIVIDI IL RAPPORTO';
  @override
  String get continueLabel => 'CONTINUA';
  @override
  String get tapToContinue => 'Tocca per continuare';
  @override
  String date(DateTime time) =>
      '${_two(time.day)}/${_two(time.month)}/${time.year} ${_two(time.hour)}:${_two(time.minute)}';

  // Main menu
  @override
  String get menuDisclaimer =>
      'Ogni riferimento a persone esistenti o a fatti realmente accaduti è puramente casuale';
  @override
  String get menuNewGame => 'NUOVA PARTITA';
  @override
  String get menuLoadGame => 'CARICA PARTITA';
  @override
  String get menuAudioOn => 'AUDIO: SÌ';
  @override
  String get menuAudioOff => 'AUDIO: NO';
  @override
  String get menuLanguage => 'Lingua';
  @override
  String get menuCredits => 'CREDITI';
  @override
  String get settingsTitle => 'IMPOSTAZIONI';
  @override
  String settingsLanguage(String language) => 'LINGUA: $language';
  @override
  String settingsSendData({required bool on}) =>
      'INVIO DATI ANONIMI: ${on ? 'SÌ' : 'NO'}';
  @override
  String get menuChooseNewSlot => 'SCEGLI DOVE SALVARE';
  @override
  String get menuChooseSave => 'SCEGLI UN SALVATAGGIO';
  @override
  String menuOverwrite(int slot) =>
      'SOVRASCRIVERE LO SLOT $slot?\nTOCCA ANCORA PER CONFERMARE';
  @override
  String get menuSlotEmpty => 'vuoto';
  @override
  String get menuSlotDamaged => 'danneggiato, non si può caricare';
  @override
  String get menuSlotBackup => '(riserva)';
  @override
  String get menuSlotSuspended => '(in sospeso)';
  @override
  String get menuGift => 'REGALO';
  @override
  String menuSkin(String name) => 'Skin $name';
  @override
  String get menuLinkExpired => 'LINK SCADUTO';
  @override
  String get menuLinkInvalid => 'O NON VALIDO';
  @override
  String get creditsMusic => 'MUSICA';
  @override
  String get creditsAttribution => 'Con attribuzione';
  @override
  String get creditsEffects =>
      'Effetti sonori: Kenney.nl e OpenGameArt.org (CC0)';

  // Pause menu and game over
  @override
  String get restartLevel => 'RICOMINCIA IL LIVELLO';
  @override
  String get yesRestart => 'SÌ, RICOMINCIA';
  @override
  String get resumeCampfire => 'RIPRENDI DAL FALÒ';
  @override
  String get resumeCampfireConfirm => 'SÌ, TORNA AL FALÒ';
  @override
  String get resumeCampfireCost =>
      'Tornare all’ultimo falò? Quello che hai fatto da lì in poi va perso.';
  @override
  String get resumeTrain => 'RIPRENDI DAL TRENO';
  @override
  String get resumeTrainConfirm => 'SÌ, TORNA AL TRENO';
  @override
  String get resumeTrainCost =>
      'Tornare al treno? Quello che hai fatto da lì in poi va perso.';
  @override
  String get quitSinceCampfireCost =>
      'Uscire al menù principale? Quello che hai fatto dall’ultimo falò va perso.';
  @override
  String get quitSinceTrainCost =>
      'Uscire al menù principale? Quello che hai fatto dal treno va perso.';
  @override
  String get quitUnsavedCost =>
      'Uscire al menù principale? Questa partita non è mai stata salvata: esci e la perdi tutta.';
  @override
  String get pauseRestartFromArrivalCost =>
      'Ricominciare il livello? Si riparte dall’arrivo in città: quello che hai trovato e fatto qui si azzera, le altre città restano come le hai lasciate, e lo slot viene salvato all’inizio del livello.';
  @override
  String get pauseRestartFromStoryCost =>
      'Ricominciare il livello? Si riparte dalla prima scena della storia: quello che hai trovato e fatto a Molfetta si azzera, le altre città ti aspettano sul treno come le hai lasciate. Restano le ore di gioco.';
  @override
  String get pauseBackToGame => 'TORNA AL GIOCO';
  @override
  String get pauseToMainMenu => 'VAI AL MENÙ PRINCIPALE';
  @override
  String get pauseYesQuit => 'SÌ, ESCI';
  @override
  String get outfitWorn => 'GIÀ IN USO';
  @override
  String get outfitWear => 'INDOSSA';
  @override
  String get outfitLocked => 'NON DISPONIBILE';
  @override
  String get gameOver => 'GAME OVER';
  @override
  String get gameOverMainMenu => 'MENÙ PRINCIPALE';
  @override
  String gameOverRestartCampfireCost({required bool fromStory}) =>
      'Ricominciare il livello? Il falò dove hai salvato va perso: ${_restartFrom(fromStory: fromStory)}';
  @override
  String gameOverRestartTrainCost({required bool fromStory}) =>
      'Ricominciare il livello? Il salvataggio sul treno va perso: ${_restartFrom(fromStory: fromStory)}';

  // Loading
  @override
  String get levelHometown => 'Città natale';
  @override
  String get levelRome => 'Roma';
  @override
  String get loadingGame => 'Caricamento della partita';
  @override
  String get loadingTutorial => 'Caricamento del tutorial';

  // Places, as the maps name them: only the names a language says
  // otherwise, the others (proper names) are shown as they are
  @override
  Map<String, String> get placeNames => const <String, String>{};

  // Missions
  @override
  String get missions => 'MISSIONI';
  @override
  String get missionFindSurvivors => 'Trova altri sopravvissuti';
  @override
  String get missionFreeLuigi => 'Trova un modo per liberare Luigi';
  @override
  String get missionReachLuigi => 'Raggiungi Luigi alla stazione';
  @override
  String get missionClearGate => 'Spara o allontana gli zombi dal cancello';
  @override
  String get missionFindIncense => "Trova dell'incenso";
  @override
  String get missionFindRing => "Trova l'anello episcopale";
  @override
  String get missionInitiation => 'Partecipa alla cerimonia di iniziazione';
  @override
  String get missionExploreTerraces =>
      'Usa il rampino per esplorare i terrazzi';
  @override
  String get missionReachSurvivor =>
      "Raggiungi Chiara dall'altra parte degli uffici";
  @override
  String get missionFindSupplies => 'Trova delle provviste in città';
  @override
  String get missionFindValuable =>
      'Cerca qualcosa di prezioso per Tonino e Marcello';
  @override
  String get missionDiscoverColosseum => 'Scopri cosa succede al Colosseo';
  @override
  String get secretMissions => 'MISSIONI SEGRETE';
  @override
  String secretMissionRow(String mission) => 'Segreta: $mission';
  @override
  String get secretUnarmedToLuigi =>
      'Se hai il coraggio ricomincia il livello completando la trama di Luigi senza raccogliere la pistola';
  @override
  String get secretUnarmedToLuigiShort => 'da Luigi senza la pistola';

  // Outfits
  @override
  String get outfitBase => 'Base';
  @override
  String get outfitCultist => 'Occultista';
  @override
  String get outfitGhost => 'Fantasma';
  @override
  String get outfitVampire => 'Vampiro';
  @override
  String get outfitJackOLantern => 'Jack-o’-lantern';
  @override
  String get outfitZombie => 'Zombi';

  // Level complete and the figures of the adventure
  @override
  String get levelComplete => 'LIVELLO COMPLETATO';
  @override
  String get levelCompleteSaveFailed =>
      'Salvataggio non riuscito: la partita riprenderà dall’ultimo falò, non dal treno.';
  @override
  String get statBackpacks => 'ZAINI TROVATI';
  @override
  String get statMemories => 'RICORDI VISSUTI';
  @override
  String get statCampfires => 'FALÒ TROVATI';
  @override
  String get statZombieKinds => 'ZOMBI CONOSCIUTI';
  @override
  String get statKills => 'ZOMBI UCCISI';
  @override
  String get statSteps => 'PASSI FATTI';
  @override
  String get statsReplayMemories => 'RIVIVI I RICORDI';
  @override
  String get statsExit => 'ESCI';

  // Screens of the story and the books on the train
  @override
  String get tapToRead => 'Tocca per leggere';
  @override
  String get skip => 'SALTA';
  @override
  String get close => 'CHIUDI';
  @override
  String get zombieBookUnmet => 'Non hai ancora incontrato questo zombi.';

  // The intro story, the night of the outbreak and Rome's
  @override
  String get speakerNewsreader => 'Telecronista';
  @override
  String get speakerHostess => 'Hostess';
  @override
  String get speakerGeneral => 'Generale';
  @override
  String get speakerPrimeMinister => 'Presidente del consiglio';
  @override
  String get speakerSecretary => 'Segretaria';
  @override
  String get introNewsFlash =>
      'Attenzione, interrompiamo le comunicazioni per una edizione straordinaria del telegiornale';
  @override
  String get introBlackout => '... Che succede? ... Ragazzi, la luce?';
  @override
  String get introScream => 'Aaaaahhh!';
  @override
  String get outbreakNight =>
      'Quella notte migliaia di persone in ogni dove si trasformarono in zombi, creature non morte prive di una coscienza propria, interessate solo a divorare altri esseri umani';
  @override
  String get outbreakPlaneHelp => 'Aiuto, comandante! Aiuto!';
  @override
  String get outbreakPlaneCaptain => 'Comandante?';
  @override
  String get outbreakCollapse =>
      "Quella notte l'intera civiltà umana crollò per colpa di questa malvagia e misteriosa minaccia";
  @override
  String get romeGeneralReinforcements =>
      'Signor presidente, abbiamo bisogno di rinforzi!';
  @override
  String get romePresidentNoForces =>
      'Non è possibile, tutte le nostre forze sono già occupate';
  @override
  String get romeGeneralHundreds =>
      'Signore qui siamo nella merda, ci sono centinaia e centinaia di questi zombi bastardi';
  @override
  String get romePresidentAlone =>
      'Generale non posso fare altrimenti, dovete vedervela da soli';
  @override
  String get romeSecretaryDoubt =>
      'Signor presidente siete sicuro di quello che state facendo?';
  @override
  String get romePresidentBunker =>
      'Non preoccuparti Petunia, quei rinforzi servono per proteggere il mio bunker';
  @override
  String get romeSecretaryDying =>
      'Ma... ma signor presidente quelle persone lì fuori stanno morendo...';
  @override
  String get romePresidentPetulant =>
      'Petunia non essere petulante oppure non ti ci porto nel bunker';
  @override
  String get romePresidentAttacked => 'Oddio aiuto! Petunia, aiutooo!';

  // Zombies: the name in the book, the lesson the first time one is met
  // and the card in the book
  @override
  String zombieName(EntityKind kind) => switch (kind) {
    EntityKind.wanderer => 'Vagante',
    EntityKind.carabiniere => 'Carabiniere',
    EntityKind.sprinter => 'Veloce',
    EntityKind.mutilated => 'Mutilato',
    EntityKind.burning => 'In fiamme',
    EntityKind.drunk => 'Ubriaco',
    EntityKind.cultist => 'Cultista',
    EntityKind.brute => 'Bruto',
    EntityKind.callCenter => 'Call center',
    EntityKind.blind => 'Cieco',
    _ => '',
  };
  @override
  String zombieLesson(EntityKind kind) => switch (kind) {
    EntityKind.wanderer =>
      'I normali zombi vaganti faranno un passo verso di te ogni due passi tuoi',
    EntityKind.carabiniere =>
      'Gli zombi carabinieri possono raggiungerti a due celle di distanza grazie al loro manganello',
    EntityKind.sprinter =>
      'Gli zombi veloci si muovono alla tua stessa velocità',
    EntityKind.mutilated =>
      'Gli zombi mutilati non possono inseguirti, ma se passi loro accanto ti mordono a ogni tuo passo. Giragli alla larga, o abbattili se ti sbarrano la strada',
    EntityKind.burning =>
      'Gli zombi in fiamme si muovono come i vaganti, ma ogni cella che lasciano prende fuoco e non potrai più attraversarla',
    EntityKind.drunk =>
      'Gli zombi ubriachi barcollano a caso e non ti inseguono, ma se gli capiti accanto ti mordono. Occhio: la prossima barcollata può portarlo proprio da te',
    EntityKind.cultist =>
      'Gli zombi cultisti si muovono come i vaganti, ma la loro massa muscolare richiede tre colpi di pistola per abbatterli',
    EntityKind.brute =>
      'Gli zombi bruti sono lentissimi, fanno un passo ogni tre tuoi, ma servono due colpi di pistola per abbatterli',
    EntityKind.callCenter =>
      'Gli zombi del call center sono veloci come te, ma il filo della cornetta li tiene legati alla loro postazione: oltre la lunghezza del filo non possono seguirti',
    _ => '',
  };
  @override
  String zombieDescription(EntityKind kind) => switch (kind) {
    EntityKind.wanderer =>
      'Il più comune: fino a poco fa era una persona qualunque. Lento e goffo, fa un passo ogni due dei tuoi. Da solo si evita, in gruppo ti chiude la strada.',
    EntityKind.carabiniere =>
      'Porta ancora la divisa e stringe il manganello: ti colpisce fino a due celle di distanza. Si muove come un vagante, ma non lasciarlo avvicinare.',
    EntityKind.sprinter =>
      'Si muove alla tua stessa velocità: correndo non lo semini. Ti vede e ti sente da più lontano degli altri.',
    EntityKind.mutilated =>
      'Ha perso le gambe e non si rialza più da dove è caduto. Non ti insegue, ma è sveglio quanto un veloce: passagli accanto e ti morde a ogni passo. Tienilo a due celle di distanza, o sparagli se ti chiude il passaggio.',
    EntityKind.burning =>
      'Brucia senza consumarsi. Lento come un vagante, ma ogni cella da cui si sposta resta in fiamme per sempre: nessuno ci passa più, nemmeno lui. Abbattilo prima che ti chiuda la strada del ritorno.',
    EntityKind.drunk =>
      'Era già ubriaco quando è cambiato, e lo è ancora. Barcolla di continuo in una direzione a caso, al passo di un vagante, che ti abbia visto o no. Non ti insegue, ma se gli finisci accanto il morso arriva dritto.',
    EntityKind.cultist =>
      'La mutazione ha gonfiato il corpo oltre la tunica: il cappuccio è caduto sulle spalle, le vesti si sono strappate e vene gialle innaturali attraversano le braccia. Avanza al passo di un vagante, ma i primi due colpi non bastano: ne servono tre per abbatterlo.',
    EntityKind.brute =>
      'Un colosso già prima di cambiare, e la mutazione lo ha gonfiato ancora. Fa un passo ogni tre dei tuoi e ci vede poco, ma sente il minimo rumore da lontano. Il primo colpo non lo ferma: ne servono due.',
    EntityKind.callCenter =>
      'È morto in cuffia, a metà di una telefonata, e la cornetta non la molla più. Scatta veloce quanto te, ma il filo lo tiene legato alla sua scrivania: si allunga verso di te finché il filo tiene, poi resta lì a tirare. Stagli lontano quanto basta, o sparagli prima di passargli accanto.',
    _ => '',
  };

  // Error, unfinished roads, the Europe map, the tutorial's opening
  @override
  String get errorTitle => 'QUALCOSA È ANDATO STORTO';
  @override
  String get errorExplanation =>
      'Il gioco si è fermato per un errore. Il rapporto dice quale, con la versione del gioco, il telefono, gli ultimi passi della partita e il salvataggio dello slot: niente di personale. Mandalo allo sviluppatore e poi torna al menù per riprendere dall’ultimo salvataggio.';
  @override
  String get errorExplanationSent =>
      'Il gioco si è fermato per un errore. Il rapporto, con la versione del gioco, il telefono, gli ultimi passi della partita e il salvataggio dello slot (niente di personale), parte da solo verso lo sviluppatore, anche più tardi se ora non c’è rete. Torna al menù per riprendere dall’ultimo salvataggio.';
  @override
  String get errorSharing => 'UN MOMENTO…';
  @override
  String get errorBackToMenu => 'TORNA AL MENÙ';
  @override
  String get workInProgressTitle =>
      'La demo finisce qui,\nil seguito deve ancora essere programmato';
  @override
  String get workInProgressMissingItems =>
      'I seguenti oggetti non sono ancora stati implementati:\nEstintore, Piede di porco';
  @override
  String get workInProgressFeedback => 'Fammi sapere se il gioco ti piace';
  @override
  String get mapMolfetta => 'MOLFETTA';
  @override
  String get levelNorthCape => 'Capo Nord';
  @override
  String get mapChooseDestination => 'SCEGLI LA DESTINAZIONE';
  @override
  String get mapStartLevel => 'INIZIA LIVELLO';
  @override
  String get tutorialChaos =>
      'La città è nel caos più totale! Devo cercare di mettermi in salvo in qualche modo';
  @override
  String get tutorialMove =>
      'Trascina il dito sulla parte sinistra dello schermo per muoverti';

  // The controls and what Mario carries
  @override
  String get actionZoneHint =>
      'Tocca per interagire, tieni premuto e trascina per mirare, lascia per sparare o lanciare';
  @override
  String get moveZoneHint => 'Trascina per muoverti';
  @override
  String get menuButton => 'Menù';
  @override
  String get itemIncense => 'Incenso';
  @override
  String get itemIncenseLabel => 'Incenso per Don Angelo';
  @override
  String get itemBarKey => 'Chiave del Bar Arcobaleno';
  @override
  String get itemEpiscopalRing => 'Anello episcopale';
  @override
  String get itemDuomoKey => 'Chiave del Duomo';
  @override
  String get itemPalazzoKey => 'Chiave del terzo piano';
  @override
  String get itemGrapplingHook => 'Rampino';
  @override
  String get itemGoldIngot => "Lingotto d'oro";
  @override
  String get itemColosseumTicket => 'Biglietto del Colosseo';
  @override
  String get pistol => 'Pistola';
  @override
  String get goldenPistol => "Pistola d'oro";
  @override
  String pistolMissing(String pistol, int rounds) =>
      '$pistol da trovare, proiettili: $rounds';
  @override
  String pistolInHand(String pistol, int rounds) =>
      '$pistol in mano, proiettili: $rounds';
  @override
  String pistolToTake(String pistol, int rounds) =>
      '$pistol, proiettili: $rounds, tocca per prenderla';
  @override
  String molotovInHand(int count) => 'Molotov in mano: $count';
  @override
  String molotovToTake(int count) => 'Molotov: $count, tocca per prenderne una';
  @override
  String launcherMissing(int rounds) =>
      'Lanciarazzi da trovare, colpi: $rounds';
  @override
  String launcherInHand(int rounds) => 'Lanciarazzi in mano, colpi: $rounds';
  @override
  String launcherToTake(int rounds) =>
      'Lanciarazzi, colpi: $rounds, tocca per prenderlo';
  @override
  String bulletsLeft(int rounds) =>
      rounds == 1 ? '1 proiettile' : '$rounds proiettili';
  @override
  String molotovsLeft(int count) => '$count molotov';
  @override
  String rocketsLeft(int rounds) => '$rounds colpi per lanciarazzi';

  // Saving at a campfire, or at the table aboard
  @override
  String get saved => 'Salvataggio completato';
  @override
  String get campfireSaveFailed =>
      'Salvataggio non riuscito. Riposati di nuovo accanto al fuoco per riprovare';
  @override
  String get mealSaveFailed =>
      'Salvataggio non riuscito. Torna al tavolo per riprovare';

  // The story, place by place (lib/game/story/scripts/)
  @override
  String backpacksBulletsFound(int rounds) => rounds == 1
      ? 'Hai trovato 1 proiettile'
      : 'Hai trovato $rounds proiettili';
  @override
  String backpacksMolotovsFound(int count) => 'Hai trovato $count molotov';
  @override
  String backpacksRocketsFound(int rounds) => rounds == 1
      ? 'Hai trovato 1 colpo per lanciarazzi'
      : 'Hai trovato $rounds colpi per lanciarazzi';
  @override
  String get backpacksAimLesson =>
      'Tieni premuto sulla parte destra dello schermo per iniziare a mirare';
  @override
  String get backpacksBackpackLesson =>
      'Raccogli gli zaini in giro per trovare nuovo equipaggiamento';
  @override
  String get backpacksCancelLesson =>
      'Puoi annullare il colpo di pistola senza consumare proiettili alzando il dito mentre sei nel punto centrale';
  @override
  String get backpacksDuomoKeyFound =>
      'Hai trovato la Chiave del Duomo vicino il cadavere di Don Angelo';
  @override
  String get backpacksFireLesson =>
      'Mentre tieni premuto trascina verso una direzione, appena alzi il dito parte il colpo';
  @override
  String get backpacksGoldIngotFound => "Hai trovato un lingotto d'oro";
  @override
  String get backpacksGoldIngotThought =>
      "Questo andrà bene per quei due maranza. Non penso di poterne fare qualcos'altro";
  @override
  String get backpacksGrapplingHookFound => 'Hai trovato un rampino';
  @override
  String get backpacksGrapplingHookLesson =>
      'Con il rampino puoi raggiungere i tetti vicini che non riuscivi a raggiungere';
  @override
  String get backpacksGunFound => 'Hai trovato una pistola';
  @override
  String get backpacksIncenseFound => "Hai trovato dell'incenso";
  @override
  String get backpacksInteractLesson =>
      'Tocca la parte destra dello schermo per interagire con gli oggetti vicini';
  @override
  String get backpacksMolotovLesson => 'Le molotov fanno danno ad area';
  @override
  String get backpacksNoGun => 'Non hai una pistola';
  @override
  String get backpacksNoRocketLauncher => 'Non hai un lanciarazzi';
  @override
  String get backpacksPalazzoKeyFound =>
      'Hai trovato la Chiave del terzo piano';
  @override
  String get backpacksRingFound => 'Hai trovato un anello episcopale';
  @override
  String get backpacksRocketLauncherFound => 'Hai trovato un lanciarazzi';
  @override
  String get backpacksRocketLauncherLesson =>
      'Il razzo vola dritto fino al muro e colpisce tutti gli zombi che trova sulla sua strada, 3 danni a testa';
  @override
  String get backpacksRocketRoundsLesson =>
      'I colpi per il lanciarazzi si trovano negli zaini, come i proiettili';
  @override
  String get backpacksWeaponChoiceLesson =>
      "Puoi impugnare un'arma per volta, tocca l'arma che vuoi impugnare tra gli oggetti dell'inventario. Le fiamme indicheranno l'arma attiva";
  @override
  String get barKeyUsedLine => 'Hai usato la chiave per aprire la porta';
  @override
  String get barLockedDoorLine => 'Questa porta è chiusa. Serve una chiave';
  @override
  String get barracksBarracksReached =>
      "Ecco, ce l'ho fatta! La caserma dei carabinieri";
  @override
  String get barracksBarracksSafe => 'Questo sarà un posto sicuro?';
  @override
  String get companyCallFrames1 =>
      'Dai dai speriamo che almeno questo qui risponde';
  @override
  String get companyCallFrames2 => 'Uuh ?';
  @override
  String get companyCallFrames3 =>
      'Salve, la chiamo per conto di NonPrende Mobile, vorrei offrirvi ad un prezzo veramente vantaggioso la nostra offerta Fibra Morale';
  @override
  String get companyCallFrames4 => 'Aaaarggh !';
  @override
  String get companyCallFrames5 => 'Ma che modi sono questi?! Maleducato!';
  @override
  String get companyCallFrames6 =>
      "Mamma mia... Al giorno d'oggi sono tutti senza cervello...";
  @override
  String get companyMeetingFrames1 => 'Ei ma che ci fai qui?';
  @override
  String get companyMeetingFrames2 => 'Ho degli straordinari da recuperare';
  @override
  String get companyMeetingFrames3 => "Signora c'è l'apocalisse zombi qui!";
  @override
  String get companyMeetingFrames4 =>
      'Ecco perché non chiudevo più nessun contratto';
  @override
  String get companySeeYouThere => 'Allora ci vediamo in stazione...';
  @override
  String get companySendToStation =>
      'Signora vai alla stazione, lì ci sono altri sopravvissuti';
  @override
  String get damagedDoorLine =>
      "Questa porta è un po' danneggiata, con un piede di porco potresti "
      'aprirla';
  @override
  String get duomoAreYouMadLine => 'Cosa fate? Ma siete pazzi?!';
  @override
  String get duomoFamilyWelcomeLine =>
      'Ottimo giovanotto, sei davvero un prodigio! Benvenuto nella nostra grande famiglia';
  @override
  String get duomoInitiationReminderLine =>
      'Indossa la tunica e preparati per la tua cerimonia di iniziazione';
  @override
  String get duomoKeyUsedLine =>
      'Hai usato la Chiave del Duomo per aprire la porta';
  @override
  String get duomoLetMeGoLine => 'No, lasciatemi andare! Nooo';
  @override
  String get duomoLockedDoorLine => 'Questa porta è chiusa. Serve una chiave';
  @override
  String get duomoMassSermonLine =>
      "Il Signore ha mandato questa sciagura contro l'uomo, essa però è pur sempre opera del Signore ed ha lo scopo di purificare il mondo";
  @override
  String get duomoMassWelcomeLine =>
      'Noi siamo tutti pronti a cominciare giovanotto, accomodati pure!';
  @override
  String get duomoOutfitChangedLine =>
      'Mario cambia abbigliamento uscito dal duomo';
  @override
  String get duomoOutfitObtainedLine =>
      "Hai ottenuto l'abbigliamento da occultista.";
  @override
  String get duomoRingReminderLine =>
      "Non hai ancora recuperato l'anello episcopale?";
  @override
  String get duomoRobeFoundLine => 'Hai trovato una tunica da occultista';
  @override
  String get duomoRobeLine =>
      'Abbiamo preparato una tunica anche per te, la trovi al piano superiore';
  @override
  String get duomoStairBlockedLine =>
      'Potrai passare da qui solo quando sarai anche tu davvero parte della nostra comunità';
  @override
  String get duomoSuperZombieLine =>
      'Basta un loro morso a trasformare un uomo in zombi, voi li state direttamente ingerendo... Questo vi sta trasformando in super zombi';
  @override
  String get duomoWardrobeLaterLine =>
      'In futuro potrai scegliere quale abbigliamento usare.';
  @override
  String get duomoWardrobeOnTrainLine =>
      'Potrai scegliere quale abbigliamento usare sul treno.';
  @override
  String get duomoWelcomeLine =>
      'Che bello vedere nuovi fedeli che si uniscono a noi';
  @override
  String get duomoWorshipLine =>
      'Lo zombi non va temuto. Lo zombi va venerato. Attraverso la nostra preghiera gli zombi ci salveranno';
  @override
  String get electronicsOpenFromInsideLine => 'Apri la porta dall’interno';
  @override
  String get electronicsShutterDownLine =>
      'La saracinesca è abbassata. Da fuori non si apre';
  @override
  String get journeyCarryLines1 =>
      "Le munizioni e gli oggetti consumabili, come i proiettili o le molotov, non possono essere portati tra un livello e l'altro";
  @override
  String get journeyCarryLines2 =>
      'Gli oggetti non consumabili invece, come la pistola o il rampino, possono essere portati tra i vari livelli';
  @override
  String get mallHelpCall => "Aiuto! C'è qualcuno?! Aiutooo";
  @override
  String get mallLuigiScene1 =>
      'Mi chiamo Luigi. Sono rimasto bloccato qui per colpa del sistema antifurto';
  @override
  String get mallLuigiScene2 => 'Attenzione! Dietro di te';
  @override
  String get mallLuigiScene3 => 'Aaaahhrg!';
  @override
  String get mallMeetAtStationLine =>
      'Raggiungimi alla stazione, ne parliamo lì!';
  @override
  String get mallReunionScene1 =>
      "Ce l'hai fatta, ragazzo! Adesso me la vedo io con questi qui";
  @override
  String get mallReunionScene2 =>
      "Sono felice di vedere che c'è qualcun altro vivo e vegeto";
  @override
  String get mallReunionScene3 =>
      'A chi lo dici! Finalmente qualcuno che non prova a mangiarmi il cervello';
  @override
  String get mallShutterOpened =>
      'Hai disattivato il sistema antifurto: la saracinesca si è alzata';
  @override
  String get mallSomeoneAlive => "Ei ma qui c'è qualcuno ancora vivo!";
  @override
  String get mallTrustLine =>
      'Ragazzo ho deciso di fidarmi di te! Ti parlerò del mio grande piano per non schiattare';
  @override
  String get maranzaMarcelloAfter => 'Ci vediamo al Colosseo frà';
  @override
  String get maranzaMeetingScene1 => 'Aò frà, tu non sei morto vero?';
  @override
  String get maranzaMeetingScene2 =>
      'Che vuoi passà da qua? Questa è zona nostra';
  @override
  String get maranzaMeetingScene3 => 'Cosa volete?';
  @override
  String get maranzaMeetingScene4 =>
      'Daje frà, lo sai... Qualcosa di prezioso, di valore!';
  @override
  String get maranzaMeetingScene5 =>
      "Ma cosa ve ne fate? Siamo nel pieno dell'apocalisse zombi!";
  @override
  String get maranzaMeetingScene6 =>
      'Frà, fino a quando ci saranno almeno due persone sulla Terra, servirà sempre avere roba di valore';
  @override
  String get maranzaPaidScene1 =>
      'Grande frà, questo era proprio che intendevo con qualcosa di prezioso!';
  @override
  String get maranzaPaidScene2 =>
      'Ci stai simpatico frà, tieni questo è un biglietto per il Colosseo';
  @override
  String get maranzaPaidScene3 =>
      'Il Colosseo? Ci fanno ancora le gite turistiche?';
  @override
  String get maranzaPaidScene4 =>
      'Gite turistiche!? Hehehe niente del genere frà, lo scoprirai...';
  @override
  String get maranzaToninoAfter =>
      'Ora dobbiamo trovare qualcosa da fare con questo lingotto adesso';
  @override
  String get maranzaWarnings1 =>
      'Fratè, meglio che torni con qualcosa di valore per noi';
  @override
  String get maranzaWarnings2 =>
      'Se torni senza qualcosa per noi ti becchi una sberla';
  @override
  String get northDistrictCampLesson =>
      'Interagisci con i falò per salvare il gioco';
  @override
  String get palazzoKeyUsedLine =>
      'Hai usato la Chiave del terzo piano per aprire la porta';
  @override
  String get palazzoLockedDoorLine =>
      'Questa porta è chiusa a chiave. Qualcuno dei vicini avrà la chiave';
  @override
  String get priestBarKeyLine =>
      'Usa questa chiave per aprire una porta nel bar Arcobaleno sul porto, lì troverai il mio anello episcopale';
  @override
  String get priestClearThemOut =>
      'Sbarazzati di questi zombi così potremmo parlare meglio';
  @override
  String get priestDealScene1 => 'Ci siamo padre, apra il cancello';
  @override
  String get priestDealScene2 => 'Prima dovrai fare qualcosa per noi';
  @override
  String get priestDealScene3 => 'Cosa?! Ma è pericoloso qui fuori padre...';
  @override
  String get priestDealScene4 =>
      'Giovanotto pensi che se facessi entrare chiunque nella mia chiesa ora sarei ancora sopravvissuto?';
  @override
  String get priestEveryTwoStreetsLine =>
      'Suvvia giovanotto, siamo in Italia! Nei centri storici trovi una chiesa ogni due strade';
  @override
  String get priestIncenseLine =>
      "Portami dell'incenso, mi serve per le mie cerimonie";
  @override
  String get priestMeetingScene1 =>
      'Ohh che piacere vedere qualcuno ancora in vita passeggiare per il nostro porto';
  @override
  String get priestMeetingScene2 =>
      'Siete vivi?! Qui alla chiesa vi siete salvati?';
  @override
  String get priestMeetingScene3 =>
      'Giovanotto la chiesa è sempre il primo posto in cui cercare la salvezza';
  @override
  String get priestMoreWorkLine =>
      'Ah... Immagino che vi aspettate che faccia altro per voi';
  @override
  String get priestNotCommunityYetLine =>
      'Ora puoi entrare qui ma non sei ancora davvero parte della nostra comunità';
  @override
  String get priestUseYourSkillsLine =>
      'Giovanotto sembri così bravo a muoverti nella città desolata, sarebbe un peccato non sfruttare queste tue capacità';
  @override
  String get priestWelcomeLine =>
      'Ottimo giovanotto, ben fatto! Benvenuto nella nostra chiesa';
  @override
  String get priestWhereLine => "Dove lo trovo dell'incenso?!";
  @override
  String get roadblockFireLine =>
      "L'incendio blocca completamente la strada, potresti passare con un estintore";
  @override
  String get romeArrivalLines1 =>
      'Come si suol dire: tutte le strade portano a Roma';
  @override
  String get romeArrivalLines2 =>
      'Facciamo una piccola fermata qui, io cerco un po’ di carburante in giro e tu vai a trovare delle provviste, ce ne serviranno parecchie per arrivare alla nostra meta';
  @override
  String get rooftopsGapLesson =>
      'Il tetto vicino non è molto distante, è raggiungibile con un rampino';
  @override
  String get rooftopsGrappleLine => 'Mario usa il rampino';
  @override
  String get speakerCultist => 'Cultista';
  @override
  String get speakerMysteryVoice => 'Voce misteriosa';
  @override
  String get speakerZombie => 'Zombi';
  @override
  String get stationGoldenPistolGift =>
      "Ei ma non hai nessun'arma con te? Tieni prendi questa";
  @override
  String get stationGoldenPistolLesson =>
      "La pistola d'oro infligge danni doppi";
  @override
  String get stationLockedDoorLine => 'La porta è chiusa';
  @override
  String get stationReunionScene1 =>
      "Eccoti ragazzo, ce l'hai fatta finalmente!";
  @override
  String get stationReunionScene2 =>
      'Quale sarebbe il tuo piano quindi? Cosa vuoi farci con questo treno?';
  @override
  String get stationReunionScene3 => 'Andare via da qui ovviamente!';
  @override
  String get stationReunionScene4 => 'Si ma dove?';
  @override
  String get stationReunionScene5 =>
      'La nostra meta é Capo Nord ragazzo. In Norvegia';
  @override
  String get stationReunionScene6 =>
      'Lì gli zombi non arrivano, il freddo li tiene lontani';
  @override
  String get streetZombieSpotted => 'Merda uno zombi! Meglio svignarsela';
  @override
  String get trainChiaraHometownLines1 =>
      'Dobbiamo arrivare fino in Norvegia? Sembra un sacco di strada';
  @override
  String get trainChiaraRomeLines1 => 'Cosa?! Non eri mai stato a Roma?';
  @override
  String get trainChiaraRomeLines2 =>
      'È la città eterna, ti ritrovi tra le rovine romane senza rendertene conto';
  @override
  String get trainCotLine =>
      "Ripensa all'avventura: statistiche, missioni e ricordi";
  @override
  String get trainLuigiLine => "Sarà un viaggio per l'Europa molto impegnativo";
  @override
  String get trainRomeLines1 => 'Tutte le strade portano a Roma ragazzo';
  @override
  String get trainRomeLines2 => 'Cosa? Dici che l’avevo già detto?';
  @override
  String get trainWardrobeLine => 'Scegli quale abbigliamento indossare';
  @override
  String get trainZombieNotes => 'Appunti sugli zombi conosciuti';
  @override
  String trainAmmoFull(int rounds) =>
      'Hai già abbastanza munizioni. Torna qui quando avrai meno di $rounds proiettili per ricaricare';
  @override
  String trainAmmoRefilled(int rounds) =>
      'Munizioni ricaricate. Torna qui in qualsiasi momento se hai meno di $rounds proiettili per ricaricare';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _restartFrom({required bool fromStory}) => fromStory
    ? 'si riparte dalla prima scena della storia. Le altre città restano come sono.'
    : 'si riparte dall’arrivo in città. Le altre città restano come sono.';
