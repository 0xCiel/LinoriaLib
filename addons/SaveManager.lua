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
		if not name then
			self.Library:Notify('No config file selected')
			return false
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'
		local data = { objects = {} }

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

		local encoded = httpService:JSONEncode(data)
		if not encoded then
			self.Library:Notify('Failed to encode data')
			return false
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if not name then
			self.Library:Notify('No config file selected')
			return false
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then
			self.Library:Notify('Invalid file')
			return false
		end

		local decoded = httpService:JSONDecode(readfile(file))
		if not decoded then
			self.Library:Notify('Decode error')
			return false
		end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
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
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')
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
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			local success = self:Load(name)
			if success then
				self.Library:Notify(string.format('Auto loaded config %q', name))
			end
		end
	end

	function SaveManager:BuildConfigSection(tab)
		if not self.Library then
			error('Must set SaveManager.Library')
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

			local success = self:Save(name)
			if success then
				self.Library:Notify(string.format('Created config %q', name))
				Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				Options.SaveManager_ConfigList:SetValue(nil)
			end
		end)

		section:AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value
			local success = self:Load(name)
			if success then
				self.Library:Notify(string.format('Loaded config %q', name))
			end
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value
			local success = self:Save(name)
			if success then
				self.Library:Notify(string.format('Overwrote config %q', name))
			end
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set as autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
