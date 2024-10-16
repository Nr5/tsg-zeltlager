const std = @import("std");
const zap = @import("zap");
const globals = @import("globals");
const fio = zap.fio;
const Mustache = zap.Mustache;
const allocator = std.heap.page_allocator;
const sql = @import("wrapsqlite.zig");
const data = @import("data.zig");
var global_strbuf: [0x40000000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&global_strbuf);
const fba_allocator = fba.allocator();

const SharedData = struct {
    mutex: std.Thread.Mutex,
    value: u32,

    pub fn inc(self: *SharedData) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
        return self.value;
    }
};
var shared_data: SharedData = undefined;

fn on_add_request(r: zap.Request) void {
    std.debug.print("add_request\n", .{});
    r.parseQuery();
    if (r.getParamSlice("vorname")) |x1| if (r.getParamSlice("nachname")) |x2| {
        if (x1.len > 64 or x2.len > 64 or x1.len == 0 or x2.len == 0) {
            return;
        }
        //        _ = shared_counter.?.fetchAdd(1,std.builtin.AtomicOrder.acq_rel);
        _ = shared_data.inc();
        const stmt_teilnehmer = blk: {
            var stmt: ?*sql.c.sqlite3_stmt = undefined;
            const query = "INSERT INTO teilnehmer (name, vorname, Zelte_id) values (?1, ?2, 1)";

            if (sql.c.SQLITE_OK != sql.c.sqlite3_prepare_v2(sql.db, query, query.len + 1, &stmt, null)) {
                std.debug.print("1 Can't create prepare statement: {s}\n", .{sql.c.sqlite3_errmsg(sql.db)});
                r.sendBody("SQL Error") catch {
                    std.debug.print("sendbody failed\n", .{});
                    return;
                };
            }
            break :blk stmt.?;
        };
        defer _ = sql.c.sqlite3_finalize(stmt_teilnehmer);
        if (sql.c.SQLITE_OK != sql.c.sqlite3_bind_text(stmt_teilnehmer, 1, @ptrCast(x2), @intCast(x2.len), sql.c.SQLITE_STATIC)) {
            std.debug.print("Can't bind text: {s}\n", .{sql.c.sqlite3_errmsg(sql.db)});
            return;
        }

        if (sql.c.SQLITE_OK != sql.c.sqlite3_bind_text(stmt_teilnehmer, 2, @ptrCast(x1), @intCast(x1.len), sql.c.SQLITE_STATIC)) {
            std.debug.print("Can't bind text: {s}\n", .{sql.c.sqlite3_errmsg(sql.db)});
            return;
        }

        if (sql.c.SQLITE_DONE != sql.c.sqlite3_step(stmt_teilnehmer)) {
            std.debug.print("Can't step stmt: {s}\n", .{sql.c.sqlite3_errmsg(sql.db)});
            return;
        }

        _ = sql.c.sqlite3_reset(stmt_teilnehmer);

        var buf: ["<tr class=\"teilnehmer\"><td></td><td></td><td></td><td></td></tr>".len + 6 + 6 + 64 + 64]u8 = undefined;
        std.debug.print("{s} {s}\n", .{ x1, x2 });
        const slice = std.fmt.bufPrint(&buf, "<tr class=\"teilnehmer\"><td>{}</td><td>{s}</td><td>{s}</td><td>{}</td></tr>", .{ sql.c.sqlite3_last_insert_rowid(sql.db), x1, x2, 1 }) catch return;
        std.debug.print("{s}\n", .{slice});

        r.sendBody(slice) catch std.debug.print("error sendbody in 'on_add_request' ", .{});
    };
}

fn on_zeltchange_request(r: zap.Request) void {
    std.debug.print("zeltchange\n", .{});
    r.parseQuery();
    if (r.getParamSlice("tid")) |teilnehmer| if (r.getParamSlice("from")) |from| if (r.getParamSlice("to")) |to| {
        std.debug.print("zeltchange t{s}: z{s} -> z{s}\n", .{ teilnehmer, from, to });

        var query_buf: ["UPDATE teilnehmer SET Zelte_id = ..... where id = ..... ;".len]u8 = undefined;
        const query = std.fmt.bufPrintZ(&query_buf, "UPDATE teilnehmer SET Zelte_id = {s} where id = {s} ;", .{ to, teilnehmer }) catch {
            r.sendBody("sql error") catch return;
            return;
        };
        sql.execute(@constCast(query)) catch {
            std.debug.print("sql error", .{});
            r.sendBody("sql error") catch return;
            return;
        };
        _ = shared_data.inc();
        r.sendBody("OK") catch return;
    };
}

