--!native
--!optimize 2
--!strict

local circuitvis = {}

export type gate = string
export type qubit = {gate}
export type circuit = {qubit}
export type grid = {{string}}

local function creategrid(rows: number, cols: number): grid
	local grid = table.create(rows)
	for i = 1, rows do
		grid[i] = table.create(cols, " ")
	end
	return grid
end

local function drawwire(grid: grid, row: number, startcol: number, endcol: number)
	for col = startcol, endcol do
		grid[row][col] = "─"
	end
end

local function drawgate(grid: grid, row: number, col: number, gatetype: gate)
	local gatesymbols = {
		h = "H", x = "X", y = "Y", z = "Z",
		s = "S", t = "T", cx = "●", cz = "○"
	}
	grid[row][col] = gatesymbols[string.lower(gatetype)] or gatetype
end

local function drawcontrol(grid: grid, startrow: number, endrow: number, col: number)
	for row = startrow, endrow do
		if grid[row][col] == " " then
			grid[row][col] = "│"
		end
	end
	grid[startrow][col] = "●"
	grid[endrow][col] = "X"
end

function circuitvis.visualize(circuit: circuit): string
	assert(type(circuit) == "table" and #circuit > 0, "invalid circuit")
	
	local numqubits = #circuit
	local numsteps = 0
	for i = 1, numqubits do
		assert(type(circuit[i]) == "table", "invalid qubit at index " .. i)
		numsteps = math.max(numsteps, #circuit[i])
	end
	
	local grid = creategrid(numqubits * 2 - 1, numsteps * 4 + 2)
	
	for qubit = 1, numqubits do
		local row = (qubit - 1) * 2 + 1
		grid[row][1] = tostring(qubit - 1) .. ":"
		drawwire(grid, row, 3, numsteps * 4 + 2)
		
		for step = 1, #circuit[qubit] do
			local col = (step - 1) * 4 + 4
			local gate = circuit[qubit][step]
			assert(type(gate) == "string", "invalid gate at qubit " .. qubit .. ", step " .. step)
			
			if gate:sub(1, 1) == "c" and #gate > 1 then
				local targetqubit = tonumber(gate:sub(2))
				assert(targetqubit and targetqubit <= numqubits, "invalid controlled gate target")
				local targetrow = (targetqubit - 1) * 2 + 1
				drawcontrol(grid, math.min(row, targetrow), math.max(row, targetrow), col)
			else
				drawgate(grid, row, col, gate)
			end
		end
	end
	
	local visualcircuit = ""
	for i = 1, #grid do
		visualcircuit = visualcircuit .. table.concat(grid[i]) .. "\n"
	end
	
	return visualcircuit
end

function circuitvis.printcircuit(circuit: circuit)
	print(circuitvis.visualize(circuit))
end

return circuitvis