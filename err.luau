--!native
--!optimize 2
--!strict

type complex = {r : number, i : number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local cpx = require("cpx.lua")
local gate = require("gate.lua")
local mtx = require("mtx.lua")
local qb = require("qb.lua")
local preset = require("preset.lua")

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

--[[
	TODO_LIST:
		- bitflip code
		- signflip code
		- bosonic code:
			+ binomial code
			+ cat code

]]

return err
