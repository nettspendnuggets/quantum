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

function mtx.kronecker(a: matrix, b: matrix): matrix
	local ra, ca = #a, #a[1]
	local rb, cb = #b, #b[1]
	local result: matrix = {}
	
	for i = 1, ra * rb do
		result[i] = {}
		for j = 1, ca * cb do
			result[i][j] = cpx.new(0, 0)
		end
	end
	
	for i = 1, ra do
		for j = 1, ca do
			for m = 1, rb do
				for n = 1, cb do
					result[(i-1)*rb + m][(j-1)*cb + n] = cpx.mul(a[i][j], b[m][n])
				end
			end
		end
	end
	
	return result
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

function mtx.mul_mv(matrix: matrix, vector: {complex}): {complex}
	local result = {}
	for i = 1, #matrix do
		result[i] = cpx.new(0, 0)
		for j = 1, #vector do
			result[i] = cpx.add(result[i], cpx.mul(matrix[i][j], vector[j]))
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

function mtx.conj(m: matrix): matrix
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

	for _ = 1, exponent do
		result = mtx.mul(result, matrix)
	end

	return result
end

-- new funcs

function mtx.is_unitary(m: matrix): boolean
	local rows, cols = #m, #m[1]
	if rows ~= cols then
		return false
	end

	local m_conj_transpose = mtx.conj(mtx.transpose(m))
	local product = mtx.mul(m, m_conj_transpose)
	local identity = mtx.identity(rows)

	local epsilon = 1e-10
	for i = 1, rows do
		for j = 1, cols do
			if math.abs(product[i][j].r - identity[i][j].r) > epsilon or
				math.abs(product[i][j].i - identity[i][j].i) > epsilon then
				return false
			end
		end
	end

	return true
end

function mtx.transpose(m: matrix): matrix
	local rows, cols = #m, #m[1]
	local result = {}

	for j = 1, cols do
		result[j] = {}
		for i = 1, rows do
			result[j][i] = m[i][j]
		end
	end

	return result
end

function mtx.outer_product(v1: {complex}, v2: {complex}): matrix
	local result = {}
	for i = 1, #v1 do
		result[i] = {}
		for j = 1, #v2 do
			result[i][j] = cpx.mul(v1[i], cpx.conj(v2[j]))
		end
	end
	return result
end

return mtx