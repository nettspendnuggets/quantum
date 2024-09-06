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

function bb84.eavesdrop_detection(bits_1: bits, bits_2: bits, matching_indices: bits, sample_size: {
	sample: number?;
	tolerate: number?;
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

function e91.bell_test(results_1: {number}, results_2: {number}, threshold : number?): boolean
	local count = #results_1
	local violation_threshold = (threshold or 0.75) * count -- adjust based on bells inequality criteria
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

function b92.generatebits(n: number): bits
	local bitstring = table.create(n)
	for i = 1, n do
		bitstring[i] = math.random(0, 1)
	end
	return bitstring
end

function b92.preparequbit(bit: number): qubit
	local qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	if bit == 0 then
		qubit = gate.apply(qubit, preset.hadamard)
	else
		qubit = gate.apply(qubit, preset.paulix)
	end
	return qubit
end

function b92.preparequbits(bits: bits): qubits
	local prepared = table.create(#bits)
	for i, bit in ipairs(bits) do
		prepared[i] = b92.preparequbit(bit)
	end
	return prepared
end

function b92.measurequbit(qubit: qubit): number
	local basis = math.random(0, 1)
	if basis == 0 then
		return qb.measure(qubit)
	else
		qubit = gate.apply(qubit, preset.hadamard)
		return qb.measure(qubit)
	end
end

function b92.measurequbits(qubits: qubits): bits
	local results = table.create(#qubits)
	for i, qubit in ipairs(qubits) do
		results[i] = b92.measurequbit(qubit)
	end
	return results
end

function b92.siftkey(sendbits: bits, receivebits: bits): bits
	local key = {}
	for i = 1, #sendbits do
		if sendbits[i] == 0 and receivebits[i] == 1 then
			table.insert(key, 0)
		elseif sendbits[i] == 1 and receivebits[i] == 0 then
			table.insert(key, 1)
		end
	end
	return key
end

function b92.errorestimation(alicekey: bits, bobkey: bits, samplesize: number?): number
	local errors = 0
	local samples = math.min(samplesize or math.floor(#alicekey * 0.1), #alicekey)
	
	for i = 1, samples do
		if alicekey[i] ~= bobkey[i] then
			errors += 1
		end
	end
	
	return errors / samples
end

function b92.privacyamplification(key: bits, finallength: number?): bits
	local actuallength = finallength or math.floor(#key * 0.75)
	local newkey = table.create(actuallength)
	
	for i = 1, actuallength do
		local xorsum = 0
		for j = 1, #key do
			xorsum = bit32.bxor(xorsum, key[j] * ((j * 1103515245 + 12345) % 32768))
		end
		newkey[i] = bit32.band(xorsum, 1)
	end
	
	return newkey
end

crypto.b92 = b92

local sixstates = {}

local BASIS_Z = "Z"
local BASIS_X = "X"
local BASIS_Y = "Y"

function sixstates.generatebits(n: number): bits
	local bits = table.create(n)
	for i = 1, n do
		bits[i] = math.random(0, 1)
	end
	return bits
end

function sixstates.generatebases(n: number): {string}
	local bases = table.create(n)
	for i = 1, n do
		bases[i] = ({BASIS_Z, BASIS_X, BASIS_Y})[math.random(1, 3)]
	end
	return bases
end

function sixstates.preparequbits(bits: bits, bases: {string}): qubits
	local qubits = table.create(#bits)
	for i, bit in ipairs(bits) do
		local qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))
		if bit == 1 then
			qubit = gate.apply(qubit, preset.paulix)
		end
		if bases[i] == BASIS_X then
			qubit = gate.apply(qubit, preset.hadamard)
		elseif bases[i] == BASIS_Y then
			qubit = gate.apply(qubit, preset.hadamard)
			qubit = gate.apply(qubit, preset.phase)
		end
		qubits[i] = qubit
	end
	return qubits
end

function sixstates.measurequbits(qubits: qubits, bases: {string}): bits
	local results = table.create(#qubits)
	for i, qubit in ipairs(qubits) do
		local basis = bases[i]
		if basis == BASIS_X then
			qubit = gate.apply(qubit, preset.hadamard)
		elseif basis == BASIS_Y then
			qubit = gate.apply(qubit, gate.dagger(preset.phase))
			qubit = gate.apply(qubit, preset.hadamard)
		end
		results[i] = qb.measure(qubit)
	end
	return results
end

function sixstates.siftkey(bits: bits, basesa: {string}, basesb: {string}): bits
	local key = {}
	for i = 1, #bits do
		if basesa[i] == basesb[i] then
			table.insert(key, bits[i])
		end
	end
	return key
end

function sixstates.errorestimation(alicekey: bits, bobkey: bits, samplesize: number?): number
	local errors = 0
	local samples = math.min(samplesize or math.floor(#alicekey * 0.1), #alicekey)
	
	for i = 1, samples do
		if alicekey[i] ~= bobkey[i] then
			errors += 1
		end
	end
	
	return errors / samples
end

function sixstates.privacyamplification(key: bits, finallength: number?): bits
	local actuallength = finallength or math.floor(#key * 0.75)
	local newkey = table.create(actuallength)
	
	for i = 1, actuallength do
		local xorsum = 0
		for j = 1, #key do
			xorsum = bit32.bxor(xorsum, key[j] * ((j * 1103515245 + 12345) % 32768))
		end
		newkey[i] = bit32.band(xorsum, 1)
	end
	
	return newkey
end

crypto.sixstates = sixstates

local diqkd = {}

local function apply_epr_pair(): (qubit, qubit)
	local qubit_a = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	local qubit_b = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	qubit_a = gate.apply(qubit_a, preset.hadamard)

	local entangled_qubits = gate.apply_ex({qubit_a, qubit_b}, preset.cnot)
	return entangled_qubits[1], entangled_qubits[2]
end

function diqkd.share_entangled_qubits(n: number): {{qubit}}
	local p = {}
	for i = 1, n do
		local qubit_a, qubit_b = apply_epr_pair()
		table.insert(p, {qubit_a, qubit_b})
	end
	return p
end

function diqkd.measure_qubits(pairs: {{qubit}}, basis_1: {string}, basis_2: {string}): {{number}}
	local results = {}
	for i, pair in ipairs(pairs) do
		local qubit_a = pair[1]
		local qubit_b = pair[2]
		
		local a_basis = basis_1[i]
		local b_basis = basis_2[i]

		local a_result = diqkd.measure_in_basis(qubit_a, a_basis)
		local b_result = diqkd.measure_in_basis(qubit_b, b_basis)

		table.insert(results, {a_result, b_result})
	end
	return results
end

function diqkd.measure_in_basis(qubit: qubit, basis: string): number
	if basis == "X" then
		qubit = gate.apply(qubit, preset.hadamard)
	end
	return qb.measure(qubit)
end

function diqkd.compare_results(results: {{number}}): {boolean}
	local dtc = {}
	for _, result_pair in ipairs(results) do
		local result_1 = result_pair[1]
		local result_2 = result_pair[2]
		
		if result_1 ~= result_2 then
			table.insert(dtc, true)
		else
			table.insert(dtc, false)
		end
	end
	return dtc
end

crypto.diqkd = diqkd

return crypto