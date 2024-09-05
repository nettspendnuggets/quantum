--!native
--!optimize 2
--!strict

type complex = {r : number, i : number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}
type noise_obj = {
	__index : noise_obj;
	new : ( probabilities : {
		bitflip : number?;
		phaseflip : number?;
		depolarizing : number?;
	}) -> noise_meta;
	apply_bitflip : (self : noise_meta, qubits : qubits) -> qubits;
	apply_phaseflip : (self : noise_meta, qubits : qubits) -> qubits;
	apply_depolarizing : (self : noise_meta, qubits : qubits) -> qubits;
	apply_all : (self : noise_meta, qubits : qubits) -> qubits;
}
type noise_meta = typeof(setmetatable({} :: {
	bitflip : number;
	phaseflip : number;
	depolarizing : number;
}, {} :: noise_obj))

local gate = require("gate.luau")
local preset = require("preset.luau")

local noise : noise_obj = {} :: noise_obj
noise.__index = noise

function noise.new(probabilities : {
	bitflip : number?;
	phaseflip : number?;
	depolarizing : number?;
})
	local meta = {}
	meta.bitflip = probabilities.bitflip or 0.02
	meta.phaseflip = probabilities.phaseflip or 0.02
	meta.depolarizing = probabilities.depolarizing or 0.02
	setmetatable(meta, noise)

	return meta
end

function noise:apply_bitflip(qubits: qubits): qubits
	local noisy_qubits = {}
	for i, qubit in ipairs(qubits) do
		if math.random() < self.bitflip then
			noisy_qubits[i] = gate.apply(qubit, preset.paulix)
		else
			noisy_qubits[i] = qubit
		end
	end
	return noisy_qubits
end

function noise:apply_phaseflip(qubits: qubits): qubits
	local noisy_qubits = {}
	for i, qubit in ipairs(qubits) do
		if math.random() < self.phaseflip then
			noisy_qubits[i] = gate.apply(qubit, preset.pauliz)
		else
			noisy_qubits[i] = qubit
		end
	end
	return noisy_qubits
end

function noise:apply_depolarizing(qubits: qubits): qubits
	local noisy_qubits = {}
	for i, qubit in ipairs(qubits) do
		if math.random() < self.depolarizing then
			local noise_type = math.random()
			if noise_type < 1/3 then
				noisy_qubits[i] = gate.apply(qubit, preset.paulix)
			elseif noise_type < 2/3 then
				noisy_qubits[i] = gate.apply(qubit, preset.pauliy)
			else
				noisy_qubits[i] = gate.apply(qubit, preset.pauliz)
			end
		else
			noisy_qubits[i] = qubit
		end
	end
	return noisy_qubits
end

function noise:apply_all(qubits: qubits): qubits
	qubits = self:apply_bitflip(qubits)
	qubits = self:apply_phaseflip(qubits)
	qubits = self:apply_depolarizing(qubits)
	return qubits
end

return noise