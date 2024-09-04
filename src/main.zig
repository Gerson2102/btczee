const std = @import("std");
const Config = @import("config/config.zig").Config;
const Mempool = @import("core/mempool.zig").Mempool;
const Storage = @import("storage/storage.zig").Storage;
const P2P = @import("network/p2p.zig").P2P;
const RPC = @import("network/rpc.zig").RPC;
const node = @import("node/node.zig");
const ArgParser = @import("util/ArgParser.zig");

pub fn main() !void {
    // Initialize the allocator
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_state.allocator();
    defer _ = gpa_state.deinit();

    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    var stdout_buffered = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = stdout_buffered.writer();

    try mainFull(.{
        .allocator = gpa,
        .args = args[1..],
        .stdout = stdout.any(),
    });

    return stdout_buffered.flush();
}

pub fn mainFull(options: struct {
    allocator: std.mem.Allocator,
    args: []const []const u8,
    stdout: std.io.AnyWriter,
}) !void {
    var program = Program{
        .allocator = options.allocator,
        .args = .{ .args = options.args },
        .stdout = options.stdout,
    };

    return program.mainCommand();
}

const Program = @This();

allocator: std.mem.Allocator,
args: ArgParser,
stdout: std.io.AnyWriter,

const main_usage =
    \\Usage: btczee [command] [args]
    \\
    \\Commands:
    \\  node     <subcommand>
    \\  wallet   <subcommand>
    \\  help                   Display this message
    \\
;

pub fn mainCommand(program: *Program) !void {
    while (program.args.next()) {
        if (program.args.flag(&.{"node"}))
            return program.nodeSubCommand();
        if (program.args.flag(&.{"wallet"}))
            return program.walletSubCommand();
        if (program.args.flag(&.{ "-h", "--help", "help" }))
            return program.stdout.writeAll(main_usage);
        if (program.args.positional()) |_| {
            try std.io.getStdErr().writeAll(main_usage);
            return error.InvalidArgument;
        }
    }
    try std.io.getStdErr().writeAll(main_usage);
    return error.InvalidArgument;
}

const node_sub_usage =
    \\Usage:
    \\  btczee node [command] [args]
    \\  btczee node [options] [ids]...
    \\
    \\Commands:
    \\  help                   Display this message
    \\
;

fn nodeSubCommand(program: *Program) !void {
    // Handle potential node subcommands here
    if (program.args.next()) {
        if (program.args.flag(&.{ "-h", "--help", "help" }))
            return program.stdout.writeAll(node_sub_usage);
    }

    // Otherwise, run the node
    return program.runNodeCommand();
}

fn runNodeCommand(program: *Program) !void {
    // Load configuration
    var config = try Config.load(program.allocator, "bitcoin.conf.example");
    defer config.deinit();

    // Initialize components
    var mempool = try Mempool.init(program.allocator, &config);
    defer mempool.deinit();

    var storage = try Storage.init(program.allocator, &config);
    defer storage.deinit();

    var p2p = try P2P.init(program.allocator, &config);
    defer p2p.deinit();

    var rpc = try RPC.init(program.allocator, &config, &mempool, &storage);
    defer rpc.deinit();

    // Start the node
    try node.startNode(&mempool, &storage, &p2p, &rpc);
}

const wallet_sub_usage =
    \\Usage:
    \\  btczee wallet [command] [args]
    \\
    \\Commands:
    \\  create                 Create a new wallet
    \\  load                   Load an existing wallet
    \\  help                   Display this message
    \\
;

fn walletSubCommand(program: *Program) !void {
    if (program.args.next()) {
        if (program.args.flag(&.{"create"}))
            return program.walletCreateCommand();
        if (program.args.flag(&.{"load"}))
            return program.walletLoadCommand();
        if (program.args.flag(&.{ "-h", "--help", "help" }))
            return program.stdout.writeAll(wallet_sub_usage);
    }
    try std.io.getStdErr().writeAll(wallet_sub_usage);
    return error.InvalidArgument;
}

fn walletCreateCommand(program: *Program) !void {
    return program.stdout.writeAll("Not implemented yet\n");
}

fn walletLoadCommand(program: *Program) !void {
    return program.stdout.writeAll("Not implemented yet\n");
}
