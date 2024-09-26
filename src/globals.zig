const std = @import("std");
pub var change_counter: std.atomic.Value(u32) = std.atomic.Value(u32).init(0);

