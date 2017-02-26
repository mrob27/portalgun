-- Code by UjEdwin and mrob27
-- License, revision history and instructions are in README.txt
--
-- Design documentation is also in README.txt

local op_prtl = {}
local id_p0rtal = {}
local nxt_id = 0 -- this counts how many portalpairs have been created; TODO: this will go away
local portalgun_step_interval = 0.1
local portalgun_time=0
local portalgun_lifetime = 5000 -- We delete portals that unused for this long
local portalgun_running = false
local portalgun_max_range = 13

local function portalgun_getLength(a)-- get length of an array / table
	local count = 0
	for _ in pairs(a) do count = count + 1 end
	return count
end

-- return a node definition for the node at pos, with a fallback in case
-- that pos is not presently loaded
local function node_ok(pos)
    local fallback = "default:dirt"
    local nd = minetest.get_node_or_nil(pos)
    if not nd then
		-- pos is outside the area currently loaded
        return minetest.registered_nodes[fallback]
    end
	-- use the node's name to find the node definition
    local nodef = minetest.registered_nodes[nd.name]
    if nodef then
        return nodef
    end
    return minetest.registered_nodes[fallback]
end

-- try to figure out the object's physical height. There are
-- several cases that need to be handled. Not all objects
-- have a collisionbox
local function object_height(ob)
	if ob:is_player() then
		-- We assume players have a height of 1.8 metres
		print "object_height: is player, returning 1.8"
		return 1.8
	end

	local ent = ob:get_luaentity()
	if ent then
		local cb = ent.collisionbox;
		if cb then
			-- We got lucky, an object whose entity actually defines a
			-- collisionbox! The height is in cb[5]
			print("object_height: cb ("..cb[1]..", "..cb[2]..", "..cb[3]
							..", "..cb[4]..", "..cb[5]..", "..cb[6]..")")
			return cb[5]
		elseif ent.name=="__builtin:item" then
			local iname = ItemStack(ent.itemstring):get_name()
			print("object_height: dropped obj '"..ent.itemstring
				.."', iname '"..iname.."'")
			cb = minetest.registered_entities[ent.name].collisionbox
			if cb == nil then
				cb = minetest.registered_items[iname].collisionbox
			end
			if cb then
				-- This seems to never happen
				print("  found cb ("..cb[1]..", "..cb[2]..", "..cb[3]
					..", "..cb[4]..", "..cb[5]..", "..cb[6]..")")
				return cb[5]
			else
				-- Try to get the visual attribute, but it is never available
				local vs = minetest.registered_entities[ent.name].visual
				print("  no cb, visual '"..minetest.serialize(vs).."'")
				-- TODO: Can we test what version of the Minetest engine
				-- we're in? The size of __builtin:item objects changed,
				-- look in game/item_entity.lua for a call to register_entity
				-- it used to be about 0.33 and is presently 0.6
				return 0.6
			end
		else
			print("object_height: entity '"..ent.name.."'")
			cb = minetest.registered_entities[ent.name].collisionbox
			if cb then
				-- This seems to never happen
				print("  found cb ("..cb[1]..", "..cb[2]..", "..cb[3]
					..", "..cb[4]..", "..cb[5]..", "..cb[6]..")")
				return cb[5]
			else
				print("  no cb, assume small")
			end
		end
	else
		-- we couldn't get a laentity
	end

	-- if we get here we couldn't figure it out at all.
	return 0.1
end

minetest.register_on_leaveplayer(
	-- when a player leaves the game, make their portals expire
	function(user)
		local uname = user:get_player_name()
		for i=1, portalgun_getLength(id_p0rtal),1 do
			if id_p0rtal[i]~=0 and id_p0rtal[i].user==uname then
				id_p0rtal[i].lifetime=-1
				return 0
			end
		end
	end
)

