--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type matrix = {{complex}}
type matrix_sz = {r: number, c: number}

local cpx = require("cpx")

local mtx = {}

function mtx.new(size: matrix_sz, ...: complex)
	local elements = {...}
	if #elements ~= size.r * size.c then
		error("number of elements doesnt match matrix size")
	end
	local matrix = {}
	for i = 1, size.r do
		matrix[i] = {}
		for j = 1, size.c do
			matrix[i][j] = elements[(i-1) * size.c + j]
		end
	end
	return matrix
end

function mtx.create_empty(size: matrix_sz)
	local matrix = {}
	for i = 1, size.r do
		matrix[i] = {}
		for j = 1, size.c do
			matrix[i][j] = cpx.new(0, 0)
		end
	end
	return matrix
end

function mtx.kronecker(a: matrix, b: matrix)
	local ra = #a
	local ca = #a[1]
	local rb = #b
	local cb = #b[1]
	local r = {}
	for i = 1, ra do
		for j = 1, ca do
			local ai = (i - 1) * rb
			local aj = (j - 1) * cb
			for m = 1, rb do
				for n = 1, cb do
					local new_value = {
						r = a[i][j].r * b[m][n].r - a[i][j].i * b[m][n].i,
						i = a[i][j].r * b[m][n].i + a[i][j].i * b[m][n].r
					}
					r[ai + m] = r[ai + m] or {}
					r[ai + m][aj + n] = new_value
				end
			end
		end
	end
	return r
end

function mtx.add(m1: matrix, m2: matrix): matrix
	local size1, size2 = #m1, #m2
	local cols1, cols2 = #m1[1], #m2[1]
	if size1 ~= size2 or cols1 ~= cols2 then
		error("matrix dimensions must match for addition")
	end
	local result = {}
	for i = 1, size1 do
		result[i] = {}
		for j = 1, cols1 do
			result[i][j] = cpx.add(m1[i][j], m2[i][j])
		end
	end
	return result
end

function mtx.sub(m1: matrix, m2: matrix): matrix
	local size1, size2 = #m1, #m2
	local cols1, cols2 = #m1[1], #m2[1]
	if size1 ~= size2 or cols1 ~= cols2 then
		error("matrix dimensions must match for subtraction")
	end
	local result = {}
	for i = 1, size1 do
		result[i] = {}
		for j = 1, cols1 do
			result[i][j] = cpx.sub(m1[i][j], m2[i][j])
		end
	end
	return result
end

function mtx.mul(m1: matrix, m2: matrix): matrix
	local rows1, cols1 = #m1, #m1[1]
	local rows2, cols2 = #m2, #m2[1]
	if cols1 ~= rows2 then
		error("number of columns of the first matrix must equal number of rows of the second matrix")
	end
	local result = {}
	for i = 1, rows1 do
		result[i] = {}
		for j = 1, cols2 do
			result[i][j] = cpx.new(0, 0)
			for k = 1, cols1 do
				result[i][j] = cpx.add(result[i][j], cpx.mul(m1[i][k], m2[k][j]))
			end
		end
	end
	return result
end

function mtx.scalar_mul(scalar: complex, m: matrix): matrix
	local rows, cols = #m, #m[1]
	local result = {}
	for i = 1, rows do
		result[i] = {}
		for j = 1, cols do
			result[i][j] = cpx.mul(scalar, m[i][j])
		end
	end
	return result
end

function mtx.identity(size: number): matrix
	local result = {}
	for i = 1, size do
		result[i] = {}
		for j = 1, size do
			if i == j then
				result[i][j] = cpx.new(1, 0)
			else
				result[i][j] = cpx.new(0, 0)
			end
		end
	end
	return result
end

function mtx.conj(m: matrix)
	local result = {}
	for i = 1, #m do
		result[i] = {}
		for j = 1, #m[i] do
			local val = m[i][j]
			result[i][j] = cpx.new(val.r, -val.i)
		end
	end
	return result
end

function mtx.expand(m: matrix, new_sz: matrix_sz): matrix
	local result = {}
	
	for i = 1, new_sz.r do
		result[i] = {}
		for j = 1, new_sz.c do
			if i <= #m and j <= #m[1] then
				result[i][j] = m[i][j]
			else
				result[i][j] = cpx.new(0, 0)
			end
		end
	end

	return result
end

function mtx.exp(matrix: matrix, exponent: number): matrix
	local size = #matrix
	local result = mtx.identity(size)

	for i = 1, exponent do
		result = mtx.mul(result, matrix)
	end

	return result
end

return mtx