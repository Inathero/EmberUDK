class EmberPlayerController extends UTPlayerController;

//==========
// Network of Death
//----------
struct RepMeshAnimsAssets
{
var SkeletalMesh defaultMesh;
var SkeletalMeshComponent ParentModularComponent;
var MaterialInterface defaultMaterial0;
var MaterialInterface defaultMaterial1;
var AnimTree defaultAnimTree;
var array<AnimSet> defaultAnimSet;
var PhysicsAsset defaultPhysicsAsset; 
var EmberCosmetic_ItemList Cosmetic_ItemList;
};

var repnotify RepMeshAnimsAssets PostBeginCharacterInformation;
var repnotify int updatePlayerMeshes;

//=============================================
// Mesh and Character Variables
//=============================================
var SkeletalMesh defaultMesh;
var MaterialInterface defaultMaterial0;
var MaterialInterface defaultMaterial1;
var AnimTree defaultAnimTree;
var array<AnimSet> defaultAnimSet;
var PhysicsAsset defaultPhysicsAsset;

//=============================================
// Misc Variables
//=============================================

var bool isTethering;
var float      playerStrafeDirection;
var float pitchcc;

//=============================================
// Camera Variables
//=============================================
var bool interpolateForCameraIsActive;
var int allowPawnRotationWhenStationary;
var float pawnRotationDotAngle;

var float interpMovementAttack;
var float interpMovement;
var float interpStationaryAttack;
//=============================================
// Hook Vars
//=============================================
var array<byte> verticalShift;
var bool MouseIsPressed;
//=============================================
// AI Commands
//=============================================
var int ai_followPlayer;
var int ai_attackPlayer;
var float ai_attackPlayerRange;
//=============================================
// Overrided Functions
//=============================================

//Used to not allow duplicate tethers in networking
var byte EPressedStatus;

//Insta-Respawn
state Dead
{
  event Timer()
  {
    super.Timer();
    StartFire();
  }
}


