--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type kernel_t = ("polynomial" | "gaussian" | "quantum")?

local qb = require("qb")
local cpx = require("cpx")
local gate = require("gate")

local qlm = {}

local qsvm = {}

local function get_kernel(kernel_t: kernel_t, gamma: number?): (qubits_1: qubits, qubits_2: qubits) -> complex
	return if kernel_t then
		if kernel_t == "polynomial" then
			qsvm.polynomial_kernel
		elseif kernel_t == "gaussian" then
			function(qubits_1: qubits, qubits_2: qubits)
				assert(gamma, "gamma was not provided")
				return qsvm.gaussian_kernel(qubits_1, qubits_2, gamma)
			end
		elseif kernel_t == "quantum" then
			qsvm.quantum_kernel
		else (function()
			warn "kernel type not found, falling back to quantum kernel"
			return qsvm.quantum_kernel
		end)()
	else
		qsvm.quantum_kernel
end

function qsvm.encode(data_point: {number})
	local qubits = {}
	for i = 1, #data_point do
		local angle = data_point[i] * math.pi -- scale data to [0, π]
		qubits[i] = qb.new(cpx.new(math.cos(angle / 2), math.sin(angle / 2)), cpx.new())
	end

	return qubits
end

function qsvm.quantum_kernel(qubits_1: qubits, qubits_2: qubits)
	local dot_prod = cpx.new(1)
	-- assuming both of it are the same size... just assuming!
	for i = 1, #qubits_1 do
		-- evil
		dot_prod = cpx.mul(dot_prod, cpx.mul(cpx.conj(qubits_1[i][1]), qubits_2[i][1]))
	end

	return dot_prod
end

-- alt kernel (deg2)
function qsvm.polynomial_kernel(qubits_1: qubits, qubits_2: qubits)
	return cpx.pow(qsvm.quantum_kernel(qubits_1, qubits_2), 2)
end

-- another alt kernel!!
function qsvm.gaussian_kernel(qubits_1: qubits, qubits_2: qubits, gamma: number)
	local dst = cpx.new()
	-- JUST ASSUMING....
	for i = 1, #qubits_1 do
		local diff = cpx.sub(qubits_1[i][1], qubits_2[i][2])
		dst = cpx.add(dst, cpx.mul(diff, cpx.conj(diff)))
	end
	return cpx.new(math.exp(-gamma * dst.r))
end

function qsvm.train(data: {{number}}, labels: {number}, C: number, kernel_type: kernel_t, gamma: number?)
	local n = #data
	local alpha = {}
	local kernel = get_kernel(kernel_type, gamma)

	for i = 1, n do
		alpha[i] = 0
	end

	for i = 1, n do
		for j = 1, n do
			local kernal_val = kernel(qsvm.encode(data[i]), qsvm.encode(data[j]))
			alpha[i] = alpha[i] + labels[i] * labels[j] * cpx.abs(kernal_val) * C
		end
	end

	return alpha
end

function qsvm.predict(alpha: {number}, data: {{number}}, labels: {number}, test_point: {number}, kernel_type: kernel_t, gamma: number?)
	local result = 0
	local kernel = get_kernel(kernel_type, gamma)

	for i = 1, #alpha do
		local kernel_val = kernel(qsvm.encode(data[i]), qsvm.encode(test_point))
		result = result + alpha[i] * labels[i] * cpx.abs(kernel_val)
	end

	return if result > 0 then 1 else -1
end

function qsvm.cross_validate(data: {{number}}, labels: {number}, kernel_type: kernel_t, C_values: {number}, gamma_values: {number}, folds: number)
	local best_C = C_values[1]
	local best_gamma = gamma_values[1]
	local best_accuracy = 0

	for _, C in ipairs(C_values) do
		for _, gamma in ipairs(gamma_values) do
			local total_accuracy = 0
			for fold = 1, folds do
				local train_data = {}
				local train_labels = {}
				local test_data = {}
				local test_labels = {}

				for i = 1, #data do
					if (i % folds) == fold then
						table.insert(test_data, data[i])
						table.insert(test_labels, labels[i])
					else
						table.insert(train_data, data[i])
						table.insert(train_labels, labels[i])
					end
				end

				local alpha = qsvm.train(train_data, train_labels, C, kernel_type, gamma)
				local correct = 0

				for i = 1, #test_data do
					local prediction = qsvm.predict(alpha, train_data, train_labels, test_data[i], kernel_type, gamma)
					if prediction == test_labels[i] then
						correct = correct + 1
					end
				end

				local accuracy = correct / #test_data
				total_accuracy = total_accuracy + accuracy
			end

			local avg_accuracy = total_accuracy / folds
			if avg_accuracy > best_accuracy then
				best_accuracy = avg_accuracy
				best_C = C
				best_gamma = gamma
			end
		end
	end

	return best_C, best_gamma, best_accuracy
end

--[[
	-- Example code

local data = {
	{0.5, 0.7}, 
	{0.3, 0.9}, 
	{0.8, 0.4}
}
local labels = {1, -1, 1}

-- cross-validate to find the best c and gamma parameters for the gaussian kernel
local c_vals = {0.1, 1.0, 10.0}
local gamma_vals = {0.1, 0.5, 1.0}
local best_c, best_gamma, best_acc = qsvm.cross_validate(data, labels, "gaussian", c_vals, gamma_vals, 3)

print("best c: ", best_c, "best gamma: ", best_gamma, "best accuracy: ", best_acc)

-- train and predict
local alpha = qsvm.train(data, labels, best_c, "gaussian", best_gamma)
local test_point = {0.6, 0.8}
local prediction = qsvm.predict(alpha, data, labels, test_point, "gaussian", best_gamma)

print("prediction: ", prediction)

]]