-- step function or an individual portal: checks if there are things to
-- teleport
local function portalgun_step_proc(portal, id)
	if id_p0rtal[id] == 0 then
		return 0
	end
	-- print ("[portalgun] sproc(" .. portal .. ", " .. id  .. ")")

	-- check if portals have run out of lifetime. (If they are used, by
	-- an object getting teleported, the timer is reset, see below)
	id_p0rtal[id].lifetime = id_p0rtal[id].lifetime-1
	if id_p0rtal[id].lifetime < 0 then
		if id_p0rtal[id].portal1 ~= 0 then
			id_p0rtal[id].portal1:remove()
		end
		if id_p0rtal[id].portal2 ~= 0 then
			id_p0rtal[id].portal2:remove()
		end
		id_p0rtal[id] = 0
		return 0
	end

	-- get position and direction of entry portal (pos1, d1) and
	-- of exit portal (pos2, d2)
	local pos1 = 0
	local pos2 = 0
	local d1 = 0
	local d2 = 0
	if portal == 1 then
		pos1 = id_p0rtal[id].portal1_pos
		pos2 = id_p0rtal[id].portal2_pos
		d1 = id_p0rtal[id].portal1_dir
		d2 = id_p0rtal[id].portal2_dir
	else
		pos1 = id_p0rtal[id].portal2_pos
		pos2 = id_p0rtal[id].portal1_pos
		d1 = id_p0rtal[id].portal2_dir
		d2 = id_p0rtal[id].portal1_dir
	end


	if (pos2 ~= 0) and (pos1 ~= 0) then
		-- we have two portals, so teleporting is possible
		-- check all objects within a radius of 1.5 (it has to be this big
		-- to catch players, whose "position" is a point near the feet)
		for ii, ob in pairs(minetest.get_objects_inside_radius(pos1, 1.5)) do
			local ent = ob:get_luaentity()

			-- TODO: use object height to get a more refined sense of the
			-- object's true distance from the portal, and ignore if object
			-- is not within a closer radius
			-- local height = object_height(ob)

			if ent and ent.name == "portalgun:portal" then
				-- this object is the portal itself; ignore
			else
				-- ======= set velocity then teleport
				local p = pos2
				local x = 0
				local y = 0
				local z = 0

				if ob:is_player() then
					local r1 = 0
					if d1 == "x+" then r1 = math.pi/-2
					elseif d1 == "x-" then r1 = math.pi/2
					elseif d1 == "z+" then r1 = 0
					elseif d1 == "z-" then r1 = math.pi end
					
					local relative_yaw = (ob:get_look_yaw() - (math.pi/2)) - (r1 + math.pi)
					
					if d2 == "x+" then ob:set_look_yaw(relative_yaw + (math.pi/-2))
					elseif d2 == "x-" then ob:set_look_yaw(relative_yaw + (math.pi/2))
					elseif d2 == "z+" then ob:set_look_yaw(relative_yaw)
					elseif d2 == "z-" then ob:set_look_yaw(relative_yaw + math.pi)
					end

					y = -1
				else
					-- get object's current velocity.
					local v = ob:getvelocity() 

					-- compute the magnitude of the velocity
					local vmag = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)

					-- compute exit velocity. Objects always exit in a
					-- direction perpendicular to the exit portal, with
					-- speed equal to the speed they had when entering.
					v.x = 0
					v.y = 0
					v.z = 0
					if d2 == "x+" then
						v.x = vmag
						ob:setyaw(math.pi/-2)
					elseif d2 == "x-" then
						v.x = vmag*-1
						ob:setyaw(math.pi/2)
					elseif d2 == "y+" then
						v.y = vmag
					elseif d2 == "y-" then
						v.y = vmag*-1
					elseif d2 == "z+" then
						v.z = vmag
						ob:setyaw(0)
					elseif d2 == "z-" then
						v.z = vmag*-1
						ob:setyaw(math.pi)
					end

					ob:setvelocity({x = v.x, y = v.y, z = v.z})
				end

				-- Calculate exit point, 2 nodes away from the exit portal
				-- in whatever direction the exit portal is facing. It has
				-- to be 2 nodes away so we don't immediately get
				-- teleported again.
				-- TODO: Once we manage to decrease the capture radius of 1.5,
				-- we may also diminish this distance.
				if d2 == "x+" then x = 2
				elseif d2 == "x-" then x = -2
				elseif d2 == "y+" then y = 2
				elseif d2 == "y-" then y = -2
				elseif d2 == "z+" then z = 2
				elseif d2 == "z-" then z = -2
				end

				ob:moveto({x = p.x+x, y = p.y+y, z = p.z+z}, false)

				-- this portal has been used, so we should reset the
				-- portal's expiration timer
				id_p0rtal[id].lifetime = portalgun_lifetime

				-- ======= end of set velocity part then teleport
			end
		end
	end
	return 1
