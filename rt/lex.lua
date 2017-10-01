lxaddval = func(i32, i32, i32, function(f, o, tmpid)
	local boxlen, buflen = f:locals(i32, 2)
	f:i32(12)
	f:call(nthtmp)
	f:load(o)
	f:call(tblget)
	f:tee(boxlen)
	assert(NIL == 0)
	f:eqz()
	f:iff(function()
		-- push const to constvec
		f:load(o)
		f:call(tmppush)
		f:load(tmpid)
		f:call(nthtmp)
		f:tee(buflen)
		f:i32load(buf.len)
		f:i32(2)
		f:shru()

		f:load(buflen)
		f:i32(4)
		f:call(nthtmp)
		f:tee(o)
		f:call(pushvec)
		f:load(tmpid)
		f:call(setnthtmp)

		f:tee(buflen)
		f:i64extendu()
		f:call(newi64)
		f:store(boxlen)

		-- add entry to revmap
		f:i32(16)
		f:call(nthtmp)
		f:i32(4)
		f:call(nthtmp)
		f:call(tmppop)
		f:load(boxlen)
		f:call(tblset)

		f:load(buflen)
		f:ret()
	end)
	f:load(boxlen)
	f:i32load(num.val)
end)

local function lxaddnum(f)
	f:i32(8)
	f:call(lxaddval)
end
local function lxaddstr(f)
	f:i32(12)
	f:call(lxaddval)
end

