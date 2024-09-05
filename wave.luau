--!native
--!optimize 2
--!strict

type complex = {r : number, i : number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local gate = require("gate")
local qb = require("qb")

local wave = {}

-- apply hadamard to qubits to create wave-like superposition

function wave.apply_wave(qubits : qubits, wave : gate): qubits
	for i = 1, #qubits do
		qubits = gate.apply_ex(qubits, wave)
	end
	return qubits
end

function wave.evolve(qubits : qubits, angle : number) : qubits
	for i = 1, #qubits do
		qubits = gate.apply_ex(qubits, gate.rx(angle))
	end
	return qubits
end

function wave.observe(qubits : qubits, iter : number)
	for t = 1, iter do
		print("observation at time step " .. t)
		qubits = wave.evolve(qubits, math.pi / 10)
		local result = qb.mmeasure(qubits)
		print("measured state: " .. result)
		coroutine.yield()
	end
end

function wave.run(qubits : qubits, iter : number)
	local co = coroutine.create(function() wave.observe(qubits, iter) end)
	for _ = 1, iter do
		coroutine.resume(co)
	end
end

return wave