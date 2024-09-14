--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}
type hamiltonian = {{number}}

local cpx = require("cpx")
local gate = require("gate")
local mtx = require("mtx")
local qb = require("qb")
local preset = require("preset")

local anneal = {}

local BOLTZMANN = 1.380649e-23 -- Boltzmann constant
local PLANCK = 6.62607015e-34 -- Planck constant

-- helper fucntion because it's not compatible..
local function hamiltoniantomatrix(h: hamiltonian): matrix
	local m: matrix = {}
	for i, row in ipairs(h) do
		m[i] = {}
		for j, value in ipairs(row) do
			m[i][j] = cpx.new(value, 0)
		end
	end
	return m
end

-- Unused functions 🥰
-- local function randompair()
-- 	return math.random(), math.random()
-- end

-- local function sigmoid(x) -- Sigmoid.
-- 	return 1 / (1 + math.exp(-x))
-- end

function anneal.quantumanneal(hamiltonian: hamiltonian, initialstate: {number}, temperature: number, steps: number, coolingrate: number): ({number}, number)
	local currentstate = initialstate
	local bestenergy = anneal.evaluateenergy(currentstate, hamiltonian)
	local beststate = currentstate

	for step = 1, steps do
		local newstate = anneal.perturb(currentstate)
		local newenergy = anneal.evaluateenergy(newstate, hamiltonian)
		
		local energydifference = newenergy - bestenergy
		
		if energydifference < 0 or math.exp(-energydifference / (BOLTZMANN * temperature)) > math.random() then
			currentstate = newstate
			bestenergy = newenergy
			
			if newenergy < bestenergy then
				beststate = newstate
				bestenergy = newenergy
			end
		end
		
		temperature = temperature * coolingrate
	end

	return beststate, bestenergy
end

function anneal.evaluateenergy(state: {number}, hamiltonian: hamiltonian): number
	local energy = 0
	for i = 1, #state do
		for j = 1, #state do
			energy = energy + hamiltonian[i][j] * state[i] * state[j]
		end
	end
	return energy
end

