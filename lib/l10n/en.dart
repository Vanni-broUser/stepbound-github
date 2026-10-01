// The game in English, translated from it.dart. A new language starts as
// a copy of this file: see lib/l10n/language.dart.
// ignore_for_file: lines_longer_than_80_chars

import 'package:stepbound/core/core.dart';
import 'package:stepbound/l10n/strings.dart';

final class EnglishStrings implements Strings {
  const EnglishStrings();

  // Shared by many screens
  @override
  String get back => 'BACK';
  @override
  String get no => 'NO';
  @override
  String get ok => 'OK';
  @override
  String get shareReport => 'SHARE THE REPORT';
  @override
  String get continueLabel => 'CONTINUE';
  @override
  String get tapToContinue => 'Tap to continue';
  @override
  String date(DateTime time) =>
      '${_two(time.day)}/${_two(time.month)}/${time.year} ${_two(time.hour)}:${_two(time.minute)}';

  // Main menu
  @override
  String get menuDisclaimer =>
      'Any resemblance to actual persons or events is purely coincidental';
  @override
  String get menuNewGame => 'NEW GAME';
  @override
  String get menuLoadGame => 'LOAD GAME';
  @override
  String get menuAudioOn => 'AUDIO: ON';
  @override
  String get menuAudioOff => 'AUDIO: OFF';
  @override
  String get menuLanguage => 'Language';
  @override
  String get menuCredits => 'CREDITS';
  @override
  String get settingsTitle => 'SETTINGS';
  @override
  String settingsLanguage(String language) => 'LANGUAGE: $language';
  @override
  String settingsSendData({required bool on}) =>
      'SEND ANONYMOUS DATA: ${on ? 'YES' : 'NO'}';
  @override
  String get menuChooseNewSlot => 'CHOOSE WHERE TO SAVE';
  @override
  String get menuChooseSave => 'CHOOSE A SAVE';
  @override
  String menuOverwrite(int slot) =>
      'OVERWRITE SLOT $slot?\nTAP AGAIN TO CONFIRM';
  @override
  String get menuSlotEmpty => 'empty';
  @override
  String get menuSlotDamaged => 'damaged, cannot be loaded';
  @override
  String get menuSlotBackup => '(backup)';
  @override
  String get menuSlotSuspended => '(suspended)';
  @override
  String get menuGift => 'GIFT';
  @override
  String menuSkin(String name) => '$name skin';
  @override
  String get menuLinkExpired => 'LINK EXPIRED';
  @override
  String get menuLinkInvalid => 'OR NOT VALID';
  @override
  String get creditsMusic => 'MUSIC';
  @override
  String get creditsAttribution => 'Attribution';
  @override
  String get creditsEffects =>
      'Sound effects: Kenney.nl and OpenGameArt.org (CC0)';

  // Pause menu and game over
  @override
  String get restartLevel => 'RESTART THE LEVEL';
  @override
  String get yesRestart => 'YES, RESTART';
  @override
  String get resumeCampfire => 'RESUME FROM THE CAMPFIRE';
  @override
  String get resumeCampfireConfirm => 'YES, BACK TO THE CAMPFIRE';
  @override
  String get resumeCampfireCost =>
      'Go back to the last campfire? Whatever you have done since then is lost.';
  @override
  String get resumeTrain => 'RESUME FROM THE TRAIN';
  @override
  String get resumeTrainConfirm => 'YES, BACK TO THE TRAIN';
  @override
  String get resumeTrainCost =>
      'Go back to the train? Whatever you have done since then is lost.';
  @override
  String get quitSinceCampfireCost =>
      'Quit to the main menu? Whatever you have done since the last campfire is lost.';
  @override
  String get quitSinceTrainCost =>
      'Quit to the main menu? Whatever you have done since the train is lost.';
  @override
  String get quitUnsavedCost =>
      'Quit to the main menu? This game has never been saved: quit and you lose all of it.';
  @override
  String get pauseRestartFromArrivalCost =>
      'Restart the level? You start again from your arrival in town: everything you found and did here is reset, the other cities stay as you left them, and the slot is saved at the start of the level.';
  @override
  String get pauseRestartFromStoryCost =>
      'Restart the level? You start again from the first scene of the story: everything you found and did in Molfetta is reset, the other cities wait for you on the train as you left them. Your hours of play stay.';
  @override
  String get pauseBackToGame => 'BACK TO THE GAME';
  @override
  String get pauseToMainMenu => 'GO TO THE MAIN MENU';
  @override
  String get pauseYesQuit => 'YES, QUIT';
  @override
  String get outfitWorn => 'WEARING IT';
  @override
  String get outfitWear => 'WEAR';
  @override
  String get outfitLocked => 'NOT AVAILABLE';
  @override
  String get gameOver => 'GAME OVER';
  @override
  String get gameOverMainMenu => 'MAIN MENU';
  @override
  String gameOverRestartCampfireCost({required bool fromStory}) =>
      'Restart the level? The campfire where you saved is lost: ${_restartFrom(fromStory: fromStory)}';
  @override
  String gameOverRestartTrainCost({required bool fromStory}) =>
      'Restart the level? The save on the train is lost: ${_restartFrom(fromStory: fromStory)}';