end

minetest.register_globalstep(
	-- periodically check all portals to see if objects have gotten within
	-- range
	function(dtime)
		-- if we have no portals, just exit right away
		if not portalgun_running then
			return 0
		end
		-- print "[portalgun] gstep"

		portalgun_time = portalgun_time + dtime
		if portalgun_time < portalgun_step_interval then
			return
		end

		portalgun_time=0
		local use=0

		for i=1, portalgun_getLength(id_p0rtal),1 do
			use = use + portalgun_step_proc(1, i)
			use = use + portalgun_step_proc(2, i)
		end
		if (use == 0) and (portalgun_getLength(id_p0rtal) > 0) then
			id_p0rtal = {}
			portalgun_running = false
		end
	end
)

minetest.register_entity("portalgun:portal", {		-- the portals
	visual = "mesh",
	mesh = "portalgun_portal_xp.obj",
	id=0,
	physical = false,
	textures ={"portalgun_blue.png"},
	visual_size = {x=0.66, y=0.66*2}, -- test
	-- automatic_rotate = math.pi * 2.9,
	spritediv = {x=7, y=0},
	collisionbox = {0,0,0,0,0,0},
	on_activate = function(self, staticdata)
		self.owner = ""
		self.pnum = 0
		self.id = 0
		if staticdata then
			local tmp = minetest.deserialize(staticdata)
			if tmp then
				if tmp.owner then
					self.owner = tmp.owner
				end
				if tmp.pnum then
					self.pnum = tmp.pnum
				end
				if tmp.id then
					self.id = tmp.id
				end
			end
		end
		if self.pnum > 0 then
--			print ("[portalgun] activate #" .. self.id .. ", p"..self.pnum.." for " .. self.owner)
		else
--			print ("[portalgun] portal just created")
		end

		-- a portal entity is being loaded into the environment because
		-- a player is nearby
		self.id = nxt_id
		if not id_p0rtal[self.id] then
--			print "[portalgun] not in pg_p table, removing."
			self.object:remove()
			return
		end
		local d=""
		local prj = 0
		if id_p0rtal[self.id].project then
			prj = id_p0rtal[self.id].project
		end
--		print ("[portalgun] id now "..self.id..", project="..prj)
		if prj==1 then -- label1
			d=id_p0rtal[self.id].portal1_dir
			
			if id_p0rtal[self.id].portal2 ~= 0 then
				self.object:set_properties({textures = {"portalgun_blue.png"},})
				id_p0rtal[self.id].portal2:set_properties({textures = {"portalgun_orange.png"},})
			else
				self.object:set_properties({textures = {"portalgun_blue_closed.png"},})
			end
		else
			d=id_p0rtal[self.id].portal2_dir

			if id_p0rtal[self.id].portal1 ~= 0 then
				self.object:set_properties({textures = {"portalgun_orange.png"},})
				id_p0rtal[self.id].portal1:set_properties({textures = {"portalgun_blue.png"},})
			else
				self.object:set_properties({textures = {"portalgun_orange_closed.png"},})
			end
		end

		if d=="x+" then self.object:setyaw(math.pi * 0)
		elseif d=="x-" then self.object:setyaw(math.pi * 1)
		elseif d=="y+" then self.object:set_properties({mesh = "portalgun_portal_yp.obj",}) -- becaouse there is no "setpitch"
		elseif d=="y-" then self.object:set_properties({mesh = "portalgun_portal_ym.obj",}) -- becaouse there is no "setpitch"
		elseif d=="z+" then self.object:setyaw(math.pi * 0.5) 
		elseif d=="z-" then self.object:setyaw(math.pi * 1.5)
			self.object:set_hp(1000)
		end	
	end,
	get_staticdata = function(self)
		local tmp = {
			owner = self.owner,
			pnum = self.pnum,
			id = self.id,
		}
--		print ("get_sd id="..self.id.." pnum="..self.pnum.." owner="..self.owner)
		return minetest.serialize(tmp)
	end,
})

