--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local gate = require("gate")
local preset = require("preset")

local decay = {}

function decay.new(probabilities: {
	amplitude_damping: number?;
	phase_damping: number?;
	depolarizing: number?;
})
	local meta = {}
	meta.amplitude_damping = probabilities.amplitude_damping or 0.01
	meta.phase_damping = probabilities.phase_damping or 0.02
	meta.depolarizing = probabilities.depolarizing or 0.02
	setmetatable(meta, decay)

	return meta
end

function decay:apply_amplitude_damping(qubits: qubits): qubits
	local noisy_qubits = {}
	for i, qubit in ipairs(qubits) do
		if math.random() < self.amplitude_damping then
			noisy_qubits[i] = gate.apply(qubit, preset.identity)
		else
			noisy_qubits[i] = qubit
		end
	end
	return noisy_qubits
end

function decay:apply_phase_damping(qubits: qubits): qubits
	local noisy_qubits = {}
	for i, qubit in ipairs(qubits) do
		if math.random() < self.phase_damping then
			noisy_qubits[i] = gate.apply(qubit, preset.pauliz)
		else
			noisy_qubits[i] = qubit
		end
	end
	return noisy_qubits
end

function decay:apply_depolarizing(qubits: qubits): qubits
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

function decay:apply_all(qubits: qubits): qubits
	qubits = self:apply_amplitude_damping(qubits)
	qubits = self:apply_phase_damping(qubits)
	qubits = self:apply_depolarizing(qubits)
	return qubits
end

return decay