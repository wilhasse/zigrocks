const std = @import("std");

const RocksDB = @import("rocksdb.zig").RocksDB;
const lex = @import("lex.zig");
const parse = @import("parse.zig");
const execute = @import("execute.zig");
const Storage = @import("storage.zig").Storage;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var debugTokens = false;
    var debugAST = false;
    var args = std.process.args();
    var scriptArg: usize = 0;
    var databaseArg: usize = 0;
    var i: usize = 0;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--debug-tokens")) {
            debugTokens = true;
        }

        if (std.mem.eql(u8, arg, "--debug-ast")) {
            debugAST = true;
        }

        if (std.mem.eql(u8, arg, "--database")) {
            databaseArg = i + 1;
            i += 1;
            _ = args.next();
        }

        if (std.mem.eql(u8, arg, "--script")) {
            scriptArg = i + 1;
            i += 1;
            _ = args.next();
        }

        i += 1;
    }

    if (databaseArg == 0) {
        std.debug.print("--database is a required flag. Should be a directory for data.\n", .{});
        return;
    }

    if (scriptArg == 0) {
        std.debug.print("--script is a required flag. Should be a file containing SQL.\n", .{});
        return;
    }

    const file = try std.fs.cwd().openFileZ(std.os.argv[scriptArg], .{});
    defer file.close();

    var db: RocksDB = undefined;
    const dataDirectory = std.mem.span(std.os.argv[databaseArg]);
    switch (RocksDB.open(allocator, dataDirectory)) {
        .err => |err| {
            std.debug.print("Failed to open database: {s}\n", .{err});
            return;
        },
        .val => |val| db = val,
    }
    defer db.close();

    const storage = Storage.init(allocator, db);
    const executor = execute.Executor.init(allocator, storage);

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var tokens = std.ArrayList(lex.Token).init(allocator);
        defer tokens.deinit();

        // Create a buffer to hold the new string with newline
        var line_n = try allocator.alloc(u8, line.len + 1);
        defer allocator.free(line_n);

        // Copy the original line to the new buffer
        std.mem.copyForwards(u8, line_n, line);

        // Append the newline character
        line_n[line.len] = '\n';
        const lexErr = lex.lex(line_n, &tokens);
        if (lexErr) |err| {
            std.debug.print("Failed to lex: {s}\n", .{err});
            continue;
        }

        if (debugTokens) {
            for (tokens.items) |token| {
                std.debug.print("Token: {s}\n", .{token.string()});
            }
        }

        if (tokens.items.len == 0) {
            std.debug.print("Empty line, skipping\n", .{});
            continue;
        }

        const parser = parse.Parser.init(allocator);
        var ast: parse.Parser.AST = undefined;
        switch (parser.parse(tokens.items)) {
            .err => |err| {
                std.debug.print("Failed to parse: {s}\n", .{err});
                continue;
            },
            .val => |val| ast = val,
        }

        if (debugAST) {
            ast.print();
        }

        switch (executor.execute(ast)) {
            .err => |err| {
                std.debug.print("Failed to execute: {s}\n", .{err});
            },
            .val => |val| {
                if (val.rows.len == 0) {
                    std.debug.print("ok\n", .{});
                    continue;
                }
                std.debug.print("| ", .{});
                for (val.fields) |field| {
                    std.debug.print("{s}\t\t|", .{field});
                }
                std.debug.print("\n", .{});
                std.debug.print("+ ", .{});
                for (val.fields) |field| {
                    var fieldLen = field.len;
                    while (fieldLen > 0) : (fieldLen -= 1) {
                        std.debug.print("=", .{});
                    }
                    std.debug.print("\t\t+", .{});
                }
                std.debug.print("\n", .{});
                for (val.rows) |row| {
                    std.debug.print("| ", .{});
                    for (row) |cell| {
                        std.debug.print("{s}\t\t|", .{cell});
                    }
                    std.debug.print("\n", .{});
                }
            },
        }
    }
}