function ReplicateMove
(
  float DeltaTime,
  vector NewAccel,
  eDoubleClickDir DoubleClickMove,
  rotator DeltaRot
)
{
  local SavedMove NewMove, OldMove, AlmostLastMove, LastMove;
  local byte ClientRoll;
  local float NetMoveDelta;

  // do nothing if we are no longer connected
  if (Player == None)
  {
    return;
  }

  MaxResponseTime = Default.MaxResponseTime * WorldInfo.TimeDilation;
  DeltaTime = ((Pawn != None) ? Pawn.CustomTimeDilation : CustomTimeDilation) * FMin(DeltaTime, MaxResponseTime);

  // find the most recent move (LastMove), and the oldest (unacknowledged) important move (OldMove)
  // a SavedMove is interesting if it differs significantly from the last acknowledged move
  if ( SavedMoves != None )
  {
    LastMove = SavedMoves;
    AlmostLastMove = LastMove;
    OldMove = None;
    while ( LastMove.NextMove != None )
    {
      // find first important unacknowledged move
      if ( (OldMove == None) && (Pawn != None) && LastMove.IsImportantMove(LastAckedAccel) )
      {
        OldMove = LastMove;
      }
      AlmostLastMove = LastMove;
      LastMove = LastMove.NextMove;
    }
  }

  // Get a SavedMove object to store the movement in.
  NewMove = GetFreeMove();
  if ( NewMove == None )
  {
    return;
  }
  NewMove.SetMoveFor(self, DeltaTime, NewAccel, DoubleClickMove);

  // Simulate the movement locally.
  bDoubleJump = false;
  ProcessMove(NewMove.Delta, NewMove.Acceleration, NewMove.DoubleClickMove, DeltaRot);

  // see if the two moves could be combined
  if ( (PendingMove != None) && PendingMove.CanCombineWith(NewMove, Pawn, MaxResponseTime) )
  {
    // to combine move, first revert pawn position to PendingMove start position, before playing combined move on client
    Pawn.SetLocation(PendingMove.GetStartLocation());
    Pawn.Velocity = PendingMove.StartVelocity;
    if( PendingMove.StartBase != Pawn.Base )
    {
      Pawn.SetBase(PendingMove.StartBase);
    }
    Pawn.Floor = PendingMove.StartFloor;
    NewMove.Delta += PendingMove.Delta;
    NewMove.SetInitialPosition(Pawn);

    // remove pending move from move list
    if ( LastMove == PendingMove )
    {
      if ( SavedMoves == PendingMove )
      {
        SavedMoves.NextMove = FreeMoves;
        FreeMoves = SavedMoves;
        SavedMoves = None;
      }
      else
      {
        PendingMove.NextMove = FreeMoves;
        FreeMoves = PendingMove;
        if ( AlmostLastMove != None )
        {
          AlmostLastMove.NextMove = None;
          LastMove = AlmostLastMove;
        }
      }
      FreeMoves.Clear();
    }
    PendingMove = None;
  }

  if( Pawn != None )
  {
    Pawn.AutonomousPhysics(NewMove.Delta);
  }
  else
  {
    AutonomousPhysics(DeltaTime);
  }
  NewMove.PostUpdate(self);

  if( SavedMoves == None )
  {
    SavedMoves = NewMove;
  }
  else
  {
    LastMove.NextMove = NewMove;
  }

  // if ( PendingMove == None )
  // {
  //   // Decide whether to hold off on move
  //   // send moves more frequently in small games where server isn't likely to be saturated
  //   if( (Player.CurrentNetSpeed > 10000) && (WorldInfo.GRI != None) && (WorldInfo.GRI.PRIArray.Length <= 10) )
  //   {
  //     NetMoveDelta = 0.011;
  //   }
  //   else
  //   {
  //     NetMoveDelta = FMax(0.0222,2 * WorldInfo.MoveRepSize/Player.CurrentNetSpeed);
  //   }

  //   if( (WorldInfo.TimeSeconds - ClientUpdateTime) < NetMoveDelta )
  //   {
  //     PendingMove = NewMove;
  //     return;
  //   }
  // }

  ClientUpdateTime = WorldInfo.TimeSeconds;

  // Send to the server
  // ClientRoll = (Rotation.Roll >> 8) & 255;
  ClientRoll = (Pawn.Rotation.Roll >> 8) & 255;

  CallServerMove( NewMove,
      ((Pawn == None) ? Location : Pawn.Location),
      ClientRoll,
      // ((Rotation.Yaw & 65535) << 16) + (Rotation.Pitch & 65535),
      ((Rotation.Yaw & 65535) << 16) + (Rotation.Pitch & 65535),
      OldMove );

  PendingMove = None;
}
/*
GetLoadedPawnInformation
  Gets all the information about pawns (like current stanses)
*/
// simulated function GetLoadedPawnInformation()
// {
//   local EmberPawn Receiver;
//   local EmberReplicationInfo eInfo;
//   DebugPrint("GetLoadedPawnInformation");
//   //Find all local pawns
//   ForEach WorldInfo.AllPawns(class'EmberPawn', Receiver) 
//   {
//     eInfo = EmberReplicationInfo(Receiver.PlayerReplicationInfo);
//     Receiver.ChangeStance(eInfo.ServerStancePacket.ServerStance);
//   }
// }
/*
PlayerWalking
	Used for dodge. Queued for removal
*/
    //ember_jerkoff_block
