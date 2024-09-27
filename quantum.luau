--!native
--!optimize 2
--!strict

math.randomseed(os.time())
export type complex = {r: number, i: number}
export type qubit = {complex}
export type qubits = {qubit}
export type gate = {{complex}}
export type matrix = {{complex}}
export type matrix_sz = {r: number, c: number}
return {
	mtx = require("mtx");
	cpx = require("cpx");
	qb = require("qb");
	gate = require("gate");
	preset = require("preset");
	wave = require("wave");
	algo = require("algo");
	err = require("err");
	noise = require("noise");
	tp = require("tp");
	circuitvis = require("circuitvis");
	ent = require("ent");
	crypto = require("crypto");
	kitaev = require("kitaev");
	anneal = require("anneal");
	qml = require("qml");
	decay = require("decay");
	compiler = require("compiler");
	anyon = require("anyon");
}