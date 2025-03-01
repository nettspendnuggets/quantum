--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local gate = require("gate")
local qb = require("qb")
local preset = require("preset")
local cpx = require("cpx")

local ent = {}

local bell = {}

local phi = {}
local psi = {}

function phi.plus(qubits: qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
end

function phi.minus(qubits: qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
	qubits[2] = gate.apply(qubits[2], preset.pauliz)
end

function psi.plus(qubits: qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
	qubits[2] = gate.apply(qubits[2], preset.paulix)
end

function psi.minus(qubits: qubits)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	qubits = gate.apply_ex(qubits, preset.cnot)
	qubits[2] = gate.apply(qubits[2], preset.paulix)
	qubits[2] = gate.apply(qubits[2], preset.pauliz)
end

bell.phi = phi
bell.psi = psi

ent.bell = bell

function ent.ghz(n: number): qubits
	local qubits = qb.new_ex(n)
	qubits[1] = gate.apply(qubits[1], preset.hadamard)
	for i = 2, n do
		qubits = gate.apply_ex(qubits, gate.cnot(i - 1, i))
	end
	return qubits
end

function ent.w(n: number): qubits
    local qubits = qb.new_ex(n)
    
    -- Create superposition of states with exactly one qubit in state |1⟩
    -- First, set the system to |10...0⟩ state (first qubit in state |1⟩)
    qubits[1] = gate.apply(qubits[1], preset.paulix)
    -- Now create an equal superposition of all single-excitation states
    -- This requires creating superpositions and applying rotations
    -- For n=2, we need a simple operation to get |01⟩ + |10⟩
    if n == 2 then
        -- Apply a special rotation gate to get (|01⟩ + |10⟩)/√2
        local sqrt_half = 1 / math.sqrt(2)
        local rotation_gate = {
            {cpx.new(sqrt_half), cpx.new(sqrt_half)},
            {cpx.new(sqrt_half), cpx.new(-sqrt_half)}
        }
        qubits = gate.apply_ex(qubits, rotation_gate)
    else
        -- For n>2, we need more complex operations to create the W state.
		-- Made an entire gate for this, as for the n=2 case, it uses a simple rotation to create the Bell-like state (|01⟩ + |10⟩)/√2.
	    for i = 2, n do
            local cos_theta = math.sqrt((i-1)/i)
            local sin_theta = math.sqrt(1/i)
            local rotation_gate = gate.controlled_rotation(1, i, cos_theta, sin_theta)
            qubits = gate.apply_ex(qubits, rotation_gate)
        end
    end
    
    return qubits
end

-- Does Luau support that???
-- Does Luau support that???
--[[
--- @param qubits qubits
--- @return measured_qubits, measurement_probabilities
--]]

function ent.measure(qubits: qubits)
    local measured_qubits = {}
    local measurement_probabilities = {}
    for i, qubit in ipairs(qubits) do
        local probability_0, probability_1 = qb.measure(qubit)
        measured_qubits[i] = qb.new(probability_0 > probability_1)
        measurement_probabilities[i] = {probability_0, probability_1}
    end
    return measured_qubits, measurement_probabilities
end

function ent.cluster(n: number): qubits
    local qubits = qb.new_ex(n)
    qubits[1] = gate.apply(qubits[1], preset.hadamard)
    for i = 2, n do
        qubits = gate.apply_ex(qubits, gate.cnot(i - 1, i))
        qubits = gate.apply_ex(qubits, gate.cnot(i, i - 1))
    end
    return qubits
end

function ent.partial_trace(qubits: qubits, traced_indices: {number})
    if not qubits or #qubits == 0 then
        error("No qubits provided for partial trace")
    end

    if not traced_indices or #traced_indices == 0 then
        error("No indices provided for tracing out")
    end

    local trace_map = {}
    for _, index in ipairs(traced_indices) do
        if index < 1 or index > #qubits then
            error("Invalid qubit index: " .. tostring(index))
        end
        trace_map[index] = true
    end

    local total_qubits = #qubits
    local traced_qubits = #traced_indices
    local remaining_qubits = total_qubits - traced_qubits
    local kept_indices = {}

    for i = 1, total_qubits do
        if not trace_map[i] then
            table.insert(kept_indices, i)
        end
    end
    local full_density_matrix = qb.compute_density_matrix(qubits)
	
    local function compute_reduced_density()
        local reduced_density_matrix = {}
        local reduced_dim = 2^remaining_qubits
        for i = 1, reduced_dim do
            reduced_density_matrix[i] = {}
            for j = 1, reduced_dim do
                reduced_density_matrix[i][j] = cpx.new(0, 0)
            end
        end

        for basis_state_kept = 0, reduced_dim - 1 do
            for basis_state_traced = 0, 2^traced_qubits - 1 do
                local global_state = 0
                local kept_index = 1

                for qubit_index = 1, total_qubits do
                    if not trace_map[qubit_index] then
                        local bit = bit32.band(bit32.rshift(basis_state_kept, kept_index - 1), 1)
                        global_state = bit32.bor(global_state, bit32.lshift(bit, qubit_index - 1))
                        kept_index = kept_index + 1
                    else
                        local bit = bit32.band(bit32.rshift(basis_state_traced, qubit_index - #kept_indices - 1), 1)
                        global_state = bit32.bor(global_state, bit32.lshift(bit, qubit_index - 1))
                    end
                end
                reduced_density_matrix[basis_state_kept + 1][basis_state_kept + 1] = 
                    cpx.add(reduced_density_matrix[basis_state_kept + 1][basis_state_kept + 1],
                           full_density_matrix[global_state + 1][global_state + 1])
            end
        end

        return reduced_density_matrix
    end
    
    local success, reduced_matrix = pcall(compute_reduced_density)
    if not success then
        error("Failed to compute partial trace: " .. tostring(reduced_matrix))
    end

    return reduced_matrix
end

function ent.print_density_matrix(matrix: matrix)
    for _, row in ipairs(matrix) do
        local formatted_row = {}
        for _, val in ipairs(row) do
            table.insert(formatted_row, string.format("%.4f", val.r))
        end
        print(table.concat(formatted_row, "\t"))
    end
end

return ent
