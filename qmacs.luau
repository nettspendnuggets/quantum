--!native
--!optimize 2
--!strict

local quantum = require("quantum")
local cpx = quantum.cpx
local gate = quantum.gate
local qb = quantum.qb
local mtx = quantum.mtx
local preset = quantum.preset

export type complex = quantum.complex
export type qubit = quantum.qubit
export type qubits = quantum.qubits
export type gate = quantum.gate
export type matrix = quantum.matrix

local qmacs = {}

-- QMACS Configuration
qmacs.config = {
	max_qubits = 32,
	max_gates = 1000,
	error_rate = 0.001,
	decoherence_time = 100, -- in microseconds
}

-- Quantum Register
qmacs.register = {
	qubits = {},
	size = 0,
}

function qmacs.init_register(size: number)
	assert(size > 0 and size <= qmacs.config.max_qubits, "Invalid register size")
	qmacs.register.qubits = qb.new_ex(size)
	qmacs.register.size = size
end

function qmacs.apply_gate(g: gate, target_qubits: {number})
	assert(#target_qubits <= qmacs.register.size, "Invalid number of target qubits")
	local new_state = gate.apply_ex(qmacs.register.qubits, g, target_qubits)
	qmacs.register.qubits = new_state
end

function qmacs.measure(qubit_index: number): number
	assert(qubit_index > 0 and qubit_index <= qmacs.register.size, "Invalid qubit index")
	return qb.measure(qmacs.register.qubits[qubit_index])
end

function qmacs.measure_all(): {number}
	return qb.mmeasure_ex(qmacs.register.qubits)
end

-- Reset a specific qubit to |0> state
function qmacs.reset_qubit(qubit_index: number)
	assert(qubit_index > 0 and qubit_index <= qmacs.register.size, "Invalid qubit index")
	qmacs.register.qubits[qubit_index] = qb.new(cpx.new(1, 0), cpx.new(0, 0))
end

-- Reset all qubits to |0> state
function qmacs.reset_all()
	qmacs.register.qubits = qb.new_ex(qmacs.register.size)
end

function qmacs.get_state(): qubits
	return qmacs.register.qubits
end

function qmacs.apply_noise()
	for i = 1, qmacs.register.size do
		if math.random() < qmacs.config.error_rate then
			local noise_gate = gate.rx(math.random() * math.pi / 10)
			qmacs.apply_gate(noise_gate, {i})
		end
	end
end

function qmacs.simulate_decoherence(time: number)
	local decoherence_probability = 1 - math.exp(-time / qmacs.config.decoherence_time)
	for i = 1, qmacs.register.size do
		if math.random() < decoherence_probability then
			qmacs.reset_qubit(i)
		end
	end
end

-- Create a custom gate
function qmacs.create_custom_gate(matrix: matrix): gate
	assert(mtx.is_unitary(matrix), "Custom gate must be unitary")
	return matrix
end

function qmacs.qft()
	local n = qmacs.register.size
	for i = 1, n do
		qmacs.apply_gate(preset.hadamard, {i})
		for j = i + 1, n do
			local angle = 2 * math.pi / (2^(j-i+1))
			local controlled_phase = gate.controlled_phase(angle)
			qmacs.apply_gate(controlled_phase, {i, j})
		end
	end
	-- Swap qubits
	for i = 1, math.floor(n/2) do
		qmacs.apply_gate(preset.swap, {i, n-i+1})
	end
end

function qmacs.inverse_qft()
	local n = qmacs.register.size
	for i = 1, math.floor(n/2) do
		qmacs.apply_gate(preset.swap, {i, n-i+1})
	end
	for i = n, 1, -1 do
		for j = n, i + 1, -1 do
			local angle = -2 * math.pi / (2^(j-i+1))
			local controlled_phase = gate.controlled_phase(angle)
			qmacs.apply_gate(controlled_phase, {i, j})
		end
		qmacs.apply_gate(preset.hadamard, {i})
	end
end

-- Grover's algorithm
function qmacs.grovers_algorithm(oracle: gate, iterations: number)
	local n = qmacs.register.size
	
	for i = 1, n do
		qmacs.apply_gate(preset.hadamard, {i})
	end
	
	for _ = 1, iterations do
		qmacs.apply_gate(oracle, {1, n})
		
		for i = 1, n do
			qmacs.apply_gate(preset.hadamard, {i})
		end
		for i = 1, n do
			qmacs.apply_gate(preset.paulix, {i})
		end
		qmacs.apply_gate(gate.controlledgate(preset.pauliz), {1, n})
		for i = 1, n do
			qmacs.apply_gate(preset.paulix, {i})
		end
		for i = 1, n do
			qmacs.apply_gate(preset.hadamard, {i})
		end
	end
end

function qmacs.phase_estimation(unitary: gate, precision: number)
	local n = qmacs.register.size
	local m = math.ceil(math.log(1/precision, 2))
	
	assert(n > m, "Not enough qubits for desired precision")
	
	for i = 1, m do
		qmacs.apply_gate(preset.hadamard, {i})
	end
	
	for i = 1, m do
		local controlled_u = gate.controlled_unitary(unitary, i, m+1, 2^(i-1))
		qmacs.apply_gate(controlled_u, {i, m+1})
	end
	
	qmacs.inverse_qft()
end

function qmacs.quantum_teleportation(source: number, target: number)
	assert(source ~= target, "Source and target qubits must be different")
	assert(source > 0 and source <= qmacs.register.size, "Invalid source qubit")
	assert(target > 0 and target <= qmacs.register.size, "Invalid target qubit")
	
	local aux = if source < target then target - 1 else target + 1
	
	qmacs.apply_gate(preset.hadamard, {aux})
	qmacs.apply_gate(preset.cnot, {aux, target})
	
	qmacs.apply_gate(preset.cnot, {source, aux})
	qmacs.apply_gate(preset.hadamard, {source})
	
	local m1 = qmacs.measure(source)
	local m2 = qmacs.measure(aux)
	
	if m2 == 1 then
		qmacs.apply_gate(preset.paulix, {target})
	end
	if m1 == 1 then
		qmacs.apply_gate(preset.pauliz, {target})
	end
end

-- Simple 3-qubit bit flip code
function qmacs.apply_error_correction()
	assert(qmacs.register.size >= 3, "Need at least 3 qubits for error correction")
	
	qmacs.apply_gate(preset.cnot, {1, 2})
	qmacs.apply_gate(preset.cnot, {1, 3})
	
	qmacs.apply_noise()
	
	qmacs.apply_gate(preset.cnot, {1, 2})
	qmacs.apply_gate(preset.cnot, {1, 3})
	qmacs.apply_gate(preset.ccnot, {2, 3, 1})
end

function qmacs.execute_circuit(circuit: {gate})
	for _, g in ipairs(circuit) do
		qmacs.apply_gate(g, {1, qmacs.register.size})
		qmacs.simulate_decoherence(1)
	end
end

local function qubits_to_complex_vector(state: qubits): {complex}
    local vector = {}
    for i = 1, #state do
        table.insert(vector, cpx.new(state[i].alpha.r, state[i].alpha.i)) -- That's axtrcts problem, haha!
    end
    return vector
end

function qmacs.state_tomography(measurements: number): matrix
    local n = qmacs.register.size
    local density_matrix = mtx.create_empty({r = 2^n, c = 2^n})
    
    for _ = 1, measurements do
        local state = qmacs.get_state()
        local complex_vector = qubits_to_complex_vector(state)
        local proj = mtx.outer_product(complex_vector, complex_vector)
        density_matrix = mtx.add(density_matrix, proj)
    end
    
    return mtx.scalar_mul(cpx.new(1/measurements, 0), density_matrix)
end

return qmacs