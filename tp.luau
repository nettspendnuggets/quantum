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
local preset = require("preset")

local tp = {}

function tp.entangle() : qubits
	local qubits = qb.new_ex(2)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits[2] = gate.apply(qubits[2], preset.cnot)
	return qubits
end

function tp.bell_measurement(qubits: qubits) : (number, number)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits[2] = gate.apply(qubits[2], preset.cnot)

	local result = qb.mmeasure_ex({qubits[1], qubits[2]})
	return result[1], result[2]
end

function tp.apply_corrections(qubits : qubits, bits : {number}) : qubits
	if bits[1] == 1 then
		qubits[1] = gate.apply(qubits[1], preset.paulix)
	end
	if bits[2] == 1 then
		qubits[2] = gate.apply(qubits[2], preset.pauliz)
	end
	return qubits
end

function tp.teleport(qubit : qubit, entangled_qubits : qubits) : qubits
	return tp.apply_corrections(entangled_qubits, {tp.bell_measurement({qubit, entangled_qubits[1]})})
end

return tp