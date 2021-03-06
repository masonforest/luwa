local M = require 'make'
local func = M.func

local alloc = require 'alloc'
local types, obj, vec, tbl, buf, coro = alloc.types, alloc.obj, alloc.vec, alloc.tbl, alloc.buf, alloc.coro

local stack = require 'stack'
local tmppush = stack.tmppush

local vm = require 'vm'
local dataframe = vm.dataframe

local debug_getmetatable = func(function(f)
	local a, b = f:locals(i32, 2)

	f:call(loadframebase)
	f:i32load(dataframe.base)
	f:loadg(oluastack)
	f:i32load(coro.stack)
	f:i32load(buf.ptr)
	f:add()
	f:i32load(vec.base)
	f:tee(a)
	f:i32load8u(obj.type)
	f:tee(b)
	f:i32(types.tbl)
	f:eq()
	f:iff(i32, function()
		f:load(a)
		f:i32load(tbl.meta)
	end, function()
		-- TODO implement metatable logic for all types
		f:loadg(ostrmt)
		f:i32(NIL)
		f:load(a)
		f:i32(types.str)
		f:eq()
		f:select()
	end)
	f:call(tmppush)
end)

local debug_setmetatable = func(function(f)
	local a, b, c, base = f:locals(i32, 4)

	f:call(loadframebase)
	f:i32load(dataframe.base)
	f:loadg(oluastack)
	f:i32load(coro.stack)
	f:i32load(buf.ptr)
	f:add()
	f:tee(base)
	f:i32load(vec.base)
	f:tee(a)
	f:i32load8u(obj.type)
	f:tee(c)
	f:i32(types.tbl)
	f:eq()
	f:iff(function(err)
		f:load(base)
		f:i32load(vec.base + 4)
		f:tee(b)
		f:i32load8u(obj.type)
		f:i32(types.tbl)
		f:ne()
		f:brif(err)

		f:load(a)
		f:load(b)
		f:i32store(tbl.meta)
		f:load(a)
		f:call(tmppush)
		f:ret()
	end)
	f:load(c)
	f:i32(types.str)
	f:eq()
	f:iff(function(err)
		f:load(base)
		f:i32load(vec.base + 4)
		f:i32load8u(obj.type)
		f:i32(types.tbl)
		f:ne()
		f:brif(err)

		f:load(b)
		f:storeg(ostrmt)
		f:load(a)
		f:call(tmppush)
		f:ret()
	end)
	f:unreachable()
end)

return {
	debug_getmetatable = debug_getmetatable,
	debug_setmetatable = debug_setmetatable,
}