lex = export('lex', func(i32, void, function(f, src)
	local i, ch, j, k, srclen, tstr, tlen = f:locals(i32, 7)
	local temp64, temp642 = f:locals(i64, 2)
	local double, flt10 = f:locals(f64, 2)

	f:load(src)
	f:i32load(str.len)
	f:store(srclen)

	-- TODO move src+revmap to top of stack so we can efficiently pop without popping other 3
	-- 5 src
	f:load(src)
	f:call(tmppush)

	-- 4 lex
	f:i32(1011)
	f:call(newstrbuf)
	f:call(tmppush)

	-- 3 reverse mapping of strs/nums
	f:call(newtbl)
	f:call(tmppush)

	-- 2 [strs]
	f:i32(256)
	f:call(newvecbuf)
	f:call(tmppush)

	-- 1 [nums]
	f:i32(64)
	f:call(newvecbuf)
	f:call(tmppush)

	f:i32(GS._ENV)
	lxaddstr(f)
	f:drop()
	f:i32(GS.self)
	lxaddstr(f)
	f:drop()

	f:block(function(loopwrap)
		f:load(srclen)
		f:eqz()
		f:brif(loopwrap)

		f:loop(function(loopnoinc)
			f:block(function(blloop)
				f:load(i)
				f:load(srclen)
				f:geu()
				f:brif(loopwrap)

				f:i32(20)
				f:call(nthtmp)
				f:tee(src)
				f:load(i)
				f:add()
				f:i32load8u(str.base)
				f:tee(ch)
				f:i32(32)
				f:leu()
				f:brif(blloop)

				f:block(i32, function(token1)
					local function tcase(s)
						return string.byte(s) - 33
					end
					f:switch(function()
						f:load(ch)
						f:i32(33)
						f:sub()
					end,
					tcase("'"), tcase('"'), function()
						f:i32(11)
						f:call(newstr)
						f:tee(tstr)
						f:call(tmppush)

						f:i32(0)
						f:store(tlen)

						f:block(function(blockscanq)
						f:loop(function(loopscanq)
							f:load(i)
							f:i32(1)
							f:add()
							f:tee(i)
							f:load(srclen)
							f:eq()
							f:brif(blockscanq)

							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:tee(j)
							f:load(ch)
							f:eq()
							f:brif(blockscanq)

							-- prep for pushstr call
							f:load(tstr)

							f:load(j)
							f:i32(92)
							f:eq()
							f:iff(i32, function(stresc)
								f:i32(0)
								f:load(i)
								f:i32(1)
								f:add()
								f:tee(i)
								f:load(srclen)
								f:eq()
								f:brif(stresc)
								f:drop()

								f:load(i)
								f:load(src)
								f:add()
								f:i32load8u(str.base)
								f:tee(j)
								f:i32(34)
								f:eq()
								f:load(j)
								f:i32(34)
								f:eq()
								f:bor()
								f:load(j)
								f:i32(92)
								f:eq()
								f:bor()
								f:iff(i32, function()
									f:load(j)
								end, function()
									f:load(j)
									f:i32(48)
									f:sub()
									f:tee(j)
									f:i32(10)
									f:ltu()
									f:iff(i32, function(tblbr)
										f:i32(0)
										f:load(i)
										f:i32(1)
										f:add()
										f:tee(i)
										f:load(srclen)
										f:eq()
										f:brif(stresc)
										f:drop()

										f:load(i)
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(48)
										f:sub()
										f:tee(ch)
										f:i32(10)
										f:ltu()
										f:iff(i32, function()
											f:i32(0)
											f:load(i)
											f:i32(1)
											f:add()
											f:tee(i)
											f:load(srclen)
											f:eq()
											f:brif(stresc)
											f:drop()

											f:load(i)
											f:load(src)
											f:add()
											f:i32load8u(str.base)
											f:i32(48)
											f:sub()
											f:tee(k)
											f:i32(10)
											f:ltu()
											f:iff(i32, function()
												f:load(j)
												f:i32(100)
												f:mul()
												f:load(ch)
												f:i32(10)
												f:mul()
												f:add()
												f:load(k)
												f:add()
											end, function()
												f:load(i)
												f:i32(1)
												f:sub()
												f:store(i)

												f:load(j)
												f:i32(10)
												f:mul()
												f:load(ch)
												f:add()
											end)
										end, function()
											f:load(i)
											f:i32(1)
											f:sub()
											f:store(i)

											f:load(j)
										end)
									end, function(tblbr)
										f:switch(function()
											f:load(j)
											f:i32(49)
											f:sub()
										end, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 18, 22, 24, -1, 'noesc', function()
											f:unreachable()
										end, 25, function()
											f:loop(function(loop)
												f:i32(0)
												f:load(i)
												f:i32(1)
												f:add()
												f:tee(i)
												f:load(srclen)
												f:eq()
												f:brif(stresc)
												f:drop()

												f:load(i)
												f:load(src)
												f:add()
												f:i32load8u(str.base)
												f:tee(j)
												f:i32(32)
												f:eq()
												f:brif(loop)

												f:load(j)
												f:i32(9)
												f:geu()
												f:load(j)
												f:i32(13)
												f:leu()
												f:bor()
												f:brif(loop)
											end)

											f:load(i)
											f:i32(1)
											f:sub()
											f:store(i)
											f:br(loopscanq)
										end, 23, function()
											f:i32(0)
											f:load(i)
											f:i32(2)
											f:add()
											f:tee(i)
											f:load(srclen)
											f:geu()
											f:brif(stresc)
											f:drop()

											f:load(i)
											f:i32(1)
											f:sub()
											f:load(src)
											f:add()
											f:i32load8u(str.base)
											f:call(chex)
											f:i32(16)
											f:mul()

											f:load(i)
											f:load(src)
											f:add()
											f:i32load8u(str.base)
											f:call(chex)
											f:add()
											f:br(tblbr)
										end, 21, function()
											f:i32(11)
											f:br(tblbr)
										end, 20, function()
											f:i32(0)
											f:load(i)
											f:i32(1)
											f:add()
											f:tee(i)
											f:load(srclen)
											f:eq()
											f:brif(stresc)
											f:drop()

											f:i32(0)
											f:load(i)
											f:load(src)
											f:add()
											f:i32load8u(str.base)
											f:i32(123)
											f:ne()
											f:brif(stresc)
											f:drop()

											f:i32(0)
											f:store(j)

											-- j <- parse {hex} to int
											f:loop(function(uloop)
												f:i32(0)
												f:load(i)
												f:i32(1)
												f:add()
												f:tee(i)
												f:load(srclen)
												f:eq(0)
												f:brif(stresc)
												f:drop()

												f:load(i)
												f:load(src)
												f:add()
												f:i32load8u(str.base)
												f:tee(ch)
												f:i32(125)
												f:eq()
												f:iff(function()
													f:load(j)
													f:i32(4)
													f:shl()
													f:load(ch)
													f:call(chex)
													f:bor()
													f:store(j)
													f:br(uloop)
												end)
											end)

											-- encode utf8 codepoint j
											f:load(j)
											f:i32(0x80)
											f:ltu()
											f:iff(i32, function()
												f:load(tstr)
												f:load(j)
												f:call(pushstr)
											end, function()
												f:load(j)
												f:i32(0x800)
												f:ltu()
												f:iff(i32, function()
													f:load(tstr)
													f:load(j)
													f:i32(6)
													f:shru()
													f:i32(0x1f)
													f:band()
													f:i32(0xc0)
													f:bor()
													f:call(pushstr)

													f:load(j)
													f:i32(0x3f)
													f:band()
													f:i32(0x80)
													f:bor()
													f:call(pushstr)
												end, function()
													f:load(j)
													f:i32(0x10000)
													f:ltu()
													f:iff(i32, function()
														f:load(tstr)
														f:load(j)
														f:i32(12)
														f:shru()
														f:i32(0x0f)
														f:band()
														f:i32(0xe0)
														f:bor()
														f:call(pushstr)

														f:load(j)
														f:i32(6)
														f:shru()
														f:i32(0x3f)
														f:band()
														f:i32(0x80)
														f:bor()
														f:call(pushstr)

														f:load(j)
														f:i32(0x3f)
														f:band()
														f:i32(0x80)
														f:bor()
														f:call(pushstr)
													end, function()
														f:load(tstr)
														f:load(j)
														f:i32(18)
														f:shru()
														f:i32(0x07)
														f:band()
														f:i32(0xf0)
														f:bor()
														f:call(pushstr)

														f:load(j)
														f:i32(12)
														f:shru()
														f:i32(0x3f)
														f:band()
														f:i32(0x80)
														f:bor()
														f:call(pushstr)

														f:load(j)
														f:i32(6)
														f:shru()
														f:i32(0x3f)
														f:band()
														f:i32(0x80)
														f:bor()
														f:call(pushstr)

														f:load(j)
														f:i32(0x3f)
														f:band()
														f:i32(0x80)
														f:bor()
														f:call(pushstr)
													end)
												end)
											end)
											f:store(tstr)
											f:br(loopscanq)
										end, 19, function()
											f:i32(9)
											f:br(tblbr)
										end, 17, function()
											f:i32(13)
											f:br(tblbr)
										end, 13, function()
											f:i32(10)
											f:br(tblbr)
										end, 5, function()
											f:i32(12)
											f:br(tblbr)
										end, 1, function()
											f:i32(8)
											f:br(tblbr)
										end, 0)
										f:i32(7)
									end)
								end)
							end, function()
								f:load(j)
							end)

							f:call(pushstr)
							f:store(tstr)
							f:br(loopscanq)
						end)
						end)

						f:load(tlen)
						f:call(newstr)
						f:tee(ch)
						f:i32(13)
						f:add()
						f:i32(4)
						f:call(nthtmp)
						f:i32(13)
						f:add()
						f:load(ch)
						f:i32load(str.len)
						f:call(memcpy1rl)
						f:call(tmppop)

						f:load(ch)
						lxaddstr(f)
						f:store(ch)

						f:i32(16)
						f:call(nthtmp)
						f:i32(128)
						f:call(pushstr)

						f:load(ch)
						f:call(pushstr)

						f:load(ch)
						f:i32(8)
						f:shru()
						f:call(pushstr)

						f:load(ch)
						f:i32(16)
						f:shru()
						f:call(pushstr)

						f:load(ch)
						f:i32(24)
						f:shru()
						f:call(pushstr)
						f:i32(16)
						f:call(setnthtmp)

						f:br(blloop)
					end, tcase('#'), function()
						f:i32(29)
						f:br(token1)
					end, tcase('%'), function()
						f:i32(27)
						f:br(token1)
					end, tcase('&'), function()
						f:i32(30)
						f:br(token1)
					end, tcase('('), function()
						f:i32(43)
						f:br(token1)
					end, tcase(')'), function()
						f:i32(44)
						f:br(token1)
					end, tcase('*'), function()
						f:i32(25)
						f:br(token1)
					end, tcase('+'), function()
						f:i32(23)
						f:br(token1)
					end, tcase(','), function()
						f:i32(52)
						f:br(token1)
					end, tcase('-'), function()
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(24)
						end, function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(45) -- '-
							f:eq()
							f:iff(i32, function()
								f:load(i)
								f:i32(1)
								f:add()
								f:load(srclen)
								f:eq()
								f:brif(blloop)

								f:load(i)
								f:i32(1)
								f:add()
								f:load(src)
								f:add()
								f:i32load8u(str.base)
								f:i32(91) --'[
								f:eq()
								f:iff(function(ifdeepcomm)
									f:i32(0)
									f:store(ch)
									f:loop(function(loop) -- count =s
										-- eof?
										f:load(ch)
										f:i32(1)
										f:add()
										f:tee(ch)
										f:load(i)
										f:add()
										f:load(srclen)
										f:eq()
										f:brif(loopnoinc)

										-- =?
										f:load(ch)
										f:load(i)
										f:add()
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(61) -- '=
										f:eq()
										f:brif(loop)

										-- if [, scan, else enter newline scan
										f:load(ch)
										f:load(i)
										f:add()
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(91) -- '[
										f:ne()
										f:brif(ifdeepcomm)
									end)

									f:loop(function(srscan) -- scan for ]
										-- eof?
										f:load(i)
										f:i32(1)
										f:add()
										f:tee(i)
										f:load(ch)
										f:add()
										f:load(srclen)
										f:eq()
										f:brif(loopnoinc)

										-- reloop if not ]
										f:load(i)
										f:load(ch)
										f:add()
										f:tee(i)
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(93) -- ']
										f:ne()
										f:brif(srscan)

										-- count =s
										f:load(i)
										f:store(j)
										f:loop(i32, function(loop)
											-- eof?
											f:load(i)
											f:i32(1)
											f:add()
											f:tee(i)
											f:load(ch)
											f:add()
											f:load(srclen)
											f:eq()
											f:brif(loopnoinc)

											-- =?
											f:load(i)
											f:load(ch)
											f:add()
											f:load(src)
											f:add()
											f:i32load8u(str.base)
											f:i32(61)
											f:eq()
											f:brif(loop)

											f:load(i)
										end)
										f:load(j)
										f:sub()
										f:load(ch)
										f:ne()
										f:brif(srscan) -- reloop if wrong = count

										-- eof?
										f:load(i)
										f:i32(1)
										f:add()
										f:tee(i)
										f:load(ch)
										f:add()
										f:load(srclen)
										f:eq()
										f:brif(loopnoinc)

										-- if not ], reloop
										f:load(i)
										f:load(ch)
										f:add()
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(93) -- ']
										f:ne()
										f:brif(srscan)

										-- end of comment. Increment i by ch & break
										f:load(i)
										f:load(ch)
										f:add()
										f:store(i)

										f:br(blloop)
									end)
								end)

								f:loop(i32, function(loop)
									f:load(i)
									f:i32(1)
									f:add()
									f:tee(i)
									f:load(srclen)
									f:eq()
									f:brif(loopnoinc)

									f:load(i)
									f:load(src)
									f:add()
									f:i32load8u(str.base)
									f:i32(10)
									f:eq()
									f:brtable(loop, blloop)
								end)
							end, function()
								f:i32(24)
							end)
						end)
						f:br(token1)
					end, tcase('/'), function()
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(26)
						end, function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(47) -- '/
							f:eq()
							f:iff(i32, function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(35)
							end, function()
								f:i32(26)
							end)
						end)
						f:br(token1)
					end, tcase('.'), function(scopes)
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(53)
						end, function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:tee(ch)
							f:i32(46) -- '.
							f:eq()
							f:iff(i32, function()
								f:load(i)
								f:i32(1)
								f:add()
								f:tee(i)
								f:load(srclen)
								f:eq()
								f:iff(i32, function()
									f:i32(54)
								end, function()
									f:load(i)
									f:load(src)
									f:add()
									f:i32load8u(str.base)
									f:i32(46) -- '.
									f:eq()
									f:iff(i32, function()
										f:load(i)
										f:i32(1)
										f:add()
										f:store(i)

										f:i32(55)
									end, function()
										f:i32(54)
									end)
								end)
							end, function()
								f:load(ch)
								f:i32(48)
								f:sub()
								f:i32(10)
								f:ltu()
								f:iff(function()
									-- move i before . to parse as of 0.x
									f:load(i)
									f:i32(2)
									f:sub()
									f:store(i)
									f:i32(48)
									f:store(ch)
									f:br(scopes.digit)
								end)
								f:i32(53)
							end)
						end)
						f:br(token1)
					end, tcase('0'), function(scopes)
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:ne()
						f:iff(function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(120)
							f:eq()
							f:iff(function()
								f:i64(0)
								f:store(temp64)
								f:i32(0)
								f:store(tlen)
								f:loop(function(hexloop)
									f:load(i)
									f:i32(1)
									f:add()
									f:tee(i)
									f:load(srclen)
									f:ne()
									f:iff(function()
										f:load(i)
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:tee(ch)
										f:i32(46)
										f:eq()
										f:iff(function() -- hex float
											f:load(temp64)
											f:f64convertu()
											f:store(double)

											f:f64(1)
											f:store(flt10)

											f:i32(1)
											f:store(tlen)

											f:loop(function(xfltloop)
												f:load(i)
												f:i32(1)
												f:add()
												f:tee(i)
												f:load(srclen)
												f:ne()
												f:iff(function()
													f:load(i)
													f:load(src)
													f:add()
													f:i32load8u(str.base)
													f:call(chex)
													f:tee(ch)
													f:i32(-1)
													f:ne()
													f:iff(function()
														f:load(double)
														f:load(ch)
														f:f64convertu()
														f:load(flt10)
														f:f64(16)
														f:div()
														f:tee(flt10)
														f:mul()
														f:add()
														f:store(double)
														f:br(xfltloop)
													end)
												end)
											end)
											f:br(scopes.digitpush)
										end)

										f:load(ch)
										f:call(chex)
										f:tee(ch)
										f:i32(-1)
										f:eq()
										f:brif(scopes.digitpush)

										f:load(temp64)
										f:i64(4)
										f:shl()
										f:load(ch)
										f:i64extendu()
										f:bor()
										f:store(temp64)

										f:br(hexloop)
									end)
									f:br(scopes.digitpush)
								end)
							end)
						end)
						f:load(i)
						f:i32(1)
						f:sub()
						f:store(i)

					end, 'digit', tcase('1'), tcase('2'), tcase('3'), tcase('4'), tcase('5'), tcase('6'), tcase('7'), tcase('8'), tcase('9'), function()
						f:load(ch)
						f:i32(48)
						f:sub()
						f:i64extendu()
						f:store(temp64)

						f:i32(0)
						f:store(tlen)

						f:loop(function(intloop)
							f:load(i)
							f:i32(1)
							f:add()
							f:tee(i)
							f:load(srclen)
							f:ne()
							f:iff(function()
								f:load(i)
								f:load(src)
								f:add()
								f:i64load8u(str.base)
								f:i64(48)
								f:sub()
								f:tee(temp642)
								f:i64(10)
								f:ltu()
								f:iff(function()
									f:load(temp64)
									f:i64(10)
									f:mul()
									f:load(temp642)
									f:add()
									f:store(temp64)
									f:br(intloop)
								end, function()
									f:load(temp642)
									f:i64(-2)
									f:eq()
									f:iff(function()
										f:load(temp64)
										f:f64convertu()
										f:store(double)

										f:f64(1)
										f:store(flt10)

										f:i32(1)
										f:store(tlen)

										f:loop(function(fltloop)
											f:load(i)
											f:i32(1)
											f:add()
											f:tee(i)
											f:load(srclen)
											f:ne()
											f:iff(function()
												f:load(i)
												f:load(src)
												f:add()
												f:i64load8u(str.base)
												f:i64(48)
												f:sub()
												f:tee(temp642)
												f:i64(10)
												f:ltu()
												f:iff(function()
													f:load(double)
													f:load(temp642)
													f:f64convertu()
													f:load(flt10)
													f:f64(10)
													f:div()
													f:tee(flt10)
													f:mul()
													f:add()
													f:store(double)
													f:br(fltloop)
												end)
											end)
										end)
									end)
								end)
							end)
						end)
					end, 'digitpush', function() -- shared endpoint of dec/hex parse

						f:load(i)
						f:load(srclen)
						f:ltu()
						f:iff(function(eorp)
							f:i32(0)
							f:store(j)

							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(-33) -- x&~32 is lower(x)
							f:band()
							f:tee(ch)
							f:i32(69) -- E
							f:eq()
							f:tee(k)
							f:load(ch)
							f:i32(80) -- P
							f:eq()
							f:bor()
							f:iff(function()
								f:f64(10)
								f:f64(2)
								f:load(k)
								f:select()
								f:store(flt10)

								-- First iteration is unrolled to check for +-
								f:load(i)
								f:i32(1)
								f:add()
								f:tee(i)
								f:load(srclen)
								f:eq()
								f:brif(eorp)

								f:load(i)
								f:load(src)
								f:add()
								f:i32load8u(str.base)
								f:i32(48)
								f:sub()
								f:tee(j)
								f:i32(10)
								f:geu()
								f:iff(function()
									f:load(j)
									f:i32(-3)-- -
									f:eq()
									f:iff(function()
										f:f64(1)
										f:load(flt10)
										f:div()
										f:store(flt10)
									end, function()
										f:load(j)
										f:i32(-5) -- + is nop
										f:ne()
										f:brif(eorp) -- invalid number
									end)
									f:i32(0)
									f:store(j)
								end)

								f:loop(function(eorploop)
									f:load(i)
									f:i32(1)
									f:add()
									f:tee(i)
									f:load(srclen)
									f:eq()
									f:brif(eorp)

									f:load(i)
									f:load(src)
									f:add()
									f:i32load8u(str.base)
									f:i32(48)
									f:sub()
									f:tee(ch)
									f:i32(10)
									f:ltu()
									f:iff(function()
										f:load(j)
										f:i32(10)
										f:mul()
										f:load(ch)
										f:add()
										f:store(j)
										f:br(eorploop)
									end)
								end)
								f:load(tlen)
								f:eqz()
								f:iff(function()
									f:i32(1)
									f:store(tlen)
									f:load(temp64)
									f:f64convertu()
									f:store(double)
								end)
								f:load(j)
								f:iff(function()
									f:loop(function(loop)
										f:load(double)
										f:load(flt10)
										f:mul()
										f:store(double)

										f:load(j)
										f:i32(1)
										f:sub()
										f:tee(j)
										f:brif(loop)
									end)
								end)
							end)
						end)
						---- TODO once 1 & 1.0 hash the same this breaks
						---- 1 & 1.0 need unique indices
						f:load(tlen)
						f:iff(i32, function()
							f:load(double)
							f:call(newf64)
						end, function()
							f:load(temp64)
							f:call(newi64)
						end)
						lxaddnum(f)
						f:store(ch)

						f:i32(16)
						f:call(nthtmp)
						f:i32(192)
						f:call(pushstr)

						f:load(ch)
						f:call(pushstr)

						f:load(ch)
						f:i32(8)
						f:shru()
						f:call(pushstr)

						f:load(ch)
						f:i32(16)
						f:shru()
						f:call(pushstr)

						f:load(ch)
						f:i32(24)
						f:shru()
						f:call(pushstr)
						f:i32(16)
						f:call(setnthtmp)

						f:br(loopnoinc)
					end, tcase(':'), function()
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(51)
						end, function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(58) -- ':
							f:eq()
							f:iff(i32, function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(49)
							end, function()
								f:i32(51)
							end)
						end)
						f:br(token1)
					end, tcase(';'), function()
						f:i32(50)
						f:br(token1)
					end, tcase('<'), function() --@lt <
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(38)
						end, function(ltifelse)
							f:switch(function()
								f:load(i)
								f:load(src)
								f:add()
								f:i32load8u(str.base)
								f:i32(60) -- '<
								f:sub()
							end, 0, '<', function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(33) -- lsh
								f:br(ltifelse)
							end, 1, '=', function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(40) -- lte
								f:br(ltifelse)
							end, -1)
							f:i32(38)
						end)
						f:br(token1)
					end, tcase('='), function()
						f:i32(16)
						f:call(nthtmp)
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(42)
						end, function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(61) -- '=
							f:eq()
							f:iff(i32, function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(36)
							end, function()
								f:i32(42)
							end)
						end)
						f:call(pushstr)
						f:i32(16)
						f:call(setnthtmp)
						f:br(loopnoinc)
					end, tcase('>'), function()
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(39)
						end, function(gtifelse)
							f:switch(function()
								f:load(i)
								f:load(src)
								f:add()
								f:i32load8u(str.base)
								f:i32(61) -- '=
								f:sub()
							end, 0, '=', function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(41) -- gte
								f:br(gtifelse)
							end, 1, '>', function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(34) -- rsh
								f:br(gtifelse)
							end, -1)
							f:i32(39)
						end)
						f:br(token1)
					end, tcase('a'), tcase('b'), tcase('c'), tcase('d'), tcase('e'), tcase('f'), tcase('g'), tcase('h'), tcase('i'), tcase('j'), tcase('k'), tcase('l'), tcase('m'), tcase('n'), tcase('o'), tcase('p'), tcase('q'), tcase('r'), tcase('s'), tcase('t'), tcase('u'), tcase('v'), tcase('w'), tcase('x'), tcase('y'), tcase('z'),
					tcase('A'), tcase('B'), tcase('C'), tcase('D'), tcase('E'), tcase('F'), tcase('G'), tcase('H'), tcase('I'), tcase('J'), tcase('K'), tcase('L'), tcase('M'), tcase('N'), tcase('O'), tcase('P'), tcase('Q'), tcase('R'), tcase('S'), tcase('T'), tcase('U'), tcase('V'), tcase('W'), tcase('X'), tcase('Y'), tcase('Z'),
					tcase('_'), function()
						f:load(i)
						f:store(j)

						f:block(function(block)
							f:loop(function(loop) -- scan until not 0-9A-Z_a-z
								f:load(i)
								f:i32(1)
								f:add()
								f:tee(i)
								f:load(srclen)
								f:eq()
								f:brif(block)

								f:load(src)
								f:load(i)
								f:add()
								f:i32load8u(str.base)
								f:i32(48)
								f:sub()
								f:tee(ch)
								f:i32(10)
								f:ltu()
								f:brif(loop)

								f:load(ch)
								f:i32(17) -- 65-48 ('A - '0)
								f:sub()
								f:tee(ch)
								f:i32(26)
								f:ltu()
								f:brif(loop)

								f:load(ch)
								f:i32(30) -- 95-65-48 ('_ - 'A - '0)
								f:eq()
								f:brif(loop)

								f:load(ch)
								f:i32(32) -- 97-65-48 ('a - 'A - '0)
								f:sub()
								f:i32(26)
								f:ltu()
								f:brif(loop)
							end)
						end)

						f:load(i)
						f:load(j)
						f:sub()
						f:tee(ch)

						-- Check whether keyword
						-- TODO assert we won't read out of memory
						f:switch(function()
							f:load(ch)
						end, 8, function(scopes)
							f:load(j)
							f:load(src)
							f:add()
							f:i64load(str.base)
							f:i64(string.unpack("<i8", "function"))
							f:ne()
							f:brif(scopes[0])

							f:i32(9)
							f:br(token1)
						end, 6, function(scopes)
							f:load(j)
							f:load(src)
							f:add()
							f:i64load(str.base)
							f:i64(0xffffffffffff)
							f:band()

							f:tee(temp64)
							f:i64(string.unpack("<i6", "return"))
							f:eq()
							f:iff(i32, function()
								f:i32(18)
							end, function()
								f:load(temp64)
								f:i64(string.unpack("<i6", "elseif"))
								f:eq()
								f:iff(i32, function()
									f:i32(5)
								end, function()
									f:load(temp64)
									f:i64(string.unpack("<i6", "repeat"))
									f:ne()
									f:brif(scopes[0])

									f:i32(17)
								end)
							end)
							f:br(token1)
						end, 5, function(scopes)
							f:load(j)
							f:load(src)
							f:add()
							f:i64load(str.base)
							f:i64(0xffffffffff)
							f:band()

							f:tee(temp64)
							f:i64(string.unpack("<i5", "local"))
							f:eq()
							f:iff(i32, function()
								f:i32(13)
							end, function()
								f:load(temp64)
								f:i64(string.unpack("<i5", "while"))
								f:eq()
								f:iff(i32, function()
									f:i32(22)
								end, function()
									f:load(temp64)
									f:i64(string.unpack("<i5", "false"))
									f:eq()
									f:iff(i32, function()
										f:i32(7)
									end, function()
										f:load(temp64)
										f:i64(string.unpack("<i5", "break"))
										f:eq()
										f:iff(i32, function()
											f:i32(2)
										end, function()
											f:load(temp64)
											f:i64(string.unpack("<i5", "until"))
											f:ne()
											f:brif(scopes[0])

											f:i32(21)
										end)
									end)
								end)
							end)
							f:br(token1)
						end, 4, function(scopes)
							f:load(j)
							f:load(src)
							f:add()
							f:i32load(str.base)

							f:tee(k)
							f:i32(string.unpack("<i4", "then"))
							f:iff(i32, function()
								f:i32(19)
							end, function()
								f:load(k)
								f:i32(string.unpack("<i4", "else"))
								f:eq()
								f:iff(i32, function()
									f:i32(4)
								end, function()
									f:load(k)
									f:i32(string.unpack("<i4", "true"))
									f:eq()
									f:iff(i32, function()
										f:i32(20)
									end, function()
										f:load(k)
										f:i32(string.unpack("<i4", "goto"))
										f:ne()
										f:brif(scopes[0])

										f:i32(10)
									end)
								end)
							end)
							f:br(token1)
						end, 3, function(scopes)
							-- can't load/mask because bounds
							f:load(j)
							f:load(src)
							f:add()
							f:tee(k)
							f:i32load16u(str.base)
							f:load(k)
							f:i32load8u(str.base + 1)
							f:i32(16)
							f:shl()
							f:bor()

							f:tee(k)
							f:i32(string.unpack("<i3", "end"))
							f:iff(i32, function()
								f:i32(6)
							end, function()
								f:load(k)
								f:i32(string.unpack("<i3", "and"))
								f:eq()
								f:iff(i32, function()
									f:i32(1)
								end, function()
									f:load(k)
									f:i32(string.unpack("<i3", "for"))
									f:eq()
									f:iff(i32, function()
										f:i32(8)
									end, function()
										f:load(k)
										f:i32(string.unpack("<i3", "nil"))
										f:eq()
										f:iff(i32, function()
											f:i32(14)
										end, function()
											f:load(k)
											f:i32(string.unpack("<i3", "not"))
											f:ne()
											f:brif(scopes[0])

											f:i32(15)
										end)
									end)
								end)
							end)
							f:br(token1)
						end, 2, function(scopes)
							f:load(j)
							f:load(src)
							f:add()
							f:i32load16u(str.base)

							f:tee(k)
							f:i32(string.unpack("<i2", "if"))
							f:eq()
							f:iff(i32, function()
								f:i32(11)
							end, function()
								f:load(k)
								f:i32(string.unpack("<i2", "or"))
								f:eq()
								f:iff(i32, function()
									f:i32(16)
								end, function()
									f:load(k)
									f:i32(string.unpack("<i2", "do"))
									f:eq()
									f:iff(i32, function()
										f:i32(3)
									end, function()
										f:load(k)
										f:i32(string.unpack("<i2", "in"))
										f:ne()
										f:brif(scopes[0])

										f:i32(12)
									end)
								end)
							end)
							f:br(token1)
						end, 0, 1, 7)

						f:call(newstr)
						f:tee(src)
						f:i32(13)
						f:add()
						f:i32(20)
						f:call(nthtmp)
						f:load(j)
						f:add()
						f:i32(13)
						f:add()
						f:load(ch)
						f:call(memcpy1rl)

						f:load(src)
						lxaddstr(f)
						f:store(ch)

						f:i32(16)
						f:call(nthtmp)
						f:i32(64)
						f:call(pushstr)

						f:load(ch)
						f:call(pushstr)

						f:load(ch)
						f:i32(8)
						f:shru()
						f:call(pushstr)

						f:load(ch)
						f:i32(16)
						f:shru()
						f:call(pushstr)

						f:load(ch)
						f:i32(24)
						f:shru()
						f:call(pushstr)
						f:i32(16)
						f:call(setnthtmp)

						f:br(blloop)
					end, tcase('['), function()
						f:i32(16)
						f:call(nthtmp)

						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(47)
						end, function(lsvalif)
							-- TODO nested strings, omit opening character being newline
							f:i32(0)
							f:store(tlen)
							f:load(i)
							f:i32(1)
							f:sub()
							f:store(j)

							f:loop(i32, function(lscounteq)
								f:i32(47)
								f:load(j)
								f:i32(1)
								f:add()
								f:tee(j)
								f:load(srclen)
								f:eq()
								f:brif(lsvalif)
								f:drop()

								f:load(j)
								f:load(src)
								f:add()
								f:i32load8u(str.base)
								f:tee(ch)
								f:i32(61) -- '=
								f:eq()
								f:iff(i32, function()
									f:load(tlen)
									f:i32(1)
									f:add()
									f:store(tlen)
									f:br(lscounteq)
								end, function()
									f:i32(47)
									f:load(ch)
									f:i32(91) -- '[
									f:ne()
									f:brif(lsvalif)
									f:drop()

									f:loop(i32, function(lsseekeq)
										f:i32(47)
										f:load(j)
										f:i32(1)
										f:add()
										f:tee(j)
										f:load(srclen)
										f:eq()
										f:brif(lsvalif)
										f:drop()

										f:load(j)
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(93) -- ']
										f:ne()
										f:brif(lsseekeq)

										f:load(j)
										f:store(ch)
										f:block(function(block)
										f:loop(function(loop)
											f:load(j)
											f:load(ch)
											f:sub()
											f:load(tlen)
											f:eq()
											f:brif(block)

											f:i32(47)
											f:load(j)
											f:i32(1)
											f:add()
											f:tee(j)
											f:load(srclen)
											f:eq()
											f:brif(lsvalif)
											f:drop()

											f:load(j)
											f:load(src)
											f:add()
											f:i32load8u(str.base)
											f:i32(61)
											f:ne()
											f:brif(lsseekeq)
											f:br(loop)
										end)
										end)

										f:i32(47)
										f:load(j)
										f:i32(1)
										f:add()
										f:tee(j)
										f:load(srclen)
										f:eq()
										f:brif(lsvalif)
										f:drop()

										f:load(j)
										f:load(src)
										f:add()
										f:i32load8u(str.base)
										f:i32(93)
										f:ne()
										f:brif(lsseekeq)

										-- i, ch, tlen = j+1, i + 1 + tlen + 13, ch - i - tlen - 1
										f:load(ch)
										f:load(i)
										f:sub()
										f:load(tlen)
										f:sub()
										f:i32(1)
										f:sub()

										f:load(i)
										f:load(tlen)
										f:add()
										f:i32(14)
										f:add()

										f:load(j)
										f:i32(1)
										f:add()

										f:store(i)
										f:store(ch)
										f:tee(tlen)

										f:call(newstr)
										f:tee(src)
										f:i32(13)
										f:add()
										f:i32(20)
										f:call(nthtmp)
										f:load(ch)
										f:add()
										f:load(tlen)
										f:call(memcpy1rl)

										f:load(src)
										lxaddstr(f)
										f:store(ch)

										f:i32(16)
										f:call(nthtmp)
										f:i32(128)
										f:call(pushstr)

										f:load(ch)
										f:call(pushstr)

										f:load(ch)
										f:i32(8)
										f:shru()
										f:call(pushstr)

										f:load(ch)
										f:i32(16)
										f:shru()
										f:call(pushstr)

										f:load(ch)
										f:i32(24)
										f:shru()
										f:call(pushstr)
										f:i32(16)
										f:call(setnthtmp)

										f:load(j)
										f:i32(1)
										f:add()
										f:store(i)
										f:br(loopnoinc)
									end)
								end)
							end)
						end)
						f:call(pushstr)
						f:i32(16)
						f:call(setnthtmp)

						f:br(loopnoinc)
					end, tcase(']'), function()
						f:i32(48)
						f:br(token1)
					end, tcase('^'), function()
						f:i32(28)
						f:br(token1)
					end, tcase('{'), function()
						f:i32(45)
						f:br(token1)
					end, tcase('|'), function()
						f:i32(32)
						f:br(token1)
					end, tcase('}'), function()
						f:i32(46)
						f:br(token1)
					end, tcase('~'), function()
						f:load(i)
						f:i32(1)
						f:add()
						f:tee(i)
						f:load(srclen)
						f:eq()
						f:iff(i32, function()
							f:i32(51)
						end, function()
							f:load(i)
							f:load(src)
							f:add()
							f:i32load8u(str.base)
							f:i32(61) -- '=
							f:eq()
							f:iff(i32, function()
								f:load(i)
								f:i32(1)
								f:add()
								f:store(i)

								f:i32(31)
							end, function()
								f:i32(51)
							end)
						end)
						f:br(token1)
					end, tcase('!'), tcase('$'), tcase('?'), tcase('@'), tcase('`'), tcase('\\'), -1)
					f:unreachable()
				end) -- token1
				f:store(k)
				f:i32(16)
				f:call(nthtmp)
				f:load(k)
				f:call(pushstr)
				f:i32(16)
				f:call(setnthtmp)
				f:br(blloop)
			end)
			f:load(i)
			f:i32(1)
			f:add()
			f:store(i)
			f:br(loopnoinc)
		end)
	end)
	f:i32(16)
	f:call(nthtmp)
	f:i32(0)
	f:call(pushstr)
	f:call(unbufstr)
	f:i32(8)
	f:call(nthtmp)
	f:call(unbufvec)
	f:i32(4)
	f:call(nthtmp)
	f:call(unbufvec)
	f:call(tmppop)
	f:call(tmppop)
	f:i32(4)
	f:call(setnthtmp)
	f:i32(8)
	f:call(setnthtmp)
	f:i32(12)
	f:call(setnthtmp)
end))
