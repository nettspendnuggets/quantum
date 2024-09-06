--!native
--!optimize 2
--!strict
type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
export type gate = {{complex}}

local cpx = require("cpx")
local mtx = require("mtx")

local gate = {}

function gate.new(a11: complex, a12: complex, a21: complex, a22: complex): gate
	return {{a11, a12}, {a21, a22}}
end

function gate.new_ex(size: number, ...: complex): gate
	local matrix = {...}
	assert(#matrix == size^2, "matrix must be " .. size .. "x" .. size)
	local g = {}
	for i = 1, size do
		g[i] = {}
		for j = 1, size do
			g[i][j] = matrix[(i-1)*size + j]
		end
	end
	return g
end

function gate.apply(qubit: qubit, g: gate): qubit
	local alpha = cpx.add(
		cpx.mul(g[1][1], qubit[1]),
		cpx.mul(g[1][2], qubit[2])
	)
	local beta = cpx.add(
		cpx.mul(g[2][1], qubit[1]),
		cpx.mul(g[2][2], qubit[2])
	)
	return {alpha, beta}
end

function gate.apply_ex(qubits: qubits, g: gate, scope : {number}?): qubits
	local n = #g
	local new_qubits = {}
	for i = 1, n do
		new_qubits[i] = {cpx.new(0, 0), cpx.new(0, 0)}
		if scope then
			for _, v in ipairs(scope) do
				new_qubits[v][1] = cpx.add(new_qubits[v][1], cpx.mul(g[v][i], qubits[i][1]))
				new_qubits[v][2] = cpx.add(new_qubits[v][2], cpx.mul(g[v][i], qubits[i][2]))
			end
			break
		end
		for j = 1, n do
			new_qubits[i][1] = cpx.add(new_qubits[i][1], cpx.mul(g[i][j], qubits[j][1]))
			new_qubits[i][2] = cpx.add(new_qubits[i][2], cpx.mul(g[i][j], qubits[j][2]))
		end
	end
	return new_qubits
end

function gate.controlled_modular_exponentiation(a: number, N: number, n: number): gate
	local function mod_exp(base: number, exp: number, mod: number): number
		local result = 1
		base = base % mod
		while exp > 0 do
			if exp % 2 == 1 then
				result = (result * base) % mod
			end
			base = (base * base) % mod
			exp = math.floor(exp / 2)
		end
		return result
	end

	local g = mtx.identity(2^n)
	for x = 0, 2^n - 1 do
		local y = mod_exp(a, x, N)
		g[x + 1][y + 1] = cpx.new(1, 0)
		g[x + 1][x + 1] = cpx.new(0, 0)
	end
	return g
end

function gate.diffusion(qubits: qubits): qubits
	local n = #qubits
	local g = {}
	for i = 1, n do
		g[i] = {}
		for j = 1, n do
			if i == j then
				g[i][j] = cpx.new(2/n - 1, 0)
			else
				g[i][j] = cpx.new(2/n, 0)
			end
		end
	end
	return gate.apply_ex(qubits, g)
end

function gate.controlled_phase(angle: number): gate
	return gate.new_ex(4,
		cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(math.cos(angle), math.sin(angle))
	)
end

function gate.rx(angle : number) : gate
	local half_angle = angle / 2
	local cos_half = math.cos(half_angle)
	local sin_half = math.sin(half_angle)
	return gate.new(
		cpx.new(cos_half, 0), cpx.new(0, -sin_half),
		cpx.new(0, sin_half), cpx.new(cos_half, 0)
	)
end

function gate.ry(angle : number) : gate
	local half_angle = angle / 2
	local cos_half = math.cos(half_angle)
	local sin_half = math.sin(half_angle)
	return gate.new(
		cpx.new(cos_half, 0), cpx.new(-sin_half, 0),
		cpx.new(sin_half, 0), cpx.new(cos_half, 0)
	)
end

function gate.rz(angle : number) : gate
	local half_angle = angle / 2
	return gate.new(
		cpx.new(math.cos(half_angle), -math.sin(half_angle)), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(math.cos(-half_angle), math.sin(half_angle))
	)
end

function gate.qft(n: number) : gate
	local sz = 2^n
	local qft = mtx.new({r = sz, c = sz})

	for i = 1, sz do
		for j = 1, sz do
			qft[i][j] = cpx.new(0, 0)
		end
	end

	for i = 1, sz do
		for j = 1, sz do
			local angle = 2 * math.pi * (i - 1) * (j - 1) / sz
			qft[i][j] = cpx.exp(cpx.new(0, angle))
		end
	end
	
	local norm = 1 / math.sqrt(sz)
	for i = 1, sz do
		for j = 1, sz do
			qft[i][j] = cpx.mul(qft[i][j], cpx.new(norm, 0))
		end
	end

	return qft
end
--[[
function gate.new_ex(n : number) : qubits
	local size = 2 ^ n
	local qubits = {}
	for i = 1, size do
		qubits[i] = {cpx.new(if i == 1 then 1 else 0, 0), cpx.new(0, 0)}
	end
	return qubits
end
]]--

function gate.phase_estimation(a: number, N: number, qubits: qubits): qubits
	local n = #qubits
	local qs = {}
	for i = 1, 2 ^ n do
		qs[i] = {cpx.new(if i == 1 then 1 else 0, 0), cpx.new(0, 0)}
	end

	for i = 1, n do
		qs = gate.apply_ex(qs, gate.new(
			cpx.new(1/math.sqrt(2), 0), cpx.new(1/math.sqrt(2), 0),
			cpx.new(1/math.sqrt(2), 0), cpx.new(-1/math.sqrt(2), 0)
		))
	end

	local cme_gate = gate.controlled_modular_exponentiation(a, N, n)
	qs = gate.apply_ex(qs, cme_gate)

	qs = gate.apply_ex(qs, gate.qft(n))

	return qs
end

function gate.cnot(control, target)
	local identity = {
		{cpx.new(1, 0), cpx.new(0, 0)},
		{cpx.new(0, 0), cpx.new(1, 0)}
	}
	local x_gate = {
		{cpx.new(0, 0), cpx.new(1, 0)},
		{cpx.new(1, 0), cpx.new(0, 0)}
	}
	local cnot = identity
	cnot[control][target] = x_gate[1][1]
	return cnot
end

function gate.cost_hamiltonian(qs: qubits, gamma: number): qubits
	for i = 1, #qs do
		local z_gate = gate.new(
			cpx.new(1, 0), cpx.new(0, 0),
			cpx.new(0, 0), cpx.exp(cpx.new(0, -gamma))
		)
		qs = gate.apply_ex(qs, z_gate)
	end
	return qs
end

function gate.mixer_hamiltonian(qs: qubits, beta: number): qubits
	for i = 1, #qs do
		local x_gate = gate.new(
			cpx.mul(cpx.exp(cpx.new(0, -beta)), cpx.new(0, 0)),
			cpx.mul(cpx.exp(cpx.new(0, beta)), cpx.new(1, 0)),
			cpx.new(1, 0), cpx.new(0, 0)
		)
		qs = gate.apply_ex(qs, x_gate)
	end
	return qs
end

function gate.dagger(g: gate): gate
	local n = #g
	local dagger = {}
	for i = 1, n do
		dagger[i] = {}
		for j = 1, n do
			dagger[i][j] = cpx.conj(g[j][i])
		end
	end
	return dagger
end

return gate