local lex = require 'lex'
local ast = require 'ast'
local bc = require 'bc'

local function nop()
end

local asmmeta = {}
local asmmt = { __index = asmeta }
local function Assembler(lx, uplink)
	return setmetatable({
		lx = lx,
		pcount = 0,
		isdotdotdot = false,
		uplink = uplink,
		scopes = nil,
		names = {},
		idxfree = {},
		bc = {},
	}, asmmt)
end

function asmmeta:push(op, ...)
	self.bc[#self.bc+1] = op
	for i=1,select('#', ...) do
		self.bc[#self.bc+1],self.bc[#self.bc+2],self.bc[#self.bc+3],self.bc[#self.bc+4] = string.pack('<i4', select(i, ...))
	end
end
function asmmeta:scope(f)
	self.scopes = { prev = self.scopes }
	f(self)
	for i=1, #self.scopes do
		local name = self.scopes[i]
		self.names[name] = self.names[name].prev
	end
	self.scopes = self.scopes.prev
end

function asmmeta:name(n, idx)
	local prevscope = self.names[n]
	local newscope = { prev = prevscope, idx = idx, func = self }
	self.scopes[#self.scopes+1] = n
	self.names[n] = newscope
end

function asmmeta:usename(n)
	local name = self.names[n]
	if name then
		if name.func ~= self then
			self.idxfree[name.idx] = true
		end
	else
		return asmmeta:usename(1) -- _ENV
	end
end

local function nextNodeFactory(ty)
	return function(node, i)
		while i > 0 do
			local child = node.fathered[i]
			i = i - 1
			if (child.type & 31) == ty then
				return i, child
			end
		end
	end
end
local nextNode = {}
for k,v in pairs(ast) do
	nextNode[v] = nextNode(v)
end

local function nextMask(ty)
	return function(node, i)
		while i > 0 do
			local child = node.fathered[i]
			i = i - 1
			if child.type == -1 and child:val() == ty then
				return i, child
			end
		end
	end
end
local nextString = nextMask(lex._string)
local nextNumber = nextMask(lex._number)
local nextIdent = nextMask(lex._ident)

local function selectNodes(node, ty)
	return nextNode[ty], node, #node.fathered
end
local function selectNode(node, ty)
	return nextNode[ty](node, #node.fathered)
end

local function selectIdents(node)
	return nextIdent, node, #node.fathered
end
local function selectIdent(node)
	return nextIdent(node, #node.fathered)
end

local scopeStatSwitch, emitStatSwitch, emitValueSwitch, visitScope, emitScope

local function singleNode(self, node, ty, visit)
	local sn = selectNode(node, ty)
	if sn then
		return visit[ty](self, sn)
	end
end
local function multiNodes(self, node, ty, visit)
	local fn = visit[ty]
	for i, node in selectNodes(node, ty) do
		fn(self, node)
	end
end
local function scopeNode(self, node, ty)
	return singleNode(self, node, ty, visitScope)
end
local function emitNode(self, node, ty)
	return singleNode(self, node, ty, visitEmit)
end
local function scopeNode(self, node, ty)
	return multiNodes(self, node, ty, visitScope)
end
local function emitNode(self, node, ty)
	return multiNodes(self, node, ty, visitEmit)
end

scopeStatSwitch = {
	nop, -- 1 ;
	function(self, node) -- 2 vars=exps
		scopeNodes(self, node, ast.ExpOr)
		scopeNodes(self, node, ast.Var)
	end,
	function(self, node) -- 3 call
		scopeNode(self, node, ast.Functioncall)
	end,
	nop, -- 4 label
	nop, -- 5 break
	nop, -- 6 goto
	function(self, node) -- 7 do-end
		self:scope(function()
			scopeNode(self, node, ast.Block)
		end)
	end,
	function(self, node) -- 8 while
		self:scope(function()
			scopeNode(self, node, ast.ExpOr)
			scopeNode(self, node, ast.Block)
		end)
	end,
	function(self, node) -- 9 repeat
		self:scope(function()
			scopeNode(self, node, ast.Block)
			scopeNode(self, node, ast.ExpOr)
		end)
	end,
	function(self, node) -- 10 if
		scopeNodes(self, node, ast.ExpOr)
		for i, block in selectNodes(node, ast.Block) do
			self:scope(function()
				visitScope[ty](self, block)
			end)
		end
	end,
	function(self, node) -- 11 for
		scopeNodes(self, node, ast.ExpOr)
		local name = selectIdent(node)
		self:name(name:int(), name.li)
		scopeNode(self, node, ast.Block)
	end,
	function(self, node) -- 12 generic for
		scopeNodes(self, node, ast.ExpOr)
		for i, name in selectIdents(node) do
			self:name(name:int(), name.li)
		end
		scopeNode(self, node, ast.Block)
	end,
	function(self, node) -- 13 func
		local clasm = Assembler(self.lx, self)
		local fruit = selectNode(node, ast.Funcbody)
		self:usename(selectIdent(node):int())
		visitScope[ast.Funcbody](clasm, fruit)
		visitEmit[ast.Funcbody](clasm, fruit)
	end,
	function(self, node) -- 14 self:func
		local clasm = Assembler(self.lx, self)
		local fruit = selectNode(node, ast.Funcbody)
		self:usename(selectIdent(node):int())
		clasm:name(2, -2)
		visitScope[ast.Funcbody](clasm, fruit)
		visitEmit[ast.Funcbody](clasm, fruit)
	end,
	function(self, node) -- 15 local func
		local clasm = Assembler(self.lx, self)
		local fruit = selectNode(node, ast.Funcbody)
		local name = selectIdent(node)
		self:name(name:int(), name.li)
		visitScope[ast.Funcbody](clasm, fruit)
		visitEmit[ast.Funcbody](clasm, fruit)
	end,
	function(self, node) -- 16 locals=exps
		scopeNodes(self, node, ast.ExpOr)
		for i, name in selectIdents(node) do
			self:name(name:int(), name.li)
		end
	end,
}
emitStatSwitch = {
	nop, -- 1 ;
	function(self, node) -- 2 vars=exps
	end,
	function(self, node) -- 3 call
	end,
	function(self, node) -- 4 label
	end,
	function(self, node) -- 5 break
	end,
	function(self, node) -- 6 goto
	end,
	function(self, node) -- 7 do-end
	end,
	function(self, node) -- 8 while
	end,
	function(self, node) -- 9 repeat
	end,
	function(self, node) -- 10 if
	end,
	function(self, node) -- 11 for
	end,
	function(self, node) -- 12 generic for
	end,
	function(self, node) -- 13 func
	end,
	function(self, node) -- 14 self:func
	end,
	function(self, node) -- 15 local func
	end,
	function(self, node) -- 16 locals=exps
	end,
}
emitValueSwitch = {
	function(self, node) -- 1 nil
		self:push(bc.Loadnil)
	end,
	function(self, node) -- 2 false
		self:push(bc.Loadfalse)
	end,
	function(self, node) -- 3 true
		self:push(bc.Loadtrue)
	end,
	function(self, node) -- 3 num
	end,
	function(self, node) -- 4 str
	end,
	function(self, node) -- 5 ...
	end,
	function(self, node) -- 6 Funcbody
	end,
	function(self, node) -- 7 Table
	end,
	function(self, node) -- 8 Call
	end,
	function(self, node) -- 9 Var load
	end,
	function(self, node) -- 10 Exp
	end,
}
visitScope = {
	[ast.Block] = function(self, node)
		scopeNodes(self, node, ast.Stat)
		scopeNode(self, node, ast.Retstat)
	end,
	[ast.Stat] = function(self, node)
		return scopeStatSwitch[node.type >> 5](self, node)
	end,
	[ast.Retstat] = function(self, node)
		scopeNodes(self, node, ast.ExpOr)
	end,
	[ast.Label] = function(self, node)
		-- TODO how do we even
	end,
	[ast.Var] = function(self, node)
		if node.types >> 5 == 0 then
			self:usename(selectIdent(node):int())
		else
			scopeNode(self, node, ast.Prefix)
			scopeNode(self, node, ast.Index)
		end
	end,
	[ast.Exp] = function(self, node)
		if #node.fathered == 1 then
			assert(self.fathered[1].type == ast.Value)
			return visitScope[ast.Value](self.fathered[1], node)
		elseif node.type >> 5 == 0 then
			return scopeNodes(self, node, ast.Exp)
		else
			for i = #node.fathered, 1, -1 do
				local n = node.fathered[i]
				local nt = n.type & 31
				if nt == ast.Exp then
					visitScope[ast.Exp](self, node)
				elseif nt == ast.Value then
					visitScope[ast.Value](self, node)
				end
			end
		end
	end,
	[ast.Prefix] = function(self, node)
		if node.type >> 5 == 0 then
			self:usename(selectIdent(node):int())
		else
			scopeNode(self, node, ast.ExpOr)
		end
	end,
	[ast.Args] = function(self, node)
		local t = node.type >> 5
		if t == 0 then
			scopeNodes(self, node, ast.ExpOr)
		elseif t == 1 then
			scopeNode(self, node, ast.Tableconstructor)
		end
	end,
	[ast.Funcbody] = function(self, node)
		-- TODO ahhh
	end,
	[ast.Tableconstructor] = function(self, node)
		scopeNodes(self, node, ast.Field)
	end,
	[ast.Field] = function(self, node)
		scopeNodes(self, node, ast.ExpOr)
	end,
	[ast.Binop] = nop,
	[ast.Unop] = nop,
	[ast.Value] = function(self, node)
		local t = node.type >> 5
		-- TODO if t == 5 then assert(self.isdotdotdot)
		if t == 7 then
			scopeNode(self, node, ast.Funcbody)
		elseif t == 8 then
			scopeNode(self, node, ast.Tableconstructor)
		elseif t == 9 then
			scopeNode(self, node, ast.Prefix)
			scopeNode(self, node, ast.Args)
		elseif t == 10 then
			scopeNode(self, node, ast.Var)
		elseif t == 11 then
			scopeNode(self, node, ast.ExpOr)
		end
	end,
	[ast.Index] = function(self, node)
		if node.type >> 5 == 0 then
			scopeNode(self, node, ast.ExpOr)
		end
	end,
	[ast.Suffix] = function(self, node)
		if node.type >> 5 == 0 then
			scopeNode(self, node, ast.Args)
		else
			scopeNode(self, node, ast.Index)
		end
	end,
	[ast.ExpOr] = function(self, node)
		return scopeNodes(self, node, ast.ExpAnd)
	end,
	[ast.ExpAnd] = function(self, node)
		return scopeNodes(self, node, ast.Exp)
	end,
}
visitEmit = {
	[ast.Block] = function(self, node)
		emitNodes(self, node, ast.Stat)
		emitNode(self, node, ast.Retstat)
	end,
	[ast.Stat] = function(self, node)
		return emitStatSwitch[node.type >> 5](self, node)
	end,
	[ast.Retstat] = function(self, node)
	end,
	[ast.Label] = function(self, node)
	end,
	[ast.Var] = function(self, node)
	end,
	[ast.Exp] = function(self, node)
	end,
	[ast.Prefix] = function(self, node)
	end,
	[ast.Args] = function(self, node)
	end,
	[ast.Funcbody] = function(self, node)
	end,
	[ast.Tableconstructor] = function(self, node)
	end,
	[ast.Field] = function(self, node)
	end,
	[ast.Binop] = function(self, node)
	end,
	[ast.Unop] = function(self, node)
	end,
	[ast.Value] = function(self, node)
		return emitValueSwitch[self.type >> 5](self, node)
	end,
	[ast.Index] = function(self, node)
	end,
	[ast.Suffix] = function(self, node)
	end,
	[ast.ExpOr] = function(self, node)
	end,
	[ast.ExpAnd] = function(self, node)
	end,
}

function asmmeta:synth()
end

return function(lx, root)
	local asm = Assembler(lx, nil)
	asm.pcount = 1
	asm.isdotdotdot = true
	asm:scope(function()
		asm:name(1, -1) -- _ENV
		visitScope[ast.Block](asm, root)
	end)
	visitEmit[ast.Block](asm, root)
	asm:push(bc.Return, 0, 0)
	return asm.synth()
end