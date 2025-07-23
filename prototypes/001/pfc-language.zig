const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const HashMap = std.HashMap;
const Allocator = std.mem.Allocator;

// ============================================================================
// AST (Abstract Syntax Tree) Definitions
// ============================================================================

const TokenType = enum {
    // Literals
    atom,
    number,
    string,
    boolean,
    
    // Identifiers
    identifier,
    module_name,
    
    // Operators
    pipe,           // |>
    match,          // ->
    assign,         // =
    plus,           // +
    minus,          // -
    multiply,       // *
    divide,         // /
    
    // Delimiters
    lparen,         // (
    rparen,         // )
    lbrace,         // {
    rbrace,         // }
    lbracket,       // [
    rbracket,       // ]
    comma,          // ,
    dot,            // .
    
    // Keywords
    kw_defmodule,   // defmodule
    kw_def,         // def
    kw_defmacro,    // defmacro
    kw_packet,      // packet
    kw_molecule,    // molecule
    kw_reactor,     // reactor
    kw_node,        // node
    kw_when,        // when
    kw_case,        // case
    kw_with,        // with
    kw_quote,       // quote
    kw_unquote,     // unquote
    
    // Special
    newline,
    eof,
    invalid,
};

const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: u32,
    column: u32,
};

const ASTNodeType = enum {
    module_def,
    function_def,
    macro_def,
    packet_def,
    molecule_def,
    reactor_def,
    node_def,
    pipe_expr,
    call_expr,
    match_expr,
    case_expr,
    with_expr,
    literal,
    identifier,
    list,
    tuple,
    map,
    quote_expr,
    unquote_expr,
    block,
};

const ASTNode = union(ASTNodeType) {
    module_def: ModuleDef,
    function_def: FunctionDef,
    macro_def: MacroDef,
    packet_def: PacketDef,
    molecule_def: MoleculeDef,
    reactor_def: ReactorDef,
    node_def: NodeDef,
    pipe_expr: PipeExpr,
    call_expr: CallExpr,
    match_expr: MatchExpr,
    case_expr: CaseExpr,
    with_expr: WithExpr,
    literal: Literal,
    identifier: Identifier,
    list: List,
    tuple: Tuple,
    map: Map,
    quote_expr: QuoteExpr,
    unquote_expr: UnquoteExpr,
    block: Block,
    
    pub fn deinit(self: *ASTNode, allocator: Allocator) void {
        switch (self.*) {
            .module_def => |*m| m.deinit(allocator),
            .function_def => |*f| f.deinit(allocator),
            .macro_def => |*m| m.deinit(allocator),
            .packet_def => |*p| p.deinit(allocator),
            .molecule_def => |*m| m.deinit(allocator),
            .reactor_def => |*r| r.deinit(allocator),
            .node_def => |*n| n.deinit(allocator),
            .pipe_expr => |*p| p.deinit(allocator),
            .call_expr => |*c| c.deinit(allocator),
            .match_expr => |*m| m.deinit(allocator),
            .case_expr => |*c| c.deinit(allocator),
            .with_expr => |*w| w.deinit(allocator),
            .literal => |*l| l.deinit(allocator),
            .identifier => |*i| i.deinit(allocator),
            .list => |*l| l.deinit(allocator),
            .tuple => |*t| t.deinit(allocator),
            .map => |*m| m.deinit(allocator),
            .quote_expr => |*q| q.deinit(allocator),
            .unquote_expr => |*u| u.deinit(allocator),
            .block => |*b| b.deinit(allocator),
        }
    }
};

const ModuleDef = struct {
    name: []const u8,
    body: []*ASTNode,
    
    pub fn deinit(self: *ModuleDef, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.body) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        allocator.free(self.body);
    }
};

const FunctionDef = struct {
    name: []const u8,
    params: [][]const u8,
    guards: ?[]*ASTNode,
    body: []*ASTNode,
    
    pub fn deinit(self: *FunctionDef, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.params) |param| {
            allocator.free(param);
        }
        allocator.free(self.params);
        
        if (self.guards) |guards| {
            for (guards) |guard| {
                guard.deinit(allocator);
                allocator.destroy(guard);
            }
            allocator.free(guards);
        }
        
        for (self.body) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        allocator.free(self.body);
    }
};

const MacroDef = struct {
    name: []const u8,
    params: [][]const u8,
    body: []*ASTNode,
    
    pub fn deinit(self: *MacroDef, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.params) |param| {
            allocator.free(param);
        }
        allocator.free(self.params);
        for (self.body) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        allocator.free(self.body);
    }
};

const PacketDef = struct {
    name: []const u8,
    group: []const u8,
    element: []const u8,
    properties: []*ASTNode,
    
    pub fn deinit(self: *PacketDef, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.group);
        allocator.free(self.element);
        for (self.properties) |prop| {
            prop.deinit(allocator);
            allocator.destroy(prop);
        }
        allocator.free(self.properties);
    }
};

const MoleculeDef = struct {
    name: []const u8,
    composition: []*ASTNode,
    bonds: []*ASTNode,
    properties: []*ASTNode,
    
    pub fn deinit(self: *MoleculeDef, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.composition) |comp| {
            comp.deinit(allocator);
            allocator.destroy(comp);
        }
        allocator.free(self.composition);
        for (self.bonds) |bond| {
            bond.deinit(allocator);
            allocator.destroy(bond);
        }
        allocator.free(self.bonds);
        for (self.properties) |prop| {
            prop.deinit(allocator);
            allocator.destroy(prop);
        }
        allocator.free(self.properties);
    }
};

