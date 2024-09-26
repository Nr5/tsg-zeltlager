const std = @import("std");
const zap = @import("zap");
const globals = @import("globals");
const fio = zap.fio;
const Mustache = zap.Mustache;
const allocator = std.heap.page_allocator;

var global_strbuf     : [0x400000]u8     =undefined;
var fba = std.heap.FixedBufferAllocator.init(&global_strbuf);
const fba_allocator = fba.allocator();

const c = @cImport({
    @cInclude("sqlite3.h");
});
const SharedData = struct {
    mutex: std.Thread.Mutex,
    value: u32,

    pub fn inc(self: *SharedData) u32{
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
        return self.value;
    }
};
var shared_data: SharedData = undefined;


const DB_Iterator = struct {
    T: type,
    stmt: *c.sqlite3_stmt,
    allocator: std.mem.Allocator,
    fn next(self: DB_Iterator, stmt: *c.sqlite3_stmt) ?self.T{
        _ = self.stmt;
        const rc = c.sqlite3_step(stmt);
        var value: self.T =undefined;
        if  (rc == c.SQLITE_ROW) {
            
            inline for (std.meta.fields(self.T),0..) |field,i|{
                switch (field.type){
                []u8 => {
                    @field(value,field.name)= @constCast(std.mem.span(c.sqlite3_column_text(stmt, i)));
                },
                []const u8 => {
                    const bla =  std.mem.span(c.sqlite3_column_text(stmt, i));
                    const memory = allocator.alloc(u8,bla.len) catch return null; 
                    
                    @memcpy(memory,bla);
                    @field(value,field.name)= memory;
                },
                u64, i64, u32, i32, u24, i24, u16, i16, u8, i8, u4, i4, u2, i2, u1, i1 => {
                    @field(value,field.name)= @intCast(c.sqlite3_column_int(stmt, i));
                },
                else => {},
                }
            }
            return value;
        }
        else return null;
    }

    fn init(t: type,a: std.mem.Allocator) DB_Iterator{
        return .{.T=t, .stmt=undefined, .allocator=a};
    }
};
const DB = struct {
    db: *c.sqlite3,

    fn init(initdb: *c.sqlite3) DB {
        return .{ .db = initdb };
    }

    fn deinit(self: DB) void {
        _ = c.sqlite3_close(self.db);
    }

    fn execute(self: DB, query: [:0]const u8) !void {
        var errmsg: [*c]u8 = undefined;
        if (c.SQLITE_OK != c.sqlite3_exec(self.db, query, null, null, &errmsg)) {
            defer c.sqlite3_free(errmsg);
            std.debug.print("Exec query failed: {s}\n", .{errmsg});
            return error.execError;
        }
        return;
    }

    fn insertTable(self: DB) !void {
        const stmt = blk: {
            var stmt: ?*c.sqlite3_stmt = undefined;
            const query = "INSERT INTO teilnehmer (name, vorname, zelt_id) values (?1, ?2, ?3)";
            if (c.SQLITE_OK != c.sqlite3_prepare_v2(self.db, query, query.len + 1, &stmt, null)) {
                std.debug.print("Can't create prepare statement: {s}\n", .{c.sqlite3_errmsg(self.db)});
                return error.prepareStmt;
            }
            break :blk stmt.?;
        };
        defer _ = c.sqlite3_finalize(stmt);

        const teilnehmer = 
                \\Tigger,Sammy,1
                \\beep,beep,e
                \\Bam,Theodore,1
                \\cropp,friedrich,2
                \\floep,balthasar,3
                \\blerp,goodman,1
                \\shoop,heep,4
                \\Bammy,Ludwig,1
                \\coco,Stue,2
                \\cocojo,Lue,3
                \\Tiggeiir,Sammy,1
                \\beeoqqp,beep,e
                \\Baojlmm,Theodore,1
                \\croooqwppp,friedrich,2
                \\floowejep,balthasar,3
                \\bleroowpp,goodman,1
                \\shooowwp,heep,4
                \\Bamowimy,Ludwig,1
                \\cochioo,Stuooe,2
                \\cocoamelo,Lwoue,3
                \\oqwppp,friedrich,2
                \\floiijep,balthasar,3
                \\bleroowpp,goodman,1
                \\swwp,heep,4
                \\Bamowimy,Ludwig,1
                \\cochioo,Stuooe,2
                \\clo,Lwoue,3
                \\cppp,friedrich,2
                \\fep,balthasar,3
                \\bpp,goodman,1
                \\sp,heep,4
                \\By,Ludwig,1
                \\coco,Stuooe,2
                \\cocelo,Lwoue,3
                    ;
        var rowiterator = std.mem.split(u8, teilnehmer, "\n");
        while (rowiterator.next()) |row| {
            var fielditerator = std.mem.split(u8, row, ",");
            var field_n: u8 = 1;
            while (fielditerator.next())|field|{
                if (c.SQLITE_OK != c.sqlite3_bind_text(stmt, field_n, @ptrCast(field), @intCast(field.len), c.SQLITE_STATIC)) {
                    std.debug.print("Can't bind text: {s}\n", .{c.sqlite3_errmsg(self.db)});
                    return error.bindText;
                }
                field_n += 1;
            }
                if (c.SQLITE_DONE != c.sqlite3_step(stmt)) {
                    std.debug.print("Can't step color stmt: {s}\n", .{c.sqlite3_errmsg(self.db)});
                    return error.step;
                }
                _ = c.sqlite3_reset(stmt);
                //            const last_id = c.sqlite3_last_insert_rowid(self.db);
        }

        return;
    }
    fn fillZelte(self: DB) !void {
        const stmt_blk = blk: {
            var stmt: ?*c.sqlite3_stmt = undefined;
            const query = "INSERT INTO zelte (plaetze) values (?1)";
            if (c.SQLITE_OK != c.sqlite3_prepare_v2(self.db, query, query.len + 1, &stmt, null)) {
                std.debug.print("Can't create prepare statement: {s}\n", .{c.sqlite3_errmsg(self.db)});
                return error.prepareStmt;
            }
            break :blk stmt.?;
        };
        defer _ = c.sqlite3_finalize(stmt_blk);

        const zelte = .{
                .{.plaetze= 3},
                .{.plaetze= 4},
                .{.plaetze= 2},
                .{.plaetze= 5},
        };

        inline for (zelte) |row| {

            // bind index is 1-based.
            if (c.SQLITE_OK != c.sqlite3_bind_int(stmt_blk, 1, row.plaetze)) {
                std.debug.print("Can't bind text: {s}\n", .{c.sqlite3_errmsg(self.db)});
                return error.bindText;
            }
            if (c.SQLITE_DONE != c.sqlite3_step(stmt_blk)) {
                std.debug.print("Can't step color stmt: {s}\n", .{c.sqlite3_errmsg(self.db)});
                return error.step;
            }


            _ = c.sqlite3_reset(stmt_blk);

//            const last_id = c.sqlite3_last_insert_rowid(self.db);
        }

        return;
    }
};


