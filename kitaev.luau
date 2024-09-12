local kitaev = {}
kitaev.__index = kitaev

-- chain_size: kitaevs chain size
-- delta: pairing param (controls strength of superconducting pairing)
-- mu: chemical potential
-- t: hopping param
-- time_step: simulation time step
function kitaev.init_chain(chain_size: number?, delta: number?, mu: number?, t: number?, time_step: number?)
	local meta = {}
	meta.lattice = {}
	meta.chain_size = chain_size or 10
	meta.delta = delta or 0.5
	meta.mu = mu or 0.5
	meta.t = t or 1
	meta.time_step = time_step or 0.1

	setmetatable(meta, kitaev)

	for i = 1, meta.chain_size do
		meta.lattice[i] = {majorana1 = 0, majorana2 = 0}
	end

	return meta
end

function kitaev:apply_majorana(i, mode)
	if mode == 1 then
		self.lattice[i].majorana1 = (self.lattice[i].majorana1 + 1) % 2
	else
		self.lattice[i].majorana2 = (self.lattice[i].majorana2 + 1) % 2
	end
end

function kitaev:hamiltonian()
	local energy = 0
	for i = 1, self.size - 1 do
		-- hopping term (t * c_i† * c_{i+1} + h.c.)
		energy = energy - self.t * (self.lattice[i].majorana2 * self.lattice[i+1].majorana1)

		-- pairing term (Δ * c_i * c_{i+1} + h.c.)
		energy = energy + self.delta * (self.lattice[i].majorana1 * self.lattice[i+1].majorana2)
	end
	-- chemical potential term (μ * c_i† * c_i)
	for i = 1, self.size do
		energy = energy - self.mu * (self.lattice[i].majorana1 * self.lattice[i].majorana2)
	end
	return energy
end

function kitaev:detect_majorana()
	local left_majorana = self.lattice[1].majorana1
	local right_majorana = self.lattice[self.size].majorana2

	if left_majorana == 1 then
		print("Unpaired Majorana mode detected at the left end of the chain.")
	end
	if right_majorana == 1 then
		print("Unpaired Majorana mode detected at the right end of the chain.")
	end
end

function kitaev:evolve_chain(steps)
	for step = 1, steps do
		local energy = kitaev.hamiltonian()
		print("Energy at step " .. step .. ": " .. energy)
		kitaev.detect_majorana()

		for i = 1, self.size - 1 do
			self.lattice[i].majorana1 = (self.lattice[i].majorana1 + self.time_step * self.delta) % 2
			self.lattice[i].majorana2 = (self.lattice[i].majorana2 + self.time_step * self.t) % 2
		end
	end
end

function kitaev:braid_majorana(i, j, mode_i, mode_j)
	print("Braiding Majorana modes at positions " .. i .. " and " .. j)
	local temp
	if mode_i == 1 then
		temp = self.lattice[i].majorana1
		self.lattice[i].majorana1 = self.lattice[j].majorana1
		self.lattice[j].majorana1 = temp
	else
		temp = self.lattice[i].majorana2
		self.lattice[i].majorana2 = self.lattice[j].majorana2
		self.lattice[j].majorana2 = temp
	end
end

function kitaev:error_detect()
	local errors = 0
	for i = 1, self.size do
		if self.lattice[i].majorana1 ~= 0 and self.lattice[i].majorana2 ~= 0 then
			print("Error detected at site " .. i)
			errors = errors + 1
		end
	end
	return errors
end

function kitaev:error_correct()
	print("Performing error correction...")
	for i = 1, self.size do
		self.lattice[i].majorana1 = 0
		self.lattice[i].majorana2 = 0
	end
end

function kitaev:measure_majorana(i, mode)
	if mode == 1 then
		return self.lattice[i].majorana1
	else
		return self.lattice[i].majorana2
	end
end

function kitaev:full_simulation(steps)
	for step = 1, steps do
		print("\nStep " .. step)
		kitaev.evolve_chain(1)

		local errors = kitaev.error_detect()
		if errors > 0 then
			kitaev.error_correct()
		end

		if step % 5 == 0 then
			kitaev.braid_majorana(1, self.size, 1, 2)
		end
	end
end

function kitaev:perform_braiding_sequence(sequence)
	print("Performing braiding sequence...")
	for _, pair in ipairs(sequence) do
		local i, j, mode_i, mode_j = table.unpack(pair)
		kitaev.braid_majorana(i, j, mode_i, mode_j)
	end
end

function kitaev:time_evolution(steps, dt)
	for step = 1, steps do
		local energy = kitaev.hamiltonian()
		print("Energy at step " .. step .. ": " .. energy)
		kitaev.detect_majorana()

		for i = 1, self.size - 1 do
			self.lattice[i].majorana1 = (self.lattice[i].majorana1 + dt * self.delta) % 2
			self.lattice[i].majorana2 = (self.lattice[i].majorana2 + dt * self.t) % 2
		end
	end
end

return kitaev