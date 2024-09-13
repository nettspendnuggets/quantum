--!native
--!optimize 2
--!strict

type complex = {r: number, i: number}
type qubit = {complex}
type qubits = {qubit}
type gate = {{complex}}
type matrix = {{complex}}

local cpx = require("cpx")
local gate = require("gate")
local mtx = require("mtx")
local qb = require("qb")
local preset = require("preset")

local anneal = {}

-- Jiface please make.
-- quantum annealing Thanks

return anneal