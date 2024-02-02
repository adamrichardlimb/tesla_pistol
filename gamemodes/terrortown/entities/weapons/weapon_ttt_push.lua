if SERVER then
	AddCSLuaFile( "shared.lua" )
end

DEFINE_BASECLASS "weapon_tttbase"

if CLIENT then
	SWEP.PrintName = "Tesla Pistol"
	SWEP.Slot = 7
	SWEP.Icon = "vgui/ttt/icon_teslapistol"
end

SWEP.BASE = "weapon_tttbase"

SWEP.HoldType = "pistol"

SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 3
SWEP.Primary.Clipsize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Cone          = 0.005
SWEP.Primary.Sound         = Sound( "weapons/ar2/fire1.wav" )
SWEP.Primary.SoundLevel    = 54
SWEP.Primary.Recoil        = 4

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"
SWEP.Secondary.Delay       = 0.5
SWEP.Primary.Recoil        = 4

SWEP.UseHands = true
SWEP.DrawAmmo = false
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54
SWEP.ViewModel             = "models/weapons/c_toolgun.mdl"
SWEP.WorldModel            = "models/weapons/w_toolgun.mdl"

SWEP.Kind                  = WEAPON_EQUIP2
SWEP.CanBuy                = {ROLE_TRAITOR}

SWEP.Kind = WEAPON_EQUIP2

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2, then this gun can
-- be spawned as a random weapon.
SWEP.AutoSpawnable = false

-- CanBuy is a table of ROLE_* entries like ROLE_TRAITOR and ROLE_DETECTIVE. If
-- a role is in this table, those players can buy this.
SWEP.CanBuy = { ROLE_TRAITOR }

-- InLoadoutFor is a table of ROLE_* entries that specifies which roles should
-- receive this weapon as soon as the round starts. In this case, none.
SWEP.InLoadoutFor = { nil }

-- If LimitedStock is true, you can only buy one per round.
--SWEP.LimitedStock = true

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = true

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = true

-- Equipment menu information is only needed on the client
if CLIENT then
   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = "Revamped Newton Launcher.\nDeals no damage but launches targets in radius\naround impact site.Allows you to Tesla Jump by firing\nbeneath you. Will still knock back targets struck."
   };
end

AccessorFuncDT(SWEP, "charge", "Charge")
 
SWEP.IsCharging            = false
SWEP.NextCharge            = 0
 
local CHARGE_AMOUNT = 0.02
local CHARGE_DELAY = 0.025
 
local math = math
 
function SWEP:Initialize()
   if SERVER then
      self:SetSkin(1)
   end
   return self.BaseClass.Initialize(self)
end
 
function SWEP:SetupDataTables()
   self:DTVar("Float", 0, "charge")
end
 
function SWEP:PrimaryAttack()
   if self.IsCharging then return end
 
   self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
   self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
 
   self:FirePulse(600, 300)
end
 
function SWEP:SecondaryAttack()
   if self.IsCharging then return end
 
   self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
   self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
 
   self.IsCharging = true
end
 
local function PushPullRadius(pos, pusher, force_fwd, force_up)
   local radius = 100
   local phys_force = force_fwd
   local push_force = force_up
 
   -- pull physics objects and push players
   for k, target in pairs(ents.FindInSphere(pos, radius)) do
      if IsValid(target) then
         local tpos = target:LocalToWorld(target:OBBCenter())
         local dir = (tpos - pos):GetNormal()
         local phys = target:GetPhysicsObject()
 
         if target:IsPlayer() and (not target:IsFrozen()) and ((not target.was_pushed) or target.was_pushed.t != CurTime()) then
 
            -- always need an upwards push to prevent the ground's friction from
            -- stopping nearly all movement
            dir.z = math.abs(dir.z) + 1
 
            local push = dir * push_force
 
            -- try to prevent excessive upwards force
            local vel = target:GetVelocity() + push
            vel.z = math.min(vel.z, push_force)
 
            -- mess with discomb jumps
            if pusher == target then
               --vel = VectorRand() * vel:Length()
               vel.z = math.abs((vel.z * 1.25))
               -- If jumping, give them a boost.
            end
 
            target:SetVelocity(vel)
 
            target.was_pushed = {att=pusher, t=CurTime(), wep="weapon_ttt_confgrenade"}
 
         elseif IsValid(phys) then
            phys:ApplyForceCenter(dir * -1 * phys_force)
         end
      end
   end
 
   local phexp = ents.Create("env_physexplosion")
   local zapsound = Sound("ambient/levels/citadel/portal_beam_shoot2.wav")
   if IsValid(phexp) then
      phexp:SetPos(pos)
      phexp:SetKeyValue("magnitude", 100) --max
      phexp:SetKeyValue("radius", radius)
      -- 1 = no dmg, 2 = push ply, 4 = push radial, 8 = los, 16 = viewpunch
      phexp:SetKeyValue("spawnflags", 1 + 2 + 16)
      phexp:Spawn()
      phexp:Fire("Explode", "", 0.2)
      local effect = EffectData()
      effect:SetStart(pos)
      effect:SetOrigin(pos)
     
      util.Effect("VortDispel", effect, true, true)
      util.Effect("StunstickImpact", effect, true, true)
      sound.Play(zapsound, pos, 70, 200, 0.25)
   end
end
 