state PlayerWalking
{
ignores SeePlayer, HearNoise, Bump;
   /*
    * The function called when the user presses the fire key (left mouse button by default)
    */
   exec function StartFire( optional byte FireModeNum )
   {

      //Moves Mouse a little bit to allow rapid clicks (unreal issue)
   local vector2D MPos;
   MPos = LocalPlayer(Player).ViewportClient.GetMousePosition();
   LocalPlayer(Player).ViewportClient.SetMouse(MPos.X, MPos.Y+2);

      //Does attack or block, depends on FireModeNum

   // FireModeNum == 0 ? EmberPawn(pawn).doAttack(playerStrafeDirection) : EmberPawn(pawn).doBlock();
   // (FireModeNum == 0) ? EmberPawn(pawn).doAttackQueue() : EmberPawn(pawn).doChamber();
   // (FireModeNum == 0) ? EmberPawn(pawn).doAttackQueue() : EmberPawn(pawn).doChamber();
   if(FireModeNum == 0) 
   {
    EmberPawn(pawn).doAttackQueue();
    MouseIsPressed = true;
    }
    else
      EmberPawn(pawn).doBlock();
       
   // DebugPrint("startfire");

   }
exec function StopFire(optional byte FireModeNum )
{
   // if(FireModeNum == 0)
   // DebugPrint("stopfire");
   MouseIsPressed = false;
  (FireModeNum == 0) ?EmberPawn(pawn).stopAttackQueue() : EmberPawn(pawn).stopBlock();
}

// function ProcessMove(float DeltaTime, vector NewAccel, eDoubleClickDir DoubleClickMove, rotator DeltaRot)
//    {
// 		if ( (DoubleClickMove == DCLICK_Active) && (Pawn.Physics == PHYS_Falling) )
// 			DoubleClickDir = DCLICK_Active;
// 		else if ( (DoubleClickMove != DCLICK_None) && (DoubleClickMove < DCLICK_Active) )
// 		{
// 			if ( EmberPawn(Pawn).Dodge(DoubleClickMove) )
// 				DoubleClickDir = DCLICK_Active;
// 		}

//    playerStrafeDirection = PlayerInput.aStrafe;
//       if( Pawn == None )
//       {
//          return;
//       }

//       if (Role == ROLE_Authority)
//       {
//          // Update ViewPitch for remote clients
//          Pawn.SetRemoteViewPitch( Rotation.Pitch );
//       }

//       Pawn.Acceleration = NewAccel;

//       CheckJumpOrDuck();
// 		Super.ProcessMove(DeltaTime,NewAccel,DoubleClickMove,DeltaRot);
//    }
}
/*
UpdateRotation
*/
function UpdateRotation( float DeltaTime )
{
   local Rotator   DeltaRot, newRotation, ViewRotation;
   local vector v1, v2;
   local float dott;
   ViewRotation = Rotation;
   

   // Calculate Delta to be applied on ViewRotation
   DeltaRot.Yaw   = PlayerInput.aTurn;
   DeltaRot.Pitch   = PlayerInput.aLookUp;

   ProcessViewRotation( DeltaTime, ViewRotation, DeltaRot );
   SetRotation(ViewRotation);

   NewRotation = ViewRotation;
   NewRotation.Roll = Rotation.Roll;

// if(VSize(pawn.Velocity) != 0)   
   // if ( Pawn != N one )

   if(allowPawnRotationWhenStationary == 1)
   {
      // Pawn.FaceRotation(NewRotation, deltatime);
            if(VSize(pawn.Velocity) != 0) 
      {
         // Pawn.FaceRotation(NewRotation, deltatime);
          v1 = normal(vector(Rotation));
         v2 = normal(vector(pawn.Rotation));
         dott = v1 dot v2; 
         if(dott < pawnRotationDotAngle || NewRotation.pitch > 5000)
            interpolateForCameraIsActive = true;

         else if(dott >= 0.95 || NewRotation.pitch < 5000) 
            interpolateForCameraIsActive = false;
            if(interpolateForCameraIsActive && allowPawnRotationWhenStationary == 1)
            {
               if(EmberPawn(pawn).GetTimeLeftOnAttack() > 0)
                     Pawn.FaceRotation(RInterpTo(Pawn.Rotation, NewRotation, DeltaTime, interpMovementAttack, true),DeltaTime); 
                  else
                     Pawn.FaceRotation(RInterpTo(Pawn.Rotation, NewRotation, DeltaTime, interpMovement, true),DeltaTime); 
             }

            if(pitchcc!=NewRotation.pitch)
               pitchcc = NewRotation.pitch;
      }
      else
      {
        if(EmberPawn(pawn).GetTimeLeftOnAttack() == 0)
        Pawn.FaceRotation(NewRotation, deltatime);
        else
        {
      
       v1 = normal(vector(Rotation));
         v2 = normal(vector(pawn.Rotation));
         dott = v1 dot v2; 
         if(dott < pawnRotationDotAngle)
            interpolateForCameraIsActive = true;

         else if(dott >= 0.95) 
            interpolateForCameraIsActive = false; 

            if(interpolateForCameraIsActive && allowPawnRotationWhenStationary == 1)
               {
                Pawn.FaceRotation(RInterpTo(Pawn.Rotation, NewRotation, DeltaTime, interpStationaryAttack, true),DeltaTime); 
                TargetViewRotation = RInterpTo(Pawn.Rotation, NewRotation, DeltaTime, interpStationaryAttack, true);
                     // SetRotation(RInterpTo(ViewRotation, DeltaRot, DeltaTime, 100, true));
               }
            if(pitchcc!=NewRotation.pitch)
               pitchcc = NewRotation.pitch;
             }
}
               // if(EmberPawn(pawn).GetTimeLeftOnAttack() == 0)
               //    Pawn.FaceRotation(NewRotation, deltatime);
   }

//================================
// Legacy Code, to know how to interpolate
//================================

      // else 
      // { 

      //    }
      bForceNetUpdate=true;
ViewShake( DeltaTime );
// if(role < ROLE_Authority)
  // ServerUpdateRotation(DeltaTime);
}   

