----// TTT Bots //----
-- Author: Exho
-- Version: 9/11/15

require("navigation")

tttBot = tttBot or {}
tttBot.speed = 220

-- Keys = player count. Values = number of bots
tttBot.playerToBotCount = {
	[1] = 7,
	[2] = 7,
	[3] = 6,
	[4] = 6,
	[5] = 5,
	[6] = 4,
	[7] = 3,
	[8] = 2,
	[9] = 1,
}

-- Should bots be spawned? 
tttBot.shouldSpawnBots = true

-- Should Traitor bots be slain if there are no more Traitor humans alive? 
tttBot.slayBotTraitors = true

tttBot.developerMode = false

--// TTTPrepareRound hook to balance the amount of bots in the game
hook.Add("TTTPrepareRound", "tttBots", function()
	local roundsLeft = math.max(0, GetGlobalInt("ttt_rounds_left", 6))
	local maxRounds = GetConVar("ttt_round_limit"):GetInt()
	
	-- Only spawn bots if the server wants them and it isn't the first round of the map (so players don't lose their slots)
	if tttBot.shouldSpawnBots and roundsLeft < maxRounds then 
		local maxPlayers = game.MaxPlayers()
		local curPlayers = #player.GetHumans()
		local curBots = #player.GetBots()
		local botsToHave = tttBot.playerToBotCount[curPlayers] or 0
		
		if curBots < botsToHave then
			-- Create bots
			for i = 1, botsToHave - curBots do
				RunConsoleCommand("bot")
			end
		elseif curBots > botsToHave then
			-- Kick bots
			for i = 1, curBots - botsToHave do
				local unluckyBot = table.Random( player.GetBots() )
			
				unluckyBot:Kick("Lowering bot count")
			end
		end
	else
		-- Remove any existing bots, they shouldn't be in the game anyways
		if #player.GetBots() > 0 then
			for _, v in pairs( player.GetBots() ) do
				v:Kick("Not wanted here")
			end
		end
	end

	-- Reset all the living bots
	for _, ply in pairs( player.GetBots() ) do
		ply:setTarget( nil )
		ply:setNewPos( nil )
		ply.tttBot_endGunSearchTime = -1
		
		ply:setActive( false )
	end
end)

--// TTTBeginRound hook to reset the bots and activate them
hook.Add("TTTBeginRound", "tttBots", function()
	local botCount = #player.GetBots()
	local spawningTime = 5
	
	local botsPerWave = math.ceil(botCount/spawningTime)
	local botsInWave = 0
	local delay = 1
	
	for _, ply in pairs( player.GetBots() ) do
		-- Reset bot values to if the bot was freshly spawned
		ply:setTarget( nil )
		ply:setNewPos( nil )
		ply.tttBot_endGunSearchTime = -1
		
		botsInWave = botsInWave + 1
		if botsInWave > botsPerWave then
			delay = delay + 1
			botsInWave = 0
		end
		
		-- Stagger the activation of bots in waves as to not put a large amount of stress on the server at a single time
		timer.Create(ply:EntIndex().."_wake", delay, 1, function()
			ply:setActive( true )
		end)
	end
end)

--// StartCommand hook that serves as the backbone to run the bots
hook.Add("StartCommand", "tttBots", function( ply, cmd )
	if ply:IsBot() and IsValid( ply ) then
		ply.cmd = cmd
		
		if ply:Alive() then
			if GetRoundState() == ROUND_ACTIVE and ply:getActive() then
				ply:lerpAngles()
				ply:followPath()
				
				--// INNOCENT BOT LOGIC
				if ply:GetRole() == ROLE_INNOCENT then
					if IsValid( ply:getTarget() ) then
						ply:huntTarget()
					else
						if not ply:hasGuns() then
							ply:findWeapon() 
							ply:selectCrowbar()
						end
						ply:wander() -- WARNING: Resource intensive
					end
				end
				
				--// DETECTIVE BOT LOGIC
				if ply:GetRole() == ROLE_DETECTIVE then
					local vsrc = ply:GetShootPos()
					local vang = ply:GetAimVector()
					local vvel = ply:GetVelocity()
      
					local vthrow = vvel + vang * 200
	  
					-- Drop a health station to help out the innocents
					local health = ents.Create("ttt_health_station")
					if IsValid(health) then
						health:SetPos(vsrc + vang * 10)
						health:Spawn()

						health:SetPlacer(ply)

						health:PhysWake()
						local phys = health:GetPhysicsObject()
						if IsValid(phys) then
							phys:SetVelocity(vthrow)
						end
					end
					
					-- Remove a credit because of the health station and kill the bot
					ply:AddCredits( -1 )
					ply:Kill()
					ply:AddFrags( -1 )
					
					-- ID their body
					ply:SetNWBool("body_found", true)
					local dti = CORPSE.dti
					ply.server_ragdoll:SetDTBool(dti.BOOL_FOUND, true)
				end
				
				--// TRAITOR BOT LOGIC
				if ply:GetRole() == ROLE_TRAITOR then
					ply.tttBot_endGunSearchTime = ply.tttBot_endGunSearchTime or 0
					
					-- Set a period of time that the bot will search for weapons before trying to kill players
					if ply.tttBot_endGunSearchTime == -1 then
						ply.tttBot_endGunSearchTime = CurTime() + math.random(15, 45)
					end
					
					-- Its time! Or we were attacked
					if CurTime() > ply.tttBot_endGunSearchTime or IsValid( ply:getTarget() ) then
						-- Get a target and hunt them down
						if not IsValid( ply:getTarget() ) then
							ply:debug("New target - StartCommand")
							ply:setTarget( ply:findNewTarget( true ) )
						end

						ply:huntTarget()
					else
						-- Search for weapons
						if not ply:hasGuns() then
							ply:findWeapon()
						end
						
						ply:wander() -- WARNING: Resource intensive
					end
				end
			else
				-- The round hasn't started
				ply:setTarget( nil )
				ply:idle()
			end
		else
			-- Don't do anything we're dead
			ply:idle()
		end
	end
end)