var db: DB = undefined;
fn on_add_request(r: zap.Request) void {
    std.debug.print("add_request\n", .{});
    r.parseQuery();
    if (r.getParamSlice("vorname"))|x1| if (r.getParamSlice("nachname"))|x2| {
        if (x1.len > 64 or x2.len > 64 or x1.len == 0 or x2.len == 0){
            return;
        }
//        _ = shared_counter.?.fetchAdd(1,std.builtin.AtomicOrder.acq_rel);
        _ = shared_data.inc();
        const stmt_teilnehmer = blk: {
            var stmt: ?*c.sqlite3_stmt = undefined;
            const query = "INSERT INTO teilnehmer (name, vorname, zelt_id) values (?1, ?2, 1)";
            
            if (c.SQLITE_OK != c.sqlite3_prepare_v2(db.db, query, query.len + 1, &stmt, null)) {
                std.debug.print("Can't create prepare statement: {s}\n", .{c.sqlite3_errmsg(db.db)});
                r.sendBody("SQL Error") catch {
                    std.debug.print("sendbody failed\n",.{});
                    return;
                };
            }
            break :blk stmt.?;
        };
        defer _ = c.sqlite3_finalize(stmt_teilnehmer);
        if (c.SQLITE_OK != c.sqlite3_bind_text(stmt_teilnehmer, 1, @ptrCast(x2),@intCast(x2.len), c.SQLITE_STATIC)) {
                std.debug.print("Can't bind text: {s}\n", .{c.sqlite3_errmsg(db.db)});
                return;
        }
            
        if (c.SQLITE_OK != c.sqlite3_bind_text(stmt_teilnehmer, 2, @ptrCast(x1),@intCast(x1.len), c.SQLITE_STATIC)) {
            std.debug.print("Can't bind text: {s}\n", .{c.sqlite3_errmsg(db.db)});
            return;
        }

        if (c.SQLITE_DONE != c.sqlite3_step(stmt_teilnehmer)) {
            std.debug.print("Can't step stmt: {s}\n", .{c.sqlite3_errmsg(db.db)});
            return;
        }


        _ = c.sqlite3_reset(stmt_teilnehmer);

        var buf: ["<tr class=\"teilnehmer\"><td></td><td></td><td></td><td></td></tr>".len + 6 + 6 + 64 + 64]u8 = undefined;
        std.debug.print("{s} {s}\n", .{x1,x2});
        const slice = std.fmt.bufPrint(&buf, "<tr class=\"teilnehmer\"><td>{}</td><td>{s}</td><td>{s}</td><td>{}</td></tr>",.{
            c.sqlite3_last_insert_rowid(db.db),x1,x2,1}) catch return;
        std.debug.print("{s}\n", .{slice});

        r.sendBody(slice) catch std.debug.print("error sendbody in 'on_add_request' ",.{});
    };

}

