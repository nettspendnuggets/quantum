--!native
--!optimize 2
--!strict

local qb = require("qb")
local cpx = require("cpx")
local gate = require("gate")
local preset = require("preset")

export type complex = {r: number, i: number}
type Bit = number -- 0 or 1
type ResultCallback = (results: {Bit}) -> ()
export type qubit = {complex}

local qot = {}

function qot.prepare_states(m0: Bit, m1: Bit): {qubit}
    local state0 = qb.new(cpx.new(math.cos(math.pi/8), 0), cpx.new(math.sin(math.pi/8), 0))
    local state1 = qb.new(cpx.new(math.cos(3*math.pi/8), 0), cpx.new(math.sin(3*math.pi/8), 0))
    
    if m0 == 1 then
        state0 = gate.apply(state0, preset.paulix)
    end
    if m1 == 1 then
        state1 = gate.apply(state1, preset.paulix)
    end
    
    return {state0, state1}
end

function qot.measure_state(state: qubit, basis: Bit): Bit
    if basis == 0 then
        return qb.measure(state)
    else
        state = gate.apply(state, preset.hadamard)
        return qb.measure(state)
    end
end

function qot.sender(m0: Bit, m1: Bit): ({qubit}, ResultCallback)
    local states = qot.prepare_states(m0, m1)
    
    return states, function(results: {Bit})
        assert(#results == 2, "Sender expected 2 measurement results")
        print("Sender: Message 0 was " .. tostring(m0) .. ", Message 1 was " .. tostring(m1))
        print("Sender: Receiver's results were " .. tostring(results[1]) .. " and " .. tostring(results[2]))
        
        if results[1] == results[2] then
            warn("Warning: Receiver's measurements are identical. Possible cheating attempt.")
        end
    end
end

function qot.receiver(states: {qubit}, c: Bit): (Bit, {Bit})
    assert(#states == 2, "Receiver expected 2 quantum states")
    
    local results: {Bit} = {qot.measure_state(states[1], c), qot.measure_state(states[2], 1-c)}
    local received_bit = results[c+1]
    
    return received_bit, results
end

function qot.run_protocol(): ()
    print("Starting Enhanced 1-2 Quantum Oblivious Transfer Protocol")
    
    local m0, m1 = math.random(0, 1), math.random(0, 1)
    
    local states, sender_callback = qot.sender(m0, m1)
    
    local c = math.random(0, 1)
    print("Receiver wants to receive bit " .. tostring(c))
    
    local received_bit, results = qot.receiver(states, c)
    
    print("Receiver: I chose c = " .. tostring(c) .. " and received bit " .. tostring(received_bit))
    
    sender_callback(results)
    
    if c == 0 and received_bit == m0 then
        print("Protocol successful: Receiver correctly obtained m0")
    elseif c == 1 and received_bit == m1 then
        print("Protocol successful: Receiver correctly obtained m1")
    else
        warn("Protocol error: Received bit does not match the chosen message")
    end
    
    print("Enhanced 1-2 Quantum Oblivious Transfer Protocol Completed")
end

return qot