strcmp = func(i32, i32, i32, function(f, a, b)
	local idx, len, c, eqlenv = f:locals(i32, 4)
	-- len = min(a.len, b.len); eqlenv = a.len - b.len
	f:load(a)
	f:i32load(str.len)
	f:tee(idx)
	f:load(b)
	f:i32load(str.len)
	f:tee(len)
	f:load(idx)
	f:load(len)
	f:ltu()
	f:select()
	f:load(idx)
	f:load(len)
	f:sub()
	f:store(eqlenv)
	f:store(len)

	f:loop(function(loop)
		f:load(idx)
		f:load(len)
		f:ne()
		f:iff(function()
			f:load(a)
			f:load(idx)
			f:add()
			f:i32load8u()
			f:load(b)
			f:load(idx)
			f:add()
			f:i32load8u()
			f:sub()
			f:tee(c)
			f:iff(function()
				f:i32(1)
				f:i32(-1)
				f:load(c)
				f:i32(0)
				f:gts()
				f:select()
				f:ret()
			end)
			f:load(idx)
			f:i32(1)
			f:add()
			f:store(idx)
			f:br(loop)
		end)
	end)
	f:i32(1)
	f:i32(-1)
	f:load(eqlenv)
	f:i32(0)
	f:gts()
	f:select()
	f:i32(0)
	f:load(eqlenv)
	f:select()
end)