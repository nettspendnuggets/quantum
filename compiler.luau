--!native
--!optimize 2
--!strict

-- feel free to advance this further i'm too lazy
-- dude?? it's literally like basic stuff

local EPSILON = 1e-10
local MAX_QUBITS = 10

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type operation = {gate: string, target: number, control: number?, params: {number}?}

local gate = require("gate")
local preset = require("preset")
local noise = require("noise")

local compiler = {}

local function _isclose(a: number, b: number): boolean
	return math.abs(a - b) < EPSILON
end

local function matrixmultiply(a: gate, b: gate): gate
	local result: gate = table.create(#a)
	local colsb = #b[1]
	
	for i = 1, #a do
		result[i] = table.create(colsb)
		for j = 1, colsb do
			local sum = { r = 0, i = 0 }
			for k = 1, #a[1] do
				sum.r += a[i][k].r * b[k][j].r - a[i][k].i * b[k][j].i
				sum.i += a[i][k].r * b[k][j].i + a[i][k].i * b[k][j].r
			end
			result[i][j] = sum
		end
	end
	
	return result
end

function compiler.parse(algorithm: { operation }): { operation }
	local parsed = table.create(#algorithm)
	
	for _, op in ipairs(algorithm) do
		if type(op) == "table" and op.gate and op.target then
			table.insert(parsed, op)
		else
			warn("Invalid operation skipped:", op)
		end
	end
	
	return parsed
end

function compiler.optimize(circuit: { operation }): { operation }
	local optimized = table.create(#circuit)
	local i = 1
	
	while i <= #circuit do
		local current = circuit[i]
		local next = circuit[i + 1]
		
		if next and current.gate == next.gate and current.target == next.target then
			if current.gate == "paulix" or current.gate == "pauliy" or current.gate == "pauliz" then
				i += 2  -- Cancel out consecutive Pauli gates
			elseif current.gate == "rotation" and current.params and next.params then
				-- Combine consecutive rotations
				current.params[1] += next.params[1]
				table.insert(optimized, current)
				i += 2
			else
				table.insert(optimized, current)
				i += 1
			end
		else
			table.insert(optimized, current)
			i += 1
		end
	end
	
	return optimized
end

function compiler.compile(circuit: { operation }): { gate }
	local instructions = table.create(#circuit)
	
	for _, op in ipairs(circuit) do
		local gatematrix: gate
		
		if op.gate == "hadamard" then
			gatematrix = preset.hadamard
		elseif op.gate == "cnot" then
			assert(op.control, "Control qubit not specified for CNOT gate")
			gatematrix = gate.cnot(op.control, op.target)
		elseif op.gate == "paulix" then
			gatematrix = preset.paulix
		elseif op.gate == "pauliy" then
			gatematrix = preset.pauliy
		elseif op.gate == "pauliz" then
			gatematrix = preset.pauliz
		elseif op.gate == "rotation" then
			assert(op.params and #op.params == 3, "Rotation gate requires 3 parameters")
			gatematrix = gate.rx(op.params[1])
			gatematrix = matrixmultiply(gate.ry(op.params[2]), gatematrix)
			gatematrix = matrixmultiply(gate.rz(op.params[3]), gatematrix)
		elseif op.gate == "phase" then
			assert(op.params and #op.params == 1, "Phase gate requires 1 parameter")
			gatematrix = gate.rz(op.params[1])
		elseif op.gate == "toffoli" then
			assert(op.control, "Control qubit not specified for Toffoli gate")
			gatematrix = gate.toffoli() -- AXTRCT. i hope that your gate is good enough to handle toffoli, 
		else                            -- it should probably take parameters to specify the control and target qubits
			error("Unknown gate: " .. op.gate) -- and im not checking this at all. if it isn't good enough, code breaks.
		end
		
		table.insert(instructions, gatematrix)
	end
	
	return instructions
end

function compiler.applynoise(circuit: { gate }, noisemodel: noise.noise_meta): { gate }
	local noisycircuit = table.create(#circuit)
	
	for _, gatematrix in ipairs(circuit) do
		local noisygate = noisemodel:apply_all(gatematrix)
		table.insert(noisycircuit, noisygate)
	end
	
	return noisycircuit
end

function compiler.compresscircuit(circuit: { gate }): { gate }
	local compressed = {}
	local currentgate: gate = circuit[1]
	
	for i = 2, #circuit do
		local nextgate = circuit[i]
		local combined = matrixmultiply(nextgate, currentgate)
		
		if #combined <= MAX_QUBITS then
			currentgate = combined
		else
			table.insert(compressed, currentgate)
			currentgate = nextgate
		end
	end
	
	table.insert(compressed, currentgate)
	return compressed
end

function compiler.compilealgorithm(algorithm: { operation }, noisemodel: noise.noise_meta?): { gate }
	local parsedcircuit = compiler.parse(algorithm)
	local optimizedcircuit = compiler.optimize(parsedcircuit)
	local machineinstructions = compiler.compile(optimizedcircuit)
	local compressedcircuit = compiler.compresscircuit(machineinstructions)
	
	if noisemodel then
		return compiler.applynoise(compressedcircuit, noisemodel)
	else
		return compressedcircuit
	end
end

function compiler.simulate(compiledcircuit: { gate }, initialstate: qubits): qubits
	local state = initialstate
	
	for _, gatematrix in ipairs(compiledcircuit) do
		state = gate.apply_ex(state, gatematrix)
	end
	
	return state
end

function compiler.measure(state: qubits): { number }
	local probabilities = table.create(#state)
	local totalprobability = 0
	
	for i, amplitude in ipairs(state) do
		local probability = amplitude[1].r * amplitude[1].r + amplitude[1].i * amplitude[1].i
		probabilities[i] = probability
		totalprobability += probability
	end
	
	-- Normalize probabilities
	for i, prob in ipairs(probabilities) do
		probabilities[i] = prob / totalprobability
	end
	
	local result = {}
	local random = math.random()
	local cumulative = 0
	
	for i, prob in ipairs(probabilities) do
		cumulative += prob
		if random <= cumulative then
			result[1] = i - 1  -- convert to 0-based index
			break
		end
	end
	
	-- convert result to binary representation
	local binary = table.create(math.log(#state, 2))
	local value = result[1]
	for i = 1, #binary do
		binary[i] = value % 2
		value = math.floor(value / 2)
	end
	
	return binary
end

return compiler