class EmberSword_Model extends Actor;


var SkeletalMeshComponent Mesh;
var array<PhysicsAsset> PhysicsAssetCollection;

/*
SwitchPhysicsAsset
	
*/
function SwitchPhysicsAsset(int Index)
{
	mesh.setPhysicsAsset(PhysicsAssetCollection[Index]);
}
/*
AddPhysicsAsset
	
*/
function AddPhysicsAsset(PhysicsAsset pAsset)
{

	PhysicsAssetCollection.AddItem(pAsset);
	if(PhysicsAssetCollection.length == 1)
		SwitchPhysicsAsset(0);
}

defaultproperties
{
    Begin Object class=SkeletalMeshComponent Name=SwordMesh
       	bCacheAnimSequenceNodes=false
       	AlwaysLoadOnClient=true
       	AlwaysLoadOnServer=true
       	CastShadow=true
       	bUpdateSkelWhenNotRendered=false
       	bIgnoreControllersWhenNotRendered=true
       	bUpdateKinematicBonesFromAnimation=true
       	bCastDynamicShadow=true
       	bOverrideAttachmentOwnerVisibility=true
       	bAcceptsDynamicDecals=false
       	bHasPhysicsAssetInstance=true
       	TickGroup=TG_PreAsyncWork
       	MinDistFactorForKinematicUpdate=0.2f
       	bChartDistanceFactor=true
       	RBDominanceGroup=20
       	Scale=1
       	bAllowAmbientOcclusion=false 
       	bUseOnePassLightingOnTranslucency=true
       	bPerBoneMotionBlur=true
       	bOwnerNoSee=false
       	BlockZeroExtent=true 
       	BlockNonZeroExtent=true
       	CollideActors=true
		// Since 65536 = 0 = 360, half of that equals 180, right?
		Rotation=(Pitch=000 ,Yaw=0, Roll=16384 )

    End Object
    
    Mesh = SwordMesh
    Components.Add(SwordMesh)
}