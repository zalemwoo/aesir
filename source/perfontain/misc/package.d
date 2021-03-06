module perfontain.misc;

import
		std.conv,
		std.math,
		std.range,
		std.traits,
		std.string,
		std.algorithm,
		std.experimental.allocator.gc_allocator,

		core.stdc.string,

		ciema,

		perfontain.opengl,
		perfontain.config,
		perfontain.math.matrix,

		tt.error,
		tt.logger : log;

public import
				tt.misc,
				tt.binary;


alias Op(string S) = (a, b) => mixin(`a` ~ S ~ `b`);

@property blendingModeGL(ubyte m)
{
	static immutable modes =
	[
		GL_ZERO,
		GL_ONE,
		GL_SRC_COLOR,
		GL_ONE_MINUS_SRC_COLOR,
		GL_SRC_ALPHA,
		GL_ONE_MINUS_SRC_ALPHA,
		GL_DST_ALPHA,
		GL_ONE_MINUS_DST_ALPHA,
		GL_DST_COLOR,
		GL_ONE_MINUS_DST_COLOR,
		GL_SRC_ALPHA_SATURATE,
	],
	modes2 =
	[
		GL_CONSTANT_COLOR,
		GL_ONE_MINUS_CONSTANT_ALPHA,
	];

	return m < 14 ? modes[m - 1] : modes2[m - 14]; // [1, 15]
}

auto packModes(ubyte src, ubyte dst)
{
	assert(src < 16 && dst < 16);
	return cast(ubyte)(dst << 4 | src);
}

auto unpackModes(ubyte mode)
{
	ubyte[2] res;
	res.front = mode & 0xF;
	res.back = mode >> 4;
	return res;
}

auto alignTo(T)(T v, ushort a)
{
	return cast(T)((v + a - 1) / a * a);
}

auto makeAligned(void[] b, ubyte a)
{
	auto k = cast(size_t)b.ptr;
	return b[alignTo(k, a) - k..$];
}

auto removeUnstable(T, A...)(ref T[] arr, A args)
{
	arr = arr.remove!(SwapStrategy.unstable)(args);
}

auto removeStable(T, A...)(ref T[] arr, A args)
{
	arr = arr.remove(args);
}

auto sliceOne(T)(ref T t)
{
	return (&t)[0..1];
}

void eachGroup(alias F, T)(T[] arr, void delegate(T[]) dg)
{
	for(auto start = arr.ptr, cur = start + 1; true; cur++)
	{
		bool end = cur > &arr.back;

		if(end || F(*start, *cur))
		{
			dg(start[0..cur - start]);

			if(end)
			{
				break;
			}

			start = cur;
		}
	}
}

/*auto as(T, E)(E *arr, size_t len)
{
	return (cast(T *)arr)[0..len];
}*/
auto constAway(T)(in T[] arr)
{
	return arr.as!T;
}

auto createArray(T, A...)(uint len, A args)
{
	static if(args.length)
	{
		return generate!(() => createArray!T(args)).take(len).array;
	}
	else
	{
		return new T[len];
	}
}

ubyte direction(Vector2 v, bool inv = false)
{
	auto k = cast(ubyte)((atan2(v.normalize.x, v.y) * TO_DEG - 22.5 + 360) / 45);

	return (inv ? cast(ubyte)(k + 5) : ~k) & 7;
}

auto makeIndices(uint cnt)
{
	return cnt
				.iota
				.map!(a => a * 3)
				.map!(a => triangleOrder[].map!(b => b + a))
				.join;
}

void cas(T)(ref T var, T old, T new_)
{
	if(var == old)
	{
		var = new_;
	}
}

bool set(T)(ref T var, T new_)
{
	if(var != new_)
	{
		var = new_;
		return true;
	}

	return false;
}

void setBit(T)(ref T var, T bit, bool b)
{
	if(b)	var |=	bit;
	else	var &=	~bit;
}