  // Loading
  @override
  String get levelHometown => 'Hometown';
  @override
  String get levelRome => 'Rome';
  @override
  String get loadingGame => 'Loading the game';
  @override
  String get loadingTutorial => 'Loading the tutorial';

  // Places, as the maps name them: only the names a language says
  // otherwise, the others (proper names) are shown as they are
  @override
  Map<String, String> get placeNames => const <String, String>{
    'Porto e centro storico': 'Harbour and old town',
    'Ospedale': 'Hospital',
    'Tetto dell’ospedale': 'Hospital roof',
    'Palazzo': 'Apartment block',
    'Palazzo accanto all’ospedale': 'Block next to the hospital',
    'Azienda': 'Company offices',
    'Elettronica': 'Electronics shop',
    'Dietro la caserma': 'Behind the barracks',
    'Zona nord': 'North side',
    'Davanti all’azienda': 'Outside the company',
    'Sagrato del Duomo': 'Duomo churchyard',
    'Fine del porto': 'End of the harbour',
    'Tetti di via Marsala': 'Via Marsala rooftops',
    'Banca': 'Bank',
    'Caveau della banca': 'Bank vault',
    'Piazza dei Cinquecento': 'Piazza dei Cinquecento',
    'Treno': 'Train',
    'Inizio del livello': 'Start of the level',
    'Città natale': 'Hometown',
    'Roma': 'Rome',
  };

  // Missions
  @override
  String get missions => 'MISSIONS';
  @override
  String get missionFindSurvivors => 'Find other survivors';
  @override
  String get missionFreeLuigi => 'Find a way to free Luigi';
  @override
  String get missionReachLuigi => 'Meet Luigi at the station';
  @override
  String get missionClearGate => 'Shoot or lure the zombies away from the gate';
  @override
  String get missionFindIncense => 'Find some incense';
  @override
  String get missionFindRing => 'Find the episcopal ring';
  @override
  String get missionInitiation => 'Take part in the initiation ceremony';
  @override
  String get missionExploreTerraces =>
      'Use the grappling hook to explore the terraces';
  @override
  String get missionReachSurvivor =>
      'Reach Chiara on the other side of the offices';
  @override
  String get missionFindSupplies => 'Find some supplies in the city';
  @override
  String get missionFindValuable =>
      'Look for something valuable for Tonino and Marcello';
  @override
  String get missionDiscoverColosseum =>
      'Find out what is going on at the Colosseum';
  @override
  String get secretMissions => 'SECRET MISSIONS';
  @override
  String secretMissionRow(String mission) => 'Secret: $mission';
  @override
  String get secretUnarmedToLuigi =>
      "If you dare, restart the level and finish Luigi's story without picking up the pistol";
  @override
  String get secretUnarmedToLuigiShort => 'to Luigi without the pistol';

  // Outfits
  @override
  String get outfitBase => 'Basic';
  @override
  String get outfitCultist => 'Occultist';
  @override
  String get outfitGhost => 'Ghost';
  @override
  String get outfitVampire => 'Vampire';
  @override
  String get outfitJackOLantern => 'Jack-o’-lantern';
  @override
  String get outfitZombie => 'Zombie';

