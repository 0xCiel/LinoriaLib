local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			self.Library:Notify('No config file selected')
			return false
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if not self.Ignore[idx] then
				table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
			end
		end

		for idx, option in next, Options do
			if self.Parser[option.Type] and not self.Ignore[idx] then
				table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
			end
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			self.Library:Notify('Failed to encode data: ' .. tostring(encoded))
			return false
		end

		local success, err = pcall(writefile, fullPath, encoded)
		if not success then
			self.Library:Notify('Failed to save file: ' .. tostring(err))
			return false
		end

		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			self.Library:Notify('No config file selected')
			return false
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not pcall(isfile, file) then 
			self.Library:Notify('Invalid file')
			return false 
		end

		local fileContent
		local success, err = pcall(readfile, file)
		if not success then
			self.Library:Notify('Failed to read file: ' .. tostring(err))
			return false
		else
			fileContent = err
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, fileContent)
		if not success then 
			self.Library:Notify('Failed to decode data: ' .. tostring(decoded))
			return false 
		end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() 
					local success, err = pcall(self.Parser[option.type].Load, self, option.idx, option)
					if not success and self.Library then
						self.Library:Notify('Failed to load option ' .. tostring(option.idx) .. ': ' .. tostring(err))
					end
				end)
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName',
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not pcall(isfolder, str) then
				local success, err = pcall(makefolder, str)
				if not success and self.Library then
					self.Library:Notify('Failed to create folder: ' .. tostring(err))
				end
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list
		local success, err = pcall(listfiles, self.Folder .. '/settings')
		if not success then
			if self.Library then
				self.Library:Notify('Failed to list configs: ' .. tostring(err))
			end
			return {}
		else
			list = err
		end

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		if pcall(isfile, self.Folder .. '/settings/autoload.txt') then
			local name, err = pcall(readfile, self.Folder .. '/settings/autoload.txt')
			if not name then
				if self.Library then
					self.Library:Notify('Failed to read autoload: ' .. tostring(err))
				end
				return
			end

			local success, err = self:Load(name)
			if not success and self.Library then
				self.Library:Notify('Failed to load autoload config: ' .. tostring(err))
			elseif success and self.Library then
				self.Library:Notify(string.format('Auto loaded config %q', name))
			end
		end
	end

	function SaveManager:BuildConfigSection(tab)
		if not self.Library then
			self.Library:Notify('Must set SaveManager.Library')
		end

		local section = tab:AddRightGroupbox('Configuration')

		section:AddInput('SaveManager_ConfigName', { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if name:gsub(' ', '') == '' then 
				self.Library:Notify('Invalid config name (empty)', 2)
				return
			end

			local success, err = self:Save(name)
			if not success then
				self.Library:Notify('Failed to save config: ' .. tostring(err))
			else
				self.Library:Notify(string.format('Created config %q', name))
				Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				Options.SaveManager_ConfigList:SetValue(nil)
			end
		end)

		section:AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then
				self.Library:Notify('No config selected')
				return
			end

			local success, err = self:Load(name)
			if not success then
				self.Library:Notify('Failed to load config: ' .. tostring(err))
			else
				self.Library:Notify(string.format('Loaded config %q', name))
			end
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then
				self.Library:Notify('No config selected')
				return
			end

			local success, err = self:Save(name)
			if not success then
				self.Library:Notify('Failed to overwrite config: ' .. tostring(err))
			else
				self.Library:Notify(string.format('Overwrote config %q', name))
			end
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then
				self.Library:Notify('No config selected')
				return
			end

			local success, err = pcall(writefile, self.Folder .. '/settings/autoload.txt', name)
			if not success then
				self.Library:Notify('Failed to set autoload: ' .. tostring(err))
			else
				SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
				self.Library:Notify(string.format('Set %q to auto load', name))
			end
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if pcall(isfile, self.Folder .. '/settings/autoload.txt') then
			local name, err = pcall(readfile, self.Folder .. '/settings/autoload.txt')
			if name then
				SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			elseif self.Library then
				self.Library:Notify('Failed to read autoload: ' .. tostring(err))
			end
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
