--!native
--!optimize 2
--!strict


local quantum = require("quantum")
local cpx = quantum.cpx
local qb = quantum.qb
local gate = quantum.gate
local preset = quantum.preset

local secret_sharing = {}

export type complex = {r: number, i: number}
export type qubit = {complex}
export type qubits = {qubit}

-- Classical Shamir's Secret Sharing

local function mod_pow(base: number, exponent: number, modulus: number): number
	local result = 1
	base = base % modulus
	while exponent > 0 do
		if exponent % 2 == 1 then
			result = (result * base) % modulus
		end
		exponent = math.floor(exponent / 2)
		base = (base * base) % modulus
	end
	return result
end

local function generate_polynomial(secret: number, threshold: number, prime: number): {number}
	local coefficients = {secret}
	for i = 2, threshold do
		coefficients[i] = math.random(0, prime - 1)
	end
	return coefficients
end

local function evaluate_polynomial(coefficients: {number}, x: number, prime: number): number
	local result = 0
	for i, coeff in ipairs(coefficients) do
		result = (result + coeff * mod_pow(x, i - 1, prime)) % prime
	end
	return result
end

function secret_sharing.generate_shares(secret: number, num_shares: number, threshold: number, prime: number): {{number}}
	local coefficients = generate_polynomial(secret, threshold, prime)
	local shares = {}
	for i = 1, num_shares do
		local x = i
		local y = evaluate_polynomial(coefficients, x, prime)
		table.insert(shares, {x, y})
	end
	return shares
end

local function mod_inverse(a: number, m: number): number
	local m0, x0, x1 = m, 0, 1
	while a > 1 do
		local q = math.floor(a / m)
		m, a = a % m, m
		x0, x1 = x1 - q * x0, x0
	end
	return x1 < 0 and x1 + m0 or x1
end

function secret_sharing.reconstruct_secret(shares: {{number}}, prime: number): number
	local secret = 0
	for i, share_i in ipairs(shares) do
		local xi, yi = share_i[1], share_i[2]
		local numerator, denominator = 1, 1
		for j, share_j in ipairs(shares) do
			if i ~= j then
				local xj = share_j[1]
				numerator = (numerator * (xj % prime)) % prime
				denominator = (denominator * ((xj - xi + prime) % prime)) % prime
			end
		end
		local lagrange = (yi * numerator * mod_inverse(denominator, prime)) % prime
		secret = (secret + lagrange) % prime
	end
	return secret
end


local function encode_qubit(qubit: qubit, threshold: number, num_shares: number): qubits
	local encoded_qubits: qubits = {}
	for i = 1, num_shares do
		local new_qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))
		encoded_qubits[i] = new_qubit
	end
	
	for i = 2, threshold do
		local result = gate.apply_ex({qubit, encoded_qubits[i]}, preset.cnot)
		encoded_qubits[i] = result[2]
	end
	
	for i = threshold + 1, num_shares do
		encoded_qubits[i] = gate.apply(encoded_qubits[i], preset.hadamard)
	end
	
	return encoded_qubits
end

function secret_sharing.quantum_share_secret(secret_qubit: qubit, num_shares: number, threshold: number): qubits
	return encode_qubit(secret_qubit, threshold, num_shares)
end

function secret_sharing.quantum_reconstruct_secret(shares: qubits, threshold: number): qubit
	local reconstructed_qubit = shares[1]
	
	for i = 2, threshold do
		local result = gate.apply_ex({reconstructed_qubit, shares[i]}, preset.cnot)
		reconstructed_qubit = result[1]
	end
	
	return reconstructed_qubit
end

-- VSS (Verifiable Secret Sharing)

local function generate_commitment(value: number, prime: number): (number, number)
	local r = math.random(1, prime - 1)
	local commitment = (mod_pow(2, value, prime) * mod_pow(3, r, prime)) % prime
	return commitment, r
end

function secret_sharing.vss_generate_shares(secret: number, num_shares: number, threshold: number, prime: number): ({{number}}, {{number}}, number, number)
	local coefficients = generate_polynomial(secret, threshold, prime)
	local shares = {}
	local commitments = {}
	
	for i = 1, num_shares do
		local x = i
		local y = evaluate_polynomial(coefficients, x, prime)
		table.insert(shares, {x, y})
	end
	
	for _, coeff in ipairs(coefficients) do
		local commitment, r = generate_commitment(coeff, prime)
		table.insert(commitments, {commitment, r})
	end
	
	return shares, commitments, coefficients[1], commitments[1][2]
end

function secret_sharing.vss_verify_share(share: {number}, commitments: {{number}}, prime: number): boolean
	local x, y = share[1], share[2]
	local product = 1
	
	for i, commitment in ipairs(commitments) do
		local c = commitment[1]
		product = (product * mod_pow(c, mod_pow(x, i - 1, prime), prime)) % prime
	end
	
	local verify = (mod_pow(2, y, prime) * mod_pow(3, math.random(1, prime - 1), prime)) % prime
	return product == verify
end

return secret_sharing