  // Level complete and the figures of the adventure
  @override
  String get levelComplete => 'LEVEL COMPLETE';
  @override
  String get levelCompleteSaveFailed =>
      'The save failed: the game will resume from the last campfire, not from the train.';
  @override
  String get statBackpacks => 'BACKPACKS FOUND';
  @override
  String get statMemories => 'MEMORIES LIVED';
  @override
  String get statCampfires => 'CAMPFIRES FOUND';
  @override
  String get statZombieKinds => 'ZOMBIES KNOWN';
  @override
  String get statKills => 'ZOMBIES KILLED';
  @override
  String get statSteps => 'STEPS TAKEN';
  @override
  String get statsReplayMemories => 'RELIVE THE MEMORIES';
  @override
  String get statsExit => 'EXIT';

  // Screens of the story and the books on the train
  @override
  String get tapToRead => 'Tap to read';
  @override
  String get skip => 'SKIP';
  @override
  String get close => 'CLOSE';
  @override
  String get zombieBookUnmet => 'You have not met this zombie yet.';

  // The intro story, the night of the outbreak and Rome's
  @override
  String get speakerNewsreader => 'Newsreader';
  @override
  String get speakerHostess => 'Flight attendant';
  @override
  String get speakerGeneral => 'General';
  @override
  String get speakerPrimeMinister => 'Prime Minister';
  @override
  String get speakerSecretary => 'Secretary';
  @override
  String get introNewsFlash =>
      'Attention, we interrupt our programmes for a special news bulletin';
  @override
  String get introBlackout => "... What's going on? ... Guys, the lights?";
  @override
  String get introScream => 'Aaaaahhh!';
  @override
  String get outbreakNight =>
      'That night thousands of people everywhere turned into zombies, undead creatures with no mind of their own, interested only in devouring other human beings';
  @override
  String get outbreakPlaneHelp => 'Help, captain! Help!';
  @override
  String get outbreakPlaneCaptain => 'Captain?';
  @override
  String get outbreakCollapse =>
      'That night the whole of human civilisation collapsed because of this evil and mysterious threat';
  @override
  String get romeGeneralReinforcements =>
      'Prime Minister, we need reinforcements!';
  @override
  String get romePresidentNoForces =>
      'Impossible, all our forces are already committed';
  @override
  String get romeGeneralHundreds =>
      "Sir, we're in deep shit here, there are hundreds and hundreds of these bastard zombies";
  @override
  String get romePresidentAlone =>
      "General, I've no choice, you'll have to manage on your own";
  @override
  String get romeSecretaryDoubt =>
      "Prime Minister, are you sure about what you're doing?";
  @override
  String get romePresidentBunker =>
      "Don't worry, Petunia, those reinforcements are there to protect my bunker";
  @override
  String get romeSecretaryDying =>
      'But... but Prime Minister, those people out there are dying...';
  @override
  String get romePresidentPetulant =>
      "Petunia, don't be petulant or I won't take you to the bunker";
  @override
  String get romePresidentAttacked => 'Oh God help! Petunia, heeelp!';