fn on_zeltchange_request(r: zap.Request) void {
    std.debug.print("zeltchange\n", .{});
    r.parseQuery();
    if (r.getParamSlice("tid"))|teilnehmer| if (r.getParamSlice("from"))|from|  if (r.getParamSlice("to"))|to|{
        std.debug.print("zeltchange t{s}: z{s} -> z{s}\n",.{teilnehmer,from,to});
        
        var query_buf: ["UPDATE teilnehmer SET zelt_id = ..... where id = ..... ;".len]u8 = undefined;
        const query = std.fmt.bufPrintZ(&query_buf,"UPDATE teilnehmer SET zelt_id = {s} where id = {s} ;", .{to,teilnehmer}) catch {
                r.sendBody("sql error") catch return;
                return;
            };
        db.execute(@constCast(query)) catch {
            std.debug.print("sql error" , .{});
            r.sendBody("sql error") catch return;
            return;
        };
        r.sendBody("OK") catch return;
    };
}

fn on_request_minimal(r: zap.Request) void {
    std.debug.print("on_request_minimal",.{});
    if (r.path)|p|{
        if (std.mem.eql(u8, p,"/zap/add")){
            if (r.query)|_|{
                on_add_request(r);
            }
            return;
        }
        else if (std.mem.eql(u8, p,"/zap/change_zelt")){
            if (r.query)|_|{
                on_zeltchange_request(r);
            }
            return;
        }
        else if (std.mem.eql(u8, p,"/zap/change_counter")){
            var buf: [10]u8 = undefined;
            //            const value = shared_counter.?.load(std.builtin.AtomicOrder.unordered);
            const slice = std.fmt.bufPrint(&buf, "{}", .{shared_data.value}) catch return;
            r.sendBody(slice) catch return ;
            return;
        }
        std.debug.print("{s}\n", .{p});
    }
    const template_buf: []u8 = allocator.alloc(u8,0x10000) catch {
        std.debug.print("alloc failed ", .{});
        return; 
    };
    const template = std.fs.cwd().readFile("template.html",template_buf) catch {
        std.debug.print("readfile failed ", .{});
        return; 
    };

    var mustache = Mustache.fromData(template) catch {
        std.debug.print("mustache error",.{});
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


    const maybe_stmt_teilnehmer = prepare_stmt("SELECT id, name, vorname, zelt_id FROM teilnehmer order by zelt_id");
    const maybe_stmt_zelte = prepare_stmt("SELECT id, plaetze FROM zelte order by id");

    defer _ = c.sqlite3_finalize(maybe_stmt_teilnehmer);
    defer _ = c.sqlite3_finalize(maybe_stmt_zelte);

    var zelt_i: u16 = 0;
    if (maybe_stmt_zelte)|stmt_zelte|{
        const zelt_iter = DB_Iterator.init(struct {id: u8, plaetze: u4},fba_allocator);
        while (zelt_iter.next(stmt_zelte))|z|{
            zelte[zelt_i] = .{
                .id=     z.id, 
                .plaetze=z.plaetze,
                .zteilnehmer=teilnehmer[0..2],
            };

            zelt_i=zelt_i+1;
        }
    }


    var i: u16 = 0;
    if(maybe_stmt_teilnehmer) |stmt_teilnehmer| {
        const iter = DB_Iterator.init(Teilnehmer,fba_allocator);
        var zelt_id: u16 = 1;
        var start_of_this_zelt: u16 = 0;
        while (iter.next(stmt_teilnehmer))|t| {
            teilnehmer[i] = t;
            std.debug.print("{},{s},{s},{}\n",t);
            if (t.zelt_id != zelt_id){
                //            std.debug.print("{}: {}-{}\n",.{zelt_id,start_of_this_zelt,i-1});
                zelte[zelt_id-1].zteilnehmer= teilnehmer[start_of_this_zelt..i];
                zelt_id = t.zelt_id;
                start_of_this_zelt = i;

            }
            i=i+1;
        }
        //        zelte[zelt_id-1].zteilnehmer = teilnehmer[start_of_this_zelt..i];
    }


    const ret = mustache.build(.{ .teilnehmer=teilnehmer[0..i], .zelte=zelte[0..zelt_i]} );


    if (ret.str())|mustache_string|{
        //        std.debug.print("{s}\n", .{ mustache_string} );    
        r.sendBody(mustache_string) catch {
            std.debug.print("sendbody failed\n",.{});
            return;
        };
    }
}
fn prepare_stmt(query: []const u8) ?*c.sqlite3_stmt{
    var maybe_stmt: ?*c.sqlite3_stmt = undefined;
     
    if (c.SQLITE_OK != c.sqlite3_prepare_v2(db.db, @ptrCast(query), @intCast(query.len + 1), &maybe_stmt, null)) {
        std.debug.print("Can't create prepare statement: {s}\n", .{c.sqlite3_errmsg(db.db)});
    }
    return maybe_stmt;
}


pub fn main() !void {

    const version = c.sqlite3_libversion();
    std.debug.print("libsqlite3 version is {s}\n", .{version});
    shared_data = SharedData{.mutex = std.Thread.Mutex{}, .value=0};
    var c_db: ?*c.sqlite3 = undefined;
    if (c.SQLITE_OK != c.sqlite3_open("beepdoop_zeltlager.db", &c_db)) {
        std.debug.print("Can't open database: {s}\n", .{c.sqlite3_errmsg(c_db)});
        return;
    }
    db = DB.init(c_db.?);
    defer db.deinit();
    
    
     
    const db_iter = DB_Iterator.init(struct {name: []const u8, vorname: []const u8, zelt: u16},fba_allocator);
    const maybe_stmt = prepare_stmt ("select name, vorname, zelt_id from teilnehmer");
    if (maybe_stmt) |stmt| {
        while (db_iter.next(stmt)) |retval|{
            std.debug.print("retval: {s},{s},{}\n",.{retval.vorname,retval.name,retval.zelt});
        }
    } 

   try db.execute(
       \\ drop table if exists zelte;
       \\ drop table if exists teilnehmer;
       \\ create table if not exists zelte (
       \\   id integer not null primary key,
       \\   plaetze integer not null
       \\);
       \\ create table if not exists teilnehmer (
       \\   id integer not null primary key,
       \\   name text not null,
       \\   vorname text not null,
       \\   zelt_id integer not null,
       \\   foreign key (zelt_id)references zelte(id)
       \\ );
   );
   try db.fillZelte();
   try db.insertTable();

    var listener = zap.HttpListener.init(.{
        .port = 3000,
        .on_request = on_request_minimal,
        .log = false,
        .max_clients = 100000,
    });
    try listener.listen();

    std.debug.print("Listening on 0.0.0.0:3000\n", .{});

    // start worker threads
    zap.start(.{
        .threads = 4,
        .workers = 1, // empirical tests: yield best perf on my machine
    });
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
