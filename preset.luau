--!native
--!optimize 2
--!strict

local cpx = require("cpx")
local gate = require("gate")

return {
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
		-- you can represent e^(i*π/4) by using the eulers formula:
		-- e^(i*θ) = cos(θ) + i * sin(θ)
		-- in this case, θ = π/4
		-- e^(i*π/4) = cos(π/4) + i * sin(π/4)
		--           = 1/√(2) + 1/√(2) * i
		-- -> real part is 1/√(2), imaginary part is 1/√(2)
		-- (<REAL>+<IMG>i)
	);
	cnot = gate.new_ex(4,
		cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0)
	);
	swap = gate.new_ex(4,
		cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(1, 0), cpx.new(0, 0), cpx.new(0, 0),
		cpx.new(0, 0), cpx.new(0, 0), cpx.new(0, 0), cpx.new(1, 0)
	);
	ccnot = gate.new_ex(8,
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