  // Zombies: the name in the book, the lesson the first time one is met
  // and the card in the book
  @override
  String zombieName(EntityKind kind) => switch (kind) {
    EntityKind.wanderer => 'Wanderer',
    EntityKind.carabiniere => 'Carabiniere',
    EntityKind.sprinter => 'Sprinter',
    EntityKind.mutilated => 'Mutilated',
    EntityKind.burning => 'Burning',
    EntityKind.drunk => 'Drunk',
    EntityKind.cultist => 'Cultist',
    EntityKind.brute => 'Brute',
    EntityKind.callCenter => 'Call centre',
    EntityKind.blind => 'Blind',
    _ => '',
  };
  @override
  String zombieLesson(EntityKind kind) => switch (kind) {
    EntityKind.wanderer =>
      'Ordinary wandering zombies take one step towards you for every two of yours',
    EntityKind.carabiniere =>
      'Carabiniere zombies can reach you from two cells away with their baton',
    EntityKind.sprinter => 'Sprinter zombies move as fast as you do',
    EntityKind.mutilated =>
      'Mutilated zombies cannot chase you, but if you walk past them they bite you at every step you take. Give them a wide berth, or take them down if they block your way',
    EntityKind.burning =>
      'Burning zombies move like wanderers, but every cell they leave catches fire and you will never be able to cross it again',
    EntityKind.drunk =>
      'Drunk zombies stagger about at random and do not chase you, but if you end up next to them they bite. Careful: the next stagger may bring one right to you',
    EntityKind.cultist =>
      'Cultist zombies move like wanderers, but their muscle mass takes three pistol shots to bring them down',
    EntityKind.brute =>
      'Brute zombies are very slow, one step for every three of yours, but it takes two pistol shots to bring them down',
    EntityKind.callCenter =>
      'Call centre zombies are as fast as you, but the cord of their handset keeps them tied to their desk: they cannot follow you past the length of the cord',
    _ => '',
  };
  @override
  String zombieDescription(EntityKind kind) => switch (kind) {
    EntityKind.wanderer =>
      'The most common kind: until recently it was an ordinary person. Slow and clumsy, it takes one step for every two of yours. Alone it is easy to avoid; in a group it cuts off your way.',
    EntityKind.carabiniere =>
      'It still wears the uniform and grips its baton: it hits you from up to two cells away. It moves like a wanderer, but do not let it come close.',
    EntityKind.sprinter =>
      'It moves as fast as you do: running will not shake it off. It sees and hears you from further away than the others.',
    EntityKind.mutilated =>
      'It has lost its legs and will never get up from where it fell. It does not chase you, but it is as alert as a sprinter: walk past it and it bites you at every step. Keep it two cells away, or shoot it if it blocks the way.',
    EntityKind.burning =>
      'It burns without burning out. As slow as a wanderer, but every cell it moves off stays on fire for good: nobody can cross it again, not even the zombie. Take it down before it cuts off your way back.',
    EntityKind.drunk =>
      "It was already drunk when it turned, and it still is. It keeps staggering in a random direction, at a wanderer's pace, whether it has seen you or not. It does not chase you, but end up next to it and the bite comes straight away.",
    EntityKind.cultist =>
      "The mutation has swollen its body beyond the robe: the hood has fallen onto its shoulders, the clothes have torn and unnatural yellow veins run along its arms. It walks at a wanderer's pace, but the first two shots are not enough: it takes three to bring it down.",
    EntityKind.brute =>
      'A giant even before it turned, and the mutation has swollen it further. It takes one step for every three of yours and can barely see, but it hears the faintest noise from far away. The first shot does not stop it: it takes two.',
    EntityKind.callCenter =>
      'It died with its headset on, halfway through a call, and it will not let go of the handset. It lunges as fast as you, but the cord keeps it tied to its desk: it stretches towards you as far as the cord allows, then stays there pulling. Keep far enough away, or shoot it before you walk past.',
    _ => '',
  };

  // Error, unfinished roads, the Europe map, the tutorial's opening
  @override
  String get errorTitle => 'SOMETHING WENT WRONG';
  @override
  String get errorExplanation =>
      'The game stopped because of an error. The report says which one, along with the game version, the phone, the last steps of the game and the save in the slot: nothing personal. Send it to the developer, then go back to the menu to resume from the last save.';
  @override
  String get errorExplanationSent =>
      'The game stopped because of an error. The report, with the game version, the phone, the last steps of the game and the save in the slot (nothing personal), goes to the developer on its own, later if there is no network now. Go back to the menu to resume from the last save.';
  @override
  String get errorSharing => 'ONE MOMENT…';
  @override
  String get errorBackToMenu => 'BACK TO THE MENU';
  @override
  String get workInProgressTitle =>
      'The demo ends here,\nwhat comes next is still to be programmed';
  @override
  String get workInProgressMissingItems =>
      'These items are not in the game yet:\nFire extinguisher, Crowbar';
  @override
  String get workInProgressFeedback => 'Let me know if you like the game';
  @override
  String get mapMolfetta => 'MOLFETTA';
  @override
  String get levelNorthCape => 'North Cape';
  @override
  String get mapChooseDestination => 'CHOOSE YOUR DESTINATION';
  @override
  String get mapStartLevel => 'START LEVEL';
  @override
  String get tutorialChaos =>
      'The city is in total chaos! I have to find some way to get to safety';
  @override
  String get tutorialMove =>
      'Drag your finger on the left side of the screen to move';

