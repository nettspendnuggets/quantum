--!native
--!optimize 2
--!strict

--[[-----------------------------------------------------------]]--
--++ quantum simulation written in luauu                        ++--
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
	mtx = require("mtx.luau");
	cpx = require("cpx.luau");
	qb = require("qb.luau");
	gate = require("gate.luau");
	preset = require("preset.luau");
	wave = require("wave.luau");
	algo = require("algo.luau")
}