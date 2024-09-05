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

function cpx.log(c : complex) : complex
	return cpx.new(math.log(math.sqrt(c.r * c.r + c.i * c.i)), math.atan2(c.i, c.r))
end

-- https://hewgill.com/picomath/lua/gamma.lua.html

function cpx.gamma(c: complex): complex
	local gamma_const = 0.577215664901532860606512090

	if c.r < 0.001 then
		local term = {r = c.r * (1.0 + gamma_const * c.r), i = c.i}
		return {r = 1.0 / term.r, i = -term.i / (term.r * term.r)}
	end

	if c.r < 12.0 then
		local y = c.r
		local n = 0
		local arg_was_less_than_one = (y < 1.0)

		if arg_was_less_than_one then
			y = y + 1.0
		else
			n = math.floor(y) - 1
			y = y - n
		end

		local p = {
			-1.71618513886549492533811E+0,
			 2.47656508055759199108314E+1,
			-3.79804256470945635097577E+2,
			 6.29331155312818442661052E+2,
			 8.66966202790413211295064E+2,
			-3.14512729688483675254357E+4,
			-3.61444134186911729807069E+4,
			 6.64561438202405440627855E+4
		}
		local q = {
			-3.08402300119738975254353E+1,
			 3.15350626979604161529144E+2,
			-1.01515636749021914166146E+3,
			-3.10777167157231109440444E+3,
			 2.25381184209801510330112E+4,
			 4.75584627752788110767815E+3,
			-1.34659959864969306392456E+5,
			-1.15132259675553483497211E+5
		}

		local num = {r = 0.0, i = 0.0}
		local den = {r = 1.0, i = 0.0}

		local z = y - 1
		for i = 1, 8 do
			local term = cpx.mul({r = p[i], i = 0}, {r = z, i = 0})
			num = cpx.add(num, term)
			term = cpx.mul({r = q[i], i = 0}, {r = z, i = 0})
			den = cpx.add(den, term)
		end

		local result = cpx.div(num, den)
		result = cpx.add(result, {r = 1.0, i = 0.0})

		if arg_was_less_than_one then
			local term = {r = y - 1.0, i = 0.0}
			result = cpx.div(result, term)
		else
			for i = 1, n do
				result = cpx.mul(result, {r = y, i = 0.0})
				y = y + 1
			end
		end

		return result
	end

	if c.r > 171.624 then
		return {r = 1.0 / 0, i = 0}
	end

	local log_gamma = cpx.log(cpx.gamma(c))
	return cpx.exp(log_gamma)
end

return cpx