auto setFlag(string f, string b, uint bit)
{
	return format(`%1$s = %1$s ^ ((-typeof(%1$s)(%2$s) ^ %1$s) & %3$s);`, f, b, bit);
}

void byFlag(T)(ref T v, uint bit, bool st)
{
	v ^= (-int(st) ^ v) & bit;
}

@property
{
	auto toInts(ubyte N)(in float[N] arr)
	{
		int[N] res;

		foreach(i, ref v; res)
		{
			v = cast(int)lrint(arr[i] * 1000);
		}

		return res;
	}

	auto parseNum(string s) // TODO
	{
		return s.startsWith(`0x`) || s.startsWith(`0X`) ? s[2..$].to!uint(16) : s.to!uint;
	}

	/********************************************//**
	 * \brief Converts ubyte from 0-255 to float 0-1.
	 *
	 * \param b Unsigned byte.
	 * \return Float.
	 *
	 ***********************************************/
	float toFloat(ubyte b)
	{
		union U
		{
			uint i;
			float f;
		}

		U u;
		u.i = 0x47000000 | b;
		return u.f - 32768f;
	}

	//Color toCol(ref in Vector4 v) { with(v) return Color(cast(uint)x * 255, cast(uint)y * 255, cast(uint)z * 255, cast(uint)w * 255); }

	Vector4 toVec(Color c) { with(c) return Vector4(r.toFloat, g.toFloat, b.toFloat, a.toFloat); }

	uint systemTick()
	{
		import core.time : TickDuration;
		return cast(uint)TickDuration.currSystemTick.msecs;
	}

	auto swapBytes(T)(in T value)
	{
		T res = value;
		res.toByte.reverse();
		return res;
	}

	bool isPowerOf2(uint x) { return x && !(x & (x - 1)); }

	size_t ptrToInt(T)(T t) { return cast(size_t)cast(void *)t; }
}

mixin template readableToString()
{
	const toString()
	{
		string r;
		alias T = typeof(this);

        import std.string : format;
        import std.traits : FunctionTypeOf, Unqual;

		foreach(m; __traits(allMembers, T))
		{
			static if(mixin(`__traits(compiles, &this.` ~ m ~ `) && !is(FunctionTypeOf!(T.` ~ m ~ `) == function) && is(typeof(T.` ~ m ~ `.offsetof))`))
			{
				r ~= (r.length ? `, ` : ``) ~ format(`%s: %s`, m, mixin(`this.` ~ m));
			}
		}

		return Unqual!T.stringof ~ `(` ~ r ~ `)`;
	}
}

mixin template createCtorsDtors(A...)
{
    void ctors() { foreach(ref a; A) if(!a) a = new typeof(a); }
    void dtors() { foreach_reverse(a; A) a.destroy; }
}

mixin template publicProperty(T, string name, string value = null)
{
	mixin(`
		public ref ` ~ name ~ `() @property const { return _` ~ name ~ `; }
		T _` ~ name ~ (value.length ? `=` ~ value : null) ~ `;`
																);
}

mixin template makeHelpers(A...)
{
	static gen()
	{
		string res;

		foreach(i; IndexTuple!(A.length / 2))
		{
			auto n = A[i * 2], f = A[i * 2 + 1];

			res ~= `@property const ` ~ n ~ `() { return !!(_flags & ` ~ f ~ `); } @property ` ~ n ~ `(bool b) { mixin(setFlag("flags", "b", ` ~ f ~ `)); }`;
		}

		return res;
	}

	mixin(gen);
}

void changed(uint old, uint new_, uint bit, void delegate(bool) func)
{
	auto v = new_ & bit;
	if((old & bit) != v) func(!!v);
}

struct TimeMeter
{
	this(A...)(string msg, auto ref in A args)
	{
		static if(args.length) msg = format(msg, args);

		_msg = msg;
		_t = systemTick;
	}

	~this()
	{
		log(`%s : %u ms`, _msg, systemTick - _t);
	}

private:
	string _msg;
	uint _t;
}
