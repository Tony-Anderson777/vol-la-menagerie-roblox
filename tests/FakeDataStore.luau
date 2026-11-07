-- FakeDataStore : un faux DataStore pour les tests (ModuleScript dans ServerStorage > Tests).
-- Il garde les données en mémoire et peut, à la demande, échouer ou attendre,
-- pour reproduire les pannes de Roblox sans attendre qu'elles arrivent vraiment.

local FakeDataStore = {}
FakeDataStore.__index = FakeDataStore

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

function FakeDataStore.new()
	return setmetatable({
		data = {}, -- [clé] = valeur enregistrée
		failUpdates = false, -- true : chaque UpdateAsync lève une erreur
		failGets = false, -- true : chaque GetAsync lève une erreur
		failKeys = {}, -- [clé] = true : UpdateAsync échoue seulement pour cette clé
		delay = 0, -- secondes d'attente avant chaque appel
		updateCount = 0, -- nombre d'écritures réussies
	}, FakeDataStore)
end

function FakeDataStore:seed(key, value)
	self.data[key] = deepCopy(value)
end

function FakeDataStore:peek(key)
	return deepCopy(self.data[key])
end

function FakeDataStore:GetAsync(key)
	if self.delay > 0 then
		task.wait(self.delay)
	end
	if self.failGets then
		error("FakeDataStore : GetAsync en panne")
	end
	return deepCopy(self.data[key])
end

function FakeDataStore:UpdateAsync(key, transform)
	if self.delay > 0 then
		task.wait(self.delay)
	end
	if self.failUpdates or self.failKeys[key] then
		error("FakeDataStore : UpdateAsync en panne")
	end
	local newValue = transform(deepCopy(self.data[key]))
	if newValue == nil then
		return nil -- écriture annulée par la fonction
	end
	self.data[key] = deepCopy(newValue)
	self.updateCount += 1
	return deepCopy(newValue)
end

return FakeDataStore
