--!native
--!optimize 2
--!strict

local qb = require("qb")
local cpx = require("cpx")
local gate = require("gate")
local preset = require("preset")

type Bit = number -- 0 or 1
type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}

type Party = {
    id: number,
    input: Bit,
    qubit: qubit
}

local qsmc = {}

local function quantum_channel(state: qubit): qubit
    local noise_angle = math.random() * math.pi / 10 
    return gate.apply(state, gate.ry(noise_angle))
end

function qsmc.create_ghz_state(n: number): qubits
    assert(n > 1, "Number of parties must be greater than 1")
    local ghz = qb.new(cpx.new(1, 0), cpx.new(0, 0))  -- |0⟩ state
    ghz = gate.apply(ghz, preset.hadamard)
    
    local states: qubits = {ghz}
    for _ = 2, n do
        local new_qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))  -- |0⟩ state
        states[#states] = gate.apply_ex({states[#states], new_qubit}, preset.cnot)[1]
        table.insert(states, new_qubit)
    end
    
    return states
end

function qsmc.encode_bit(bit: Bit): qubit
    local state = qb.new(cpx.new(1, 0), cpx.new(0, 0))  -- |0⟩ state
    if bit == 1 then
        state = gate.apply(state, preset.paulix)  -- Apply X gate to flip to |1⟩ state
    end
    return state
end

function qsmc.measure(qubit: qubit): Bit
    return qb.measure(qubit)
end

function qsmc.secure_and(party1: Party, party2: Party): Bit
    local ghz = qsmc.create_ghz_state(3)
    
    ghz[1] = gate.apply_ex({ghz[1], party1.qubit}, preset.cnot)[1]
    ghz[2] = gate.apply_ex({ghz[2], party2.qubit}, preset.cnot)[1]
    
    local result = qsmc.measure(ghz[3])
    
    result = if qsmc.measure(quantum_channel(qsmc.encode_bit(result))) == 1 then 1 else 0
    
    return result
end

function qsmc.secure_xor(party1: Party, party2: Party): Bit
    local bell_pair = qsmc.create_ghz_state(2)
    
    bell_pair[1] = gate.apply_ex({bell_pair[1], party1.qubit}, gate.controlledgate(preset.pauliz))[1]
    bell_pair[2] = gate.apply_ex({bell_pair[2], party2.qubit}, gate.controlledgate(preset.pauliz))[1]
    
    local result1 = qsmc.measure(gate.apply(bell_pair[1], preset.hadamard))
    local result2 = qsmc.measure(gate.apply(bell_pair[2], preset.hadamard))
    
    return bit32.bxor(result1, result2)
end

function qsmc.run_protocol(num_parties: number): ()
    assert(num_parties > 1, "Number of parties must be greater than 1")
    print("Starting Quantum Secure Multiparty Computation Protocol")
    
    local parties: {Party} = {}
    for i = 1, num_parties do
        local input = math.random(0, 1)
        parties[i] = {
            id = i,
            input = input,
            qubit = qsmc.encode_bit(input)
        }
        print("Party " .. tostring(i) .. " input: " .. tostring(input))
    end
    
    local and_result: Bit = parties[1].input
    for i = 2, num_parties do
        and_result = qsmc.secure_and({id = i-1, input = and_result, qubit = qsmc.encode_bit(and_result)}, parties[i])
    end
    
    local xor_result: Bit = parties[1].input
    for i = 2, num_parties do
        xor_result = qsmc.secure_xor({id = i-1, input = xor_result, qubit = qsmc.encode_bit(xor_result)}, parties[i])
    end
    
    print("QSMC Protocol Results:")
    print("AND of all inputs: " .. tostring(and_result))
    print("XOR of all inputs: " .. tostring(xor_result))
    print("Quantum Secure Multiparty Computation Protocol Completed")
end

return qsmc