fn on_request_minimal(r: zap.Request) void {
    std.debug.print("on_request_minimal\n", .{});
    if (r.path) |p| {
        std.debug.print("path: {s}\n",.{p});
        if (std.mem.eql(u8, p, "/zap/add")) {
            if (r.query) |_| {
                on_add_request(r);
            }
            return;
        } else if (std.mem.eql(u8, p, "/zap/change_zelt")) {
            if (r.query) |_| {
                on_zeltchange_request(r);
            }
            return;
        } else if (std.mem.eql(u8, p, "/zap/change_counter")) {
            var buf: [10]u8 = undefined;
            //            const value = shared_counter.?.load(std.builtin.AtomicOrder.unordered);
            const slice = std.fmt.bufPrint(&buf, "{}", .{shared_data.value}) catch return;
            r.sendBody(slice) catch return;
            return;
        } else if (std.mem.eql(u8, p, "/zap/update")) {
            if (r.query) |_| {
               r.parseQuery(); 
               if (r.getParamSlice("version")) |v| {
                    std.debug.print("{s}\n", .{v});
                    var buf: [10]u8 = undefined;
                    //            const value = shared_counter.?.load(std.builtin.AtomicOrder.unordered);
                    const slice = std.fmt.bufPrint(&buf, "{}", .{shared_data.value}) catch {std.debug.print("bufPrinterr\n",.{});return;};
                    r.sendBody(slice) catch {std.debug.print("sendbodyerr\n",.{});return;};
                    return;
               }
            }
            
        }
        std.debug.print("{s}\n", .{p});
    }
    const template_buf: []u8 = allocator.alloc(u8, 0x10000) catch {
        std.debug.print("alloc failed ", .{});
        return;
    };
    const template = std.fs.cwd().readFile("template.html", template_buf) catch {
        std.debug.print("readfile failed ", .{});
        return;
    };

    var mustache = Mustache.fromData(template) catch {
        std.debug.print("mustache error", .{});
        return;
    };
    defer mustache.deinit();

    const Teilnehmer = struct {
        id: u8,
        name: []const u8,
        vorname: []const u8,
        zelt_id: u8,
    };
    const Zelt = struct {
        id: u8,
        plaetze: u8,
        zteilnehmer: []const Teilnehmer,
    };

    var teilnehmer: [0x10000]Teilnehmer = undefined;
    var zelte: [0x1000]Zelt = undefined;

    const maybe_stmt_teilnehmer = sql.prepare_stmt("SELECT id, name, vorname, Zelte_id FROM Teilnehmer order by Zelte_id");
    const maybe_stmt_zelte = sql.prepare_stmt("SELECT id, plaetze FROM Zelte order by id");
    const maybe_stmt_allergene = sql.prepare_stmt("SELECT id, name FROM Allergene ORDER BY id");

    defer _ = sql.c.sqlite3_finalize(maybe_stmt_teilnehmer);
    defer _ = sql.c.sqlite3_finalize(maybe_stmt_zelte);
    defer _ = sql.c.sqlite3_finalize(maybe_stmt_allergene);

    var zelt_i: u16 = 0;
    if (maybe_stmt_zelte) |stmt_zelte| {
        const zelt_iter = sql.DB_Iterator.init(struct { id: u8, plaetze: u4 }, fba_allocator);
        while (zelt_iter.next(stmt_zelte)) |z| {
            zelte[zelt_i] = .{
                .id = z.id,
                .plaetze = z.plaetze,
                .zteilnehmer = teilnehmer[0..2],
            };

            zelt_i = zelt_i + 1;
        }
    }

    var i: u16 = 0;
    if (maybe_stmt_teilnehmer) |stmt_teilnehmer| {
        const iter = sql.DB_Iterator.init(Teilnehmer, fba_allocator);
        var zelt_id: u16 = 1;
        var start_of_this_zelt: u16 = 0;
        while (iter.next(stmt_teilnehmer)) |t| {
            teilnehmer[i] = t;
            std.debug.print("{},{s},{s},{}\n", t);
            if (t.zelt_id != zelt_id) {
                zelte[zelt_id - 1].zteilnehmer = teilnehmer[start_of_this_zelt..i];
                zelt_id = t.zelt_id;
                start_of_this_zelt = i;
            }
            i = i + 1;
        }
    }

    if (maybe_stmt_allergene) |stmt_allergene| {
        const allergen_iter = sql.DB_Iterator.init(struct { id: u8, name: []const u8 }, fba_allocator);
        while (allergen_iter.next(stmt_allergene)) |allergen| {
            std.debug.print("{c}: {s}\n", allergen);
        }
    }

    const ret = mustache.build(.{ .version=shared_data.value, .teilnehmer = teilnehmer[0..i], .zelte = zelte[0..zelt_i] });

    if (ret.str()) |mustache_string| {
        //        std.debug.print("{s}\n", .{ mustache_string} );
        r.sendBody(mustache_string) catch {
            std.debug.print("sendbody failed\n", .{});
            return;
        };
    }
}

pub fn main() !void {
    shared_data = SharedData{ .mutex = std.Thread.Mutex{}, .value = 0 };
    sql.openDB("beepdoop_zeltlager");
    sql.initDB(data.db_structure);
    defer sql.closeDB();
    
    sql.fillTable("Zelte", data.zelte);
    sql.fillTable("Allergene", data.allergene);
    sql.fillTable("Teilnehmer", data.teilnehmer);
    sql.fillTable("Teilnehmer_Allergene", data.teilnehmer_allergene);

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request_minimal,
        .log = false,
        .max_clients = 100000,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    zap.start(.{
        .threads = 4,
        .workers = 1, 
    });
}
test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