local function portal_useproc(itemstack, user, pointed_thing, RMB, remove)
	--[[local moon = minetest.get_timeofday() -- 0 for midnight, 0.5 for midday
	local moon = (moon + 0.5) % 1 -- 0 for midday, 0.5 for midnight
	local moon = moon - 0.5 -- -0.5 for midday, 0 for midnight, 0.5 for midday]]
	
	-- print "[portalgun] useproc"
	local pnum = 1
	if RMB then
		pnum = 2
	end
    if pointed_thing.type ~= "node" then
		-- print "[portals] useproc: pt.type is not a node"
        return itemstack
    end
	local pos = pointed_thing.under
	local node = node_ok(pos)
	local nn = node.name

	-- portals can only be placed on walkable nodes: not torches, papyrus, etc.
	-- NOTE: We might also want to exclude certain node types (e.g. steps,
	-- fence, trapdoors, etc)
	if (not node.walkable) or (not (minetest.registered_nodes[nn] and minetest.registered_nodes[nn].groups.portalable)) then
		return itemstack
	end

	-- Modify the itemstack so the portal gun's color matches that of the new portal
	itemstack:set_name(RMB and "portalgun:gun_orange" or (remove and "portalgun:gun" or "portalgun:gun_blue"))

	pos = user:getpos()
	local dir = user:get_look_dir() -- unit vector
	local uname = user:get_player_name()
	local found = false
	local len = portalgun_getLength(id_p0rtal)

	-- in my mods is as default I set   0 or false   in a array when not
	-- using anymore, then clear the array when not used, that saves much.

	-- this check if you can hold shift+leftclick to clear your user-portals,
	-- lifetime=0 means the portals will die to next run.
	for i=1, len,1 do
		if id_p0rtal[i]~=0
			and id_p0rtal[i]~=nil
			and id_p0rtal[i].user==uname
		then
			if not RMB then
				-- left mouse button
				if remove then
					id_p0rtal[i].lifetime=0
					return itemstack
				end
			end
			found = true
			nxt_id = i
			break
		end
	end

	if not found then
		-- this user hasn't made any portals yet

		-- create a new set of portals, to add to the global list in the event
		-- this is the first time this player has used the gun
		local ob={} -- label2
		ob.project=1
		ob.lifetime=portalgun_lifetime
		ob.portal1=0
		ob.portal2=0
		ob.portal1_dir=0
		ob.portal2_dir=0
		ob.portal2_pos=0
		ob.portal1_pos=0
		ob.user = uname

		table.insert(id_p0rtal, ob)
		nxt_id = len+1
	end

	portalgun_running = true
	nxt_id = portalgun_getLength(id_p0rtal)

	-- we scan away from the player to find out what they hit. we need to
	-- start 1.5 blocks above the player's location because the gun is
	-- being held about that far above the player's feet.
	pos.y = pos.y+1.5

	-- the project
	for i = 1, (portalgun_max_range+1), 1 do
		if minetest.get_node({x=pos.x+(dir.x*i), y=pos.y+(dir.y*i), z=pos.z+(dir.z*i)}).name~="air" then
			local id = nxt_id
			if id_p0rtal[id]==0 then
				return itemstack
			end
			id_p0rtal[id].lifelim=portalgun_lifetime
			local lpos={x=pos.x+(dir.x*(i-1)), y=pos.y+(dir.y*(i-1)), z=pos.z+(dir.z*(i-1))}
			local cpos={x=pos.x+(dir.x*i), y=pos.y+(dir.y*i), z=pos.z+(dir.z*i)}
			local x=math.floor((lpos.x-cpos.x)+ 0.5)
			local y=math.floor((lpos.y-cpos.y)+ 0.5)
			local z=math.floor((lpos.z-cpos.z)+ 0.5)
			local portal_dir=0

			-- the rotation & poss of the portals 

			-- some overriding test calculations
			local x = pointed_thing.above.x - pointed_thing.under.x
			local y = pointed_thing.above.y - pointed_thing.under.y
			local z = pointed_thing.above.z - pointed_thing.under.z

			local portalable_above = minetest.get_node({x=pointed_thing.under.x, y=pointed_thing.under.y+1, z=pointed_thing.under.z}).name == "portalgun:portalable"
			local portalable_below = minetest.get_node({x=pointed_thing.under.x, y=pointed_thing.under.y-1, z=pointed_thing.under.z}).name == "portalgun:portalable"
			
			local cpos = pointed_thing.under--{x=(pointed_thing.under.x+pointed_thing.above.x)/2, y=(pointed_thing.under.y+pointed_thing.above.y)/2, z=(pointed_thing.under.z+pointed_thing.above.z)/2}

			local y_offset = 0
			if portalable_above then
				if portalable_below then y_offset = 0 else
					y_offset = 0.5 end
			else
				if portalable_below then y_offset = -0.5 else
					y_offset = 0
				end
			end

			if x>0 then
				portal_dir="x+"
				cpos.x=(math.floor(cpos.x+ 0.5))+0.504
				
				cpos.z=(math.floor(cpos.z+ 0.5))
				cpos.y=(math.floor(cpos.y+ 0.5)+ y_offset)
			elseif x<0 then
				portal_dir="x-"
				cpos.x=(math.floor(cpos.x+ 0.5))-0.504
				
				cpos.z=(math.floor(cpos.z+ 0.5))
				cpos.y=(math.floor(cpos.y+ 0.5)+ y_offset)
			elseif y>0 then
				portal_dir="y+"
				cpos.y=(math.floor(cpos.y+ 0.5))+0.504
				
				cpos.x=(math.floor(cpos.x+ 0.5))
				cpos.z=(math.floor(cpos.z+ 0.5))
			elseif y<0 then
				portal_dir="y-"
				cpos.y=(math.floor(cpos.y+ 0.5))-0.504

				cpos.x=(math.floor(cpos.x+ 0.5))
				cpos.z=(math.floor(cpos.z+ 0.5))
			elseif z>0 then
				portal_dir="z+"
				cpos.z=(math.floor(cpos.z+ 0.5))+0.504
				
				cpos.x=(math.floor(cpos.x+ 0.5))
				cpos.y=(math.floor(cpos.y+ 0.5)+ y_offset)
			elseif z<0 then
				portal_dir="z-"
				cpos.z=(math.floor(cpos.z+ 0.5))-0.504
				
				cpos.x=(math.floor(cpos.x+ 0.5))
				cpos.y=(math.floor(cpos.y+ 0.5)+ y_offset)
			end

			local obj = 0
			if RMB then
				id_p0rtal[id].project=2
				id_p0rtal[id].portal2_dir=portal_dir
				id_p0rtal[id].portal2_pos=cpos
				if id_p0rtal[id].portal2~=0 then
					id_p0rtal[id].portal2:remove()
				end
				obj = minetest.env:add_entity(cpos, "portalgun:portal")
				id_p0rtal[id].portal2 = obj
			else
				id_p0rtal[id].project=1
				id_p0rtal[id].portal1_dir=portal_dir
				id_p0rtal[id].portal1_pos=cpos
				if id_p0rtal[id].portal1~=0 then
					id_p0rtal[id].portal1:remove()
				end
				obj = minetest.env:add_entity(cpos, "portalgun:portal")
				id_p0rtal[id].portal1 = obj
			end
			if obj then
				-- fill in its staticdata
				local ent = obj:get_luaentity()
				if ent then
					ent.owner = uname
					ent.pnum = pnum
					ent.id = id
				end
			end

			local op = uname
			if RMB then
				op = op .. "2"
			else
				op = op .. "1"
			end
			if (not op_prtl[op]) or (op_prtl[op] == 0) then
				op_prtl[op] = {}
			end
			op_prtl[op].pnum = pnum
			op_prtl[op].portal = obj
			op_prtl[op].owner = uname
			op_prtl[op].pos = cpos
			op_prtl[op].dir = portal_dir
			

