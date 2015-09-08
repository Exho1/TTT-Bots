----// TTT Bots //----
-- Author: Exho
-- Version: 9/7/15

require("navigation")

--[[
	TODO:
		- replace generatenavmesh with tttBot.generateNAv
			Move the contents of the first function into the second and test it
		- Remove all the old or unused code
		- Uncomment code and change values back to normal to make everything functional
		- There can only be 1 nav per path
			- 1 nav per bot should suffice

]]

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

tttBot.shouldSpawnBots = true

--// TTTPrepareRound hook to balance the amount of bots in the game
hook.Add("TTTPrepareRound", "tttBots", function()
	local roundsLeft = math.max(0, GetGlobalInt("ttt_rounds_left", 6))
	local maxRounds = GetConVar("ttt_round_limit"):GetInt()
	
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
	for _, ply in pairs( player.GetAll() ) do
		if ply:IsBot() then
			ply:setTarget( nil )
			ply:setNewPos( nil )
			ply.tttBot_endGunSearchTime = -1
		end
	end
	
	findExho():Give("weapon_ttt_grapplehook")
end)

--// TTTBeginRound hook to reset the bots, again
hook.Add("TTTBeginRound", "tttBots", function()
	-- Reset all the living bots
	for _, ply in pairs( player.GetAll() ) do
		if ply:IsBot() then
			ply:setTarget( nil )
			ply:setNewPos( nil )
			ply.tttBot_endGunSearchTime = -1
		end
	end
end)

--// Think hook that checks if the last Traitors are bots and slays them to not hold up the round
local nextWinCheck = 0
hook.Add("Think", "tttBotsWin", function()
	if CurTime() > nextWinCheck then
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

		if aliveHumans == 0 and aliveBots > 0 and not true then 
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

--// StartCommand hook that serves as the backbone to run the bots
hook.Add("StartCommand", "tttBots", function( ply, cmd )
	if ply:IsBot() and IsValid( ply ) then
		ply.cmd = cmd
		
		if ply:Alive() then
			ply:lerpAngles()
			
			--[[
			ply:setTarget( findExho() )
			
			ply:setNewAngles( Angle( 0, 270, 0 ) )
			
			local clearLOS = ply:clearLOS( ply:getTarget() )
			local vectorVisible = ply:isVectorVisible( ply:getTarget():GetPos() )
			
			findExho():ChatPrint(tostring(clearLOS).." "..tostring(vectorVisible))
			
			ply:idle()
			]]
			
			--[[
			ply:followPath()
			if not ply.currentPath and not ply:getPathing() then
				ply:idle()
			end
			]]
			
			if GetRoundState() == ROUND_ACTIVE then
				ply:followPath()
				
				--// INNOCENT BOT LOGIC
				if ply:GetRole() == ROLE_INNOCENT then
					if IsValid( ply:getTarget() ) then
						ply:huntTarget()
					elseif not ply:hasGuns() then
						ply:findWeapon() 
						ply:wander() -- WARNING: Resource intensive
						ply:selectCrowbar()
					else
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
						if not IsValid( ply:getTarget() ) or not ply:getTarget():Alive() then
							print("New target - StartCommand")
							ply:setTarget( ply:findNewTarget( true ) )
						end

						ply:huntTarget()
					else
						-- Search for weapons
						if not ply:hasGuns() then
							ply:findWeapon()
						end
					end
				end
			else
				ply:setTarget( nil )
				ply:idle()
			end
		else
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
				
				-- Only lock onto the targets that the bot can see 
				if ply:isVectorVisible( target:GetPos() ) then
					ply:setTarget( dmginfo:GetAttacker() )
					
					ply:setNewAngles( Angle( ang.p + math.random(-10, 10), yaw, 0 ) )
				else
					-- Look around randomly in an attempt to find who shot us
					ply:setNewAngles( Angle( ang.p + math.random(-50, 50), yaw + (math.random(50, 150)*sign), 0 ) )
				end
			end
		end
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