// unreliable Server function ServerUpdateRotation(float DeltaTime)
// {
//   UpdateRotation(DeltaTime);
// }
/* 
PostBeginPlay
*/
Simulated Event PostBeginPlay() {
   super.postbeginplay();
DebugPrint("post begin");

  EmberPawn(pawn).SetupPlayerControllerReference(self);
   //set Self's worldinfo var
   // EmberGameInfo(WorldInfo.Game).playerControllerWORLD = Self;

  SaveMeshValues();
  
}
//=============================================
// Keybinded Functions
//=============================================

/*
eButtonDown
*/
exec function eButtonDown()
{
  if(EmberPawn(pawn).bAttackGrapple)
  {
    EPressedStatus = 1;
    EmberPawn(pawn).tetherBeamProjectile();
  }
}
/*
ebuttonUp
*/
exec function ebuttonUp ()
{
    EPressedStatus = 0;
    EmberPawn(pawn).DetachTether();
}
/*
increaseTether
   MouseScrollUp
*/
exec function increaseTether()
{
  DebugPrint("up");
   // EmberPawn(pawn).increaseTether();
   // EmberPawn(pawn).debugCone();
   EmberPawn(pawn).debugConeBool = true;
}
/*
decreaseTether
   MouseScrollDown
*/
exec function decreaseTether ()
{
   // EmberPawn(pawn).decreaseTether();
   EmberPawn(pawn).debugConeBool = false;
}
//=============================================
// @Temporarily disabled. 
// @Renable in DefaultInput.ini
//=============================================
/*
jumpIsRequested
   Space pressed Down
*/
exec function jumpIsRequested()
{
   EmberPawn(pawn).DoDoubleJump(true);
}
/*
jumpIsDenied
   Space let Go
*/
exec function jumpIsDenied()
{
   EmberPawn(pawn).DoDoubleJump(false);
   
}
/*
leftMouseDown
   When click, does attack based on strafe direction
   Moves mouse slightly to allow multiple attacks (otherwise multiclick is disabled)
*/
exec function leftMouseDown()
{
   // local vector2D MPos;
   // MPos = LocalPlayer(Player).ViewportClient.GetMousePosition();
   // LocalPlayer(Player).ViewportClient.SetMouse(MPos.X, MPos.Y+2);
   // EmberPawn(pawn).doAttack(playerStrafeDirection);
   // EmberPawn(pawn).SpawnStuff();
   // Custom_Sword(UTWeapon).CurrentFireMode = 0;
}
/*
leftMouseUp
   Queued for deletion
*/
exec function leftMouseUp()
{
   // Custom_Sword(UTWeapon).resetTracers = true;
}
/*
CntrlIsRequested
   Queued for deletion
*/
exec function CntrlIsRequested()
{
   // EmberPawn(pawn).DoDodge(DClick_Right);
   // EmberPawn(pawn).DoKick();
}
exec function doDodge()
{
  //DCLICK_Forward 
  EmberPawn(pawn).DoDodge(verticalShift);
}
/*
LightStance
   Switch to Light Stance 
*/
exec function LightStance()
{
  if(EmberPawn(pawn).bAttackGrapple)
  {
    EmberPawn(pawn).bAttackGrapple = false;
    EmberPawn(pawn).DrawGrappleCrosshairCalcs();
  }

  EmberPawn(pawn).ChangeStance(1);
}
/*
BalanceStance
   Switch to Light Stance
*/
exec function BalanceStance()
{
  if(EmberPawn(pawn).bAttackGrapple)
  {
    EmberPawn(pawn).bAttackGrapple = false;
    EmberPawn(pawn).DrawGrappleCrosshairCalcs();
  }

  EmberPawn(pawn).ChangeStance(2);
}
/*
HeavyStance
   Switch to Light Stance
*/ 
exec function HeavyStance()
{
  if(EmberPawn(pawn).bAttackGrapple)
  {
    EmberPawn(pawn).bAttackGrapple = false;
    EmberPawn(pawn).DrawGrappleCrosshairCalcs();
  }

  EmberPawn(pawn).ChangeStance(3);
}
/*
SheatheWeapon
   Sheathe Weapon
*/
exec function SheatheWeapon()
{
// EmberPawn(pawn).SheatheWeapon(); 
  if(!EmberPawn(pawn).bAttackGrapple)
  {
    EmberPawn(pawn).bAttackGrapple = true;
    EmberPawn(pawn).DrawGrappleCrosshairCalcs();
  }
}

