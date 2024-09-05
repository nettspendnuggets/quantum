--!native
--!optimize 2
--!strict

type complex = {r : number, i : number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local cpx = require("cpx")
local gate = require("gate")
local mtx = require("mtx")

-- NOTE: THIS IS FOR SINGULAR QUBIT SYSTEMS
-- MULTI-QUBIT FUNCTIONS WILL HAVE "m" AT THE START OF THE FUNCTION NAME

local qb = {}

function qb.new(alpha : complex, beta : complex)
	return {alpha, beta}
end

function qb.new_ex(n : number) : qubits
	local size = 2 ^ n
	local qubits = {}
	for i = 1, size do
		qubits[i] = qb.new(cpx.new(if i == 1 then 1 else 0, 0), cpx.new(0, 0))
	end
	return qubits
end

-- rudimentary but works

function qb.measure(qubit : qubit)
	return if math.random() <= (qubit[1].r ^ 2 + qubit[1].i ^ 2) then 0 else 1
end

function qb.run(qi : number, gates : {gate}?)
	local qubits = {}

	for i = 1, qi do
		-- init qubit at |0⟩ state
		local qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))

		local co = coroutine.create(function()
			if gates then
				for _, g in ipairs(gates) do
					-- since we're dealing with single qubits, we can apply the gate
					-- and take the first qubit
					qubit = gate.apply_ex({qubit}, g)[1]
				end
			end

			while true do
				print("qubit[" .. i .. "]: state: |0⟩: " .. qubit[1].r .. "+" .. qubit[1].i ..
					"i, |1⟩: " .. qubit[2].r .. "+" .. qubit[2].i .. "i")
				print("measured value:", qb.measure(qubit))
				coroutine.yield()
			end
		end)
		table.insert(qubits, co)
	end

	for _, co : thread in ipairs(qubits) do
		coroutine.resume(co)
	end
end

function qb.mnew(n: number) : qubits
	local qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0)) -- |0⟩ state
	local qubit2 = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	-- this is the kronecker product of the two qubits
	-- for n qubits, the system is rep by 2^n states
	local qubits = {}
	for i = 2, n do
		qubits = mtx.kronecker({qubit}, {qubit2})
	end
	return qubits
end

-- WIP
function qb.mapply(qubits : qubits, g : gate) : qubits
	return gate.apply_ex(qubits, g)
end

function qb.mrun(qi : number, gates : {gate}?)
	local qubits = qb.new_ex(qi)
	local co_qubits = {}

	for i = 1, qi do
		local co = coroutine.create(function()
			local qubit = {qubits[i]}

			if gates then
				for _, g in ipairs(gates) do
					qubit = gate.apply_ex(qubit, g)
				end
			end

			while true do
				print("qubit[" .. i .. "]: state: |0⟩: " .. qubit[1][1].r .. "+" .. qubit[1][1].i ..
					"i, |1⟩: " .. qubit[1][2].r .. "+" .. qubit[1][2].i .. "i")
				print("measured value:", qb.measure(qubit[1]))
				coroutine.yield()
			end
		end)

		table.insert(co_qubits, co)
	end

	for _, co in ipairs(co_qubits) do
		coroutine.resume(co)
	end

	local result = ""
	for i = 1, qi do
		local co = co_qubits[i]
		if coroutine.status(co) ~= "dead" then
			coroutine.resume(co)
		end
		result = result .. qb.measure(qubits[i])
	end

	return result
end

function qb.mmeasure(qubits: qubits): number
	local probs = {}
	local total_prob = 0
	for i = 1, #qubits do
		local prob = (qubits[i][1].r^2 + qubits[i][1].i^2)
		probs[i] = total_prob + prob
		total_prob += prob
	end
	local rand = math.random()
	for i = 1, #probs do
		if rand <= probs[i] then
			return i - 1 -- state index
		end
	end
	-- if somehow nothing matches then return last index
	return #probs - 1
end

function qb.mmeasure_ex(qubits: qubits): {number}
	local outcome = {}
	for i, qubit in ipairs(qubits) do
		local prob_0 = qubit[1].r^2 + qubit[1].i^2
		--local prob_1 = qubit[2].r^2 + qubit[2].i^2
		local rand = math.random()
		if rand < prob_0 then
			outcome[i] = 0
		else
			outcome[i] = 1
		end
	end
	return outcome
end

function qb.expectation(qubits : qubits, hamiltonian : matrix) : number
	local num_qubits = #qubits
	local state_sz = 2 ^ num_qubits
	
	local rho = mtx.new({r = state_sz, c = state_sz})

	for i = 1, state_sz do
		for j = 1, state_sz do
			rho[i][j] = cpx.new(0, 0)
		end
	end

	for i, qubit in ipairs(qubits) do
		local _alpha = qubit[1]
		local _beta = qubit[2]

		-- placeholder
		-- note: jiface do this thig
	end

	local expect = 0
	for i = 1, state_sz do
		for j = 1, state_sz do
			local rho_ij = rho[i][j]
			local H_ij = hamiltonian[i][j]
			local product = cpx.mul(rho_ij, H_ij)
			expect = expect + product.r
		end
	end

	return expect
end

function qb.qft(qubits: qubits): qubits
	local n = #qubits
	local omega = cpx.exp(cpx.new(0, 2*math.pi/n))
	local g = {}
	for i = 1, n do
		g[i] = {}
		for j = 1, n do
			g[i][j] = cpx.pow(omega, (i-1)*(j-1))
		end
	end
	return gate.apply_ex(qubits, g)
end

function qb.post_select(qubits: qubits, expected: {number}): qubits?
	local outcome = qb.mmeasure_ex(qubits)
	local matches = true
	for i = 1, #expected do
		if outcome[i] ~= expected[i] then
			matches = false
			break
		end
	end
	if matches then
		return qubits
	else
		return nil
	end
end

--[[
function qb.mmeasure(qubits: qubits): number
	local probs = {}
	local total_prob = 0
	for i = 1, #qubits do
		local prob = (qubits[i][1].r^2 + qubits[i][1].i^2)
		probs[i] = total_prob + prob
		total_prob += prob
	end
	local rand = math.random()
	for i = 1, #probs do
		if rand <= probs[i] then
				return i - 1 -- state index
		end
	end
	return -1
end]]


-- Why what 
-- It's because its Because what
-- Not very good because it's just a basic port of conj via mtx to move it here the only thing that might be useful is controlled modular exponentiation but i dont use it yet

--[[

function qb.hadamard(qubits : qubits) : qubits
	return gate.apply_ex(qubits, gate.hadamard(qubits))
end

function qb.qft(qubits : qubits) : qubits
	return gate.apply_ex(qubits, gate.qft(qubits))
end

function qb.inverse_qft(qubits : qubits) : qubits
	local inverse_qft_gate = mtx.conj(gate.qft(qubits)) -- mtx.conj does complex conjugate transpose
	return gate.apply_ex(qubits, inverse_qft_gate)
end

function qb.controlled_phase(control : number, target : number, angle : number, n : number) : gate
	local g = mtx.identity(2^n)
	local phase = cpx.exp(cpx.new(0, angle))
	g[2^n][2^n] = phase
	return g
end

function qb.controlled_modular_exponentiation(a : number, N : number, n : number) : gate
	local function mod_exp(base : number, exp : number, mod : number) : number
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

	local g = mtx.identity(2^n)
	for x = 0, 2^n - 1 do
		local y = mod_exp(a, x, N)
		g[x + 1][y + 1] = cpx.new(1, 0)
		g[x + 1][x + 1] = cpx.new(0, 0)
	end
	return g
end

--]]
return qb