--			print ("[portalgun] created #"..id.." p"..pnum.." for "..uname)
			if not remove then
				minetest.sound_play("portalgun_shoot", {pos=pos})
			end
			return itemstack
		end
	end
	return itemstack
end

function onPlace(itemstack, user, pointed_thing)
	-- print "[portalgun] on_place"
	local key = user:get_player_control()
	if (key.sneak) then
		-- remove both portals
		return portal_useproc(itemstack, user, pointed_thing, false, true)
	else
		-- place orange portal
		return portal_useproc(itemstack, user, pointed_thing, true, false)
	end
end
function onUse(itemstack, user, pointed_thing)
	-- print "[portalgun] on_use"
	local key = user:get_player_control()
	if (key.sneak) then
		-- remove both portals
		return portal_useproc(itemstack, user, pointed_thing, false, true)
	else
		-- place blue portal
		return portal_useproc(itemstack, user, pointed_thing, false, false)
	end
end

minetest.register_tool("portalgun:gun", {
	description = "Portal Gun",
	inventory_image = "portalgun_gun.png",
	range = portalgun_max_range,
	wield_image = "portalgun_gun.png",
	-- groups = { not_in_creative_inventory = 1 },
	on_use = onUse,
	on_place = onPlace
})
minetest.register_tool("portalgun:gun_blue", {
	description = "Portal Gun (blue most recently placed)",
	inventory_image = "portalgun_gun_blue.png",
	range = portalgun_max_range,
	wield_image = "portalgun_gun_blue.png",
	groups = { not_in_creative_inventory = 1 },
	on_use = onUse,
	on_place = onPlace
})
minetest.register_tool("portalgun:gun_orange", {
	description = "Portal Gun (orange most recently placed)",
	inventory_image = "portalgun_gun_orange.png",
	range = portalgun_max_range,
	wield_image = "portalgun_gun_orange.png",
	groups = { not_in_creative_inventory = 1 },
	on_use = onUse,
	on_place = onPlace
})

minetest.register_node("portalgun:unportalable", {
	description = "Unportalable Surface",
	tiles = {"portalgun_unportalable_y.png", "portalgun_unportalable_y.png", "portalgun_unportalable.png", "portalgun_unportalable.png", "portalgun_unportalable.png", "portalgun_unportalable.png"},
	groups = {cracky = 1, level = 2},
	sounds = default.node_sound_metal_defaults(),
})
minetest.register_node("portalgun:portalable", {
	description = "Portalable Surface",
	tiles = {"portalgun_portalable_y.png", "portalgun_portalable_y.png", "portalgun_portalable.png", "portalgun_portalable.png", "portalgun_portalable.png", "portalgun_portalable.png"},
	groups = {cracky = 1, level = 2, portalable = 1},
	sounds = default.node_sound_metal_defaults(),
})