exec function TempTaunt()
{
  // local EmberPawn pawner;
  // local EmberPlayerController PC;
  // local SoundCue taunt;
  // taunt = SoundCue'EmberSounds.Taunts';
  // PlaySound(taunt);
//   local vector vecty, nub, TraceStart, TraceEnd;
  
//   local Actor archetype;
//   local TestPawn AI;

// // archetype = Actor(DynamicLoadObject("TestPawn'ArtAnimation.AI_1'", class'TestPawn'));
// TraceStart = Pawn.Location;
// TraceEnd = TraceStart + Vector( Pawn.Rotation ) * 5000;
//    DrawDebugLine(TraceStart,TraceEnd, -1, 0, 0, true);
// Trace(vecty, nub, TraceStart, TraceEnd);
// DebugPrint(""@vecty);
// AI = Spawn(class'TestPawn', , ,vecty);
// updatePlayerMeshes++;
// EmberReplicationInfo(playerreplicationinfo).updateMesh = updatePlayerMeshes; 
// DebugPrint("pp -"@updatePlayerMeshes);
  // foreach Worldinfo.AllActors( class'EmberPawn', pawner ) 
  // {
  //   DebugPrint("pawner"@pawner);
  //           PC = EmberPlayerController(pawner.Instigator.Controller);
  //           PC.resetMesh();
  //         }
        // foreach Worldinfo.AllActors( class'EmberPlayerController', PC ) 

}
exec function ep_player_modular(int Category, int Index)
{
          EmberPawn(pawn).ModularPawn_Cosmetics.SwapModularItem(Category, Index);
}
//============================================= 
// Hooks Functions
//=============================================
exec function hookW()
{
     verticalShift[0] = verticalShift[0] ^ 1;
     EmberPawn(pawn).bSprintControl = EnableSprintControl();

}
exec function hookA()
{
    verticalShift[1] = verticalShift[1] ^ 1;
    EmberPawn(pawn).bSprintControl = EnableSprintControl();
}
exec function hookS()
{
    verticalShift[2] = verticalShift[2] ^ 1;
    EmberPawn(pawn).bSprintControl = EnableSprintControl();
} 
exec function hookD()
{
    verticalShift[3] = verticalShift[3] ^ 1;
    EmberPawn(pawn).bSprintControl = EnableSprintControl();
}
/*
bool EnableSprintControl
  
*/
function bool EnableSprintControl()
{  
  if((verticalShift[1] ^ 1) == 0 )  return false;
  if((verticalShift[2] ^ 1) == 0 )  return false;
  if((verticalShift[3] ^ 1) == 0 )  return false;

  if((verticalShift[0] ^ 1) == 0 )  return true;
                                    return false;
}
//=============================================
// Custom Functions
//=============================================
exec function DebugPrint(string a)
{
   GetALocalPlayerController().ClientMessage(a);
}
/*
spawnDummy
  Creates a dummy at player's spawn point
*/
exec function spawnDummy()
{
   local Pawn p;
   p = Spawn(class'TestPawn');
   p.SpawnDefaultController();
   // Spawn(class'Custom_Sword', , , l);
}