  // The controls and what Mario carries
  @override
  String get actionZoneHint =>
      'Tap to interact, hold and drag to aim, let go to shoot or throw';
  @override
  String get moveZoneHint => 'Drag to move';
  @override
  String get menuButton => 'Menu';
  @override
  String get itemIncense => 'Incense';
  @override
  String get itemIncenseLabel => 'Incense for Don Angelo';
  @override
  String get itemBarKey => 'Key of the Bar Arcobaleno';
  @override
  String get itemEpiscopalRing => 'Episcopal ring';
  @override
  String get itemDuomoKey => 'Key of the Duomo';
  @override
  String get itemPalazzoKey => 'Key of the third floor';
  @override
  String get itemGrapplingHook => 'Grappling hook';
  @override
  String get itemGoldIngot => 'Gold ingot';
  @override
  String get itemColosseumTicket => 'Colosseum ticket';
  @override
  String get pistol => 'Pistol';
  @override
  String get goldenPistol => 'Golden pistol';
  @override
  String pistolMissing(String pistol, int rounds) =>
      '$pistol still to find, bullets: $rounds';
  @override
  String pistolInHand(String pistol, int rounds) =>
      '$pistol in hand, bullets: $rounds';
  @override
  String pistolToTake(String pistol, int rounds) =>
      '$pistol, bullets: $rounds, tap to take it';
  @override
  String molotovInHand(int count) => 'Molotov in hand: $count';
  @override
  String molotovToTake(int count) => 'Molotovs: $count, tap to take one';
  @override
  String launcherMissing(int rounds) =>
      'Rocket launcher still to find, rounds: $rounds';
  @override
  String launcherInHand(int rounds) =>
      'Rocket launcher in hand, rounds: $rounds';
  @override
  String launcherToTake(int rounds) =>
      'Rocket launcher, rounds: $rounds, tap to take it';
  @override
  String bulletsLeft(int rounds) =>
      rounds == 1 ? '1 bullet' : '$rounds bullets';
  @override
  String molotovsLeft(int count) =>
      count == 1 ? '1 molotov' : '$count molotovs';
  @override
  String rocketsLeft(int rounds) => rounds == 1
      ? '1 rocket launcher round'
      : '$rounds rocket launcher rounds';

  // Saving at a campfire, or at the table aboard
  @override
  String get saved => 'Game saved';
  @override
  String get campfireSaveFailed =>
      'The save failed. Rest by the fire again to retry';
  @override
  String get mealSaveFailed => 'The save failed. Go back to the table to retry';

