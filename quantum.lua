--!native
--!optimize 2
--!strict

--[[-----------------------------------------------------------]]--
--++ quantum simulation written in luau                        ++--
--++ credits:                                                  ++--
--++    - axtrct                                               ++--
--++    - jiface                                               ++--
--[[-----------------------------------------------------------]]--


math.randomseed(os.time())
export type complex = {r : number, i : number}
export type qubit = {complex}
export type qubits = {qubit}
export type gate = {{complex}}
export type matrix = {{complex}}
export type matrix_sz = {r : number, c : number}
return {
	mtx = require("mtx.lua");
	cpx = require("cpx.lua");
	qb = require("qb.lua");
	gate = require("gate.lua");
	preset = require("preset.lua");
	wave = require("wave.lua");
	algo = require("algo.lua")
}