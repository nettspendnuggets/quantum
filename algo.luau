--!native
--!optimize 2
--!strict

local gate = require("gate")
local qb = require("qb")
local preset = require("preset")

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type matrix = {{complex}}
type matrix_sz = {r: number, c: number}

local algo = {}

function algo.shor(n: number): number
	local function period(a: number, n: number): number
		local q = 2^math.ceil(math.log(n^2, 2))
		local qs = qb.new_ex(q)
		qs = gate.apply_ex(qs, preset.hadamard)
		for i = 0, q - 1 do
			qs = gate.apply_ex(qs, gate.controlled_modular_exponentiation(a, n, i))
		end
		return qb.mmeasure(qb.qft(qs))
	end
	local function gcd(a: number, b: number): number
		while b ~= 0 do
			a, b = b, a % b
		end
		return a
	end
	if n % 2 == 0 then return 2 end
	local a = math.random(2, n - 1)
	local g = gcd(a, n)
	if g > 1 then return g end
	local r = period(a, n)
	if r % 2 ~= 0 then return algo.shor(n) end
	local factor = gcd(a^(r//2) + 1, n)
	if factor == 1 or factor == n then return algo.shor(n) end
	return factor
end

function algo.grover(f: (qubits) -> qubits, n: number): number
	local qs = qb.new_ex(n)
	qs = gate.apply_ex(qs, preset.hadamard)
	local iterations = math.floor(math.pi/4 * math.sqrt(2^n))
	for _ = 1, iterations do
		qs = f(qs)
		qs = gate.diffusion(qs)
	end
	return qb.mmeasure(qs)
end

function algo.qft(qs: qubits): qubits
	local n = #qs
	for i = 1, n do
		qs = gate.apply_ex(qs, preset.hadamard)
		for j = i + 1, n do
			local angle = 2 * math.pi / (2^(j - i + 1))
			qs = gate.apply_ex(qs, gate.controlled_phase(angle))
		end
	end
	for i = 1, n // 2 do
		qs = gate.apply_ex(qs, preset.swap)
	end
	return qs
end

function algo.vqe(hamiltonian: matrix, depth: number): number
	local n = #hamiltonian
	local function ansatz(params: {number}): qubits
		local qs = qb.new_ex(n)
		local param_idx = 1
		for _ = 1, depth do
			for i = 1, n do
				qs = gate.apply_ex(qs, gate.rx(params[param_idx]))
				param_idx = param_idx + 1
				qs = gate.apply_ex(qs, gate.ry(params[param_idx]))
				param_idx = param_idx + 1
			end
			for i = 1, n - 1 do
				qs = gate.apply_ex(qs, preset.cnot)
			end
		end
		return qs
	end

	local function objective(params: {number}): number
		local qs = ansatz(params)
		return qb.expectation(qs, hamiltonian)
	end

	local params = table.create(2 * n * depth, 0)
	for i = 1, #params do
		params[i] = math.random() * 2 * math.pi
	end

	local iterations = 100
	local learning_rate = 0.1
	for _ = 1, iterations do
		local grad = table.create(#params, 0)
		for i = 1, #params do
			local params_plus = table.clone(params)
			local params_minus = table.clone(params)
			params_plus[i] = params_plus[i] + 0.01
			params_minus[i] = params_minus[i] - 0.01
			grad[i] = (objective(params_plus) - objective(params_minus)) / 0.02
		end
		for i = 1, #params do
			params[i] = params[i] - learning_rate * grad[i]
		end
	end

	return objective(params)
end

function algo.qaoa(qubits: qubits, p: number, gammas: {number}, betas: {number}): qubits
	for k = 1, p do
		qubits = gate.cost_hamiltonian(qubits, gammas[k])
		qubits = gate.mixer_hamiltonian(qubits, betas[k])
	end
	return qubits
end

function algo.qpe(qs: qubits, unitary: matrix, precision: number): qubits
	for i = 1, precision do
		qs = gate.apply_ex(qs, preset.hadamard)
	end
	for i = 1, precision do
		local control_qubit = i
		local exponent = 2^(precision - i)
		qs = gate.apply_ex(qs, gate.controlled_unitary(unitary, control_qubit, precision + 1, exponent))
	end

	qs = (function(qs: qubits, n: number): qubits
		for i = n, 1, -1 do
			for j = i + 1, n do
				local angle = -2 * math.pi / (2^(j - i + 1))
				qs = gate.apply_ex(qs, gate.controlled_phase(angle))
			end
			qs = gate.apply_ex(qs, preset.hadamard)
		end
		return qs
	end)(qs, precision)

	return qs
end

return algo