function RecordTracers(name animation, float duration, float t1, float t2)
{ 
   local Pawn p;
      p = Spawn(class'TestPawn', , , );
      // p.SpawnDefaultController();
    GetALocalPlayerController().ClientMessage("sMessage");
      TestPawn(p).doAttackRecording(animation, duration, t1, t2);
}
//=============================================
// Console Functions
//=============================================
// exec function ep_player_spine_rotation(float Toggle = -3949212)
// {
//    allowSpineRotation = (Toggle == -3949212) ? ModifiedDebugPrint("Allows spine rotation for looking up and down. 1 = true, 0 = false. Current Value - ", allowSpineRotation) : Toggle;
// }
// exec function ep_player_spine_rotation_yaw(float Toggle = -3949212)
// {
//    spine_rotation_yaw = (Toggle == -3949212) ? ModifiedDebugPrint("Changes yaw constant. Default is 0. Current Value - ", spine_rotation_yaw) : Toggle;
// }
// exec function ep_player_spine_rotation_roll(float Toggle = -3949212)
// {
//    spine_rotation_roll = (Toggle == -3949212) ? ModifiedDebugPrint("Changes roll constant. Default is 0.  Current Value - ", spine_rotation_roll) : Toggle;
// }
exec function ep_player_rotation_when_stationary(float Toggle = -3949212)
{
   allowPawnRotationWhenStationary = (Toggle == -3949212) ? ModifiedDebugPrint("Allows player rotation when stationary. 1 = true, 0 = false. Current Value - ", allowPawnRotationWhenStationary) : Toggle;
}
exec function ep_player_rotation_iterp_stationary_attack(float Toggle = -3949212)
{
   interpStationaryAttack = (Toggle == -3949212) ? ModifiedDebugPrint("Iterpolation when stationary and attacking. Higher values = faster speed. Current Value - ", interpStationaryAttack) : Toggle;
}
exec function ep_player_rotation_iterp_movement(float Toggle = -3949212)
{
   interpMovement = (Toggle == -3949212) ? ModifiedDebugPrint("Iterpolation when moving. Higher values = faster speed. Current Value - ", interpMovement) : Toggle;
}
exec function ep_player_rotation_iterp_movement_attack(float Toggle = -3949212)
{
   interpMovementAttack = (Toggle == -3949212) ? ModifiedDebugPrint("Iterpolation when moving and attacking. Higher values = faster speed. Current Value - ", interpMovementAttack) : Toggle;
}
// exec function ep_player_rotation_when_stationary_angle(float dot_angle = -3949212)
// {
//    pawnRotationDotAngle = (dot_angle == -3949212) ? ModifiedDebugPrint("Dot angle detection to rotate player to camera. examples can be found under command dot_angle_examples. Current Value - ", pawnRotationDotAngle) : dot_angle;
// }

exec function dot_angle_examples(float dot_angle = -3949212)
{
   GetALocalPlayerController().ClientMessage("Example angles: 1 = 0 degrees, 0.5 = 45 degrees, 0 = 90 degrees, -0.5 = 135 degrees, -1 = 180 degrees.");
}