const ReactorDef = struct {
    name: []const u8,
    nodes: []*ASTNode,
    policies: []*ASTNode,
    
    pub fn deinit(self: *ReactorDef, allocator: Allocator) void {
        allocator.free(self.name);
        for (self.nodes) |node| {
            node.deinit(allocator);
            allocator.destroy(node);
        }
        allocator.free(self.nodes);
        for (self.policies) |policy| {
            policy.deinit(allocator);
            allocator.destroy(policy);
        }
        allocator.free(self.policies);
    }
};

const NodeDef = struct {
    name: []const u8,
    specialization: []const u8,
    handlers: []*ASTNode,
    
    pub fn deinit(self: *NodeDef, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.specialization);
        for (self.handlers) |handler| {
            handler.deinit(allocator);
            allocator.destroy(handler);
        }
        allocator.free(self.handlers);
    }
};

const PipeExpr = struct {
    left: *ASTNode,
    right: *ASTNode,
    
    pub fn deinit(self: *PipeExpr, allocator: Allocator) void {
        self.left.deinit(allocator);
        allocator.destroy(self.left);
        self.right.deinit(allocator);
        allocator.destroy(self.right);
    }
};

const CallExpr = struct {
    function: *ASTNode,
    args: []*ASTNode,
    
    pub fn deinit(self: *CallExpr, allocator: Allocator) void {
        self.function.deinit(allocator);
        allocator.destroy(self.function);
        for (self.args) |arg| {
            arg.deinit(allocator);
            allocator.destroy(arg);
        }
        allocator.free(self.args);
    }
};

const MatchExpr = struct {
    pattern: *ASTNode,
    body: *ASTNode,
    
    pub fn deinit(self: *MatchExpr, allocator: Allocator) void {
        self.pattern.deinit(allocator);
        allocator.destroy(self.pattern);
        self.body.deinit(allocator);
        allocator.destroy(self.body);
    }
};

const CaseExpr = struct {
    expr: *ASTNode,
    clauses: []*ASTNode,
    
    pub fn deinit(self: *CaseExpr, allocator: Allocator) void {
        self.expr.deinit(allocator);
        allocator.destroy(self.expr);
        for (self.clauses) |clause| {
            clause.deinit(allocator);
            allocator.destroy(clause);
        }
        allocator.free(self.clauses);
    }
};

const WithExpr = struct {
    clauses: []*ASTNode,
    body: *ASTNode,
    
    pub fn deinit(self: *WithExpr, allocator: Allocator) void {
        for (self.clauses) |clause| {
            clause.deinit(allocator);
            allocator.destroy(clause);
        }
        allocator.free(self.clauses);
        self.body.deinit(allocator);
        allocator.destroy(self.body);
    }
};

const Literal = struct {
    value: []const u8,
    type: []const u8,
    
    pub fn deinit(self: *Literal, allocator: Allocator) void {
        allocator.free(self.value);
        allocator.free(self.type);
    }
};

const Identifier = struct {
    name: []const u8,
    
    pub fn deinit(self: *Identifier, allocator: Allocator) void {
        allocator.free(self.name);
    }
};

const List = struct {
    elements: []*ASTNode,
    
    pub fn deinit(self: *List, allocator: Allocator) void {
        for (self.elements) |elem| {
            elem.deinit(allocator);
            allocator.destroy(elem);
        }
        allocator.free(self.elements);
    }
};

const Tuple = struct {
    elements: []*ASTNode,
    
    pub fn deinit(self: *Tuple, allocator: Allocator) void {
        for (self.elements) |elem| {
            elem.deinit(allocator);
            allocator.destroy(elem);
        }
        allocator.free(self.elements);
    }
};

const Map = struct {
    pairs: []MapPair,
    
    pub fn deinit(self: *Map, allocator: Allocator) void {
        for (self.pairs) |pair| {
            pair.key.deinit(allocator);
            allocator.destroy(pair.key);
            pair.value.deinit(allocator);
            allocator.destroy(pair.value);
        }
        allocator.free(self.pairs);
    }
};

const MapPair = struct {
    key: *ASTNode,
    value: *ASTNode,
};

const QuoteExpr = struct {
    expr: *ASTNode,
    
    pub fn deinit(self: *QuoteExpr, allocator: Allocator) void {
        self.expr.deinit(allocator);
        allocator.destroy(self.expr);
    }
};

const UnquoteExpr = struct {
    expr: *ASTNode,
    
    pub fn deinit(self: *UnquoteExpr, allocator: Allocator) void {
        self.expr.deinit(allocator);
        allocator.destroy(self.expr);
    }
};

const Block = struct {
    statements: []*ASTNode,
    
    pub fn deinit(self: *Block, allocator: Allocator) void {
        for (self.statements) |stmt| {
            stmt.deinit(allocator);
            allocator.destroy(stmt);
        }
        allocator.free(self.statements);
    }
};

// ============================================================================
// Lexer
// ============================================================================

