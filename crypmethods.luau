--!native
--!optimize 2
--!strict

local bit32 = require("bit32")
local cpx = require("cpx")
local mtx = require("mtx")

local crypmethods = {}

type Vector = {number}
type Matrix = {Vector}
type EllipticCurve = {a: number, b: number}
type EllipticCurvePoint = {x: number, y: number}

local function keccak(message: string, rate: number, capacity: number, output_length: number): string
    assert(rate + capacity == 1600, "Invalid rate and capacity combination")
    local state = table.create(200, 0)
    local message_length = #message
    local block_size = rate // 8
    local rounds = 24

    -- Constants
    local RC = {
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
        0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    }

    local function rot(x: number, n: number): number
        return bit32.bor(bit32.lshift(x, n), bit32.rshift(x, 64 - n))
    end

    local function keccak_f(A: {number})
        for round = 0, rounds - 1 do
            local C = table.create(5, 0)
            for x = 0, 4 do
                C[x + 1] = bit32.bxor(A[x + 1], A[x + 6], A[x + 11], A[x + 16], A[x + 21])
            end

            local D = table.create(5, 0)
            for x = 0, 4 do
                D[x + 1] = bit32.bxor(C[((x + 4) % 5) + 1], rot(C[((x + 1) % 5) + 1], 1))
            end

            for x = 0, 4 do
                for y = 0, 4 do
                    A[5 * x + y + 1] = bit32.bxor(A[5 * x + y + 1], D[x + 1])
                end
            end

            local B = table.create(25, 0)
            for x = 0, 4 do
                for y = 0, 4 do
                    local Y = (2 * x + 3 * y) % 5
                    B[Y * 5 + x + 1] = rot(A[5 * x + y + 1], ((x + 3 * y) * (x + 3 * y) + x + 3 * y) % 64)
                end
            end

            for x = 0, 4 do
                for y = 0, 4 do
                    A[5 * x + y + 1] = bit32.bxor(B[5 * x + y + 1], bit32.band(bit32.bnot(B[5 * ((x + 1) % 5) + y + 1]), B[5 * ((x + 2) % 5) + y + 1]))
                end
            end

            A[1] = bit32.bxor(A[1], RC[round + 1])
        end
        return A
    end

    local padded_message = message .. string.char(0x06) .. string.rep("\0", block_size - (message_length + 1) % block_size - 1) .. string.char(0x80)

    for i = 1, #padded_message, block_size do
        local block = padded_message:sub(i, i + block_size - 1)
        for j = 1, #block do
            state[j] = bit32.bxor(state[j], string.byte(block, j))
        end
        state = keccak_f(state)
    end

    local output = ""
    while #output < output_length do
        for i = 1, math.min(block_size, output_length - #output) do
            output = output .. string.char(state[i])
        end
        if #output < output_length then
            state = keccak_f(state)
        end
    end

    return output
end

local function f(m: string): string
    return keccak(m, 1088, 512, 32)  -- SHA3-256
end

local function h(m1: string, m2: string): string
    return f(m1 .. m2)
end

local function prf(seed: string, addr: number): string
    return f(seed .. string.pack(">I8", addr))
end

local function wots_chain(x: string, i: number, w: number, public_seed: string): string
    for j = 0, i - 1 do
        x = f(public_seed .. x .. string.pack(">I2I2", w, j))
    end
    return x
end

local function wots_sign(message: string, secret_seed: string, public_seed: string, w: number): string
    local n = 32  -- Hash output length
    local l1 = math.ceil(8 * n / math.log(w, 2))
    local l2 = math.floor(math.log(l1 * (w - 1), 2) / math.log(w, 2)) + 1
    local l = l1 + l2

    local b = 0
    for i = 1, l1 do
        b = b + bit32.extract(string.unpack(">I4", message, (i-1)*4 + 1), 0, 8) * (w - 1)
    end

    local signature = ""
    for i = 1, l do
        local sk_i = f(secret_seed .. string.pack(">I2", i))
        local a = i <= l1 and bit32.extract(string.unpack(">I4", message, (i-1)*4 + 1), 0, 8) or bit32.extract(b, (i-l1-1)*8, 8)
        signature = signature .. wots_chain(sk_i, a, w, public_seed)
    end
    return signature
end

local function tree_hash(seed: string, leaf_idx: number, height: number): string
    local stack = {}
    for i = 0, 2^height - 1 do
        local node = f(seed .. string.pack(">I8", leaf_idx + i))
        local node_height = 0
        while #stack > 0 and stack[#stack].height == node_height do
            local right = node
            local left = table.remove(stack).node
            node = f(left .. right)
            node_height = node_height + 1
        end
        table.insert(stack, {node = node, height = node_height})
    end
    return stack[1].node
end

local function gen_leaf_wots(secret_seed: string, public_seed: string, addr: number): string
    local leaf_secret = f(secret_seed .. string.pack(">I8", addr))
    return wots_sign(leaf_secret, leaf_secret, public_seed, 16)
end

local function secure_random(n: number): string
    local result = ""
    for _ = 1, n do
        result = result .. string.char(math.random(0, 255))
    end
    return result
end

local function constant_time_compare(a: string, b: string): boolean
    if #a ~= #b then
        return false
    end
    local result = 0
    for i = 1, #a do
        result = bit32.bor(result, bit32.bxor(string.byte(a, i), string.byte(b, i)))
    end
    return result == 0
end

local crypmethods = {}

function crypmethods.generate_key_pair(): (string, string)
    local secret_seed = secure_random(32)
    local public_seed = f(secret_seed .. "public")
    return secret_seed, public_seed
end

function crypmethods.sphincs_sign(message: string, secret_seed: string, public_seed: string): string
    local n = 32  -- Hash output length
    local w = 16  -- Winternitz parameter
    local h = 64  -- Height of the hypertree
    local d = 8   -- Number of layers in the hypertree
    
    local r = secure_random(n)
    local R = f(r .. public_seed .. message)
    
    local signature = r
    local root = tree_hash(public_seed, 0, h)
    
    for i = 1, d do
        local leaf_idx = bit32.band(bit32.rshift(string.unpack(">I4", R, 1), h - (i-1)*h//d), 2^(h//d) - 1)
        local auth_path = {}
        for j = 0, h//d - 1 do
            local sibling_idx = bit32.bxor(leaf_idx, bit32.lshift(1, j))
            table.insert(auth_path, tree_hash(public_seed, sibling_idx * 2^j, j))
        end
        
        local leaf = gen_leaf_wots(secret_seed, public_seed, leaf_idx)
        signature = signature .. leaf
        
        for _, node in ipairs(auth_path) do
            signature = signature .. node
        end
        
        R = f(R .. root)
        root = tree_hash(public_seed, leaf_idx * 2^(h//d), h//d)
    end
    
    return signature
end

function crypmethods.sphincs_verify(message: string, signature: string, public_seed: string): boolean
    local n = 32  -- Hash output length
    local w = 16  -- Winternitz parameter
    local h = 64  -- Height of the hypertree
    local d = 8   -- Number of layers in the hypertree
    
    local function wots_pk_from_sig(signature: string, message: string, public_seed: string, addr: number): string
        local l1 = math.ceil(8 * n / math.log(w, 2))
        local l2 = math.floor(math.log(l1 * (w - 1), 2) / math.log(w, 2)) + 1
        local l = l1 + l2
        
        local b = 0
        for i = 1, l1 do
            b = b + bit32.extract(string.unpack(">I4", message, (i-1)*4 + 1), 0, 8) * (w - 1)
        end
        
        local public_key = ""
        for i = 1, l do
            local sig_i = signature:sub((i-1)*n + 1, i*n)
            local a = i <= l1 and bit32.extract(string.unpack(">I4", message, (i-1)*4 + 1), 0, 8) or bit32.extract(b, (i-l1-1)*8, 8)
            public_key = public_key .. wots_chain(sig_i, w - 1 - a, w, public_seed)
        end
        
        return f(public_seed .. public_key .. string.pack(">I8", addr))
    end
    
    local r = signature:sub(1, n)
    local R = f(r .. public_seed .. message)
    signature = signature:sub(n + 1)
    
    local root = nil
    
    for i = 1, d do
        local leaf_idx = bit32.band(bit32.rshift(string.unpack(">I4", R, 1), h - (i-1)*h//d), 2^(h//d) - 1)
        local wots_sig = signature:sub(1, n * (2^(h//d) - 1))
        signature = signature:sub(n * (2^(h//d) - 1) + 1)
        
        local leaf = wots_pk_from_sig(wots_sig, R, public_seed, leaf_idx)
        
        local node = leaf
        for j = 0, h//d - 1 do
            local sibling = signature:sub(1, n)
            signature = signature:sub(n + 1)
            
            if bit32.band(bit32.rshift(leaf_idx, j), 1) == 0 then
                node = f(node .. sibling)
            else
                node = f(sibling .. node)
            end
        end
        
        if root == nil then
            root = node
        elseif not constant_time_compare(root, node) then
            return false
        end
        
        R = f(R .. root)
    end
    
    return constant_time_compare(root, tree_hash(public_seed, 0, h))
end

return crypmethods

--------------------------------------------------------------------------------------------------------

local function mod_inverse(a: number, m: number): number
	local m0, x0, x1 = m, 0, 1
	while a > 1 do
		local q = math.floor(a / m)
		m, a = a % m, m
		x0, x1 = x1 - q * x0, x0
	end
	return x1 < 0 and x1 + m0 or x1
end

local function random_vector(n: number, max: number): Vector
	local v = table.create(n)
	for i = 1, n do
		v[i] = math.random(0, max - 1)
	end
	return v
end

local function random_matrix(n: number, m: number, max: number): Matrix
	local mat = table.create(n)
	for i = 1, n do
		mat[i] = random_vector(m, max)
	end
	return mat
end

-- RING-LWE
local function polynomial_add(a: Vector, b: Vector, q: number): Vector
	local result = table.create(#a)
	for i = 1, #a do
		result[i] = (a[i] + b[i]) % q
	end
	return result
end

local function polynomial_multiply(a: Vector, b: Vector, q: number): Vector
	local n = #a
	local result = table.create(n, 0)
	for i = 1, n do
		for j = 1, n do
			local k = (i + j - 2) % n + 1
			result[k] = (result[k] + a[i] * b[j]) % q
		end
	end
	return result
end

function crypmethods.generate_key_pair(): (string, string)
    local secret_seed = secure_random(32)
    local public_seed = f(secret_seed .. "public")
    return secret_seed, public_seed
end

function crypmethods.generate_ring_lwe_keys(n: number, q: number): (Vector, {a: Vector, b: Vector})
	local a = random_vector(n, q)
	local s = random_vector(n, q)
	local e = random_vector(n, 3)  -- Small error vector
	local b = polynomial_add(polynomial_multiply(a, s, q), e, q)
	return s, {a = a, b = b}
end

function crypmethods.ring_lwe_encrypt(message: Vector, public_key: {a: Vector, b: Vector}, q: number): (Vector, Vector)
	local n = #public_key.a
	local r = random_vector(n, 3)  -- Small random vector
	local e1 = random_vector(n, 3)  -- Small error vector
	local e2 = random_vector(n, 3)  -- Small error vector
	local u = polynomial_add(polynomial_multiply(public_key.a, r, q), e1, q)
	local v = polynomial_add(polynomial_add(polynomial_multiply(public_key.b, r, q), e2, q), message, q)
	return u, v
end

function crypmethods.ring_lwe_decrypt(u: Vector, v: Vector, private_key: Vector, q: number): Vector
	local message = polynomial_add(v, polynomial_multiply(u, private_key, q), q)
	for i = 1, #message do
		message[i] = message[i] > q/2 and 0 or 1
	end
	return message
end

-- (McEliece)
local function generate_goppa_code(n: number, k: number, t: number): (Matrix, Matrix)
	-- Add goppa polynomial to this
	local g = random_matrix(k, n-k, 2)
	local h = random_matrix(n-k, n, 2)
	for i = 1, n-k do
		for j = 1, k do
			h[i][j] = g[j][i]
		end
		h[i][i+k] = 1
	end
	return g, h
end

function crypmethods.generate_mceliece_keys(n: number, k: number, t: number): ({G: Matrix, P: Matrix, S: Matrix}, Matrix)
	local g, h = generate_goppa_code(n, k, t)
	local s = random_matrix(k, k, 2)
	local p = random_matrix(n, n, 2)
	local g_pub = mtx.multiply(mtx.multiply(s, g), p)
	return {G = g, P = p, S = s}, g_pub
end

function crypmethods.mceliece_encrypt(message: Vector, public_key: Matrix): Vector
	local n = #public_key[1]
	local ciphertext = mtx.multiply({message}, public_key)[1]
	-- t random errors
	local t = math.floor((n - #message) / 2)
	for _ = 1, t do
		local pos = math.random(1, n)
		ciphertext[pos] = (ciphertext[pos] + 1) % 2
	end
	return ciphertext
end

function crypmethods.mceliece_decrypt(ciphertext: Vector, private_key: {G: Matrix, P: Matrix, S: Matrix}): Vector
	local n = #ciphertext
	local k = #private_key.S
	local permuted = table.create(n)
	for i = 1, n do
		for j = 1, n do
			if private_key.P[j][i] == 1 then
				permuted[j] = ciphertext[i]
				break
			end
		end
	end
	-- secret GOPPPA code :money_face: this is very simplified
	local decoded = table.create(k)
	for i = 1, k do
		decoded[i] = 0
		for j = 1, n do
			decoded[i] = (decoded[i] + permuted[j] * private_key.G[i][j]) % 2
		end
	end
	return mtx.multiply({decoded}, mtx.inverse(private_key.S, 2))[1]
end

local function f(m: string): string
	-- Please use the big ass table for this
end

local function h(m1: string, m2: string): string
	return f(m1 .. m2)
end

local function prf(seed: string, addr: number): string
	return f(seed .. string.pack(">I8", addr))
end

function crypmethods.sphincs_keygen(n: number): (string, string)
	local seed = string.rep("\0", n)
	for i = 1, n do
		seed = string.char(math.random(0, 255)) .. seed:sub(1, -2)
	end
	local public_seed = f(seed .. "public")
	local secret_seed = f(seed .. "secret")
	return secret_seed, public_seed
end

function crypmethods.sphincs_sign(message: string, secret_seed: string, public_seed: string): string
    local n = 32  -- Hash output length
    local w = 16  -- Winternitz parameter
    local h = 64  -- Height of the hypertree
    local d = 8   -- Number of layers in the hypertree
    
    local r = secure_random(n)
    local R = f(r .. public_seed .. message)
    
    local signature = r
    local root = tree_hash(public_seed, 0, h)
    
    for i = 1, d do
        local leaf_idx = bit32.band(bit32.rshift(string.unpack(">I4", R, 1), h - (i-1)*h//d), 2^(h//d) - 1)
        local auth_path = {}
        for j = 0, h//d - 1 do
            local sibling_idx = bit32.bxor(leaf_idx, bit32.lshift(1, j))
            table.insert(auth_path, tree_hash(public_seed, sibling_idx * 2^j, j))
        end
        
        local leaf = gen_leaf_wots(secret_seed, public_seed, leaf_idx)
        signature = signature .. leaf
        
        for _, node in ipairs(auth_path) do
            signature = signature .. node
        end
        
        R = f(R .. root)
        root = tree_hash(public_seed, leaf_idx * 2^(h//d), h//d)
    end
    
    return signature
end

function crypmethods.sphincs_verify(message: string, signature: string, public_seed: string): boolean
    local n = 32  -- Hash output length
    local w = 16  -- Winternitz parameter
    local h = 64  -- Height of the hypertree
    local d = 8   -- Number of layers in the hypertree
    
    local function wots_pk_from_sig(signature: string, message: string, public_seed: string, addr: number): string
        local l1 = math.ceil(8 * n / math.log(w, 2))
        local l2 = math.floor(math.log(l1 * (w - 1), 2) / math.log(w, 2)) + 1
        local l = l1 + l2
        
        local b = 0
        for i = 1, l1 do
            b = b + bit32.extract(string.unpack(">I4", message, (i-1)*4 + 1), 0, 8) * (w - 1)
        end
        
        local public_key = ""
        for i = 1, l do
            local sig_i = signature:sub((i-1)*n + 1, i*n)
            local a = i <= l1 and bit32.extract(string.unpack(">I4", message, (i-1)*4 + 1), 0, 8) or bit32.extract(b, (i-l1-1)*8, 8)
            public_key = public_key .. wots_chain(sig_i, w - 1 - a, w, public_seed)
        end
        
        return f(public_seed .. public_key .. string.pack(">I8", addr))
    end
    
    local r = signature:sub(1, n)
    local R = f(r .. public_seed .. message)
    signature = signature:sub(n + 1)
    
    local root = nil
    
    for i = 1, d do
        local leaf_idx = bit32.band(bit32.rshift(string.unpack(">I4", R, 1), h - (i-1)*h//d), 2^(h//d) - 1)
        local wots_sig = signature:sub(1, n * (2^(h//d) - 1))
        signature = signature:sub(n * (2^(h//d) - 1) + 1)
        
        local leaf = wots_pk_from_sig(wots_sig, R, public_seed, leaf_idx)
        
        local node = leaf
        for j = 0, h//d - 1 do
            local sibling = signature:sub(1, n)
            signature = signature:sub(n + 1)
            
            if bit32.band(bit32.rshift(leaf_idx, j), 1) == 0 then
                node = f(node .. sibling)
            else
                node = f(sibling .. node)
            end
        end
        
        if root == nil then
            root = node
        elseif not constant_time_compare(root, node) then
            return false
        end
        
        R = f(R .. root)
    end
    
    return constant_time_compare(root, tree_hash(public_seed, 0, h))
end

return crypmethods

local function point_double(P: EllipticCurvePoint, A: number, p: number): EllipticCurvePoint
	if P.x == 0 and P.y == 0 then
		return P
	end
	local m = (3 * P.x * P.x + A) * mod_inverse(2 * P.y, p) % p
	local x = (m * m - 2 * P.x) % p
	local y = (m * (P.x - x) - P.y) % p
	return {x = x, y = y}
end

local function point_add(P: EllipticCurvePoint, Q: EllipticCurvePoint, A: number, p: number): EllipticCurvePoint
	if P.x == 0 and P.y == 0 then
		return Q
	elseif Q.x == 0 and Q.y == 0 then
		return P
	elseif P.x == Q.x and P.y == Q.y then
		return point_double(P, A, p)
	elseif P.x == Q.x then
		return {x = 0, y = 0}
	end
	local m = (Q.y - P.y) * mod_inverse(Q.x - P.x, p) % p
	local x = (m * m - P.x - Q.x) % p
	local y = (m * (P.x - x) - P.y) % p
	return {x = x, y = y}
end

local function scalar_multiply(k: number, P: EllipticCurvePoint, A: number, p: number): EllipticCurvePoint
	local R = {x = 0, y = 0}
	local Q = P
	while k > 0 do
		if k % 2 == 1 then
			R = point_add(R, Q, A, p)
		end
		Q = point_double(Q, A, p)
		k = math.floor(k / 2)
	end
	return R
end

function crypmethods.sidh_keygen(p: number, l_A: number, e_A: number, l_B: number, e_B: number): ({number, EllipticCurvePoint}, {number, EllipticCurvePoint})
	local E = {a = 0, b = 1}  -- Starting curve y^2 = x^3 + x
	local x_P = 1
	local y_P = math.sqrt(x_P^3 + E.a*x_P + E.b) % p
	local P_A = {x = x_P, y = y_P}
	local Q_A = scalar_multiply(l_A^(e_A - 1), P_A, E.a, p)
	local sk_A = math.random(1, l_A^e_A - 1)
	local pk_A = scalar_multiply(sk_A, P_A, E.a, p)
	
	local x_P = 2
	local y_P = math.sqrt(x_P^3 + E.a*x_P + E.b) % p
	local P_B = {x = x_P, y = y_P}
	local Q_B = scalar_multiply(l_B^(e_B - 1), P_B, E.a, p)
	local sk_B = math.random(1, l_B^e_B - 1)
	local pk_B = scalar_multiply(sk_B, P_B, E.a, p)
	
	return {sk_A, P_A}, {sk_B, P_B}
end

function crypmethods.sidh_exchange(sk: number, P: EllipticCurvePoint, Q: EllipticCurvePoint, A: number, p: number): number
	local R = point_add(scalar_multiply(sk, P, A, p), Q, A, p)
	return R.x
end

local function secure_random(n: number): string
	local result = ""
	for _ = 1, n do
		result = result .. string.char(math.random(0, 255))
	end
	return result
end

local function constant_time_compare(a: string, b: string): boolean
	if #a ~= #b then
		return false
	end
	local result = 0
	for i = 1, #a do
		result = bit32.bor(result, bit32.bxor(string.byte(a, i), string.byte(b, i)))
	end
	return result == 0
end

-- implement a more secure version of SPHINCS+ with an improved Winternitz One-Time Signature (WOTS+)
local function wots_chain(x: string, i: number, w: number, public_seed: string): string
	for j = 0, i - 1 do
		x = f(public_seed .. x .. string.pack(">I2I2", w, j))
	end
	return x
end

local function wots_sign(message: string, secret_seed: string, public_seed: string, w: number): string
	local n = 32 
	local l1 = math.ceil(8 * n / math.log(w, 2))
	local l2 = math.floor(math.log(l1 * (w - 1), 2) / math.log(w, 2)) + 1
	local l = l1 + l2

	local b = 0
	for i = 1, l1 do
		b = b + bit32.extract(message, (i-1)*4, 4) * (w - 1)
	end

	local signature = ""
	for i = 1, l do
		local sk_i = f(secret_seed .. string.pack(">I2", i))
		local a = i <= l1 and bit32.extract(message, (i-1)*4, 4) or bit32.extract(b, (i-l1-1)*4, 4)
		signature = signature .. wots_chain(sk_i, a, w, public_seed)
	end
	return signature
end

function crypmethods.sphincs_plus_sign(message: string, secret_seed: string, public_seed: string): string
    local n = 32  -- Hash output length
    local w = 16  -- Winternitz parameter
    local h = 64  -- Height of the hypertree
    local d = 8   -- Number of layers in the hypertree
    
    local function f_tree(seed: string, addr: number): string
        return f(seed .. string.pack(">I8", addr))
    end
    
    local function tree_hash(seed: string, leaf_idx: number, height: number): string
        local stack = {}
        for i = 0, 2^height - 1 do
            local node = f_tree(seed, leaf_idx + i)
            local height = 0
            while #stack > 0 and stack[#stack].height == height do
                local right = node
                local left = table.remove(stack).node
                node = f(left .. right)
                height = height + 1
            end
            table.insert(stack, {node = node, height = height})
        end
        return stack[1].node
    end
    
    local function gen_leaf_wots(secret_seed: string, public_seed: string, addr: number): string
        local leaf_secret = f(secret_seed .. string.pack(">I8", addr))
        return wots_sign(leaf_secret, leaf_secret, public_seed, w)
    end
    
    local r = secure_random(n)
    local R = f(r .. public_seed .. message)
    
    local signature = r
    local root = tree_hash(public_seed, 0, h)
    
    for i = 1, d do
        local leaf_idx = bit32.band(bit32.rshift(R, h - (i-1)*h/d), 2^(h/d) - 1)
        local auth_path = {}
        for j = 0, h/d - 1 do
            local sibling_idx = bit32.bxor(leaf_idx, bit32.lshift(1, j))
            table.insert(auth_path, tree_hash(public_seed, sibling_idx * 2^j, j))
        end
        
        local leaf = gen_leaf_wots(secret_seed, public_seed, leaf_idx)
        signature = signature .. leaf
        
        for _, node in ipairs(auth_path) do
            signature = signature .. node
        end
        
        R = f(R .. root)
        root = tree_hash(public_seed, leaf_idx * 2^(h/d), h/d)
    end
    
    return signature
end

function crypmethods.sphincs_plus_verify(message: string, signature: string, public_seed: string): boolean
    local n = 32  -- Hash output length
    local w = 16  -- Winternitz parameter
    local h = 64  -- Height of the hypertree
    local d = 8   -- Number of layers in the hypertree
    
    local function f_tree(seed: string, addr: number): string
        return f(seed .. string.pack(">I8", addr))
    end
    
    local function wots_pk_from_sig(signature: string, message: string, public_seed: string, addr: number): string
        local n = 32  -- Hash output length
        local l1 = math.ceil(8 * n / math.log(w, 2))
        local l2 = math.floor(math.log(l1 * (w - 1), 2) / math.log(w, 2)) + 1
        local l = l1 + l2
        
        local b = 0
        for i = 1, l1 do
            b = b + bit32.extract(message, (i-1)*4, 4) * (w - 1)
        end
        
        local public_key = ""
        for i = 1, l do
            local sig_i = signature:sub((i-1)*n + 1, i*n)
            local a = i <= l1 and bit32.extract(message, (i-1)*4, 4) or bit32.extract(b, (i-l1-1)*4, 4)
            public_key = public_key .. wots_chain(sig_i, w - 1 - a, w, public_seed)
        end
        
        return f(public_seed .. public_key .. string.pack(">I8", addr))
    end
    
    local r = signature:sub(1, n)
    local R = f(r .. public_seed .. message)
    signature = signature:sub(n + 1)
    
    local root = nil
    
    for i = 1, d do
        local leaf_idx = bit32.band(bit32.rshift(R, h - (i-1)*h/d), 2^(h/d) - 1)
        local wots_sig = signature:sub(1, n * (2^(h/d) - 1))
        signature = signature:sub(n * (2^(h/d) - 1) + 1)
        
        local leaf = wots_pk_from_sig(wots_sig, R, public_seed, leaf_idx)
        
        local node = leaf
        for j = 0, h/d - 1 do
            local sibling = signature:sub(1, n)
            signature = signature:sub(n + 1)
            
            if bit32.band(bit32.rshift(leaf_idx, j), 1) == 0 then
                node = f(node .. sibling)
            else
                node = f(sibling .. node)
            end
        end
        
        if root == nil then
            root = node
        elseif root ~= node then
            return false
        end
        
        R = f(R .. root)
    end
    
    return constant_time_compare(root, tree_hash(public_seed, 0, h))
end

-- secure version of SIDH
function crypmethods.sidh_secure_keygen(p: number, l_A: number, e_A: number, l_B: number, e_B: number): ({number, EllipticCurvePoint, EllipticCurvePoint}, {number, EllipticCurvePoint, EllipticCurvePoint})
    local E = {a = 0, b = 1}  -- Starting curve y^2 = x^3 + x
    local x_P = 1
    local y_P = math.sqrt(x_P^3 + E.a*x_P + E.b) % p
    local P_A = {x = x_P, y = y_P}
    local Q_A = scalar_multiply(l_A^(e_A - 1), P_A, E.a, p)
    local sk_A = math.random(1, l_A^e_A - 1)
    local pk_A = scalar_multiply(sk_A, P_A, E.a, p)
    local pk_A_Q = scalar_multiply(sk_A, Q_A, E.a, p)
    
    local x_P = 2
    local y_P = math.sqrt(x_P^3 + E.a*x_P + E.b) % p
    local P_B = {x = x_P, y = y_P}
    local Q_B = scalar_multiply(l_B^(e_B - 1), P_B, E.a, p)
    local sk_B = math.random(1, l_B^e_B - 1)
    local pk_B = scalar_multiply(sk_B, P_B, E.a, p)
    local pk_B_Q = scalar_multiply(sk_B, Q_B, E.a, p)
    
    return {sk_A, P_A, Q_A}, {sk_B, P_B, Q_B}, {pk_A, pk_A_Q}, {pk_B, pk_B_Q}
end

function crypmethods.sidh_secure_exchange(sk: number, P: EllipticCurvePoint, Q: EllipticCurvePoint, pk: EllipticCurvePoint, pk_Q: EllipticCurvePoint, A: number, p: number): number
    local R = point_add(scalar_multiply(sk, P, A, p), Q, A, p)
    local S = point_add(scalar_multiply(sk, pk, A, p), pk_Q, A, p)
    
    if (S.y^2 % p) ~= (S.x^3 + A*S.x + 1) % p then
        error("Invalid public key")
    end
    
    return R.x
end

function crypmethods.hybrid_encrypt(message: string, ring_lwe_pk: {a: Vector, b: Vector}, sidh_pk: EllipticCurvePoint, q: number, p: number): (Vector, Vector, EllipticCurvePoint, string)
    local n = #ring_lwe_pk.a
    local ring_lwe_message = {}
    for i = 1, n do
        ring_lwe_message[i] = string.byte(message, i) or 0
    end
    
    local u, v = crypmethods.ring_lwe_encrypt(ring_lwe_message, ring_lwe_pk, q)
    
    local sidh_sk, sidh_P, sidh_Q = crypmethods.sidh_secure_keygen(p, 2, 372, 3, 239)
    local shared_secret = crypmethods.sidh_secure_exchange(sidh_sk[1], sidh_pk, sidh_Q, sidh_P, sidh_Q, 0, p)
    
    local key = f(tostring(shared_secret))
    local encrypted_tail = ""
    for i = n + 1, #message do
        encrypted_tail = encrypted_tail .. string.char(bit32.bxor(string.byte(message, i), string.byte(key, (i-n-1) % 32 + 1)))
    end
    
    return u, v, sidh_P, encrypted_tail
end

function crypmethods.hybrid_decrypt(u: Vector, v: Vector, sidh_P: EllipticCurvePoint, encrypted_tail: string, ring_lwe_sk: Vector, sidh_sk: number, q: number, p: number): string
    local decrypted_head = crypmethods.ring_lwe_decrypt(u, v, ring_lwe_sk, q)
    local message = ""
    for i = 1, #decrypted_head do
        message = message .. string.char(decrypted_head[i])
    end
    
    local shared_secret = crypmethods.sidh_secure_exchange(sidh_sk, sidh_P, {x = 0, y = 0}, {x = 0, y = 0}, {x = 0, y = 0}, 0, p)
    local key = f(tostring(shared_secret))
    
    for i = 1, #encrypted_tail do
        message = message .. string.char(bit32.bxor(string.byte(encrypted_tail, i), string.byte(key, (i-1) % 32 + 1)))
    end
    
    return message
end

return crypmethods