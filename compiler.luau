--!native
--!optimize 2
--!strict

-- feel free to advance this further i'm too lazy

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type operation = {gate: string, target: number, control: number?}

local gate = require("gate")
local preset = require("preset")
local noise = require("noise")

local compiler = {}

function compiler.parse(algorithm: {operation}): {operation}
	return algorithm
end

function compiler.optimize(circuit: {operation}): {operation}
	local optimized_circuit: {operation} = {}
	
	for _, op in ipairs(circuit) do
		if #optimized_circuit > 0 and optimized_circuit[#optimized_circuit].gate == op.gate then
			if op.gate == "paulix" then
				table.remove(optimized_circuit)
			else
				table.insert(optimized_circuit, op)
			end
		else
			table.insert(optimized_circuit, op)
		end
	end

	return optimized_circuit
end

function compiler.compile(circuit: {operation}): {gate}
	local instructions: {gate} = {}
	for _, op in ipairs(circuit) do
		if op.gate == "hadamard" then
			table.insert(instructions, preset.hadamard)
		elseif op.gate == "cnot" then
			assert(op.control, "control was not provided")
			table.insert(instructions, gate.cnot(op.control, op.target))
		elseif op.gate == "paulix" then
			table.insert(instructions, preset.paulix)
		elseif op.gate == "pauliy" then
			table.insert(instructions, preset.pauliy)
		elseif op.gate == "pauliz" then
			table.insert(instructions, preset.pauliz)
		end
	end
	return instructions
end

function compiler.apply_noise(circuit: {gate}, noise_model: noise.noise_meta): {gate}
	local noisy_circuit: {gate} = {}
	for _, qubit_state in ipairs(circuit) do
		table.insert(noisy_circuit, noise_model:apply_all(qubit_state))
	end
	return noisy_circuit
end

function compiler.compile_algorithm(algorithm: {operation}, noise_model: noise.noise_meta): {gate}
	local parsed_circuit = compiler.parse(algorithm)
	local optimized_circuit = compiler.optimize(parsed_circuit)
	local machine_instructions = compiler.compile(optimized_circuit)
	local noisy_circuit = compiler.apply_noise(machine_instructions, noise_model)
	return noisy_circuit
end

return compiler