const Lexer = struct {
    source: []const u8,
    current: usize,
    line: u32,
    column: u32,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, source: []const u8) Lexer {
        return Lexer{
            .source = source,
            .current = 0,
            .line = 1,
            .column = 1,
            .allocator = allocator,
        };
    }
    
    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespace();
        
        if (self.isAtEnd()) {
            return Token{
                .type = .eof,
                .lexeme = "",
                .line = self.line,
                .column = self.column,
            };
        }
        
        const start = self.current;
        const start_column = self.column;
        const c = self.advance();
        
        return switch (c) {
            '(' => self.makeToken(.lparen, start, start_column),
            ')' => self.makeToken(.rparen, start, start_column),
            '{' => self.makeToken(.lbrace, start, start_column),
            '}' => self.makeToken(.rbrace, start, start_column),
            '[' => self.makeToken(.lbracket, start, start_column),
            ']' => self.makeToken(.rbracket, start, start_column),
            ',' => self.makeToken(.comma, start, start_column),
            '.' => self.makeToken(.dot, start, start_column),
            '+' => self.makeToken(.plus, start, start_column),
            '-' => {
                if (self.peek() == '>') {
                    _ = self.advance();
                    return self.makeToken(.match, start, start_column);
                }
                return self.makeToken(.minus, start, start_column);
            },
            '*' => self.makeToken(.multiply, start, start_column),
            '/' => self.makeToken(.divide, start, start_column),
            '=' => self.makeToken(.assign, start, start_column),
            '|' => {
                if (self.peek() == '>') {
                    _ = self.advance();
                    return self.makeToken(.pipe, start, start_column);
                }
                return self.makeToken(.invalid, start, start_column);
            },
            ':' => {
                if (std.ascii.isAlphabetic(self.peek())) {
                    return self.atom();
                }
                return self.makeToken(.invalid, start, start_column);
            },
            '"' => self.string(),
            '\n' => {
                self.line += 1;
                self.column = 1;
                return self.makeToken(.newline, start, start_column);
            },
            else => {
                if (std.ascii.isDigit(c)) {
                    return self.number();
                } else if (std.ascii.isAlphabetic(c) or c == '_') {
                    return self.identifier();
                }
                return self.makeToken(.invalid, start, start_column);
            },
        };
    }
    
    fn makeToken(self: *Lexer, token_type: TokenType, start: usize, start_column: u32) Token {
        return Token{
            .type = token_type,
            .lexeme = self.source[start..self.current],
            .line = self.line,
            .column = start_column,
        };
    }
    
    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.source.len;
    }
    
    fn advance(self: *Lexer) u8 {
        const c = self.source[self.current];
        self.current += 1;
        self.column += 1;
        return c;
    }
    
    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }
    
    fn peekNext(self: *Lexer) u8 {
        if (self.current + 1 >= self.source.len) return 0;
        return self.source[self.current + 1];
    }
    
    fn skipWhitespace(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == ' ' or c == '\t' or c == '\r') {
                _ = self.advance();
            } else if (c == '#') {
                // Skip comment
                while (!self.isAtEnd() and self.peek() != '\n') {
                    _ = self.advance();
                }
            } else {
                break;
            }
        }
    }
    
    fn string(self: *Lexer) Token {
        const start = self.current - 1;
        const start_column = self.column - 1;
        
        while (!self.isAtEnd() and self.peek() != '"') {
            if (self.peek() == '\n') {
                self.line += 1;
                self.column = 1;
            }
            _ = self.advance();
        }
        
        if (self.isAtEnd()) {
            return self.makeToken(.invalid, start, start_column);
        }
        
        _ = self.advance(); // Closing "
        return self.makeToken(.string, start, start_column);
    }
    
    fn number(self: *Lexer) Token {
        const start = self.current - 1;
        const start_column = self.column - 1;
        
        while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
        
        // Look for fractional part
        if (!self.isAtEnd() and self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
            _ = self.advance(); // Consume '.'
            while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }
        
        return self.makeToken(.number, start, start_column);
    }
    
    fn atom(self: *Lexer) Token {
        const start = self.current - 1;
        const start_column = self.column - 1;
        
        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_')) {
            _ = self.advance();
        }
        
        return self.makeToken(.atom, start, start_column);
    }
    
    fn identifier(self: *Lexer) Token {
        const start = self.current - 1;
        const start_column = self.column - 1;
        
        while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_')) {
            _ = self.advance();
        }
        
        const text = self.source[start..self.current];
        const token_type = self.getKeywordType(text);
        
        return self.makeToken(token_type, start, start_column);
    }
    
    fn getKeywordType(self: *Lexer, text: []const u8) TokenType {
        _ = self;
        if (std.mem.eql(u8, text, "defmodule")) return .kw_defmodule;
        if (std.mem.eql(u8, text, "def")) return .kw_def;
        if (std.mem.eql(u8, text, "defmacro")) return .kw_defmacro;
        if (std.mem.eql(u8, text, "packet")) return .kw_packet;
        if (std.mem.eql(u8, text, "molecule")) return .kw_molecule;
        if (std.mem.eql(u8, text, "reactor")) return .kw_reactor;
        if (std.mem.eql(u8, text, "node")) return .kw_node;
        if (std.mem.eql(u8, text, "when")) return .kw_when;
        if (std.mem.eql(u8, text, "case")) return .kw_case;
        if (std.mem.eql(u8, text, "with")) return .kw_with;
        if (std.mem.eql(u8, text, "quote")) return .kw_quote;
        if (std.mem.eql(u8, text, "unquote")) return .kw_unquote;
        if (std.mem.eql(u8, text, "true") or std.mem.eql(u8, text, "false")) return .boolean;
        return .identifier;
    }
};

// ============================================================================
// Parser
// ============================================================================

const ParseError = error{
    UnexpectedToken,
    OutOfMemory,
    InvalidSyntax,
};