  // The story, place by place (lib/game/story/scripts/)
  @override
  String backpacksBulletsFound(int rounds) =>
      rounds == 1 ? 'You found 1 bullet' : 'You found $rounds bullets';
  @override
  String backpacksMolotovsFound(int count) =>
      count == 1 ? 'You found 1 molotov' : 'You found $count molotovs';
  @override
  String backpacksRocketsFound(int rounds) => rounds == 1
      ? 'You found 1 rocket launcher round'
      : 'You found $rounds rocket launcher rounds';
  @override
  String get backpacksAimLesson =>
      'Hold down on the right side of the screen to start aiming';
  @override
  String get backpacksBackpackLesson =>
      'Pick up the backpacks lying around to find new gear';
  @override
  String get backpacksCancelLesson =>
      'You can cancel a pistol shot without wasting bullets by lifting your finger while in the centre spot';
  @override
  String get backpacksDuomoKeyFound =>
      "You found the Key of the Duomo next to Don Angelo's body";
  @override
  String get backpacksFireLesson =>
      'While holding, drag in a direction: the shot goes off as soon as you lift your finger';
  @override
  String get backpacksGoldIngotFound => 'You found a gold ingot';
  @override
  String get backpacksGoldIngotThought =>
      "This will do for those two thugs. I can't think of anything else to do with it";
  @override
  String get backpacksGrapplingHookFound => 'You found a grappling hook';
  @override
  String get backpacksGrapplingHookLesson =>
      'With the grappling hook you can reach nearby rooftops you could not get to before';
  @override
  String get backpacksGunFound => 'You found a pistol';
  @override
  String get backpacksIncenseFound => 'You found some incense';
  @override
  String get backpacksInteractLesson =>
      'Tap the right side of the screen to interact with nearby objects';
  @override
  String get backpacksMolotovLesson => 'Molotovs deal area damage';
  @override
  String get backpacksNoGun => 'You do not have a pistol';
  @override
  String get backpacksNoRocketLauncher => 'You do not have a rocket launcher';
  @override
  String get backpacksPalazzoKeyFound => 'You found the Key of the third floor';
  @override
  String get backpacksRingFound => 'You found an episcopal ring';
  @override
  String get backpacksRocketLauncherFound => 'You found a rocket launcher';
  @override
  String get backpacksRocketLauncherLesson =>
      'The rocket flies straight to the wall and hits every zombie in its path, 3 damage each';
  @override
  String get backpacksRocketRoundsLesson =>
      'Rounds for the rocket launcher are found in backpacks, like bullets';
  @override
  String get backpacksWeaponChoiceLesson =>
      'You can hold one weapon at a time: tap the weapon you want to hold among the items in your inventory. The flames show the active weapon';
  @override
  String get barKeyUsedLine => 'You used the key to open the door';
  @override
  String get barLockedDoorLine => 'This door is locked. You need a key';
  @override
  String get barracksBarracksReached =>
      'There, I made it! The carabinieri barracks';
  @override
  String get barracksBarracksSafe => 'Will this be a safe place?';
  @override
  String get companyCallFrames1 =>
      "Come on, come on, let's hope at least this one picks up";
  @override
  String get companyCallFrames2 => 'Uuh ?';
  @override
  String get companyCallFrames3 =>
      "Hello, I'm calling on behalf of NoSignal Mobile, I'd like to offer you our Moral Fibre plan at a truly great price";
  @override
  String get companyCallFrames4 => 'Aaaarggh !';
  @override
  String get companyCallFrames5 => 'What kind of manners are these?! How rude!';
  @override
  String get companyCallFrames6 =>
      'Good grief... Nowadays nobody has a brain any more...';
  @override
  String get companyMeetingFrames1 => 'Hey, what are you doing here?';
  @override
  String get companyMeetingFrames2 => "I've got some overtime to make up";
  @override
  String get companyMeetingFrames3 =>
      "Ma'am, there's a zombie apocalypse going on!";
  @override
  String get companyMeetingFrames4 =>
      "So that's why I couldn't close a single deal any more";
  @override
  String get companySeeYouThere => 'See you at the station then...';
  @override
  String get companySendToStation =>
      "Ma'am, go to the station, there are other survivors there";
  @override
  String get damagedDoorLine =>
      'This door is a bit damaged, with a crowbar you could force it open';
  @override
  String get duomoAreYouMadLine => 'What are you doing? Are you mad?!';
  @override
  String get duomoFamilyWelcomeLine =>
      'Excellent, young man, you truly are a prodigy! Welcome to our great family';
  @override
  String get duomoInitiationReminderLine =>
      'Put on the robe and get ready for your initiation ceremony';
  @override
  String get duomoKeyUsedLine =>
      'You used the Key of the Duomo to open the door';
  @override
  String get duomoLetMeGoLine => 'No, let me go! Nooo';
  @override
  String get duomoLockedDoorLine => 'This door is locked. You need a key';
  @override
  String get duomoMassSermonLine =>
      'The Lord has sent this calamity against mankind, yet it is still the work of the Lord and its purpose is to purify the world';
  @override
  String get duomoMassWelcomeLine =>
      'We are all ready to begin, young man, please take a seat!';
  @override
  String get duomoOutfitChangedLine =>
      'Mario changes his clothes on his way out of the Duomo';
  @override
  String get duomoOutfitObtainedLine => 'You got the occultist outfit.';
  @override
  String get duomoRingReminderLine =>
      'Have you not recovered the episcopal ring yet?';
  @override
  String get duomoRobeFoundLine => 'You found an occultist robe';
  @override
  String get duomoRobeLine =>
      'We have prepared a robe for you too, you will find it upstairs';
  @override
  String get duomoStairBlockedLine =>
      'You may pass here only when you too are truly part of our community';
  @override
  String get duomoSuperZombieLine =>
      "One bite of theirs is enough to turn a man into a zombie, and you're eating them... This is turning you into super zombies";
  @override
  String get duomoWardrobeLaterLine =>
      'Later on you will be able to choose which outfit to wear.';
  @override
  String get duomoWardrobeOnTrainLine =>
      'You can choose which outfit to wear on the train.';
  @override
  String get duomoWelcomeLine => 'How lovely to see new faithful joining us';
  @override
  String get duomoWorshipLine =>
      'The zombie is not to be feared. The zombie is to be worshipped. Through our prayer the zombies will save us';
  @override
  String get electronicsOpenFromInsideLine => 'Open the door from the inside';
  @override
  String get electronicsShutterDownLine =>
      'The shutter is down. It does not open from the outside';
  @override
  String get journeyCarryLines1 =>
      'Ammunition and consumable items, such as bullets or molotovs, cannot be carried from one level to the next';
  @override
  String get journeyCarryLines2 =>
      'Items that are not used up, on the other hand, such as the pistol or the grappling hook, can be carried across levels';
  @override
  String get mallHelpCall => 'Help! Is anybody there?! Heeelp';
  @override
  String get mallLuigiScene1 =>
      'My name is Luigi. I got stuck in here because of the alarm system';
  @override
  String get mallLuigiScene2 => 'Watch out! Behind you';
  @override
  String get mallLuigiScene3 => 'Aaaahhrg!';
  @override
  String get mallMeetAtStationLine =>
      "Meet me at the station, we'll talk about it there!";
  @override
  String get mallReunionScene1 =>
      "You did it, kid! Now I'll deal with these ones myself";
  @override
  String get mallReunionScene2 =>
      "I'm glad to see there's someone else alive and kicking";
  @override
  String get mallReunionScene3 =>
      "You're telling me! Finally someone who isn't trying to eat my brain";
  @override
  String get mallShutterOpened =>
      'You switched off the alarm system: the shutter went up';
  @override
  String get mallSomeoneAlive => "Hey, there's somebody still alive in here!";
  @override
  String get mallTrustLine =>
      "Kid, I've decided to trust you! I'll tell you about my big plan for not kicking the bucket";
  @override
  String get maranzaMarcelloAfter => 'See ya at the Colosseum bruv';
  @override
  String get maranzaMeetingScene1 => 'Oi bruv, you ain’t dead, are ya?';
  @override
  String get maranzaMeetingScene2 => 'Wanna get through here? This is our turf';
  @override
  String get maranzaMeetingScene3 => 'What do you want?';
  @override
  String get maranzaMeetingScene4 =>
      'Come on bruv, you know... Something precious, something valuable!';
  @override
  String get maranzaMeetingScene5 =>
      "But what would you do with it? We're in the middle of the zombie apocalypse!";
  @override
  String get maranzaMeetingScene6 =>
      'Bruv, as long as there are at least two people left on Earth, having valuable stuff will always come in handy';
  @override
  String get maranzaPaidScene1 =>
      'Nice one bruv, this is exactly what I meant by something precious!';
  @override
  String get maranzaPaidScene2 =>
      'We like you bruv, here, this is a ticket for the Colosseum';
  @override
  String get maranzaPaidScene3 =>
      'The Colosseum? Do they still run guided tours there?';
  @override
  String get maranzaPaidScene4 =>
      'Guided tours!? Hehehe nothing like that bruv, you’ll see...';
  @override
  String get maranzaToninoAfter =>
      'Now we gotta figure out what to do with this ingot';
  @override
  String get maranzaWarnings1 =>
      'Bruv, you better come back with something valuable for us';
  @override
  String get maranzaWarnings2 =>
      'Come back empty-handed and you’re getting a slap';
  @override
  String get northDistrictCampLesson =>
      'Interact with the campfires to save the game';
  @override
  String get palazzoKeyUsedLine =>
      'You used the Key of the third floor to open the door';
  @override
  String get palazzoLockedDoorLine =>
      'This door is locked. One of the neighbours must have the key';
  @override
  String get priestBarKeyLine =>
      'Use this key to open a door in the Bar Arcobaleno on the harbour, there you will find my episcopal ring';
  @override
  String get priestClearThemOut =>
      'Get rid of these zombies so we can talk properly';
  @override
  String get priestDealScene1 => 'Here I am, Father, open the gate';
  @override
  String get priestDealScene2 => 'First you will have to do something for us';
  @override
  String get priestDealScene3 =>
      "What?! But it's dangerous out here, Father...";
  @override
  String get priestDealScene4 =>
      'Young man, do you think I would still be alive if I let just anyone into my church now?';
  @override
  String get priestEveryTwoStreetsLine =>
      'Come now, young man, we are in Italy! In the old towns you find a church every other street';
  @override
  String get priestIncenseLine =>
      'Bring me some incense, I need it for my ceremonies';
  @override
  String get priestMeetingScene1 =>
      'Ohh what a pleasure to see someone still alive strolling about our harbour';
  @override
  String get priestMeetingScene2 =>
      "You're alive?! You found safety here in the church?";
  @override
  String get priestMeetingScene3 =>
      'Young man, the church is always the first place to seek salvation';
  @override
  String get priestMoreWorkLine =>
      'Ah... I suppose you expect me to do more for you';
  @override
  String get priestNotCommunityYetLine =>
      'Now you may come in here, but you are not yet truly part of our community';
  @override
  String get priestUseYourSkillsLine =>
      'Young man, you seem so good at getting around the desolate city, it would be a shame not to make use of your talents';
  @override
  String get priestWelcomeLine =>
      'Excellent, young man, well done! Welcome to our church';
  @override
  String get priestWhereLine => 'Where am I supposed to find incense?!';
  @override
  String get roadblockFireLine =>
      'The fire blocks the road completely, you could get through with an extinguisher';
  @override
  String get romeArrivalLines1 => 'As the saying goes: all roads lead to Rome';
  @override
  String get romeArrivalLines2 =>
      "Let's make a short stop here: I'll look around for some fuel and you go and find some supplies, we'll need plenty to reach our destination";
  @override
  String get rooftopsGapLesson =>
      'The next roof is not far away, you can reach it with a grappling hook';
  @override
  String get rooftopsGrappleLine => 'Mario uses the grappling hook';
  @override
  String get speakerCultist => 'Cultist';
  @override
  String get speakerMysteryVoice => 'Mysterious voice';
  @override
  String get speakerZombie => 'Zombie';
  @override
  String get stationGoldenPistolGift =>
      "Hey, you've got no weapon on you? Here, take this";
  @override
  String get stationGoldenPistolLesson =>
      'The golden pistol deals double damage';
  @override
  String get stationLockedDoorLine => 'The door is locked';
  @override
  String get stationReunionScene1 => 'There you are, kid, you finally made it!';
  @override
  String get stationReunionScene2 =>
      'So what would your plan be? What do you want to do with this train?';
  @override
  String get stationReunionScene3 => 'Get out of here, obviously!';
  @override
  String get stationReunionScene4 => 'Yes, but where to?';
  @override
  String get stationReunionScene5 =>
      'Our destination is North Cape, kid. In Norway';
  @override
  String get stationReunionScene6 =>
      "The zombies can't get there, the cold keeps them away";
  @override
  String get streetZombieSpotted => 'Shit, a zombie! Better get out of here';
  @override
  String get trainChiaraHometownLines1 =>
      'We have to go all the way to Norway? That sounds like a hell of a trip';
  @override
  String get trainChiaraRomeLines1 => 'What?! You had never been to Rome?';
  @override
  String get trainChiaraRomeLines2 =>
      "It's the eternal city, you find yourself among the Roman ruins without even noticing";
  @override
  String get trainCotLine =>
      'Look back on the adventure: figures, missions and memories';
  @override
  String get trainLuigiLine =>
      "It's going to be a very tough journey across Europe";
  @override
  String get trainRomeLines1 => 'All roads lead to Rome, kid';
  @override
  String get trainRomeLines2 => 'What? You say I already said that?';
  @override
  String get trainWardrobeLine => 'Choose which outfit to wear';
  @override
  String get trainZombieNotes => 'Notes on the zombies met so far';
  @override
  String trainAmmoFull(int rounds, {required bool rocketLauncher}) =>
      'You already have enough ammunition. Come back here when you have '
      'fewer than $rounds bullets${rocketLauncher ? ' or 1 rocket' : ''} '
      'to reload';
  @override
  String trainAmmoRefilled(int rounds, {required bool rocketLauncher}) =>
      'Ammunition refilled. Come back here any time you have fewer than '
      '$rounds bullets${rocketLauncher ? ' or 1 rocket' : ''} to reload';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _restartFrom({required bool fromStory}) => fromStory
    ? 'you start again from the first scene of the story. The other cities stay as they are.'
    : 'you start again from your arrival in town. The other cities stay as they are.';