--// EntityTakeDamage hook so bots can fight back
hook.Add("EntityTakeDamage", "tttBots", function( ply, dmginfo )
	if ply.IsBot and ply:IsBot() then
		if not IsValid( ply:getTarget() ) then
			if !dmginfo:IsDamageType( DMG_BURN ) and !dmginfo:IsDamageType( DMG_BLAST ) then
				local target = dmginfo:GetAttacker()
				
				local ang = ply:EyeAngles()
				local tPos = target:GetPos() 
				local pos = ply:GetPos()
				local dist = pos:Distance( tPos )
				
				yaw = math.deg(math.atan2(tPos.y - pos.y, tPos.x - pos.x))
				pitch = math.deg(math.atan2( -(tPos.z - pos.z), dist))
				
				local sign = math.random(2) and 1 or -1
				
				ply:setNewPos( nil )
				
				-- Only lock onto the targets that the bot can see 
				if ply:isVectorVisible( target:GetPos() ) then
					ply:setTarget( dmginfo:GetAttacker() )
					
					ply:setNewAngles( Angle( ang.p + math.random(-10, 10), yaw, 0 ) )
				else
					-- Look around randomly in an attempt to find who shot us
					ply:setNewAngles( Angle( ang.p + math.random(-75, 75), yaw + (math.random(50, 150)*sign), 0 ) )
				end
			end
		end
	end
end)

--// TTTKarmaLow hook to make sure a bot doesn't get kicked for poor karma as that will lead to all the bots getting kicked
hook.Add("TTTKarmaLow", "tttBots", function( ply )
	if ply:IsBot() then
		return false
	end
end)

--// Think hook that checks if the last Traitors are bots and slays them to not hold up the round
local nextWinCheck = 0
hook.Add("Think", "tttBotsWin", function()
	if CurTime() > nextWinCheck and GetRoundState() == ROUND_ACTIVE then
		local aliveBots = 0
		local aliveHumans = 0
		for _, v in pairs( GetTraitors() ) do
			if v:Alive() then
				if v:IsBot() then
					aliveBots = aliveBots + 1
				else
					aliveHumans = aliveHumans + 1
				end	
			end
		end

		if aliveHumans == 0 and aliveBots > 0 and tttBot.slayBotTraitors then 
			PrintMessage( HUD_PRINTTALK, "The last Traitor(s) are bots and have been slain")
			
			for _, v in pairs( GetTraitors() ) do
				if v:Alive() and v:IsBot() then
					v:Kill()
				end
			end
			
			--[[local convertedInnocents = 0
			for _, v in RandomPairs( player.GetHumans() ) do
				if convertedInnocents < aliveBots then
					if v:Alive() and v:GetRole() == ROLE_INNOCENT then
						v:ChatPrint( "You have been converted to Traitor" )
						v:SetRole( ROLE_TRAITOR )
						v:AddCredits( 1 )
						convertedInnocents = convertedInnocents + 1
					end
				else
					break
				end
			end]]
		end
		
		nextWinCheck = CurTime() + 1
	end
end)

local spawns = {
	"info_player_deathmatch", "info_player_combine",
	"info_player_rebel", "info_player_counterterrorist", "info_player_terrorist",
	"info_player_axis", "info_player_allies", "gmod_player_start",
	"info_player_teamspawn", "info_player_start"
}

--// Think hook that keeps a global table of "landmarks" which are positions that the bots can wander to
local nextLandmarkUpdate = 0
hook.Add("Think", "tttBotsLandmarks", function()
	if not tttBot.landmarks then
		tttBot.landmarks = {}
	end
	
	if CurTime() > nextLandmarkUpdate then
		local landmarks = {}
		
		-- Add spawnpoints and weapons
		for _, ent in pairs( ents.GetAll() ) do
			for _, class in pairs( spawns ) do
				if ent:GetClass():lower() == class:lower() then
					table.insert( landmarks, ent )
				end
			end
		end
		
		-- Add living players
		for _, v in pairs( player.GetAll() ) do
			if v:Alive() then
				table.insert( landmarks, v )
			end
		end
		
		tttBot.landmarks = landmarks
		
		nextLandmarkUpdate = CurTime() + 10
	end
end)

--// Think hook to locate all the weapons that are on the ground
local nextWeaponUpdate = 0
hook.Add("Think", "tttBotsWeapons", function()
	if not tttBot.weapons then
		tttBot.weapons = {}
	end
	
	if CurTime() > nextWeaponUpdate then
		local weps = {}
		
		for _, ent in pairs( ents.GetAll() ) do
			if ent:IsWeapon() and not IsValid( ent:GetOwner() ) and tttBot.weaponIsValid( ent ) then
				table.insert( weps, ent )
			end
		end
		
		tttBot.weapons = weps
		
		nextWeaponUpdate = CurTime() + 5
	end
end)

--// Returns if the weapon is valid for the bot to pick up
function tttBot.weaponIsValid( wep )
	if not IsValid( wep ) then return false end
	if IsValid( wep:GetOwner() ) then return false end
	
	return true
end

--// Returns if the given weapon is not a default weapon
function tttBot.weaponIsNotDefault( wep )
	if wep:GetClass() == "weapon_zm_improvised" or wep:GetClass() == "weapon_ttt_unarmed" or wep:GetClass() == "weapon_zm_carry" then
		return false
	end
	
	return true
end