function anneal.perturb(state: {number}): {number}
	local newstate = table.create(#state)
	for i = 1, #state do
		newstate[i] = state[i]
	end
	
	local index = math.random(1, #state)
	newstate[index] = -newstate[index] -- Flip the spin!
	
	return newstate
end

function anneal.preparequbits(n: number): qubits
	local qubits: qubits = {}
	for i = 1, n do
		qubits[i] = qb.new(cpx.new(1 / math.sqrt(2), 0), cpx.new(1 / math.sqrt(2), 0))
	end
	return qubits
end

function anneal.applyquantumfluctuation(qubits: qubits, strength: number): qubits
	local hadamardgate = preset.hadamard
	for i = 1, #qubits do
		qubits[i] = gate.apply(qubits[i], mtx.scalar_mul(cpx.new(strength, 0), hadamardgate))
	end
	return qubits
end

function anneal.measurestate(qubits: qubits): {number}
	local state: {number} = {}
	for i = 1, #qubits do
		state[i] = qb.measure(qubits[i]) * 2 - 1 -- Convert to {-1, 1}
	end
	return state
end

function anneal.quantumfluctuationstrength(t: number, tmax: number): number
	return (1 - t / tmax) ^ 2
end

function anneal.classicalfluctuationstrength(t: number, tmax: number): number
	return (t / tmax) ^ 2
end

function anneal.metropolisacceptance(energydiff: number, temperature: number): number
	return math.exp(-energydiff / temperature)
end

function anneal.simulatedquantumannealing(hamiltonian: hamiltonian, nqubits: number, steps: number, initialtemp: number, finaltemp: number): ({number}, number)
	local qubits = anneal.preparequbits(nqubits)
	local currentenergy = anneal.evaluateenergy(anneal.measurestate(qubits), hamiltonian)
	local bestenergy = currentenergy
	local beststate = anneal.measurestate(qubits)
	
	for step = 1, steps do
		local t = step / steps
		local temperature = initialtemp + (finaltemp - initialtemp) * t
		
		local qstrength = anneal.quantumfluctuationstrength(step, steps)
		local cstrength = anneal.classicalfluctuationstrength(step, steps)
		
		qubits = anneal.applyquantumfluctuation(qubits, qstrength)
		
		local newstate = anneal.measurestate(qubits)
		local newenergy = anneal.evaluateenergy(newstate, hamiltonian)
		
		local energydiff = newenergy - currentenergy
		
		if energydiff < 0 or math.random() < anneal.metropolisacceptance(energydiff, temperature) then
			currentenergy = newenergy
			if newenergy < bestenergy then
				bestenergy = newenergy
				beststate = newstate
			end
		else
			qubits = anneal.preparequbits(nqubits)
		end
		
		if cstrength > 0 then
			newstate = anneal.perturb(newstate)
			newenergy = anneal.evaluateenergy(newstate, hamiltonian)
			energydiff = newenergy - currentenergy
			
			if energydiff < 0 or math.random() < anneal.metropolisacceptance(energydiff, temperature) then
				currentenergy = newenergy
				if newenergy < bestenergy then
					bestenergy = newenergy
					beststate = newstate
				end
				qubits = anneal.statetoqubits(newstate)
			end
		end
	end
	
	return beststate, bestenergy
end

function anneal.statetoqubits(state: {number}): qubits
	local qubits: qubits = {}
	for i = 1, #state do
		local angle = state[i] == 1 and 0 or math.pi
		qubits[i] = qb.new(cpx.new(math.cos(angle/2), 0), cpx.new(math.sin(angle/2), 0))
	end
	return qubits
end

function anneal.quantumtunneling(currentstate: {number}, hamiltonian: hamiltonian, temperature: number): {number}
	local n = #currentstate
	local tunneledstate = table.create(n)
	
	for i = 1, n do
		tunneledstate[i] = currentstate[i]
	end
	
	local i, j = math.random(1, n), math.random(1, n)
	while i == j do
		j = math.random(1, n)
	end
	
	tunneledstate[i], tunneledstate[j] = -tunneledstate[i], -tunneledstate[j]
	
	local energydiff = anneal.evaluateenergy(tunneledstate, hamiltonian) - anneal.evaluateenergy(currentstate, hamiltonian)
	local tunnelingprob = math.exp(-energydiff / temperature)
	
	if math.random() < tunnelingprob then
		return tunneledstate
	else
		return currentstate
	end
end

function anneal.quantumoperator(qubits: qubits, hamiltonian: hamiltonian): qubits
	local n = #qubits
	local result: qubits = table.create(n)
	local matrixH = hamiltoniantomatrix(hamiltonian)
	
	for i = 1, n do
		result[i] = qb.new(cpx.new(0, 0), cpx.new(0, 0))
		for j = 1, n do
			local term = gate.apply(qubits[j], mtx.scalar_mul(matrixH[i][j], preset.pauliz))
			result[i] = {cpx.add(result[i][1], term[1]), cpx.add(result[i][2], term[2])}
		end
	end
	
	return result
end

function anneal.trotter(qubits: qubits, hamiltonian: hamiltonian, timestep: number, trottersteps: number): qubits
	for _ = 1, trottersteps do
		local evolved = anneal.quantumoperator(qubits, hamiltonian)
		for i = 1, #qubits do
			local phase = cpx.mul(cpx.new(0, -timestep / trottersteps), evolved[i][1])
			qubits[i] = {cpx.mul(qubits[i][1], cpx.exp(phase)), cpx.mul(qubits[i][2], cpx.exp(phase))}
		end
	end
	return qubits
end

function anneal.quantummontecarloanneal(hamiltonian: hamiltonian, nqubits: number, steps: number, initialtemp: number, finaltemp: number, trottersteps: number): ({number}, number)
	local qubits = anneal.preparequbits(nqubits)
	local currentenergy = qb.expectation(qubits, hamiltoniantomatrix(hamiltonian))
	local bestenergy = currentenergy
	local beststate = anneal.measurestate(qubits)
	
	for step = 1, steps do
		local temperature = initialtemp + (finaltemp - initialtemp) * (step / steps)
		local timestep = PLANCK / (BOLTZMANN * temperature)
		
		qubits = anneal.trotter(qubits, hamiltonian, timestep, trottersteps)
		
		local newenergy = qb.expectation(qubits, hamiltoniantomatrix(hamiltonian))
		local energydiff = newenergy - currentenergy
		
		if energydiff < 0 or math.random() < math.exp(-energydiff / temperature) then
			currentenergy = newenergy
			if newenergy < bestenergy then
				bestenergy = newenergy
				beststate = anneal.measurestate(qubits)
			end
		else
			qubits = anneal.preparequbits(nqubits)
		end
		
		if step % 10 == 0 then
			local measuredState = anneal.measurestate(qubits)
			qubits = anneal.statetoqubits(anneal.quantumtunneling(measuredState, hamiltonian, temperature))
		end
	end
	
	return beststate, bestenergy
end

return anneal