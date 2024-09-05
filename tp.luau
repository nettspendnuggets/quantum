--!native
--!optimize 2
--!strict

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

return tp