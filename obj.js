const metas = new WeakMap(),
	Table = require("./table");


const stringMetatable = new Table();
stringMetatable.set("__index", require("./string"));

exports.metaget = metaget;
function metaget(x, prop) {
	let t = getmetatable(x);
	return t && (t.get(prop) || null);
}

function getmetatable(x) {
	return typeof x == "string" ? stringMetatable : metas.get(x) || null;
}
exports.getmetatable = getmetatable;

exports.setmetatable = (x, y) => {
	if (x && typeof x === "object" && typeof y === "object") {
		metas.set(x, y);
		return x;
	}
}

exports.index = function index(x, key) {
	let v = x instanceof Table ? x.get(key) : null;
	if (v === null) {
		let __index = metaget(x, "__index");
		if (__index) return index(__index, key);
	}
	return v;
}

exports.len = function len(x) {
	if (typeof x == "string") {
		return x.length;
	} else if (x instanceof Table) {
		let __len = metaget(x, "__len");
		return __len(x);
	} else throw "# expected string or table";
}

exports.numcoerce = x => {
	return typeof x == "number" || (x=+x, x === x) ? x : null;
}

exports.add = (x, y) => {
	if (typeof x == "number" && typeof y == "number") {
		return x + y;
	} else {
		let x__add = metaget(x, "__add");
		if (x__add !== null) {
			yield*x__add(x, y);
		}
		let y__add = metaget(y, "__add");
		if (y__add !== null) {
			yield*y__add(x, y);
		}
		throw "+: Incompatible types";
	}
}

exports.sub = (x, y) => {
}