const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    allocator: Allocator,
    
    pub fn init(allocator: Allocator, lexer: *Lexer) !Parser {
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .allocator = allocator,
        };
        parser.current_token = try lexer.nextToken();
        return parser;
    }
    
    pub fn parse(self: *Parser) !*ASTNode {
        return self.parseModule();
    }
    
    fn advance(self: *Parser) !void {
        self.current_token = try self.lexer.nextToken();
    }
    
    fn check(self: *Parser, token_type: TokenType) bool {
        return self.current_token.type == token_type;
    }
    
    fn match(self: *Parser, token_types: []const TokenType) !bool {
        for (token_types) |token_type| {
            if (self.check(token_type)) {
                try self.advance();
                return true;
            }
        }
        return false;
    }
    
    fn consume(self: *Parser, token_type: TokenType) !Token {
        if (self.check(token_type)) {
            const token = self.current_token;
            try self.advance();
            return token;
        }
        return ParseError.UnexpectedToken;
    }
    
    fn parseModule(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_defmodule);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        _ = try self.consume(.kw_def); // Temporary - should handle multiple body elements
        
        var body = ArrayList(*ASTNode).init(self.allocator);
        
        while (!self.check(.eof)) {
            if (self.check(.kw_def)) {
                const func = try self.parseFunction();
                try body.append(func);
            } else if (self.check(.kw_defmacro)) {
                const macro = try self.parseMacro();
                try body.append(macro);
            } else if (self.check(.kw_packet)) {
                const packet = try self.parsePacket();
                try body.append(packet);
            } else if (self.check(.kw_molecule)) {
                const molecule = try self.parseMolecule();
                try body.append(molecule);
            } else if (self.check(.kw_reactor)) {
                const reactor = try self.parseReactor();
                try body.append(reactor);
            } else if (self.check(.kw_node)) {
                const node = try self.parseNode();
                try body.append(node);
            } else {
                try self.advance(); // Skip unknown tokens for now
            }
        }
        
        const module_def = ModuleDef{
            .name = name,
            .body = body.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .module_def = module_def };
        return node;
    }
    
    fn parseFunction(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_def);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        var params = ArrayList([]const u8).init(self.allocator);
        
        if (self.check(.lparen)) {
            _ = try self.consume(.lparen);
            
            if (!self.check(.rparen)) {
                while (true) {
                    const param_token = try self.consume(.identifier);
                    const param = try self.allocator.dupe(u8, param_token.lexeme);
                    try params.append(param);
                    
                    if (!try self.match(&[_]TokenType{.comma})) break;
                }
            }
            
            _ = try self.consume(.rparen);
        }
        
        // Parse guards if present
        var guards: ?[]*ASTNode = null;
        if (try self.match(&[_]TokenType{.kw_when})) {
            var guard_list = ArrayList(*ASTNode).init(self.allocator);
            const guard = try self.parseExpression();
            try guard_list.append(guard);
            guards = guard_list.toOwnedSlice();
        }
        
        // Parse body
        var body = ArrayList(*ASTNode).init(self.allocator);
        const body_expr = try self.parseExpression();
        try body.append(body_expr);
        
        const func_def = FunctionDef{
            .name = name,
            .params = params.toOwnedSlice(),
            .guards = guards,
            .body = body.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .function_def = func_def };
        return node;
    }
    
    fn parseMacro(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_defmacro);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        var params = ArrayList([]const u8).init(self.allocator);
        
        if (self.check(.lparen)) {
            _ = try self.consume(.lparen);
            
            if (!self.check(.rparen)) {
                while (true) {
                    const param_token = try self.consume(.identifier);
                    const param = try self.allocator.dupe(u8, param_token.lexeme);
                    try params.append(param);
                    
                    if (!try self.match(&[_]TokenType{.comma})) break;
                }
            }
            
            _ = try self.consume(.rparen);
        }
        
        var body = ArrayList(*ASTNode).init(self.allocator);
        const body_expr = try self.parseExpression();
        try body.append(body_expr);
        
        const macro_def = MacroDef{
            .name = name,
            .params = params.toOwnedSlice(),
            .body = body.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .macro_def = macro_def };
        return node;
    }
    
    fn parsePacket(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_packet);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        _ = try self.consume(.lbrace);
        
        // Parse group
        const group_token = try self.consume(.atom);
        const group = try self.allocator.dupe(u8, group_token.lexeme[1..]); // Skip ':'
        
        _ = try self.consume(.comma);
        
        // Parse element
        const element_token = try self.consume(.atom);
        const element = try self.allocator.dupe(u8, element_token.lexeme[1..]); // Skip ':'
        
        var properties = ArrayList(*ASTNode).init(self.allocator);
        
        // Parse additional properties
        while (!self.check(.rbrace)) {
            if (try self.match(&[_]TokenType{.comma})) {
                const prop = try self.parseExpression();
                try properties.append(prop);
            } else {
                break;
            }
        }
        
        _ = try self.consume(.rbrace);
        
        const packet_def = PacketDef{
            .name = name,
            .group = group,
            .element = element,
            .properties = properties.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .packet_def = packet_def };
        return node;
    }
    
    fn parseMolecule(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_molecule);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        _ = try self.consume(.lbrace);
        
        var composition = ArrayList(*ASTNode).init(self.allocator);
        var bonds = ArrayList(*ASTNode).init(self.allocator);
        var properties = ArrayList(*ASTNode).init(self.allocator);
        
        while (!self.check(.rbrace)) {
            if (self.check(.identifier)) {
                const expr = try self.parseExpression();
                try composition.append(expr);
            }
            
            if (try self.match(&[_]TokenType{.comma})) {
                continue;
            } else {
                break;
            }
        }
        
        _ = try self.consume(.rbrace);
        
        const molecule_def = MoleculeDef{
            .name = name,
            .composition = composition.toOwnedSlice(),
            .bonds = bonds.toOwnedSlice(),
            .properties = properties.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .molecule_def = molecule_def };
        return node;
    }
    
    fn parseReactor(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_reactor);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        _ = try self.consume(.lbrace);
        
        var nodes = ArrayList(*ASTNode).init(self.allocator);
        var policies = ArrayList(*ASTNode).init(self.allocator);
        
        while (!self.check(.rbrace)) {
            const expr = try self.parseExpression();
            try nodes.append(expr);
            
            if (try self.match(&[_]TokenType{.comma})) {
                continue;
            } else {
                break;
            }
        }
        
        _ = try self.consume(.rbrace);
        
        const reactor_def = ReactorDef{
            .name = name,
            .nodes = nodes.toOwnedSlice(),
            .policies = policies.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .reactor_def = reactor_def };
        return node;
    }
    
    fn parseNode(self: *Parser) !*ASTNode {
        _ = try self.consume(.kw_node);
        const name_token = try self.consume(.identifier);
        const name = try self.allocator.dupe(u8, name_token.lexeme);
        
        _ = try self.consume(.lbrace);
        
        const spec_token = try self.consume(.atom);
        const specialization = try self.allocator.dupe(u8, spec_token.lexeme[1..]);
        
        var handlers = ArrayList(*ASTNode).init(self.allocator);
        
        while (!self.check(.rbrace)) {
            if (try self.match(&[_]TokenType{.comma})) {
                const handler = try self.parseExpression();
                try handlers.append(handler);
            } else {
                break;
            }
        }
        
        _ = try self.consume(.rbrace);
        
        const node_def = NodeDef{
            .name = name,
            .specialization = specialization,
            .handlers = handlers.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .node_def = node_def };
        return node;
    }
    
    fn parseExpression(self: *Parser) !*ASTNode {
        return self.parsePipe();
    }
    
    fn parsePipe(self: *Parser) !*ASTNode {
        var expr = try self.parseCall();
        
        while (try self.match(&[_]TokenType{.pipe})) {
            const right = try self.parseCall();
            const pipe_expr = PipeExpr{
                .left = expr,
                .right = right,
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .pipe_expr = pipe_expr };
            expr = node;
        }
        
        return expr;
    }
    
    fn parseCall(self: *Parser) !*ASTNode {
        var expr = try self.parsePrimary();
        
        while (self.check(.lparen)) {
            _ = try self.consume(.lparen);
            
            var args = ArrayList(*ASTNode).init(self.allocator);
            
            if (!self.check(.rparen)) {
                while (true) {
                    const arg = try self.parseExpression();
                    try args.append(arg);
                    
                    if (!try self.match(&[_]TokenType{.comma})) break;
                }
            }
            
            _ = try self.consume(.rparen);
            
            const call_expr = CallExpr{
                .function = expr,
                .args = args.toOwnedSlice(),
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .call_expr = call_expr };
            expr = node;
        }
        
        return expr;
    }
    
    fn parsePrimary(self: *Parser) !*ASTNode {
        if (try self.match(&[_]TokenType{.number})) {
            const value = try self.allocator.dupe(u8, self.lexer.source[self.current_token.line..self.current_token.column]);
            const literal = Literal{
                .value = value,
                .type = try self.allocator.dupe(u8, "number"),
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .literal = literal };
            return node;
        }
        
        if (try self.match(&[_]TokenType{.string})) {
            const value = try self.allocator.dupe(u8, self.current_token.lexeme);
            const literal = Literal{
                .value = value,
                .type = try self.allocator.dupe(u8, "string"),
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .literal = literal };
            return node;
        }
        
        if (try self.match(&[_]TokenType{.atom})) {
            const value = try self.allocator.dupe(u8, self.current_token.lexeme);
            const literal = Literal{
                .value = value,
                .type = try self.allocator.dupe(u8, "atom"),
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .literal = literal };
            return node;
        }
        
        if (try self.match(&[_]TokenType{.identifier})) {
            const name = try self.allocator.dupe(u8, self.current_token.lexeme);
            const identifier = Identifier{
                .name = name,
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .identifier = identifier };
            return node;
        }
        
        if (try self.match(&[_]TokenType{.kw_quote})) {
            const expr = try self.parseExpression();
            const quote_expr = QuoteExpr{
                .expr = expr,
            };
            
            const node = try self.allocator.create(ASTNode);
            node.* = ASTNode{ .quote_expr = quote_expr };
            return node;
        }
        
        if (try self.match(&[_]TokenType{.lbracket})) {
            return self.parseList();
        }
        
        if (try self.match(&[_]TokenType{.lbrace})) {
            return self.parseMap();
        }
        
        return ParseError.UnexpectedToken;
    }
    
    fn parseList(self: *Parser) !*ASTNode {
        var elements = ArrayList(*ASTNode).init(self.allocator);
        
        if (!self.check(.rbracket)) {
            while (true) {
                const element = try self.parseExpression();
                try elements.append(element);
                
                if (!try self.match(&[_]TokenType{.comma})) break;
            }
        }
        
        _ = try self.consume(.rbracket);
        
        const list = List{
            .elements = elements.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .list = list };
        return node;
    }
    
    fn parseMap(self: *Parser) !*ASTNode {
        var pairs = ArrayList(MapPair).init(self.allocator);
        
        if (!self.check(.rbrace)) {
            while (true) {
                const key = try self.parseExpression();
                _ = try self.consume(.match); // =>
                const value = try self.parseExpression();
                
                try pairs.append(MapPair{
                    .key = key,
                    .value = value,
                });
                
                if (!try self.match(&[_]TokenType{.comma})) break;
            }
        }
        
        _ = try self.consume(.rbrace);
        
        const map = Map{
            .pairs = pairs.toOwnedSlice(),
        };
        
        const node = try self.allocator.create(ASTNode);
        node.* = ASTNode{ .map = map };
        return node;
    }
};

