std_pcall = func(function(f)
	-- > func, p1, p2, ...
	-- < true, p1, p2, ...
	-- modify datastack: 2, 0, framesz, retc, base+1
	local a, valvec, base = f:locals(i32, 3)
	f:loadg(oluastack)
	f:i32load(coro.stack)
	f:i32load(buf.ptr)
	f:tee(valvec)
	f:loadg(oluastack)
	f:i32load(coro.data)
	f:tee(a)
	f:i32load(buf.ptr)
	f:load(a)
	f:i32load(buf.len)
	f:add()
	f:i32(17)
	f:sub()
	f:tee(a)
	-- TODO load localc from p0 & assign to dataframe

	f:i32load(dataframe.base)
	f:tee(base)
	f:add()
	f:i32(TRUE)
	f:i32store(vec.base)

	f:load(a)
	f:i32(calltypes.prot)
	f:i32store8(dataframe.type)

	f:load(a)
	f:i32(0)
	f:i32store(dataframe.pc)

	f:load(a)
	f:load(a)
	f:i32load(dataframe.retc)
	f:i32(1)
	f:sub()
	f:i32store(dataframe.retc)

	f:load(a)
	f:load(base)
	f:i32(4)
	f:add()
	f:i32store(dataframe.base)
end)

std_select = func(function(f)
	-- L.stack[base] == '#' ? L.stack.len - base - 1 : L.stack[base + L.stack[base]]
	local a, valstack, base, p0 = f:locals(i32, 4)

	-- base = L.data.base
	-- a = L.stack + base
	f:loadg(oluastack)
	f:i32load(coro.stack)
	f:tee(valstack)
	f:i32load(buf.ptr)
	f:loadg(oluastack)
	f:i32load(coro.data)
	f:tee(a)
	f:i32load(buf.ptr)
	f:load(a)
	f:i32load(buf.len)
	f:add()
	loadstrminus(f, 4)
	f:tee(base)
	f:add()
	f:tee(p0)
	f:i32load(obj.type)
	f:i32(types.str)
	f:eq()
	f:iff(function()
		assert(str.base & 7 == 0)
		f:load(p0)
		f:i32load8u(str.base)
		f:i32(string.byte('#'))
		f:eq()
		f:load(p0)
		f:i32load(str.len)
		f:i32(1)
		f:eq()
		f:band()
		f:iff(function()
			f:load(valstack)
			f:i32load(buf.ptr)
			f:load(valstack)
			f:i32load(buf.len)
			f:load(base)
			f:sub()
			f:i32(1)
			f:sub()
			f:add()
			f:i32load(vec.base)
			f:i64extends()
			f:call(newi64)
			-- TODO truncate based on base
			f:i32(4)
			f:call(setnthtmp)
			f:ret()
		end)
	end)

	f:load(p0)
	f:call(toint)
	f:tee(p0)
	f:iff(function()
		-- TODO bounds check
		f:loadg(oluastack)
		f:i32load(coro.stack)
		f:i32load(buf.ptr)
		f:load(base)
		f:load(p0)
		f:i32load(num.base)
		f:add()
		f:add()
		f:i32load(vec.base)
	end, function()
		f:unreachable()
	end)
end)

math_abs = func(function(f)
	local a = f:locals(i32)
	local a64 = f:locals(i64)

	f:block(function(err)
		f:block(function(flt)
			f:block(function(int)
				f:i32(4)
				f:call(nthtmp)
				f:tee(a)
				f:i32load(obj.type)
				f:brtable(int, flt, err)
			end) -- int
			f:load(a)
			f:i64load(num.base)
			f:tee(a64)
			f:i64(0)
			f:lts()
			f:iff(function()
				f:i64(0)
				f:load(a64)
				f:sub()
				f:call(newi64)
				f:i32(4)
				f:call(setnthtmp)
			end)
			f:ret()
		end) -- flt
		f:load(a)
		f:f64load(num.base)
		f:abs()
		f:call(newf64)
		f:i32(4)
		f:call(setnthtmp)
		f:ret()
	end) -- err
	f:unreachable()
end)

local function genmathround(op)
	return func(function(f)
		f:i32(4)
		f:call(nthtmp)
		f:tee(a)
		f:i32load(obj.type)
		f:i32(1)
		f:eq()
		f:iff(function()
			f:load(a)
			f:f64load(num.base)
			f[op](f)
			f:i64truncs()
			f:call(newi64)
			f:i32(4)
			f:call(setnthtmp)
		end, function()
			f:unreachable()
		end)
	end)
end

math_ceil = genmathround('ceil')
math_floor = genmathround('floor')

math_frexp = func(function(f)
	-- TODO come up with a DRY type checking strategy
	-- TODO update ABI
	f:i32(4)
	f:call(nthtmp)
	f:f64load(num.val)
	f:call(frexp)
	-- Replace param x with ret of frexp
	-- 2nd retval is already in place
	f:call(newf64)
	f:i32(8)
	f:call(setnthtmp)
end)

math_type = func(function(f)
	f:block(i32, function(res)
		f:block(function(nonu)
			f:block(function(flt)
				f:block(function(int)
					f:i32(4)
					f:call(nthtmp)
					f:i32load(obj.type)
					f:brtable(int, flt, nonu)
				end)
				f:i32(GS.integer)
				f:br(res)
			end)
			f:i32(GS.float)
			f:br(res)
		end)
		f:i32(NIL)
	end)
	f:i32(4)
	f:call(setnthtmp)
end)

coro_running = func(function(f)
	-- TODO discard parameters
	f:loadg(oluastack)
	f:i32load(coro.stack)
	f:loadg(oluastack)
	f:call(pushvec)
	f:i32(TRUE)
	f:i32(FALSE)
	f:loadg(oluastack)
	f:i32load(coro.caller)
	f:select()
	f:call(pushvec)
	f:drop()
end)

coro_status = func(function(f)
	local a = f:locals(i32)

	f:loadg(oluastack)
	f:i32load(coro.stack)
	f:i32load(buf.ptr)
	f:loadg(oluastack)
	f:i32load(coro.data)
	f:tee(a)
	f:i32load(buf.ptr)
	f:load(a)
	f:i32load(buf.len)
	f:add()
	loadvecminus(f, 4)
	f:add()
	f:tee(a)
	f:load(a)
	f:i32load(vec.base)
	f:i32load(obj.type)
	f:i32(types.coro)
	f:eq()
	f:iff(i32, function(res)
		assert(corostate.dead == 0 and corostate.norm == 1 and corostate.live == 2 and corostate.wait == 3)
		f:block(function(wait)
			f:block(function(live)
				f:block(function(norm)
					f:block(function(dead)
						f:brtable(dead, norm, live, wait)
					end)
					f:i32(GS.dead)
					f:br(res)
				end)
				f:i32(GS.normal)
				f:br(res)
			end)
			f:i32(GS.running)
			f:br(res)
		end)
		f:i32(GS.suspended)
	end, function()
		-- error
		f:unreachable()
	end)
	f:i32store(vec.base)
end)
