const std = @import("std");
pub const c = @cImport({
    @cInclude("sqlite3.h");
});
pub var db: *c.sqlite3 = undefined;

pub const DB_Iterator = struct {
    T: type,
    stmt: *c.sqlite3_stmt,
    allocator: std.mem.Allocator,
    pub fn next(self: DB_Iterator, stmt: *c.sqlite3_stmt) ?self.T {
        _ = self.stmt;
        const rc = c.sqlite3_step(stmt);
        var value: self.T = undefined;
        if (rc == c.SQLITE_ROW) {
            inline for (std.meta.fields(self.T), 0..) |field, i| {
                switch (field.type) {
                    []u8 => {
                        @field(value, field.name) = @constCast(std.mem.span(c.sqlite3_column_text(stmt, i)));
                    },
                    []const u8 => {
                        const bla = std.mem.span(c.sqlite3_column_text(stmt, i));
                        const memory = self.allocator.alloc(u8, bla.len) catch return null;

                        @memcpy(memory, bla);
                        @field(value, field.name) = memory;
                    },
                    u64, i64, u32, i32, u24, i24, u16, i16, u8, i8, u4, i4, u2, i2, u1, i1 => {
                        @field(value, field.name) = @intCast(c.sqlite3_column_int(stmt, i));
                    },
                    else => {
                        const bla = std.mem.span(c.sqlite3_column_text(stmt, i));
                        const memory = self.allocator.alloc(u8, bla.len) catch return null;

                        @memcpy(memory, bla);
                        @field(value, field.name) = memory;
                },
                }
            }
            return value;
        } else return null;
    }
    pub fn init(t: type, a: std.mem.Allocator) DB_Iterator {
        return .{ .T = t, .stmt = undefined, .allocator = a };
    }
};
pub fn prepare_stmt(query: []const u8) ?*c.sqlite3_stmt {
    var maybe_stmt: ?*c.sqlite3_stmt = undefined;

    if (c.SQLITE_OK != c.sqlite3_prepare_v2(db, @ptrCast(query), @intCast(query.len + 1), &maybe_stmt, null)) {
        std.debug.print("Can't create prepare statement: {s}\n", .{c.sqlite3_errmsg(db)});
    }
    return maybe_stmt;
}
pub fn openDB(dbname: [:0]const u8) void {
    var maybe_db: ?*c.sqlite3 = undefined;
    if (c.SQLITE_OK != c.sqlite3_open(dbname, &maybe_db)) {
        std.debug.print("Can't open database: {s}\n", .{c.sqlite3_errmsg(maybe_db)});
        return;
    }
    db = maybe_db.?;
}
pub fn closeDB() void {
    _ = c.sqlite3_close(db);
}
    pub fn execute(query: [:0]const u8) !void {
    var errmsg: [*c]u8 = undefined;
    if (c.SQLITE_OK != c.sqlite3_exec(db, query, null, null, &errmsg)) {
        defer c.sqlite3_free(errmsg);
        std.debug.print("Exec query failed: {s}\n", .{errmsg});
        return error.execError;
    }
    return;
}
fn drop_tables(Ts: type) void{ 
    var cmdbuf: [256]u8 = undefined;
    inline for (std.meta.fields(Ts)) |table| {
       defer {
            const slice =std.fmt.bufPrintZ(&cmdbuf,"DROP TABLE IF EXISTS {s}", .{table.name}) catch "xxx";
            execute (slice) catch {};
       }
    }

}
pub fn initDB(Ts: type) void{
    //    std.debug.print("maybe_u8 = {}\n",.{@typeInfo(?u8)});
    var cmdbuf: [256]u8 = undefined;
//    drop_tables(Ts);
   inline for (0..std.meta.fields(Ts).len) |i| {
       const field_number= std.meta.fields(Ts).len-i-1;
       const table = std.meta.fields(Ts)[field_number];
       const slice =std.fmt.bufPrintZ(&cmdbuf, "DROP TABLE IF EXISTS {s};\n", .{table.name}) catch return;
       execute(slice) catch return;
   }
    
    inline for (std.meta.fields(Ts)) |table| {
        std.debug.print("{s}\n", .{table.name});
        var cmdlen: usize = 0;

        std.debug.print("{s}\n",.{table.name});
        var slice =std.fmt.bufPrint(cmdbuf[cmdlen..], "CREATE TABLE {s} (\n", .{table.name}) catch return;
        cmdlen+=slice.len;
        inline for (std.meta.fields(table.type)) |field| {
            const T = if (@typeInfo(field.type) == .Optional ) @typeInfo(field.type).Optional.child else field.type;

            slice =std.fmt.bufPrint(cmdbuf[cmdlen..], "{s} {s} {s} {s} ,\n", .{
                field.name, 

                switch (T){
                    u8,u16,u32,u64,i8,i16,i32,i64,comptime_int => "integer" ,
                    f16,f32,f64,comptime_float => "float", 
                    else => "text"}, 

                    if (@typeInfo(field.type) == .Optional ) "" else "not null" , 

                        if (field.name.len == 2 and field.name[0]=='i' and field.name[1]=='d') "primary key" else "" , 
            }) catch return;
            cmdlen+=slice.len;
            if (field.name.len > 3 and 
                field.name[field.name.len-1]=='d' and 
                field.name[field.name.len-2]=='i' and field.name[field.name.len-3]=='_') {
                slice =std.fmt.bufPrint(cmdbuf[cmdlen-2..], "REFERENCES {s}(id),\n", .{field.name[0..field.name.len-3]}) catch return;
                cmdlen+=slice.len-2;

            }
        }
        slice =std.fmt.bufPrintZ(cmdbuf[cmdlen-2..], "\n);", .{}) catch return;

        std.debug.print("{s}\n", .{@as([:0]u8, @ptrCast(&cmdbuf))});

        execute(@ptrCast(&cmdbuf)) catch { std.debug.print("failure\n", .{}); };
    }
    //    for (cmdbuf[0..120]) |ch|{
    //       std.debug.print("`{c}", .{ch});
    //  }
}
pub fn fillTable(tablename: [:0]const u8, values: anytype) void {
   const T = @TypeOf(values[0]);
   var cmdbuf: [values.len * @as(usize,64)]u8 = undefined;
   //std.debug.print("{}\n", .{@TypeOf(values)});
   std.debug.print("fill {s}\n", .{tablename});

   var cmdlen: usize = 0;
   var slice =std.fmt.bufPrint(cmdbuf[cmdlen..], "INSERT INTO {s} (", .{tablename}) catch return;
   cmdlen += slice.len;
  inline for (std.meta.fields(T)) |field| {
      slice =std.fmt.bufPrint(cmdbuf[cmdlen..], "{s},", .{field.name}) catch return;
      cmdlen += slice.len;
   }
   cmdlen-=1;
   slice =std.fmt.bufPrint(cmdbuf[cmdlen..], ") VALUES  ", .{}) catch return;
   cmdlen += slice.len;
   inline for (values) |value|{
       slice =std.fmt.bufPrint(cmdbuf[cmdlen-2..], "(", .{}) catch return;
//       cmdlen += slice.len;
       inline for (std.meta.fields(T)) |field| {
//           std.debug.print("{s}: {}\n", .{field.name,field.type});
           switch (field.type) {
               u64, i64, u32, i32, u24, i24, u16, i16, u8, i8, u4, i4, u2, i2, u1, i1, comptime_int => {
                  slice =std.fmt.bufPrint(cmdbuf[cmdlen-1..], "{},", .{@field(value,field.name)}) catch return;
               },
               f16, f32, f64, comptime_float => {
                   slice =std.fmt.bufPrint(cmdbuf[cmdlen-1..], "{},", .{@field(value,field.name)}) catch return;
               },
               else => {
//               []u8, []const u8 => {
                   slice =std.fmt.bufPrint(cmdbuf[cmdlen-1..], "'{s}',", .{@field(value,field.name)}) catch return;
               },
           }
           cmdlen += slice.len;
       }
       slice =std.fmt.bufPrint(cmdbuf[cmdlen-2..], "),", .{}) catch return;
       cmdlen += slice.len;
   }
   cmdbuf[cmdlen-3]=';';
   cmdbuf[cmdlen-2]=0;
   std.debug.print("{s}\n",.{@as([:0]u8, @ptrCast(&cmdbuf))});

    
   execute(@ptrCast(&cmdbuf)) catch { std.debug.print("failure\n", .{}); };
}
