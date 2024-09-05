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

local ent = {}

local bell = {}

local phi = {}
local psi = {}

function phi.plus(qubits : qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
end

function phi.minus(qubits : qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
	qubits[2] = gate.apply(qubits[2], preset.pauliz)
end

function psi.plus(qubits : qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
	qubits[2] = gate.apply(qubits[2], preset.paulix)
end

function psi.minus(qubits : qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
	qubits[2] = gate.apply(qubits[2], preset.paulix)
	qubits[2] = gate.apply(qubits[2], preset.pauliz)
end

bell.phi = phi
bell.psi = psi

ent.bell = bell

function ent.ghz(n : number) : qubits
	local qubits = qb.new_ex(n)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	for i = 2, n do
		qubits = gate.apply_ex(qubits, gate.cnot(i - 1, i))
	end
	return qubits
end

return ent