// ============================================================================
// Code Generator
// ============================================================================

const CodeGen = struct {
    allocator: Allocator,
    output: ArrayList(u8),
    indent_level: u32,
    
    pub fn init(allocator: Allocator) CodeGen {
        return CodeGen{
            .allocator = allocator,
            .output = ArrayList(u8).init(allocator),
            .indent_level = 0,
        };
    }
    
    pub fn deinit(self: *CodeGen) void {
        self.output.deinit();
    }
    
    pub fn generate(self: *CodeGen, ast: *ASTNode) ![]u8 {
        try self.generateNode(ast);
        return self.output.toOwnedSlice();
    }
    
    fn generateNode(self: *CodeGen, node: *ASTNode) !void {
        switch (node.*) {
            .module_def => |module| try self.generateModule(&module),
            .function_def => |func| try self.generateFunction(&func),
            .macro_def => |macro| try self.generateMacro(&macro),
            .packet_def => |packet| try self.generatePacket(&packet),
            .molecule_def => |molecule| try self.generateMolecule(&molecule),
            .reactor_def => |reactor| try self.generateReactor(&reactor),
            .node_def => |n| try self.generateNodeDef(&n),
            .pipe_expr => |pipe| try self.generatePipe(&pipe),
            .call_expr => |call| try self.generateCall(&call),
            .literal => |literal| try self.generateLiteral(&literal),
            .identifier => |id| try self.generateIdentifier(&id),
            .list => |list| try self.generateList(&list),
            .map => |map| try self.generateMap(&map),
            .quote_expr => |quote| try self.generateQuote(&quote),
            else => {
                try self.output.appendSlice("// Unimplemented AST node\n");
            },
        }
    }
    
    fn generateModule(self: *CodeGen, module: *const ModuleDef) !void {
        try self.writeIndented("// Generated PacketFlow module: ");
        try self.output.appendSlice(module.name);
        try self.output.appendSlice("\n\n");
        
        try self.writeIndented("const std = @import(\"std\");\n");
        try self.writeIndented("const PacketFlow = @import(\"packetflow.zig\");\n");
        try self.writeIndented("const Allocator = std.mem.Allocator;\n\n");
        
        for (module.body) |node| {
            try self.generateNode(node);
            try self.output.appendSlice("\n");
        }
    }
    
    fn generateFunction(self: *CodeGen, func: *const FunctionDef) !void {
        try self.writeIndented("pub fn ");
        try self.output.appendSlice(func.name);
        try self.output.appendSlice("(allocator: Allocator");
        
        for (func.params) |param| {
            try self.output.appendSlice(", ");
            try self.output.appendSlice(param);
            try self.output.appendSlice(": anytype");
        }
        
        try self.output.appendSlice(") !*PacketFlow.Packet {\n");
        self.indent_level += 1;
        
        for (func.body) |stmt| {
            try self.generateNode(stmt);
            try self.output.appendSlice(";\n");
        }
        
        self.indent_level -= 1;
        try self.writeIndented("}\n");
    }
    
    fn generateMacro(self: *CodeGen, macro: *const MacroDef) !void {
        try self.writeIndented("// Macro: ");
        try self.output.appendSlice(macro.name);
        try self.output.appendSlice("\n");
        try self.writeIndented("comptime {\n");
        self.indent_level += 1;
        
        for (macro.body) |stmt| {
            try self.generateNode(stmt);
            try self.output.appendSlice(";\n");
        }
        
        self.indent_level -= 1;
        try self.writeIndented("}\n");
    }
    
    fn generatePacket(self: *CodeGen, packet: *const PacketDef) !void {
        try self.writeIndented("const ");
        try self.output.appendSlice(packet.name);
        try self.output.appendSlice(" = try PacketFlow.");
        
        // Map group to packet constructor
        if (std.mem.eql(u8, packet.group, "cf")) {
            if (std.mem.eql(u8, packet.element, "seq")) {
                try self.output.appendSlice("sequentialPacket(allocator, payload)");
            } else if (std.mem.eql(u8, packet.element, "br")) {
                try self.output.appendSlice("branchPacket(allocator, condition, true_path, false_path)");
            } else if (std.mem.eql(u8, packet.element, "lp")) {
                try self.output.appendSlice("loopPacket(allocator, condition, body, iterations)");
            }
        } else if (std.mem.eql(u8, packet.group, "df")) {
            if (std.mem.eql(u8, packet.element, "pr")) {
                try self.output.appendSlice("producerPacket(allocator, data_source)");
            } else if (std.mem.eql(u8, packet.element, "tr")) {
                try self.output.appendSlice("transformPacket(allocator, transform_fn, complexity)");
            } else if (std.mem.eql(u8, packet.element, "ag")) {
                try self.output.appendSlice("aggregatePacket(allocator, aggregation_fn, threshold)");
            }
        } else if (std.mem.eql(u8, packet.group, "ed")) {
            if (std.mem.eql(u8, packet.element, "sg")) {
                try self.output.appendSlice("signalPacket(allocator, signal_type)");
            } else if (std.mem.eql(u8, packet.element, "tm")) {
                try self.output.appendSlice("timerPacket(allocator, duration, action)");
            } else if (std.mem.eql(u8, packet.element, "pt")) {
                try self.output.appendSlice("patternPacket(allocator, pattern_def, action, complexity)");
            }
        }
        
        try self.output.appendSlice(";\n");
    }
    
    fn generateMolecule(self: *CodeGen, molecule: *const MoleculeDef) !void {
        try self.writeIndented("const ");
        try self.output.appendSlice(molecule.name);
        try self.output.appendSlice("_composition = [_]*PacketFlow.Packet{");
        
        for (molecule.composition, 0..) |comp, i| {
            if (i > 0) try self.output.appendSlice(", ");
            try self.generateNode(comp);
        }
        
        try self.output.appendSlice("};\n");
        
        try self.writeIndented("const ");
        try self.output.appendSlice(molecule.name);
        try self.output.appendSlice(" = try PacketFlow.Molecule.init(allocator, &");
        try self.output.appendSlice(molecule.name);
        try self.output.appendSlice("_composition);\n");
    }
    
    fn generateReactor(self: *CodeGen, reactor: *const ReactorDef) !void {
        try self.writeIndented("const ");
        try self.output.appendSlice(reactor.name);
        try self.output.appendSlice(" = try PacketFlow.Reactor.init(allocator);\n");
        
        for (reactor.nodes) |node| {
            try self.writeIndented("try ");
            try self.output.appendSlice(reactor.name);
            try self.output.appendSlice(".addNode(\"");
            try self.generateNode(node);
            try self.output.appendSlice("\", .general);\n");
        }
    }
    
    fn generateNodeDef(self: *CodeGen, node: *const NodeDef) !void {
        try self.writeIndented("const ");
        try self.output.appendSlice(node.name);
        try self.output.appendSlice(" = try PacketFlow.Node.init(allocator, \"");
        try self.output.appendSlice(node.name);
        try self.output.appendSlice("\", .");
        try self.output.appendSlice(node.specialization);
        try self.output.appendSlice(");\n");
    }
    
    fn generatePipe(self: *CodeGen, pipe: *const PipeExpr) !void {
        try self.generateNode(pipe.left);
        try self.output.appendSlice(" |> ");
        try self.generateNode(pipe.right);
    }
    
    fn generateCall(self: *CodeGen, call: *const CallExpr) !void {
        try self.generateNode(call.function);
        try self.output.appendSlice("(");
        
        for (call.args, 0..) |arg, i| {
            if (i > 0) try self.output.appendSlice(", ");
            try self.generateNode(arg);
        }
        
        try self.output.appendSlice(")");
    }
    
    fn generateLiteral(self: *CodeGen, literal: *const Literal) !void {
        if (std.mem.eql(u8, literal.type, "string")) {
            try self.output.appendSlice("\"");
            try self.output.appendSlice(literal.value);
            try self.output.appendSlice("\"");
        } else if (std.mem.eql(u8, literal.type, "atom")) {
            try self.output.appendSlice(".");
            try self.output.appendSlice(literal.value[1..]); // Skip ':'
        } else {
            try self.output.appendSlice(literal.value);
        }
    }
    
    fn generateIdentifier(self: *CodeGen, id: *const Identifier) !void {
        try self.output.appendSlice(id.name);
    }
    
    fn generateList(self: *CodeGen, list: *const List) !void {
        try self.output.appendSlice("[_]");
        if (list.elements.len > 0) {
            try self.output.appendSlice("*PacketFlow.Packet");
        } else {
            try self.output.appendSlice("void");
        }
        try self.output.appendSlice("{");
        
        for (list.elements, 0..) |elem, i| {
            if (i > 0) try self.output.appendSlice(", ");
            try self.generateNode(elem);
        }
        
        try self.output.appendSlice("}");
    }
    
    fn generateMap(self: *CodeGen, map: *const Map) !void {
        try self.output.appendSlice("std.HashMap([]const u8, *const anyopaque).init(allocator)");
        
        for (map.pairs) |pair| {
            try self.output.appendSlice(".put(");
            try self.generateNode(pair.key);
            try self.output.appendSlice(", ");
            try self.generateNode(pair.value);
            try self.output.appendSlice(")");
        }
    }
    
    fn generateQuote(self: *CodeGen, quote: *const QuoteExpr) !void {
        try self.output.appendSlice("// Quoted: ");
        try self.generateNode(quote.expr);
    }
    
    fn writeIndented(self: *CodeGen, text: []const u8) !void {
        for (0..self.indent_level * 4) |_| {
            try self.output.append(' ');
        }
        try self.output.appendSlice(text);
    }
};

