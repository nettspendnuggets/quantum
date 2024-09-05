--!native
--!optimize 2
--!strict

--[[
	NOTE: these are extremely basic, try to reimplement them in some way that is more complex
]]

type complex = {r : number, i : number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local cpx = require("cpx.luau")
local gate = require("gate.luau")
local mtx = require("mtx.luau")
local qb = require("qb.luau")
local preset = require("preset.luau")

local err = {}

function err.shor(N : number): (number, number)
	local function mod_exp(base: number, exp: number, mod: number): number
		local result = 1
		base = base % mod
		while exp > 0 do
			if exp % 2 == 1 then
				result = (result * base) % mod
			end
			base = (base * base) % mod
			exp = math.floor(exp / 2)
		end
		return result
	end
	local function gcd(a: number, b: number): number
		while b ~= 0 do
			local temp = b
			b = a % b
			a = temp
		end
		return a
	end
	local function classical_shor(N: number): (number, number)
		if N % 2 == 0 then
			return 2, N / 2
		end

		local a = math.random(2, N - 1)
		local g = gcd(a, N)
		if g > 1 then
			return g, N / g -- i hope so.
		end

		return a, -1
	end
	local function continued_fraction(x: number, N: number): (number, number)
		local epsilon = 1e-6
		local a, b = 0, 1
		local prev_a, prev_b = 1, 0

		while math.abs(a / b - x) > epsilon do
			local q = math.floor(x)
			x = 1 / (x - q)
			local temp_a = a
			a = q * a + prev_a
			prev_a = temp_a

			local temp_b = b
			b = q * b + prev_b
			prev_b = temp_b
		end
		return a, b
	end
	local a, factor = classical_shor(N)
	if factor then
		return factor, N / factor
	end

	local qs = qb.new_ex(math.ceil(math.log(N) / math.log(2)))
	qs = gate.phase_estimation(a, N, qs)

	local period = qb.mmeasure(qs)
	local _, r = continued_fraction(period / (2^#qs), N)

	if r % 2 == 0 then
		local x1 = mod_exp(a, r // 2, N) - 1
		local x2 = mod_exp(a, r // 2, N) + 1
		local factor1 = gcd(x1, N)
		local factor2 = gcd(x2, N)

		if factor1 > 1 and factor2 > 1 then
			return factor1, factor2
		end
	end

	return err.shor(N)
end

local steane = {}

function steane.new() : qubits
	local qubits = {}
	for i = 1, 7 do
		qubits[i] = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	end
	return qubits
end

function steane.encode(qubit : qubit) : qubits
	local encoded = steane.new()
	
	encoded[1] = gate.apply(qubit, preset.paulix)
	encoded[2] = gate.apply(qubit, preset.paulix)
	encoded[3] = gate.apply(qubit, preset.hadamard)
	encoded[4] = gate.apply(qubit, preset.hadamard)
	encoded[5] = gate.apply(qubit, preset.paulix)
	encoded[6] = gate.apply(qubit, preset.paulix)
	encoded[7] = gate.apply(qubit, preset.hadamard)

	return encoded
end

function steane.measure_synd(qubits : qubits) : matrix
	local synd = mtx.new({r = 3, c = 7})
	local H = mtx.new({r = 3, c = 7},
		cpx.new(1), cpx.new(1), cpx.new(1), cpx.new(1), cpx.new(), cpx.new(), cpx.new(),
		cpx.new(1), cpx.new(-1), cpx.new(1), cpx.new(-1), cpx.new(), cpx.new(), cpx.new(),
		cpx.new(1), cpx.new(1), cpx.new(-1), cpx.new(-1), cpx.new(1), cpx.new(1), cpx.new(-1)
	)
	for i = 1, 3 do
		for j = 1, 4 do
			synd[i][j] = cpx.new(0, 0)
			for k = 1, 7 do
				synd[i][j] = cpx.add(synd[i][j], cpx.mul(qubits[k][j], H[i][k]))
			end
		end
	end

	return synd
end

function steane.correct_errors(qubits : qubits, synd : matrix) : qubits
	local ecr_mtx = mtx.identity(7)
	for i = 1, 7 do
		for j = 1, 3 do
			if synd[j][i] == cpx.new(1, 0) then
				qubits = gate.apply_ex(qubits, ecr_mtx)
			end
		end
	end

	return qubits
end

function steane.decode(qubits: qubits): qubit
	local decoded = qb.new(cpx.new(), cpx.new())
	decoded = gate.apply(decoded, preset.hadamard)
	decoded = gate.apply(decoded, preset.paulix)

	return decoded
end

err.steane = steane

local surface = {}

function surface.create_grid(size: number): qubits
	local qubits = {}
	for i = 1, size * size do
		qubits[i] = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	end
	return qubits
end

function surface.stabilizers(size: number): (matrix, matrix)
	local x_stabilizers = {}
	local z_stabilizers = {}

	for i = 1, size do
		x_stabilizers[i] = {}
		z_stabilizers[i] = {}
		for j = 1, size do
			x_stabilizers[i][j] = cpx.new(0, 0)
			z_stabilizers[i][j] = cpx.new(0, 0)
		end
	end

	for i = 1, size do
		for j = 1, size do
			x_stabilizers[i][j] = cpx.new(1, 0)
		end
	end

	for i = 1, size - 1 do
		for j = 1, size - 1 do
			z_stabilizers[i][j] = cpx.new(1, 0)
		end
	end

	return x_stabilizers, z_stabilizers
end

function surface.measure_syndrome(qubits: qubits, x_stabilizers: matrix, z_stabilizers: matrix): ({complex}, {complex})
	local x_syndrome = {}
	local z_syndrome = {}

	for i = 1, #x_stabilizers do
		x_syndrome[i] = cpx.new()
		for j = 1, #x_stabilizers[i] do
			x_syndrome[i] = cpx.add(x_syndrome[i], cpx.mul(qubits[j][1], x_stabilizers[i][j]))
		end
	end

	for i = 1, #z_stabilizers do
		z_syndrome[i] = cpx.new()
		for j = 1, #z_stabilizers[i] do
			z_syndrome[i] = cpx.add(z_syndrome[i], cpx.mul(qubits[j][1], z_stabilizers[i][j]))
		end
	end

	return x_syndrome, z_syndrome
end

function surface.correct_errors(qubits: qubits, x_syndrome: {number}, z_syndrome: {number}): qubits
	for i = 1, #x_syndrome do
		if x_syndrome[i] == 1 then
			qubits[i] = gate.apply(qubits[i], preset.paulix)
		end
	end

	for i = 1, #z_syndrome do
		if z_syndrome[i] == 1 then
			qubits[i] = gate.apply(qubits[i], preset.pauliz)
		end
	end

	return qubits
end

err.surface = surface

local bitflip = {}

function bitflip.encode(qubit: qubit): qubits
	local encoded = {}
	for i = 1, 3 do
		encoded[i] = qb.new(cpx.new(qubit[1].r, qubit[1].i), cpx.new(0, 0))
	end
	return encoded
end

function bitflip.apply_error(encoded: qubits, qubit_index: number, error_type: string): qubits
	if error_type == "bitflip" then
		encoded[qubit_index] = gate.apply(encoded[qubit_index], preset.paulix)
	elseif error_type == "phaseflip" then
		encoded[qubit_index] = gate.apply(encoded[qubit_index], preset.pauliz)
	elseif error_type == "both" then
		encoded[qubit_index] = gate.apply(encoded[qubit_index], preset.paulix)
		encoded[qubit_index] = gate.apply(encoded[qubit_index], preset.pauliz)
	else
		error("Unknown error type")
	end
	return encoded
end

function bitflip.decode(encoded: qubits): qubit
	local counts = {0, 0}
	for i = 1, 3 do
		if encoded[i][1].r > 0.5 then
			counts[1] = counts[1] + 1
		else
			counts[2] = counts[2] + 1
		end
	end
	local state = counts[1] > counts[2] and cpx.new(1, 0) or cpx.new(0, 0)
	return qb.new(state, cpx.new(0, 0))
end

function bitflip.correct_errors(encoded: qubits): qubits
	local syndrome = {0, 0, 0}
	for i = 1, 3 do
		syndrome[i] = (encoded[i][1].r > 0.5 and 1 or 0)
	end

	local majority = (syndrome[1] + syndrome[2] + syndrome[3]) / 2
	for i = 1, 3 do
		if syndrome[i] ~= majority then
			encoded[i] = gate.apply(encoded[i], preset.paulix)
		end
	end

	return encoded
end

err.bitflip = bitflip

local signflip = {}

function signflip.encode(qubit: qubit): qubits
	local encoded = {}
	for i = 1, 3 do
		encoded[i] = qb.new(cpx.new(qubit[1].r, qubit[1].i), cpx.new(0, 0))
	end
	return encoded
end

function signflip.apply_error(encoded: qubits, qubit_index: number): qubits
	encoded[qubit_index] = gate.apply(encoded[qubit_index], preset.pauliz)
	return encoded
end

function signflip.decode(encoded: qubits): qubit
	local counts = {0, 0}
	for i = 1, 3 do
		if encoded[i][1].r > 0.5 then
			counts[1] = counts[1] + 1
		else
			counts[2] = counts[2] + 1
		end
	end
	local state = counts[1] > counts[2] and cpx.new(1, 0) or cpx.new(0, 0)
	return qb.new(state, cpx.new(0, 0))
end

function signflip.measure_syndrome(encoded: qubits): {number}
	local syndrome = {0, 0}
	for i = 1, 3 do
		if encoded[i][1].r < 0.5 then
			syndrome[i] = 1
		else
			syndrome[i] = 0
		end
	end
	return syndrome
end

function signflip.correct_errors(encoded: qubits, syndrome: {number}): qubits
	for i = 1, 3 do
		if syndrome[i] == 1 then
			encoded[i] = gate.apply(encoded[i], preset.pauliz)
		end
	end
	return encoded
end

err.signflip = signflip

local cat = {}

-- TODO: make cat codes

err.cat = cat

local binomial = {}

-- TODO: make this too

err.binomial = binomial

return err
