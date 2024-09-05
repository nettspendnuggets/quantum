--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type bits = {number}

local qb = require("qb")
local gate = require("gate")
local cpx = require("cpx")
local preset = require("preset")

local crypto = {}

local bb84 = {}

local function random_bit(): number
	return math.random(0, 1)
end

--[[

	how to use bb84:
	user 1:
	generate_random_bits -> generate_random_bases -> prepare_qubits
	user 2:
	generate_random_bits -> generate_random_bases -> prepare_qubits
	compare:
	compare_bases -> sift_key (user 1) -> sift_key (user 2)
	spy dtc:
	eavesdrop_detection
	privacy amp:
	privacy_amplification (user 1) -> privacy_amplification (user 2)

]]

function bb84.generate_random_bits(n: number): bits
	local bitstring = {}
	for i = 1, n do
		bitstring[i] = random_bit()
	end
	return bitstring
end

function bb84.generate_random_bases(n: number): bits
	local bases = {}
	for i = 1, n do
		bases[i] = random_bit() -- 0 for rectilinear (|0⟩, |1⟩), 1 for diagonal (|+⟩, |-⟩)
	end
	return bases
end

function bb84.prepare_qubits(bits: bits, bases: bits): qubits
	local qubits = {}
	for i = 1, #bits do
		local bit = bits[i]
		local basis = bases[i]
		local qubit
		if basis == 0 then
			-- rectilinear basis: |0⟩ or |1⟩
			qubit = bit == 0 and qb.new(cpx.new(1, 0), cpx.new(0, 0)) or qb.new(cpx.new(0, 0), cpx.new(1, 0))
		else
			-- diagonal basis: |+⟩ = (|0⟩ + |1⟩)/√2 or |−⟩ = (|0⟩ − |1⟩)/√2
			qubit = bit == 0 and qb.new(cpx.new(1 / math.sqrt(2), 0), cpx.new(1 / math.sqrt(2), 0))
				or qb.new(cpx.new(1 / math.sqrt(2), 0), cpx.new(-1 / math.sqrt(2), 0))
		end
		qubits[i] = qubit
	end
	return qubits
end

function bb84.measure_qubits(qubits: qubits, bases: bits): bits
	local measured_bits = {}
	for i = 1, #qubits do
		local qubit = qubits[i]
		local basis = bases[i]
		local result
		if basis == 0 then
			-- rectilinear basis
			result = qb.measure(qubit)
		else
			-- diagonal basis
			qubit = gate.apply(qubit, preset.hadamard)
			result = qb.measure(qubit)
		end
		measured_bits[i] = result
	end
	return measured_bits
end

function bb84.compare_bases(bases_1: bits, bases_2: bits): bits
	local matching_indices = {}
	for i = 1, #bases_1 do
		if bases_1[i] == bases_2[i] then
			table.insert(matching_indices, i)
		end
	end
	return matching_indices
end

function bb84.sift_key(bits: bits, matching_indices: bits): bits
	local key = {}
	for _, index in ipairs(matching_indices) do
		table.insert(key, bits[index])
	end
	return key
end

function bb84.eavesdrop_detection(bits_1: bits, bits_2: bits, matching_indices: bits, sample_size : {
	sample : number?;
	tolerate : number?;
}?): boolean
	local a = sample_size or {
		sample = 0.1;
		tolerate = 0.2;
	}
	local samp = math.floor(#matching_indices * (a.sample or 0.1))
	local errors = 0

	for i = 1, samp do
		local index = matching_indices[i]
		if bits_1[index] ~= bits_2[index] then
			errors += 1
		end
	end

	return errors / samp < (a.tolerate or 0.2)
end

function bb84.privacy_amplification(key: bits): bits
	local new_key = {}
	for i = 1, #key, 2 do
		new_key[#new_key + 1] = bit32.bxor(bit32.lrotate(bit32.bxor(key[i], key[i + 1]) % 2, i),
			bit32.rshift(key[i] * math.random(1, #key), bit32.bxor(#new_key, os.time())))
	end
	return new_key
end

crypto.bb84 = bb84

local e91 = {}

function e91.entangle(n: number): {qubits}
	local entangled_pairs = {}
	for i = 1, n do
		-- epr pair (|00⟩ + |11⟩) / √2
		local qubits = qb.new_ex(2)
		qubits[1] = qb.new(cpx.new(1 / math.sqrt(2), 0), cpx.new(0, 0))
		qubits[2] = qb.new(cpx.new(0, 0), cpx.new(1 / math.sqrt(2), 0))
		table.insert(entangled_pairs, qubits)
	end
	return entangled_pairs
end

function e91.random_basis(n: number): {number}
	local bases = {}
	for i = 1, n do
		bases[i] = math.random(1, 3)
	end
	return bases
end

function e91.measure_qubit(qubit: qubit, basis: number): number
	if basis == 1 then
		return qb.measure(qubit)
	elseif basis == 2 then
		local rotated_qubit = gate.apply(qubit, preset.paulix)
		return qb.measure(rotated_qubit)
	elseif basis == 3 then
		local rotated_qubit = gate.apply(qubit, preset.pauliz)
		return qb.measure(rotated_qubit)
	end
	error("three basis only")
end

function e91.bell_test(results_1: {number}, results_2: {number}): boolean
	local count = #results_1
	local violation_threshold = 0.75 * count -- adjust based on Bell inequality criteria
	local violations = 0

	for i = 1, count do
		if results_1[i] ~= results_2[i] then
			violations += 1
		end
	end

	-- since e91 is based on violation of the bells thing, if it is violated -> secure
	return violations / count > violation_threshold
end

function e91.sift_key(bits_1: {number}, bits_2: {number}, bases_1: {number}, bases_2: {number}): {number}
	local key = {}
	for i = 1, #bits_1 do
		if bases_1[i] == bases_2[i] then
			table.insert(key, bits_1[i])
		end
	end
	return key
end

crypto.e91 = e91

local b92 = {}

function b92.prepare_qubits(bits: {number}): qubits
	local qubits = {}
	for i = 1, #bits do
		if bits[i] == 0 then
			qubits[i] = qb.new(cpx.new(1, 0), cpx.new(0, 0))  -- |0>
		else
			qubits[i] = qb.new(cpx.new(0, 0), cpx.new(1, 0))  -- |1>
		end
	end
	return qubits
end

function b92.measure_qubits(qubits: qubits, bases: {number}): {number}
	local results = {}
	for i = 1, #qubits do
		if bases[i] == 0 then
			results[i] = qb.measure(gate.apply(qubits[i], preset.pauliz)) -- Measure in Z basis
		else
			results[i] = qb.measure(gate.apply(qubits[i], preset.paulix)) -- Measure in X basis
		end
	end
	return results
end

function b92.sift_key(bits: {number}, bases: {number}, measured_bases: {number}): {number}
	local key = {}
	for i = 1, #bits do
		if bases[i] == measured_bases[i] then
			table.insert(key, bits[i])
		end
	end
	return key
end

crypto.b92 = b92

return crypto