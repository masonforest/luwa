chex = func(i32, function(f)
	local ch = f:params(i32)
	f:load(ch)
	f:i32(48)
	f:sub()
	f:tee(ch)
	f:i32(10)
	f:ltu()
	f:ifelse(i32, function()
		f:load(ch)
	end, function()
		f:load(ch)
		f:i32(17)
		f:sub()
		f:tee(ch)
		f:i32(6)
		f:geu()
		f:iff (function()
			f:i32(-1)
			f:load(ch)
			f:i32(32)
			f:sub()
			f:tee(ch)
			f:i32(6)
			f:geu()
			f:brif(f)
			f:drop()
		end)
		f:load(ch)
		f:i32(10)
		f:add()
	end)
end)

pushstr = func(i32, function(f)
	local ch, tmpid, len = f:params(i32, i32, i32)
	local str, cap, l1 = f:i32(), f:i32(), f:i32()
	f:load(len)
	f:i32(1)
	f:add()
	f:tee(l1)
	f:load(tmpid)
	f:call(nthtmp)
	f:tee(str)
	f:f32load(5)
	f:tee(cap)
	f:eq()
	f:iff (function()
		f:load(cap)
		f:load(cap)
		f:add()
		f:tee(cap)
		f:call(newstr)
		f:load(tmpid)
		f:call(nthtmp)
		f:tee(str)
		f:load(len)
		f:i32(13)
		f:add()
		f:call(memcpy8)

		f:load(str)
		f:load(cap)
		f:i32store(5)

		f:load(str)
		f:load(tmpid)
		f:call(setnthtmp)
	end)

	f:load(str)
	f:load(len)
	f:add()
	f:load(ch)
	f:i32store8(13)
	f:load(l1)
end)

pushvec = func(i32, function(f)
	local o, tmpid, len = f:params(i32, i32, i32)
	local vec, cap, l1 = f:i32(), f:i32(), f:i32()
	f:load(len)
	f:i32(4)
	f:add()
	f:tee(l1)
	f:load(tmpid)
	f:call(nthtmp)
	f:tee(vec)
	f:i32load(5)
	f:tee(cap)
	f:eq()
	f:iff(function()
		f:load(o)
		f:storeg(otmp)

		f:load(cap)
		f:load(cap)
		f:add()
		f:tee(cap)
		f:call(newvec)
		f:load(tmpid)
		f:call(nthtmp)
		f:tee(vec)
		f:load(len)
		f:i32(9)
		f:add()
		f:call(memcpy8)

		f:load(vec)
		f:load(cap)
		f:i32store(5)

		f:load(vec)
		f:load(tmpid)
		f:call(setnthtmp)

		f:loadg(otmp)
		f:store(o)
	end)

	f:load(vec)
	f:load(len)
	f:add()
	f:load(o)
	f:i32store(9)
	f:load(l1)
end)

memcpy1rl = func(function(f)
	local dst, src, len = f:params(i32, i32, i32)
	f:loop(function(loop)
		f:load(len)
		f:eqz()
		f:brif(f)

		f:load(dst)
		f:load(len)
		f:i32(1)
		f:sub()
		f:tee(len)
		f:add()
		f:load(src)
		f:load(len)
		f:add()
		f:i32load8u()
		f:i32store8()

		f:br(loop)
	end)
end)

memcpy8 = func(function(f)
	local dst, src, len = f:params(i32, i32, i32)
	local n = f:i32()
	f:loop(function(loop)
		f:load(n)
		f:load(len)
		f:geu()
		f:brif(f)

		f:load(dst)
		f:load(n)
		f:add()
		f:load(src)
		f:load(n)
		f:add()
		f:i64load()
		f:i64store()

		f:load(n)
		f:i32(8)
		f:add()
		f:store(n)

		f:br(loop)
	end)
end)