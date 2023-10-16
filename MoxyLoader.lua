-- --==:[[ ASSIGNMENTS ]]:==--
local Moxy = { }
local Meta = { }

-- --==:[[ CONSTANTS ]]:==--
-- Services
local RunService = game:GetService("RunService")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local ServerScriptService = game:GetService("ServerScriptService")

-- --==:[[ HELPERS ]]:==--
local function PrintTable(tab)
	for k, v in tab do
		print(k, v)
	end
end

-- --==:[[ MAIN LOGIC ]]:==--
-- Utilizing call manipulation to abstract the concept of invoking a table, making it possible to execute the following chunk of code
Meta.__call = function(t, ...)

	-- Multiple options for arguments to be built later on if necessary (varargs)
	local args = {...}
	local bootType = args[1]

	if type(bootType) ~= 'string' then
		error('bootType must be a string')
	end

	if bootType == "Boot" then

		-- Path evaluation
		local path = nil
		if RunService:IsServer( ) then
			path = ServerScriptService.MoxyServer.Server
		elseif RunService:IsClient( ) then -- Safety
			path = StarterPlayerScripts.MoxyClient.Client
		else
			error('Invalid side trying to load Moxy main module')
		end

		local sidesVars = {
			["MetaVars"] = { },
			["Privates"] = { }
		}
		-- Handle public functions, assign the private functions to sidesVars table, evaluate the MetaVars and also collect them
		local function loadModulesInfo()
			for id, module in path:GetDescendants() do
				-- If the module is not a ModuleScript, continue
				if module.ClassName ~= "ModuleScript" then
					continue
				end
				-- Change the path of the module to load in the client side as it's supposed to be
				if RunService:IsClient( ) then
					local playerScriptsFolder = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
					module.Parent = playerScriptsFolder
				end

				-- Using pcall to handle any errors that may occur when requiring the module
				local success, loadedModule = pcall(require, module)
				if success then
					-- Check if the module has either of the methods:
					if not loadedModule.Public and not loadedModule.Private then
						error("The module has to have either a public or a private method to load")
					end

					-- Check if the module has a public method to execute before trying to do it
					if loadedModule.Public then
						-- Execute the public function and then remove it to ensure cleaner MetaVars
						loadedModule:Public()
						loadedModule.Public = nil
					end

					if loadedModule.Private then
						-- Remove private function so the MetaVars become cleaner
						table.insert(sidesVars["Privates"], loadedModule.Private)
						loadedModule.Private = nil
					end

					-- Copy all the elements from loadedModule to MetaVars
					for index, var in loadedModule do
						sidesVars["MetaVars"][index] = var
					end
				else
					print('Error loading module: '..tostring(loadedModule))
				end
			end
		end

		-- Call the function to load the modules info
		loadModulesInfo( )

		-- Handle the logic of loading the private functions and setting the MetaVars
		local function loadPrivates_setMetaVars()
			-- Loop through the numerically indexed table of private functions
			for _, private in ipairs(sidesVars["Privates"]) do
				-- Create a coroutine to handle the private functions that will be executed quickly using several threads
				local routine = coroutine.create(function( )
					-- Create the metamethod to borrow variables from the metatable
					-- This is done to avoid having to use a modified environment to store the variables
					-- Also, this is possible due to the fact that we built a new scope for each module
					local formattedModule = {
						Private = private,
						BorrowVar = setmetatable({ }, {
							__call = function(t, var)
								if rawget(sidesVars["MetaVars"], var) then
									return rawget(sidesVars["MetaVars"], var)
								else
									error("This variable does not exist in any module")
								end
							end,
						})
					}
					-- Call the private method
					formattedModule:Private()
				end)

				-- Using pcall to handle any errors that may occur when resuming the coroutine
				local success, err = coroutine.resume(routine)
				if not success then
					print('Error with coroutine: '..tostring(err))
				end
			end
		end

		-- Call the function to load the private functions and set the metavars
		loadPrivates_setMetaVars( )
	end
end

-- Metatable definition
Moxy = setmetatable(Moxy, Meta)

return Moxy
