--!native
--!optimize 2
--!strict

type complex = {r : number, i : number}

local cpx = {}

function cpx.new(real : number?, imaginary : number?) : complex
	return {r = real or 0, i = imaginary or 0}
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

function cpx.abs(c : complex)
	return math.sqrt(c.r * c.r + c.i * c.i)
end

function cpx.conj(c : complex)
	return cpx.new(c.r, -c.i)
end

function cpx.exp(c : complex)
	local e = math.exp(c.r)
	return cpx.new(e * math.cos(c.i), e * math.sin(c.i))
end

function cpx.pow(c : complex, n : number)  -- Becuase you still suck :heart:
	local r = cpx.abs(c)
	local theta = math.atan2(c.i, c.r)
	local rn = r ^ n
	local ntheta = n * theta
	return cpx.new(rn * math.cos(ntheta), rn * math.sin(ntheta))
end

function cpx.sqrt(c : complex) -- sqrt
	local r = cpx.abs(c)
	local x = math.sqrt((r + c.r) / 2)
	local y = math.sqrt((r - c.r) / 2)
	if c.i < 0 then y = -y end
	return cpx.new(x, y)
end

return cpx