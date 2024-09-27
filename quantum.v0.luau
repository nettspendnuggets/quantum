math.randomseed(os.time())

----------------------------------------------------------------------------------------------

type complex = {r : number, i : number}
type qubit = {complex}
type gate = {{complex}}

----------------------------------------------------------------------------------------------

local cpx = {}

function cpx.new(real : number, imaginary : number) : complex
	return {r = real, i = imaginary}
end

function cpx.add(c1 : complex, c2 : complex)
	return cpx.new(c1.r + c2.r, c1.i + c2.i)
end

function cpx.sub(c1 : complex, c2 : complex)
	return cpx.new(c1.r - c2.r, c1.i - c2.i)
end

function cpx.mul(c1 : complex, c2 : complex)
	return cpx.new(c1.r * c2.r - c1.i * c2.i, c1.r * c2.i + c1.i * c2.r)
end

function cpx.div(c1 : complex, c2 : complex)
	local d = c2.r * c2.r + c2.i * c2.i
	return cpx.new((c1.r * c2.r + c1.i * c2.i) / d, (c1.i * c2.r - c1.r * c2.i) / d)
end

----------------------------------------------------------------------------------------------

local qb = {}

function qb.new(alpha : complex, beta : complex)
	return {alpha, beta}
end

function qb.gate(qubit : qubit, gate : gate)
	local alpha = cpx.add(
		cpx.mul(gate[1][1], qubit[1]),
		cpx.mul(gate[1][2], qubit[2])
	)
	local beta = cpx.add(
		cpx.mul(gate[2][1], qubit[1]),
		cpx.mul(gate[2][2], qubit[2])
	)
	return {alpha, beta}
end

-- rudimentary but works

function qb.measure(qubit : qubit)
	return if math.random() <= (qubit[1].r * qubit[1].r + qubit[1].i * qubit[1].i) then 0 else 1
end

function qb.run(qi : number, gates : {gate}?)
	local qubits = {}

	for i = 1, qi do
		-- init qubit at |0⟩ state
		local qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))
		
		local co = coroutine.create(function()
			if gates then
				for _, gate in ipairs(gates) do
					qubit = qb.gate(qubit, gate)
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

----------------------------------------------------------------------------------------------

local gate = {}

function gate.new(a11 : complex, a12 : complex, a21 : complex, a22 : complex) : gate
	return {{a11, a12}, {a21, a22}}
end

function gate.new_size(size : number, ... : complex)
	local matrix = {...}
	if #matrix ~= size * size then
		error("matrix must be " .. size .. "x" .. size)
	end
	local g = {}
	for i = 1, size do
		g[i] = {}
		for j = 1, size do
			g[i][j] = matrix[(i-1)*size + j]
		end
	end
	return g
end

----------------------------------------------------------------------------------------------

local preset = {
	identity = gate.new(
		cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0)
	);
	paulix = gate.new(
		cpx.new(0, 0), cpx.new(1, 0),
		cpx.new(1, 0), cpx.new(0, 0)
	);
	pauliy = gate.new(
		cpx.new(0, 0), cpx.new(0, -1),
		cpx.new(0, 1), cpx.new(0, 0)
	);
	pauliz = gate.new(
		cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(-1, 0)
	);
	hadamard = gate.new(
		cpx.new(1/math.sqrt(2), 0), cpx.new(1/math.sqrt(2), 0),
		cpx.new(1/math.sqrt(2), 0), cpx.new(-1/math.sqrt(2), 0)
	);
	phase = gate.new(
		cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 1)
	);
	pi8 = gate.new(
		cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1/math.sqrt(2), 1/math.sqrt(2))
	);
	cnot = gate.new_size(4,
		cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0)
	);
	swap = gate.new_size(4,
		cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0)
	);
	ccnot = gate.new_size(8,
		cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0)
	);
	
}

----------------------------------------------------------------------------------------------

-- EXAMPLE

local qubit = qb.new(cpx.new(1, 0), cpx.new(0, 0))
qubit = qb.gate(qubit, preset.hadamard)

print("Qubit state after Hadamard gate:")
print("Alpha (|0⟩): " .. qubit[1].r .. " + " .. qubit[1].i .. "i")
print("Beta (|1⟩): " .. qubit[2].r .. " + " .. qubit[2].i .. "i")

local result = qb.measure(qubit)
print("Measurement result: " .. result)

qb.run(3)