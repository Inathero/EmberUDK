class EmberGameInfo extends UTGame; 

//=============================================
// Global Vars
//=============================================
var int pawnsActiveOnPlayer;

var struct AttackPacketStruct
{
	var name AnimName;
	var array<float> Mods;
	var float tDur;
	var bool isActive;
} AttackPacket;
var int counterForPawns;
/*
AddDefaultInventory
  Reenable if we need to create inventories
*/
function AddDefaultInventory( pawn PlayerPawn )
{
	PlayerPawn.AddDefaultInventory();

}
// function PostBeginPlay()
// {
//   Super.PostBeginPlay();

//   // Set the timer which broad casts a random message to all players
//   SetTimer(1.f, true, 'RandomBroadcast');
// }

event InitGame( string Options, out string ErrorMessage )
{
    super.InitGame(Options, ErrorMessage);
	// `log("INITGAME");
 //    InOpt = ParseOption(Options, "MyTeam");
 //    if(InOpt != "")
 //        MyTeam = int(InOpt);
	// `log("MyTeamINIT" @MyTeam);
}
// function PlayerStart ChoosePlayerStart( Controller Player, optional byte InTeam )
// {
// 	local PlayerStart P, BestStart;
// 	foreach WorldInfo.AllNavigationPoints(class'PlayerStart', P)
// 		{
// 			PlayerStartPointsUsed.AddItem(P);
// 		}
// 		if(MyTeam == 1)
// 			BestStart = PlayerStartPointsUsed[0];
		
// 		else
// 			BestStart = PlayerStartPointsUsed[1];

// 		return BestStart;
// }
event PostLogin(PlayerController NewPlayer)
{
		local UTPlayerController PC;
	local UTGameReplicationInfo GRI;

	Super.PostLogin(NewPlayer);

	PC = UTPlayerController(NewPlayer);
	if (PC != None)
	{
		PC.PlayStartUpMessage(StartupStage);
		PC.ClientSetSpeechRecognitionObject(SpeechRecognitionData);

		GRI = UTGameReplicationInfo(GameReplicationInfo);
		if ( bForceMidGameMenuAtStart && !GRI.bStoryMode && !GRI.bMatchHasBegun && (NetWait - PendingMatchElapsedTime > 5) )
		{
			UTPlayerReplicationInfo(PC.PlayerReplicationInfo).ShowMidGameMenu(true);
		}
	}

	//Custom Ember Function.
	//Loads a current status of all pawns
	// EmberPlayerController(PC).GetLoadedPawnInformation();

	//@hack: unfortunately the character construction process requires game tick so we can't be paused while
	// clients are doing it or they will appear to hang on the loading screen
	Pausers.length = 0;
	WorldInfo.Pauser = None;
}
/*
RestartPlayer

*/
function RestartPlayer(Controller aPlayer)
{
	local EmberPlayerController PC;
super.RestartPlayer(aPlayer);
	// foreach WorldInfo.AllControllers(class'EmberPlayerController', PC)
	// {
	// 	PC.DebugPrint("yo");
	// }
if(aPlayer.bIsPlayer)
Broadcast(self, "player spawn"@aPlayer);
if(aPlayer.pawn ==none)
{
Broadcast(self, "no pawn spawn spot for "$aPlayer);
return;
}
	//Find all local pawns
	// ForEach WorldInfo.AllPawns(class'EmberPawn', Receiver) 
	// {
	// 	//Tell players to fix light enviro for new pawn
	// 	Receiver.ServerSetupLightEnvironment();
 //    }

// EmberPlayerController(aPlayer).SaveMeshValues();
}


// function RandomBroadcast()
// {
//   local EmberPlayerController PlayerController;
//   local EmberPawn pawn;
//   local string BroadcastMessage;

//   if (WorldInfo != None)
//   {
//     // Constuct a random text message
//     for (i = 0; i < 32; ++i)
//     {
//       BroadcastMessage $= Chr(Rand(255));
//     }

//     ForEach WorldInfo.AllControllers(class'EmberPlayerController', PlayerController)
//     {
//       pawn = EmberPawn(PlayerController.pawn);
//       pawn.ClientAttackAnimReplication(BroadcastMessage);
//     }
//   }
// }


 static event class<GameInfo> SetGameType(string MapName, string Options, string Portal)
{
	return Default.Class;
}

 defaultproperties

{
// bRestartLevel =false;
	pawnsActiveOnPlayer = 0
	counterForPawns = 0;
	bUseClassicHUD=true
	// bNoCollisionFail=true
   DefaultPawnClass=class'EmberProject.EmberPawn'
   PlayerControllerClass=class'EmberProject.EmberPlayerController'
  PlayerReplicationInfoClass=class'EmberProject.EmberReplicationInfo'
   // HUDType=class'EmberProject.EmberHUD'
	HUDType=class'EmberProject.EmberHudWrapper'
   MapPrefixes[0]="UDN"
   bDelayedStart = false
   // DefaultInventory(0)=none
}