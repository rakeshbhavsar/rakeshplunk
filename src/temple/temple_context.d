/**
 * Temple (C) Dylan Knutson, 2013, distributed under the:
 * Boost Software License - Version 1.0 - August 17th, 2003
 *
 * Permission is hereby granted, free of charge, to any person or organization
 * obtaining a copy of the software and accompanying documentation covered by
 * this license (the "Software") to use, reproduce, display, distribute,
 * execute, and transmit the Software, and to prepare derivative works of the
 * Software, and to permit third-parties to whom the Software is furnished to
 * do so, all subject to the following:
 *
 * The copyright notices in the Software and this entire statement, including
 * the above license grant, this restriction and the following disclaimer,
 * must be included in all copies of the Software, in whole or in part, and
 * all derivative works of the Software, unless such copies or derivative
 * works are solely in the form of machine-executable object code generated by
 * a source language processor.
 */

module temple.temple_context;

import temple;
import temple.output_stream;

public import std.variant : Variant;
private import std.array, std.string, std.typetuple;

final class TempleContext
{
private:
	// context variables
	Variant[string] vars;


package:
	const(CompiledTemple)* partial;

	/// package
	// TODO: This needs to be marked as a "safe" string
	static Appender!string __templeRenderWith(in CompiledTemple temple, TempleContext ctx)
	body
	{
		// Allocate a buffer and call the render func with it
		auto buff = appender!string;
		temple.render(buff, ctx);
		return buff;
	}

	// sink for rendering templates to
	TempleOutputStream sink;

	// called by generated temple function
	void put(string s) {
		sink.put(s);
	}

public:
	string capture(T...)(void delegate(T) block, T args)
	{
		auto saved = this.sink;
		scope(exit) this.sink = saved;

		auto buffer = appender!string;
		this.sink = TempleOutputStream(buffer);

		// Call the block (which resides inside the template, and will
		// now write to `buffer`)
		block(args);

		return buffer.data;
	}

	bool isSet(string name)
	{
		return (name in vars && vars[name] != Variant());
	}

	ref Variant var(string name)
	{
		if(name !in vars)
			vars[name] = Variant();

		return vars[name];
	}

	void opIndexAssign(T)(string name, T val) {
		if(name !in vars)
			vars[name] = Variant();

		vars[name] = val;
	}

	VarDispatcher var()
	{
		return VarDispatcher(this);
	}

	Variant opDispatch(string op)() @property
	if(op != "__ctor") // seems a scoped!T bug requires this
	in {
		assert(op in vars, "variant does not have key: " ~ op);
	}
	body {
		return vars[op];
	}

	void opDispatch(string op, T)(T other) @property
	{
		vars[op] = other;
	}

	TempleInputStream yield() @property
	{
		auto noop = TempleInputStream(delegate(ref TempleOutputStream) {
			//debug debug_writeln("yielded input stream called (was a noop)");
		});

		if(partial !is null)
		{
			return TempleInputStream(delegate(ref TempleOutputStream os) {
				partial.render(os, this);
			});
		}

		return noop;
	}
}

private struct VarDispatcher
{
private:
	TempleContext context;

public:
	this(TempleContext context)
	{
		this.context = context;
	}

	ref Variant opDispatch(string op)() @property
	{
		return context.var(op);
	}

	void opDispatch(string op, T)(T other) @property
	{
		context.var(op) = other;
	}
}

unittest
{
	auto context = new TempleContext();
	context.foo = "bar";
	context.bar = 10;

	with(context)
	{
		assert(var.foo == "bar");
		assert(var.bar == 10);

		var.baz = true;
		assert(var.baz == true);
	}
}