//===================================
// AI Command Functions
//===================================
exec function ep_ai_follow_player(float NewVariable = -3949212)
{ 
   getAIStatus();
  ai_followPlayer = (NewVariable == -3949212) ? ModifiedDebugPrint("Follow player when player is seen. 1 = true, 0 = false. Current Value - ", ai_followPlayer) : NewVariable;
  setAIStatus();
}
exec function ep_ai_attack_player(float NewVariable = -3949212)
{ 
   getAIStatus();
  ai_attackPlayer = (NewVariable == -3949212) ? ModifiedDebugPrint("Attack player when player is seen and within X units (ep_ai_attack_player_range). 1 = true, 0 = false. Current Value - ", ai_attackPlayer) : NewVariable;
  setAIStatus();
}
exec function ep_ai_attack_player_range(float NewVariable = -3949212)
{ 
   getAIStatus();
  ai_attackPlayerRange = (NewVariable == -3949212) ? ModifiedDebugPrint("Range to start attack animations. Current Value - ", ai_attackPlayerRange) : NewVariable;
   setAIStatus();
}

function float ModifiedDebugPrint(string sMessage, float variable)
{
   GetALocalPlayerController().ClientMessage(sMessage @ string(variable));
   return variable; 
}
function bool ModifiedDebugPrintBool(string sMessage, bool variable)
{
   GetALocalPlayerController().ClientMessage(sMessage @ string(variable));
   return variable;
} 
function getAIStatus()
{
   local TestPawn tPawn;
   foreach Worldinfo.AllActors( class'TestPawn', tPawn ) 
   {
   ai_followPlayer = tPawn.followPlayer;
   ai_attackPlayer = tPawn.attackPlayer;
   ai_attackPlayerRange = tPawn.attackPlayerRange;
   }
}
function setAIStatus()
{
   local TestPawn tPawn;
   foreach Worldinfo.AllActors( class'TestPawn', tPawn ) 
   {
   tPawn.followPlayer = ai_followPlayer;
   tPawn.attackPlayer = ai_attackPlayer;
   tPawn.attackPlayerRange = ai_attackPlayerRange;
   } 
}
/*
resetMesh 
	Sets custom mesh
*/
simulated function SaveMeshValues()
{
// PostBeginCharacterInformation.defaultMesh = defaultMesh;
 PostBeginCharacterInformation.ParentModularComponent = EmberPawn(pawn).ParentModularComponent;
// PostBeginCharacterInformation.defaultMaterial0 = defaultMaterial0;
// PostBeginCharacterInformation.defaultMaterial1 = defaultMaterial1;
// PostBeginCharacterInformation.defaultAnimTree = defaultAnimTree;
// PostBeginCharacterInformation.defaultAnimSet = defaultAnimSet;
// PostBeginCharacterInformation.defaultPhysicsAsset = defaultPhysicsAsset;

// PostBeginCharacterInformation.Cosmetic_ItemList = new class'EmberProject.EmberCosmetic_ItemList';
// PostBeginCharacterInformation.Cosmetic_ItemList.InitiateCosmetics();
// RepMesh = defaultMesh;
 // SetTimer(0.1, false, 'resetMesh');
}


defaultproperties
{
  bReplicateAllPawns=true
  MinRespawnDelay=0.1
   verticalShift=(0,0,0,0);
   interpMovementAttack = 60000f
   interpMovement = 120000f
   interpStationaryAttack = 60000f
   pawnRotationDotAngle = 0.94f 
    interpolateForCameraIsActive = false
    allowPawnRotationWhenStationary = 1.0f
// defaultMesh=SkeletalMesh'EmberBase.ember_player_mesh'
// defaultMesh=SkeletalMesh'mypackage.UT3_Male'
defaultMesh=SkeletalMesh'ArtAnimation.Meshes.ember_player' 
// defaultAnimTree=AnimTree'CH_AnimHuman_Tree.AT_CH_Human'
 defaultAnimTree=AnimTree'ArtAnimation.Armature_Tree'
 
// defaultAnimSet(0)=AnimSet'CH_AnimHuman.Anims.K_AnimHuman_BaseMale'
defaultAnimSet(0)=AnimSet'ArtAnimation.AnimSets.Armature'
// defaultPhysicsAsset=PhysicsAsset'CTF_Flag_IronGuard.Mesh.S_CTF_Flag_IronGuard_Physics'
defaultPhysicsAsset=PhysicsAsset'ArtAnimation.Meshes.ember_player_Physics'
  
}