function SWEP:FirePulse(force_fwd, force_up)
   if not IsValid(self:GetOwner()) then return end
 
   self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
 
   sound.Play(self.Primary.Sound, self:GetPos(), self.Primary.SoundLevel)
 
   self:SendWeaponAnim(ACT_VM_PRIMARYATTACK )
 
   local cone = self.Primary.Cone or 0.1
   local num = 6
 
   local bullet = {}
   bullet.Num    = num
   bullet.Src    = self:GetOwner():GetShootPos()
   bullet.Dir    = self:GetOwner():GetAimVector()
   bullet.Spread = Vector( cone, cone, 0 )
   bullet.Tracer = 1
   bullet.Force  = force_fwd / 10
   bullet.Damage = 0
   bullet.TracerName = "AirboatGunHeavyTracer"
 
   local owner = self:GetOwner()
   local fwd = force_fwd / num
   local up = force_up / num
   bullet.Callback = function(att, tr, dmginfo)
                        local ply = tr.Entity
                        if SERVER and IsValid(ply) and ply:IsPlayer() and (not ply:IsFrozen()) then
                           local pushvel = tr.Normal * fwd
 
                           pushvel.z = math.max(pushvel.z, up)
 
                           ply:SetGroundEntity(nil)
                           ply:SetLocalVelocity(ply:GetVelocity() + pushvel)
 
                           ply.was_pushed = {att=owner, t=CurTime(), wep=self:GetClass()}
                        elseif SERVER then
                           local trace = util.TraceLine( {
                              start = self:GetOwner():EyePos(),
                              endpos = self:GetOwner():EyePos() + self:GetOwner():EyeAngles():Forward() * 10000,
                              filter = function( ent ) if ( ent:GetClass() == "prop_physics" ) then return true end end
                           } )
                           PushPullRadius(trace.HitPos, att, force_fwd, force_up)
                        end
                     end
 
   self:GetOwner():FireBullets( bullet )
 
end
 
 
local CHARGE_FORCE_FWD_MIN = 300
local CHARGE_FORCE_FWD_MAX = 900
local CHARGE_FORCE_UP_MIN = 100
local CHARGE_FORCE_UP_MAX = 450
function SWEP:ChargedAttack()
   local charge = math.Clamp(self:GetCharge(), 0, 1)
   
   self.IsCharging = false
   self:SetCharge(0)
 
   if charge <= 0 then return end
 
   local max = CHARGE_FORCE_FWD_MAX
   local diff = max - CHARGE_FORCE_FWD_MIN
 
   local force_fwd = ((charge * diff) - diff) + max
 
   max = CHARGE_FORCE_UP_MAX
   diff = max - CHARGE_FORCE_UP_MIN
 
   local force_up = ((charge * diff) - diff) + max
 
   self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
   self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
 
   self:FirePulse(force_fwd, force_up)
end
 
function SWEP:PreDrop(death_drop)
   -- allow dropping for now, see if it helps against heisenbug on owner death
--   if death_drop then
   self.IsCharging = false
   self:SetCharge(0)
--   elseif self.IsCharging then
--      self:ChargedAttack()
--   end
end
 
function SWEP:OnRemove()
   self.IsCharging = false
   self:SetCharge(0)
end
 
function SWEP:Deploy()
   self.IsCharging = false
   self:SetCharge(0)
   return true
end
 
function SWEP:Holster()
   return not self.IsCharging
end
 
function SWEP:Think()
   if self.IsCharging and IsValid(self:GetOwner()) and self:GetOwner():IsTerror() then
      -- on client this is prediction
      if not self:GetOwner():KeyDown(IN_ATTACK2) then
         self:ChargedAttack()
         return true
      end
 
     
      if SERVER and self:GetCharge() < 1 and self.NextCharge < CurTime() then
         self:SetCharge(math.min(1, self:GetCharge() + CHARGE_AMOUNT))
 
         self.NextCharge = CurTime() + CHARGE_DELAY
      end
   end
end
 
if CLIENT then
   local surface = surface
   function SWEP:DrawHUD()
      local x = ScrW() / 2.0
      local y = ScrH() / 2.0
 
      local nxt = self:GetNextPrimaryFire()
      local charge = self.dt.charge
 
      if LocalPlayer():IsTraitor() then
         surface.SetDrawColor(255, 0, 0, 255)
      else
         surface.SetDrawColor(0, 255, 0, 255)
      end
 
      if nxt < CurTime() or CurTime() % 0.5 < 0.2 or charge > 0 then
         local length = 10
         local gap = 5
 
         surface.DrawLine( x - length, y, x - gap, y )
         surface.DrawLine( x + length, y, x + gap, y )
         surface.DrawLine( x, y - length, x, y - gap )
         surface.DrawLine( x, y + length, x, y + gap )
      end
 
      if nxt > CurTime() and charge == 0 then
         local w = 40
 
         w = (w * ( math.max(0, nxt - CurTime()) /  self.Primary.Delay )) / 2
 
         local bx = x + 30
         surface.DrawLine(bx, y - w, bx, y + w)
 
         bx = x - 30
         surface.DrawLine(bx, y - w, bx, y + w)
      end
 
      if charge > 0 then
         y = y + (y / 3)
 
         local w, h = 100, 20
 
         surface.DrawOutlinedRect(x - w/2, y - h, w, h)
 
         if LocalPlayer():IsTraitor() then
            surface.SetDrawColor(255, 0, 0, 155)
         else
            surface.SetDrawColor(0, 255, 0, 155)
         end
 
         surface.DrawRect(x - w/2, y - h, w * charge, h)
 
         surface.SetFont("TabLarge")
         surface.SetTextColor(255, 255, 255, 180)
         surface.SetTextPos( (x - w / 2) + 3, y - h - 15)
         surface.DrawText("FORCE")
      end
   end
end