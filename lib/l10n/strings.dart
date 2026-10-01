// Every word the game shows, as each language says it: see
// lib/l10n/language.dart. The Italian (it.dart) is the original; every
// language implements this whole interface, so the compiler names any line
// a new one has left out.
//
// Kept in step with it.dart: a new line is added there, here and in every
// other language.

import 'package:stepbound/core/core.dart';

/// Every word the game shows, in one language.
abstract interface class Strings {
  // Shared by many screens
  String get back;
  String get no;
  String get ok;
  String get shareReport;
  String get continueLabel;
  String get tapToContinue;
  String date(DateTime time);

  // Main menu
  String get menuDisclaimer;
  String get menuNewGame;
  String get menuLoadGame;
  String get menuAudioOn;
  String get menuAudioOff;
  String get menuLanguage;
  String get menuCredits;
  String get menuChooseNewSlot;
  String get menuChooseSave;
  String menuOverwrite(int slot);
  String get menuSlotEmpty;
  String get menuSlotDamaged;
  String get menuSlotBackup;
  String get menuSlotSuspended;
  String get menuGift;
  String menuSkin(String name);
  String get menuLinkExpired;
  String get menuLinkInvalid;
  String get creditsMusic;
  String get creditsAttribution;
  String get creditsEffects;

  // Pause menu and game over
  String get restartLevel;
  String get yesRestart;
  String get resumeCampfire;
  String get resumeCampfireConfirm;
  String get resumeCampfireCost;
  String get resumeTrain;
  String get resumeTrainConfirm;
  String get resumeTrainCost;
  String get quitSinceCampfireCost;
  String get quitSinceTrainCost;
  String get quitUnsavedCost;
  String get pauseRestartFromArrivalCost;
  String get pauseRestartFromStoryCost;
  String get pauseBackToGame;
  String get pauseToMainMenu;
  String get pauseYesQuit;
  String get outfitWorn;
  String get outfitWear;
  String get outfitLocked;
  String get gameOver;
  String get gameOverMainMenu;
  String gameOverRestartCampfireCost({required bool fromStory});
  String gameOverRestartTrainCost({required bool fromStory});

  // Loading
  String get levelHometown;
  String get levelRome;
  String get loadingGame;
  String get loadingTutorial;

  // Places, as the maps name them: only the names a language says
  // otherwise, the others (proper names) are shown as they are
  Map<String, String> get placeNames;

  // Missions
  String get missions;
  String get missionFindSurvivors;
  String get missionFreeLuigi;
  String get missionReachLuigi;
  String get missionClearGate;
  String get missionFindIncense;
  String get missionFindRing;
  String get missionInitiation;
  String get missionExploreTerraces;
  String get missionReachSurvivor;
  String get missionFindSupplies;
  String get missionFindValuable;
  String get missionDiscoverColosseum;
  String get secretMissions;
  String secretMissionRow(String mission);
  String get secretUnarmedToLuigi;
  String get secretUnarmedToLuigiShort;

  // Outfits
  String get outfitBase;
  String get outfitCultist;
  String get outfitGhost;
  String get outfitVampire;
  String get outfitJackOLantern;
  String get outfitZombie;

  // Level complete and the figures of the adventure
  String get levelComplete;
  String get levelCompleteSaveFailed;
  String get statBackpacks;
  String get statMemories;
  String get statCampfires;
  String get statZombieKinds;
  String get statKills;
  String get statSteps;
  String get statsReplayMemories;
  String get statsExit;

  // Screens of the story and the books on the train
  String get tapToRead;
  String get skip;
  String get close;
  String get zombieBookUnmet;

  // The intro story, the night of the outbreak and Rome's
  String get speakerNewsreader;
  String get speakerHostess;
  String get speakerGeneral;
  String get speakerPrimeMinister;
  String get speakerSecretary;
  String get introNewsFlash;
  String get introBlackout;
  String get introScream;
  String get outbreakNight;
  String get outbreakPlaneHelp;
  String get outbreakPlaneCaptain;
  String get outbreakCollapse;
  String get romeGeneralReinforcements;
  String get romePresidentNoForces;
  String get romeGeneralHundreds;
  String get romePresidentAlone;
  String get romeSecretaryDoubt;
  String get romePresidentBunker;
  String get romeSecretaryDying;
  String get romePresidentPetulant;
  String get romePresidentAttacked;

  // Zombies: the name in the book, the lesson the first time one is met
  // and the card in the book
  String zombieName(EntityKind kind);
  String zombieLesson(EntityKind kind);
  String zombieDescription(EntityKind kind);

  // Error, unfinished roads, the Europe map, the tutorial's opening
  String get errorTitle;
  String get errorExplanation;
  String get errorSharing;
  String get errorBackToMenu;
  String get workInProgressTitle;
  String get workInProgressMissingItems;
  String get workInProgressFeedback;
  String get mapMolfetta;
  String get levelNorthCape;
  String get mapChooseDestination;
  String get mapStartLevel;
  String get tutorialChaos;
  String get tutorialMove;

  // The controls and what Mario carries
  String get actionZoneHint;
  String get moveZoneHint;
  String get menuButton;
  String get itemIncense;
  String get itemIncenseLabel;
  String get itemBarKey;
  String get itemEpiscopalRing;
  String get itemDuomoKey;
  String get itemPalazzoKey;
  String get itemGrapplingHook;
  String get itemGoldIngot;
  String get itemColosseumTicket;
  String get pistol;
  String get goldenPistol;
  String pistolMissing(String pistol, int rounds);
  String pistolInHand(String pistol, int rounds);
  String pistolToTake(String pistol, int rounds);
  String molotovInHand(int count);
  String molotovToTake(int count);
  String launcherMissing(int rounds);
  String launcherInHand(int rounds);
  String launcherToTake(int rounds);
  String bulletsLeft(int rounds);
  String molotovsLeft(int count);
  String rocketsLeft(int rounds);