// ============================================================================
// Macro System
// ============================================================================

const MacroEnvironment = struct {
    bindings: HashMap([]const u8, *ASTNode),
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) MacroEnvironment {
        return MacroEnvironment{
            .bindings = HashMap([]const u8, *ASTNode).init(allocator),
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *MacroEnvironment) void {
        var iterator = self.bindings.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.bindings.deinit();
    }
    
    pub fn bind(self: *MacroEnvironment, name: []const u8, value: *ASTNode) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        try self.bindings.put(owned_name, value);
    }
    
    pub fn lookup(self: *MacroEnvironment, name: []const u8) ?*ASTNode {
        return self.bindings.get(name);
    }
};

const MacroExpander = struct {
    allocator: Allocator,
    environment: MacroEnvironment,
    
    pub fn init(allocator: Allocator) MacroExpander {
        return MacroExpander{
            .allocator = allocator,
            .environment = MacroEnvironment.init(allocator),
        };
    }
    
    pub fn deinit(self: *MacroExpander) void {
        self.environment.deinit();
    }
    
    pub fn expand(self: *MacroExpander, ast: *ASTNode) !*ASTNode {
        return self.expandNode(ast);
    }
    
    fn expandNode(self: *MacroExpander, node: *ASTNode) !*ASTNode {
        switch (node.*) {
            .macro_def => |macro| {
                try self.registerMacro(&macro);
                return node;
            },
            .call_expr => |call| {
                if (call.function.* == .identifier) {
                    if (self.environment.lookup(call.function.identifier.name)) |macro_node| {
                        return self.expandMacroCall(macro_node, call.args);
                    }
                }
                return node;
            },
            .quote_expr => |quote| {
                // Don't expand inside quotes
                return node;
            },
            .unquote_expr => |unquote| {
                // Expand unquoted expressions
                return self.expandNode(unquote.expr);
            },
            else => return node,
        }
    }
    
    fn registerMacro(self: *MacroExpander, macro: *const MacroDef) !void {
        const macro_node = try self.allocator.create(ASTNode);
        macro_node.* = ASTNode{ .macro_def = macro.* };
        try self.environment.bind(macro.name, macro_node);
    }
    
    fn expandMacroCall(self: *MacroExpander, macro_node: *ASTNode, args: []*ASTNode) !*ASTNode {
        _ = self;
        _ = macro_node;
        _ = args;
        // Simplified macro expansion - would need proper pattern matching
        // and template substitution in a real implementation
        const expanded = try self.allocator.create(ASTNode);
        expanded.* = ASTNode{ 
            .identifier = Identifier{ 
                .name = try self.allocator.dupe(u8, "expanded_macro") 
            } 
        };
        return expanded;
    }
};