qlm.qsvm = qsvm

local vqc = {}

function vqc.encode(data_point: {number}, encoding_type: "angle" | "amplitude"): qubits
	local n = #data_point
	local qubits = {}
	if encoding_type == "angle" then
		for i = 1, n do
			local angle = data_point[i] * math.pi
			qubits[i] = {cpx.new(math.cos(angle / 2), 0), cpx.new(math.sin(angle / 2), 0)}
		end
	elseif encoding_type == "amplitude" then
		local norm = 0
		for i = 1, n do
			norm = norm + data_point[i] ^ 2
		end
		norm = math.sqrt(norm)
		for i = 1, n do
			qubits[i] = {cpx.new(data_point[i] / norm, 0), cpx.new(0, 0)}
		end
	end
	return qubits
end

function vqc.ansatz(params: {number}, qubits: qubits, layers: number): qubits
	local n = #qubits
	for l = 1, layers do
		for i = 1, n do
			local theta = params[i] * math.pi * l / layers
			qubits[i] = gate.apply(qubits[i], gate.rx(theta))
			qubits[i] = gate.apply(qubits[i], gate.rz(theta))
			if i < n then
				qubits[i] = gate.apply(qubits[i], gate.cnot(i, i + 1))
			end
		end
	end
	return qubits
end

function vqc.measure(qubits: qubits): {number}
	local result = {}
	for i, qubit in ipairs(qubits) do
		local prob_0 = cpx.abs(cpx.mul(cpx.conj(qubit[1]), qubit[1]))
		--local prob_1 = 1 - prob_0
		if math.random() < prob_0 then
			result[i] = 0
		else
			result[i] = 1
		end
	end
	return result
end

function vqc.loss(prediction: number, label: number, params: {number}, regularization_type: "L1" | "L2", lambda: number): number
	local loss = 0
	if label == 1 then
		loss = -math.log(prediction)
	else
		loss = -math.log(1 - prediction)
	end

	if regularization_type == "L1" then
		for _, param in ipairs(params) do
			loss = loss + lambda * math.abs(param)
		end
	elseif regularization_type == "L2" then
		for _, param in ipairs(params) do
			loss = loss + lambda * param^2
		end
	end
	return loss
end

function vqc.gradient(params: {number}, data: {number}, label: number, layers: number, epsilon: number): {number}
	local gradients = {}
	for i, param in ipairs(params) do
		local params_plus = {table.unpack(params)}
		local params_minus = {table.unpack(params)}
		params_plus[i] = param + epsilon
		params_minus[i] = param - epsilon

		local qubits_plus = vqc.encode(data, "angle")
		qubits_plus = vqc.ansatz(params_plus, qubits_plus, layers)
		local prediction_plus = vqc.measure(qubits_plus)[1]

		local qubits_minus = vqc.encode(data, "angle")
		qubits_minus = vqc.ansatz(params_minus, qubits_minus, layers)
		local prediction_minus = vqc.measure(qubits_minus)[1]

		local loss_plus = vqc.loss(prediction_plus, label, params, "L2", 0)
		local loss_minus = vqc.loss(prediction_minus, label, params, "L1", 0)

		gradients[i] = (loss_plus - loss_minus) / (2 * epsilon)
	end
	return gradients
end

-- evil optimizer
local function adam_update(params: {number}, gradients: {number}, learning_rate: number, beta1: number, beta2: number, epsilon: number, m: {number}, v: {number}, t: number)
	for i, param in ipairs(params) do
		m[i] = beta1 * m[i] + (1 - beta1) * gradients[i]
		v[i] = beta2 * v[i] + (1 - beta2) * gradients[i]^2

		local m_hat = m[i] / (1 - beta1^t)
		local v_hat = v[i] / (1 - beta2^t)

		params[i] = params[i] - learning_rate * m_hat / (math.sqrt(v_hat) + epsilon)
	end
end

function vqc.train(data: {{number}}, labels: {number}, epochs: number, learning_rate: number, layers: number): {number}
	local params = {}
	local m = {}
	local v = {}
	local n = #data[1]
	local epsilon = 1e-8
	local beta1, beta2 = 0.9, 0.999

	for i = 1, n do
		params[i] = math.random()
		m[i] = 0
		v[i] = 0
	end

	for epoch = 1, epochs do
		local total_loss = 0
		for i, data_point in ipairs(data) do
			local qubits = vqc.encode(data_point, "angle")
			qubits = vqc.ansatz(params, qubits, layers)
			local prediction = vqc.measure(qubits)[1]
			local gradients = vqc.gradient(params, data_point, labels[i], layers, epsilon)
			local loss = vqc.loss(prediction, labels[i], params, "L2", 0.001)
			total_loss = total_loss + loss

			adam_update(params, gradients, learning_rate, beta1, beta2, epsilon, m, v, epoch)
		end
		print("Epoch " .. epoch .. " Loss: " .. total_loss / #data)
	end

	return params
end

qlm.vqc = vqc

local qnn = {}

-- Pluh giant 5 please make

qlm.qnn = qnn

return qlm