  // Saving at a campfire, or at the table aboard
  String get saved;
  String get campfireSaveFailed;
  String get mealSaveFailed;

  // The story, place by place (lib/game/story/scripts/)
  String backpacksBulletsFound(int rounds);
  String backpacksMolotovsFound(int count);
  String backpacksRocketsFound(int rounds);
  String get backpacksAimLesson;
  String get backpacksBackpackLesson;
  String get backpacksCancelLesson;
  String get backpacksDuomoKeyFound;
  String get backpacksFireLesson;
  String get backpacksGoldIngotFound;
  String get backpacksGoldIngotThought;
  String get backpacksGrapplingHookFound;
  String get backpacksGrapplingHookLesson;
  String get backpacksGunFound;
  String get backpacksIncenseFound;
  String get backpacksInteractLesson;
  String get backpacksMolotovLesson;
  String get backpacksNoGun;
  String get backpacksNoRocketLauncher;
  String get backpacksPalazzoKeyFound;
  String get backpacksRingFound;
  String get backpacksRocketLauncherFound;
  String get backpacksRocketLauncherLesson;
  String get backpacksRocketRoundsLesson;
  String get backpacksWeaponChoiceLesson;
  String get barKeyUsedLine;
  String get barLockedDoorLine;
  String get barracksBarracksReached;
  String get barracksBarracksSafe;
  String get companyCallFrames1;
  String get companyCallFrames2;
  String get companyCallFrames3;
  String get companyCallFrames4;
  String get companyCallFrames5;
  String get companyCallFrames6;
  String get companyMeetingFrames1;
  String get companyMeetingFrames2;
  String get companyMeetingFrames3;
  String get companyMeetingFrames4;
  String get companySeeYouThere;
  String get companySendToStation;
  String get damagedDoorLine;
  String get duomoAreYouMadLine;
  String get duomoFamilyWelcomeLine;
  String get duomoInitiationReminderLine;
  String get duomoKeyUsedLine;
  String get duomoLetMeGoLine;
  String get duomoLockedDoorLine;
  String get duomoMassSermonLine;
  String get duomoMassWelcomeLine;
  String get duomoOutfitChangedLine;
  String get duomoOutfitObtainedLine;
  String get duomoRingReminderLine;
  String get duomoRobeFoundLine;
  String get duomoRobeLine;
  String get duomoStairBlockedLine;
  String get duomoSuperZombieLine;
  String get duomoWardrobeLaterLine;
  String get duomoWardrobeOnTrainLine;
  String get duomoWelcomeLine;
  String get duomoWorshipLine;
  String get electronicsOpenFromInsideLine;
  String get electronicsShutterDownLine;
  String get journeyCarryLines1;
  String get journeyCarryLines2;
  String get mallHelpCall;
  String get mallLuigiScene1;
  String get mallLuigiScene2;
  String get mallLuigiScene3;
  String get mallMeetAtStationLine;
  String get mallReunionScene1;
  String get mallReunionScene2;
  String get mallReunionScene3;
  String get mallShutterOpened;
  String get mallSomeoneAlive;
  String get mallTrustLine;
  String get maranzaMarcelloAfter;
  String get maranzaMeetingScene1;
  String get maranzaMeetingScene2;
  String get maranzaMeetingScene3;
  String get maranzaMeetingScene4;
  String get maranzaMeetingScene5;
  String get maranzaMeetingScene6;
  String get maranzaPaidScene1;
  String get maranzaPaidScene2;
  String get maranzaPaidScene3;
  String get maranzaPaidScene4;
  String get maranzaToninoAfter;
  String get maranzaWarnings1;
  String get maranzaWarnings2;
  String get northDistrictCampLesson;
  String get palazzoKeyUsedLine;
  String get palazzoLockedDoorLine;
  String get priestBarKeyLine;
  String get priestClearThemOut;
  String get priestDealScene1;
  String get priestDealScene2;
  String get priestDealScene3;
  String get priestDealScene4;
  String get priestEveryTwoStreetsLine;
  String get priestIncenseLine;
  String get priestMeetingScene1;
  String get priestMeetingScene2;
  String get priestMeetingScene3;
  String get priestMoreWorkLine;
  String get priestNotCommunityYetLine;
  String get priestUseYourSkillsLine;
  String get priestWelcomeLine;
  String get priestWhereLine;
  String get roadblockFireLine;
  String get romeArrivalLines1;
  String get romeArrivalLines2;
  String get rooftopsGapLesson;
  String get rooftopsGrappleLine;
  String get rooftopsNoWayOut;
  String get speakerCultist;
  String get speakerMysteryVoice;
  String get speakerZombie;
  String get stationGoldenPistolGift;
  String get stationGoldenPistolLesson;
  String get stationLockedDoorLine;
  String get stationReunionScene1;
  String get stationReunionScene2;
  String get stationReunionScene3;
  String get stationReunionScene4;
  String get stationReunionScene5;
  String get stationReunionScene6;
  String get streetZombieSpotted;
  String get trainChiaraHometownLines1;
  String get trainChiaraRomeLines1;
  String get trainChiaraRomeLines2;
  String get trainCotLine;
  String get trainLuigiLine;
  String get trainRomeLines1;
  String get trainRomeLines2;
  String get trainWardrobeLine;
  String get trainZombieNotes;
  String trainAmmoFull(int rounds);
  String trainAmmoRefilled(int rounds);
}