// ============================================================================
// Built-in Macros and Standard Library
// ============================================================================

const StandardLibrary = struct {
    pub fn registerBuiltins(expander: *MacroExpander) !void {
        try registerPipelineMacro(expander);
        try registerFaultTolerantMacro(expander);
        try registerStreamMacro(expander);
        try registerReactiveMacro(expander);
    }
    
    fn registerPipelineMacro(expander: *MacroExpander) !void {
        // defmacro pipeline(steps) do
        //   quote do
        //     steps |> Enum.reduce(&(&1 |> &2))
        //   end
        // end
        
        const macro_def = MacroDef{
            .name = try expander.allocator.dupe(u8, "pipeline"),
            .params = &[_][]const u8{try expander.allocator.dupe(u8, "steps")},
            .body = &[_]*ASTNode{}, // Simplified
        };
        
        const macro_node = try expander.allocator.create(ASTNode);
        macro_node.* = ASTNode{ .macro_def = macro_def };
        try expander.environment.bind("pipeline", macro_node);
    }
    
    fn registerFaultTolerantMacro(expander: *MacroExpander) !void {
        const macro_def = MacroDef{
            .name = try expander.allocator.dupe(u8, "fault_tolerant"),
            .params = &[_][]const u8{try expander.allocator.dupe(u8, "computation")},
            .body = &[_]*ASTNode{}, // Simplified
        };
        
        const macro_node = try expander.allocator.create(ASTNode);
        macro_node.* = ASTNode{ .macro_def = macro_def };
        try expander.environment.bind("fault_tolerant", macro_node);
    }
    
    fn registerStreamMacro(expander: *MacroExpander) !void {
        const macro_def = MacroDef{
            .name = try expander.allocator.dupe(u8, "stream"),
            .params = &[_][]const u8{
                try expander.allocator.dupe(u8, "producer"), 
                try expander.allocator.dupe(u8, "transforms"), 
                try expander.allocator.dupe(u8, "consumer")
            },
            .body = &[_]*ASTNode{}, // Simplified
        };
        
        const macro_node = try expander.allocator.create(ASTNode);
        macro_node.* = ASTNode{ .macro_def = macro_def };
        try expander.environment.bind("stream", macro_node);
    }
    
    fn registerReactiveMacro(expander: *MacroExpander) !void {
        const macro_def = MacroDef{
            .name = try expander.allocator.dupe(u8, "reactive"),
            .params = &[_][]const u8{
                try expander.allocator.dupe(u8, "triggers"), 
                try expander.allocator.dupe(u8, "actions")
            },
            .body = &[_]*ASTNode{}, // Simplified
        };
        
        const macro_node = try expander.allocator.create(ASTNode);
        macro_node.* = ASTNode{ .macro_def = macro_def };
        try expander.environment.bind("reactive", macro_node);
    }
};

// ============================================================================
// Compiler
// ============================================================================

const PacketFlowCompiler = struct {
    allocator: Allocator,
    
    pub fn init(allocator: Allocator) PacketFlowCompiler {
        return PacketFlowCompiler{
            .allocator = allocator,
        };
    }
    
    pub fn compile(self: *PacketFlowCompiler, source: []const u8) ![]u8 {
        // Lexical analysis
        var lexer = Lexer.init(self.allocator, source);
        
        // Parsing
        var parser = try Parser.init(self.allocator, &lexer);
        const ast = try parser.parse();
        defer ast.deinit(self.allocator);
        defer self.allocator.destroy(ast);
        
        // Macro expansion
        var expander = MacroExpander.init(self.allocator);
        defer expander.deinit();
        
        try
