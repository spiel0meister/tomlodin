package toml

import "core:c"
import "core:c/libc"

when ODIN_OS == .Windows {
	foreign import lib "toml.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "toml.o"
} else {
	#panic("HELP!")
}

Table :: distinct rawptr
Array :: distinct rawptr

Timestamp :: struct {
	__buffer:                       struct {
		/* internal. do not use. */
		year, month, day:               int,
		hour, minute, second, millisec: int,
		z:                              [10]u8,
	},
	year, month, day:               ^int,
	hour, minute, second, millisec: ^int,
	z:                              cstring,
}

Datum :: struct {
	ok: bool,
	u:  struct #raw_union {
		ts: ^Timestamp,
		s:  cstring,
		b:  bool,
		i:  i64,
		d:  f64,
	},
}

XX_Malloc :: #type proc(_: c.long) -> rawptr
XX_Free :: #type proc(_: rawptr)

foreign lib {
	@(link_name = "toml_parse")
	parse :: proc(conf: cstring, errbuf: ^u8, errbuf_size: int) -> Table ---
	@(link_name = "toml_parse_file")
	parse_file :: proc(fp: ^libc.FILE, errbuf: ^u8, errbuf_size: int) -> Table ---
	@(link_name = "toml_free")
	free :: proc(tabl: Table) ---

	@(link_name = "toml_array_nelem")
	array_nelem :: proc(arr: Array) -> int ---

	@(link_name = "toml_string_at")
	string_at :: proc(arr: Array, idx: int) -> Datum ---
	@(link_name = "toml_bool_at")
	bool_at :: proc(arr: Array, idx: int) -> Datum ---
	@(link_name = "toml_int_at")
	int_at :: proc(arr: Array, idx: int) -> Datum ---
	@(link_name = "toml_double_at")
	double_at :: proc(arr: Array, idx: int) -> Datum ---
	@(link_name = "toml_timestamp_at")
	timestamp_at :: proc(arr: Array, idx: int) -> Datum ---
	@(link_name = "toml_array_at")
	array_at :: proc(arr: Array, idx: int) -> Array ---
	@(link_name = "toml_table_at")
	table_at :: proc(arr: Array, idx: int) -> Table ---

	@(link_name = "toml_key_in")
	key_in :: proc(tabl: Table, idx: int) -> cstring ---
	@(link_name = "toml_exists_in")
	key_exists :: proc(tabl: Table, key: cstring) -> bool ---

	@(link_name = "toml_string_in")
	string_in :: proc(tabl: Table, key: cstring) -> Datum ---
	@(link_name = "toml_bool_in")
	bool_in :: proc(tabl: Table, key: cstring) -> Datum ---
	@(link_name = "toml_int_in")
	int_in :: proc(tabl: Table, key: cstring) -> Datum ---
	@(link_name = "toml_double_in")
	double_in :: proc(tabl: Table, key: cstring) -> Datum ---
	@(link_name = "toml_timestamp_in")
	timestamp_in :: proc(tabl: Table, key: cstring) -> Datum ---
	@(link_name = "toml_array_in")
	array_in :: proc(tabl: Table, key: cstring) -> Array ---
	@(link_name = "toml_table_in")
	table_in :: proc(tabl: Table, key: cstring) -> Table ---

	@(link_name = "toml_array_kind")
	array_kind :: proc(arr: Array) -> u8 ---
	@(link_name = "toml_array_type")
	array_type :: proc(arr: Array) -> u8 ---
	@(link_name = "toml_array_nkval")
	array_nkval :: proc(tabl: Table) -> int ---
	@(link_name = "toml_table_narr")
	table_narr :: proc(tabl: Table) -> int ---
	@(link_name = "toml_table_ntab")
	table_ntab :: proc(tabl: Table) -> int ---
	@(link_name = "toml_table_key")
	table_key :: proc(tabl: Table) -> cstring ---

	@(link_name = "toml_utf8_to_ucs")
	utf8_to_ucs :: proc(orig: ^u8, len: int, ret: ^i64) -> bool ---
	@(link_name = "toml_ucs_to_utf8")
	ucs_to_utf8 :: proc(code: i64, buf: [6]u8) -> bool ---
	@(link_name = "toml_set_memutil")
	set_memutil :: proc(xxmalloc: XX_Malloc, xxfree: XX_Free) ---

	// NOTE: Stuff under 'deprecated' have no bindings
}

// Testing

import "core:fmt"
import "core:testing"

@(test)
parse_test :: proc(t: ^testing.T) {
	CONF :: "[server]\nhost = \"127.0.0.1\"\nport = 6969\n"

	errbuf := make([]u8, 256)
	defer delete(errbuf)

	tbl := parse(CONF, &errbuf[0], len(errbuf))
	defer free(tbl)
	testing.expect(t, tbl != nil, "Parse failed")

	server := table_in(tbl, "server")
	testing.expect(t, server != nil, "Server section not found")

	host := string_in(server, "host")
	testing.expect(t, host.ok, "Host not found or is not a string")
	if host.ok do testing.expect(t, host.u.s == "127.0.0.1", "Host must be \"127.0.0.1\"")

	port := int_in(server, "port")
	testing.expect(t, port.ok, "Port not found or is not an integer")
	if port.ok do testing.expect(t, port.u.i == 6969, "Port must be 6969")
}

@(test)
parse_file_test :: proc(t: ^testing.T) {
	errbuf := make([]u8, 256)
	defer delete(errbuf)

	fp := libc.fopen("config.toml", "r")
	assert(fp != nil)
	defer libc.fclose(fp)

	tbl := parse_file(fp, &errbuf[0], len(errbuf))
	defer free(tbl)
	testing.expect(t, tbl != nil, "Parse failed")

	server := table_in(tbl, "server")
	testing.expect(t, server != nil, "Server section not found")

	host := string_in(server, "host")
	testing.expect(t, host.ok, "Host not found or is not a string")
	if host.ok do testing.expect(t, host.u.s == "127.0.0.1", "Host must be \"127.0.0.1\"")

	port := int_in(server, "port")
	testing.expect(t, port.ok, "Port not found or is not an integer")
	if port.ok do testing.expect(t, port.u.i == 6969, "Port must be 6969")
}
