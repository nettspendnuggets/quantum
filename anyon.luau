--!native
--!optimize 2
--!strict

local cpx = require("cpx")
local mtx = require("mtx")
local qb = require("qb")

type complex = {r: number, i: number}
type matrix = {{complex}}
type qubit = {complex}
type qubits = {qubit}

local anyon = {}

local function braidgenerator(n: number, i: number): matrix
	local dim = 2^n
	local result = mtx.identity(dim)
	local root5 = cpx.new(math.sqrt(5), 0)
	local tau = cpx.div(cpx.add(cpx.new(1, 0), root5), cpx.new(2, 0))
	local phase = cpx.exp(cpx.mul(cpx.new(0, 2 * math.pi / 5), tau))
	
	result[i][i] = phase
	result[i+1][i+1] = cpx.conj(phase)
	
	return result
end

function anyon.fibonaccichain(n: number): qubits
	local qubits: qubits = {}
	for i = 1, n do
		qubits[i] = qb.new(cpx.new(1, 0), cpx.new(0, 0))
	end
	return qubits
end

function anyon.applybraid(qubits: qubits, i: number): qubits
	local n = #qubits
	if i < 1 or i >= n then
		error("Invalid braid index")
	end
	
	local braidmatrix = braidgenerator(n, i)
	local state = qb.tensorproduct(qubits)
	state = mtx.mul_mv(braidmatrix, state)
	
	local newqubits: qubits = {}
	for j = 1, n do
		newqubits[j] = {state[2*j-1], state[2*j]}
	end
	
	return newqubits
end

function anyon.measurecharge(qubits: qubits): string
	local state = qb.tensorproduct(qubits)
	local prob1 = cpx.abs(state[1])^2
	
	if math.random() < prob1 then
		return "trivial"
	else
		return "nontrivial"
	end
end

function anyon.topologicalqubit(): qubits
	local qubits = anyon.fibonaccichain(4)
	return anyon.applybraid(anyon.applybraid(qubits, 2), 1)
end

function anyon.topologicalnot(qubits: qubits): qubits
	assert(#qubits == 4, "Topological qubit must consist of 4 anyons")
	
	return anyon.applybraid(anyon.applybraid(anyon.applybraid(qubits, 2), 1), 2)
end

function anyon.topologicalhadamard(qubits: qubits): qubits
	assert(#qubits == 4, "Topological qubit must consist of 4 anyons")
	
	local rotated = anyon.applybraid(qubits, 1)
	rotated = anyon.applybraid(rotated, 2)
	rotated = anyon.applybraid(rotated, 1)
	return anyon.applybraid(rotated, 2)
end

function anyon.topologicalcnot(control: qubits, target: qubits): (qubits, qubits)
	assert(#control == 4 and #target == 4, "Both control and target must be topological qubits consisting of 4 anyons each")
	
	local combined = {}
	for i = 1, 4 do
		combined[i] = control[i]
		combined[i+4] = target[i]
	end
	
	combined = anyon.applybraid(combined, 4)
	combined = anyon.applybraid(combined, 5)
	combined = anyon.applybraid(combined, 4)
	combined = anyon.applybraid(combined, 3)
	combined = anyon.applybraid(combined, 4)
	combined = anyon.applybraid(combined, 5)
	combined = anyon.applybraid(combined, 4)
	
	local newcontrol: qubits = {}
	local newtarget: qubits = {}
	
	for i = 1, 4 do
		newcontrol[i] = combined[i]
		newtarget[i] = combined[i+4]
	end
	
	return newcontrol, newtarget
end

local function fusionchannel(a: string, b: string): {string}
	if a == "1" and b == "1" then
		return {"1"}
	elseif (a == "1" and b == "τ") or (a == "τ" and b == "1") then
		return {"τ"}
	elseif a == "τ" and b == "τ" then
		return {"1", "τ"}
	else
		error("Invalid anyon types for fusion")
	end
end

function anyon.fuse(a: string, b: string): string
	local channels = fusionchannel(a, b)
	if #channels == 1 then
		return channels[1]
	else
		return channels[math.random(#channels)]
	end
end

function anyon.topologicalspin(anyontype: string): complex
	if anyontype == "1" then
		return cpx.new(1, 0)
	elseif anyontype == "τ" then
		return cpx.exp(cpx.new(0, 2 * math.pi / 5))
	else
		error("Invalid anyon type")
	end
end

function anyon.braidingphase(a: string, b: string): complex
	local spina = anyon.topologicalspin(a)
	local spinb = anyon.topologicalspin(b)
	local spinab = anyon.topologicalspin(anyon.fuse(a, b))
	return cpx.mul(cpx.mul(spinab, cpx.conj(spina)), cpx.conj(spinb))
end

return anyon