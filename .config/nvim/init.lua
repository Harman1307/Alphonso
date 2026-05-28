vim.o.background = "dark"
vim.g.colors_name = "custom"

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.tabstop        = 4
vim.opt.shiftwidth     = 4
vim.opt.expandtab      = true
vim.opt.smartindent    = true
vim.opt.wrap           = false
vim.opt.cursorline     = true
vim.opt.termguicolors  = true
vim.opt.signcolumn     = "yes"
vim.opt.clipboard      = "unnamedplus"
vim.opt.scrolloff      = 8
vim.opt.updatetime     = 150
vim.opt.pumheight      = 12
vim.g.mapleader        = " "

vim.lsp.inlay_hint.enable(false)

local colors_path = os.getenv("HOME") .. "/.config/nvim/lua/colors.lua"

local p = {}
local applying = false

local function get_colors()
    package.loaded["colors"] = nil
    local ok, result = pcall(dofile, colors_path)
    if not ok or type(result) ~= "table" then
        return {
            bg              = "#11111b",
            surface         = "#1e1e2e",
            fg              = "#cdd6f4",
            dim             = "#6c7086",
            accent          = "#89b4fa",
            red             = "#f38ba8",
            green           = "#a6e3a1",
            yellow          = "#f9e2af",
            syntax_keyword  = "#cba6f7",
            syntax_string   = "#a6e3a1",
            syntax_func     = "#89b4fa",
            syntax_type     = "#94e2d5",
            syntax_const    = "#fab387",
            syntax_comment  = "#6c7086",
            syntax_param    = "#cdd6f4",
            syntax_operator = "#89dceb",
            dark            = true,
        }
    end
    return result
end

local function parse(hex)
    hex = hex:gsub("#", "")
    return
        tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16),
        tonumber(hex:sub(5, 6), 16)
end

local function to_hex(r, g, b)
    return string.format("#%02x%02x%02x",
        math.max(0, math.min(255, math.floor(r + 0.5))),
        math.max(0, math.min(255, math.floor(g + 0.5))),
        math.max(0, math.min(255, math.floor(b + 0.5))))
end

local function mix(a, b, t)
    local r1, g1, b1 = parse(a)
    local r2, g2, b2 = parse(b)
    return to_hex(
        r1 + (r2 - r1) * t,
        g1 + (g2 - g1) * t,
        b1 + (b2 - b1) * t)
end

local function build(raw)
    local is_dark = raw.dark ~= false

    local orange = mix(raw.red, raw.yellow, 0.50)
    local cyan   = mix(raw.accent, raw.green, 0.30)
    local purple = mix(raw.accent, raw.red, 0.40)

    local surf2, surf3, surf4

    if is_dark then
        surf2 = mix(raw.surface, raw.bg, 0.55)
        surf3 = mix(raw.surface, raw.bg, 0.25)
        surf4 = mix(raw.surface, raw.bg, 0.10)
    else
        surf2 = mix(raw.surface, raw.bg, 0.40)
        surf3 = mix(raw.surface, raw.fg, 0.88)
        surf4 = mix(raw.surface, raw.fg, 0.75)
    end

    local sel  = mix(raw.accent, raw.surface, is_dark and 0.78 or 0.82)
    local sel2 = mix(raw.accent, raw.surface, is_dark and 0.91 or 0.90)

    local sk = raw.syntax_keyword  or raw.accent
    local ss = raw.syntax_string   or raw.yellow
    local sf = raw.syntax_func     or raw.green
    local st = raw.syntax_type     or cyan
    local sc = raw.syntax_const    or raw.red
    local sp = raw.syntax_param    or raw.fg
    local so = raw.syntax_operator or raw.accent

    local syn = {
        fn_def    = sf,
        fn_call   = sf,
        type      = st,
        keyword   = sk,
        string    = ss,
        param     = sp,
        const     = sc,
        number    = sc,
        namespace = mix(st, raw.accent, 0.40),
        macro     = mix(sk, raw.accent, 0.50),
        operator  = so,
        member    = mix(sp, raw.fg, 0.35),
        decorator = mix(sk, raw.accent, 0.50),
        builtin   = sk,
        escape    = mix(sc, ss, 0.40),
        label     = sk,
        exception = raw.red,
    }

    return {
        bg      = raw.bg,
        surface = raw.surface,
        fg      = raw.fg,
        dim     = raw.dim,
        accent  = raw.accent,
        green   = raw.green,
        red     = raw.red,
        yellow  = raw.yellow,
        orange  = orange,
        cyan    = cyan,
        purple  = purple,
        fg2     = mix(raw.fg, raw.dim, 0.35),
        fg3     = mix(raw.fg, raw.dim, 0.60),
        surf2   = surf2,
        surf3   = surf3,
        surf4   = surf4,
        sel     = sel,
        sel2    = sel2,
        is_dark = is_dark,
        syn     = syn,
    }
end

local function hl(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
end

local function apply()
    if applying then return end
    applying = true

    local ok, raw = pcall(get_colors)
    if not ok then applying = false; return end

    local n = build(raw)
    for k, v in pairs(n) do p[k] = v end

    vim.g.colors_name = "custom"
    vim.cmd("hi clear")

    local s = p.syn

    local diag_base = p.surface
    local ve = mix(p.red,    diag_base, 0.82)
    local vw = mix(p.yellow, diag_base, 0.82)
    local vi = mix(p.accent, diag_base, 0.82)
    local vh = mix(p.cyan,   diag_base, 0.82)

    hl("Normal",        { fg = p.fg })
    hl("NormalNC",      { fg = p.fg2 })
    hl("NormalFloat",   { fg = p.fg,     bg = p.surface })
    hl("SignColumn",    { fg = p.dim })
    hl("FoldColumn",    { fg = p.dim })
    hl("EndOfBuffer",   { fg = p.surf4 })
    hl("LineNr",        { fg = mix(p.dim, p.bg, 0.35) })
    hl("LineNrAbove",   { fg = mix(p.dim, p.bg, 0.55) })
    hl("LineNrBelow",   { fg = mix(p.dim, p.bg, 0.55) })
    hl("CursorLine",    { bg = "NONE" })
    hl("CursorLineNr",  { fg = p.accent, bg = "NONE", bold = true })
    hl("CursorColumn",  { bg = "NONE" })
    hl("ColorColumn",   { bg = p.surf2 })
    hl("Comment",       { fg = p.dim,    italic = true })
    hl("SpecialComment",{ fg = p.dim,    italic = true })
    hl("Todo",          { fg = p.yellow, bg = mix(p.yellow, p.surface, 0.80), bold = true })

    hl("StatusLine",    { fg = p.fg2,    bg = p.surface })
    hl("StatusLineNC",  { fg = p.dim,    bg = p.surf2 })
    hl("TabLine",       { fg = p.dim,    bg = p.surf2 })
    hl("TabLineSel",    { fg = p.fg,     bg = p.surface, bold = true })
    hl("TabLineFill",   { bg = p.surf2 })

    hl("Pmenu",         { fg = p.fg2,    bg = p.surface })
    hl("PmenuSel",      { fg = p.bg,     bg = p.accent,  bold = true })
    hl("PmenuSbar",     { bg = p.surf3 })
    hl("PmenuThumb",    { bg = p.fg3 })
    hl("PmenuKind",     { fg = s.type,   bg = p.surface })
    hl("PmenuKindSel",  { fg = p.bg,     bg = p.accent })
    hl("PmenuExtra",    { fg = p.dim,    bg = p.surface })
    hl("PmenuExtraSel", { fg = p.bg,     bg = p.accent })

    hl("Visual",        { bg = p.sel })
    hl("VisualNOS",     { bg = p.sel })
    hl("Search",        { fg = p.bg,     bg = p.yellow,  bold = true })
    hl("IncSearch",     { fg = p.bg,     bg = p.orange,  bold = true })
    hl("CurSearch",     { fg = p.bg,     bg = p.orange,  bold = true })
    hl("MatchParen",    { fg = s.operator, bold = true,  underline = true })

    hl("FloatBorder",   { fg = p.surf4,  bg = p.surface })
    hl("FloatTitle",    { fg = p.accent, bg = p.surface, bold = true })
    hl("WinSeparator",  { fg = p.surf4 })
    hl("Folded",        { fg = p.dim,    bg = p.surf2,   italic = true })
    hl("NonText",       { fg = p.surf4 })
    hl("Whitespace",    { fg = p.surf4 })
    hl("SpecialKey",    { fg = p.surf4 })
    hl("QuickFixLine",  { bg = p.sel })
    hl("Directory",     { fg = p.accent, bold = true })
    hl("Title",         { fg = p.accent, bold = true })
    hl("Question",      { fg = p.green })
    hl("MoreMsg",       { fg = p.green })
    hl("ModeMsg",       { fg = p.fg,     bold = true })
    hl("WarningMsg",    { fg = p.yellow })
    hl("ErrorMsg",      { fg = p.red })
    hl("SpellBad",      { undercurl = true, sp = p.red })
    hl("SpellCap",      { undercurl = true, sp = p.yellow })
    hl("SpellRare",     { undercurl = true, sp = p.purple })
    hl("SpellLocal",    { undercurl = true, sp = p.cyan })
    hl("Conceal",       { fg = p.dim })

    hl("DiagnosticError",            { fg = p.red })
    hl("DiagnosticWarn",             { fg = p.yellow })
    hl("DiagnosticInfo",             { fg = p.accent })
    hl("DiagnosticHint",             { fg = p.cyan })
    hl("DiagnosticOk",               { fg = p.green })
    hl("DiagnosticUnderlineError",   { undercurl = true, sp = p.red })
    hl("DiagnosticUnderlineWarn",    { undercurl = true, sp = p.yellow })
    hl("DiagnosticUnderlineInfo",    { undercurl = true, sp = p.accent })
    hl("DiagnosticUnderlineHint",    { undercurl = true, sp = p.cyan })
    hl("DiagnosticVirtualTextError", { fg = p.red,    bg = ve, italic = true })
    hl("DiagnosticVirtualTextWarn",  { fg = p.yellow, bg = vw, italic = true })
    hl("DiagnosticVirtualTextInfo",  { fg = p.accent, bg = vi, italic = true })
    hl("DiagnosticVirtualTextHint",  { fg = p.cyan,   bg = vh, italic = true })
    hl("DiagnosticSignError",        { fg = p.red })
    hl("DiagnosticSignWarn",         { fg = p.yellow })
    hl("DiagnosticSignInfo",         { fg = p.accent })
    hl("DiagnosticSignHint",         { fg = p.cyan })
    hl("DiagnosticDeprecated",       { strikethrough = true, fg = p.dim })
    hl("DiagnosticUnnecessary",      { fg = p.dim,    italic = true })

    hl("Keyword",       { fg = s.keyword,   bold = true })
    hl("Statement",     { fg = s.keyword,   bold = true })
    hl("Conditional",   { fg = s.keyword,   bold = true })
    hl("Repeat",        { fg = s.keyword,   bold = true })
    hl("Exception",     { fg = s.exception, bold = true })
    hl("StorageClass",  { fg = s.keyword,   italic = true })
    hl("Type",          { fg = s.type })
    hl("Structure",     { fg = s.type,      bold = true })
    hl("Typedef",       { fg = s.type,      italic = true })
    hl("Function",      { fg = s.fn_def,    bold = true })
    hl("Identifier",    { fg = p.fg })
    hl("String",        { fg = s.string })
    hl("Character",     { fg = s.string })
    hl("SpecialChar",   { fg = s.escape,    bold = true })
    hl("Number",        { fg = s.number })
    hl("Float",         { fg = s.number })
    hl("Boolean",       { fg = s.const,     bold = true })
    hl("Constant",      { fg = s.const })
    hl("PreProc",       { fg = s.macro })
    hl("PreCondit",     { fg = s.macro })
    hl("Include",       { fg = s.macro,     bold = true })
    hl("Define",        { fg = s.macro })
    hl("Macro",         { fg = s.macro,     bold = true })
    hl("Special",       { fg = s.escape })
    hl("Operator",      { fg = s.operator })
    hl("Delimiter",     { fg = p.fg2 })
    hl("Label",         { fg = s.label })
    hl("Tag",           { fg = s.keyword })
    hl("Debug",         { fg = p.red })
    hl("Underlined",    { fg = p.accent,    underline = true })
    hl("Error",         { fg = p.red })
    hl("Ignore",        { fg = p.dim })

    hl("@keyword",                     { fg = s.keyword,   bold = true })
    hl("@keyword.type",                { fg = s.type,      bold = true })
    hl("@keyword.modifier",            { fg = s.keyword,   italic = true })
    hl("@keyword.operator",            { fg = s.operator,  bold = true })
    hl("@keyword.return",              { fg = s.exception, bold = true })
    hl("@keyword.conditional",         { fg = s.keyword,   bold = true })
    hl("@keyword.conditional.ternary", { fg = s.operator })
    hl("@keyword.repeat",              { fg = s.keyword,   bold = true })
    hl("@keyword.import",              { fg = s.macro,     bold = true })
    hl("@keyword.exception",           { fg = s.exception, bold = true })
    hl("@keyword.coroutine",           { fg = s.keyword,   italic = true })
    hl("@keyword.debug",               { fg = p.red })
    hl("@keyword.directive",           { fg = s.macro })
    hl("@keyword.directive.define",    { fg = s.macro })

    hl("@type",                        { fg = s.type })
    hl("@type.builtin",                { fg = s.type,      italic = true })
    hl("@type.definition",             { fg = s.type,      bold = true })
    hl("@type.qualifier",              { fg = s.keyword,   italic = true })

    hl("@function",                    { fg = s.fn_def,    bold = true })
    hl("@function.call",               { fg = s.fn_call })
    hl("@function.builtin",            { fg = s.builtin,   italic = true })
    hl("@function.macro",              { fg = s.macro,     bold = true })
    hl("@function.method",             { fg = s.fn_def,    bold = true })
    hl("@function.method.call",        { fg = s.fn_call })
    hl("@constructor",                 { fg = s.type,      bold = true })

    hl("@string",                      { fg = s.string })
    hl("@string.escape",               { fg = s.escape,    bold = true })
    hl("@string.special",              { fg = s.escape })
    hl("@string.special.url",          { fg = p.accent,    underline = true })
    hl("@string.special.symbol",       { fg = s.string,    italic = true })
    hl("@string.regexp",               { fg = s.escape })
    hl("@string.documentation",        { fg = p.dim,       italic = true })

    hl("@number",                      { fg = s.number })
    hl("@number.float",                { fg = s.number })
    hl("@boolean",                     { fg = s.const,     bold = true })
    hl("@constant",                    { fg = s.const })
    hl("@constant.builtin",            { fg = s.const,     bold = true, italic = true })
    hl("@constant.macro",              { fg = s.macro })

    hl("@variable",                    { fg = p.fg })
    hl("@variable.builtin",            { fg = s.builtin,   italic = true })
    hl("@variable.parameter",          { fg = s.param,     italic = true })
    hl("@variable.parameter.builtin",  { fg = s.builtin,   italic = true })
    hl("@variable.member",             { fg = s.member })
    hl("@property",                    { fg = s.member })

    hl("@operator",                    { fg = s.operator })
    hl("@punctuation",                 { fg = p.fg2 })
    hl("@punctuation.bracket",         { fg = p.fg2 })
    hl("@punctuation.delimiter",       { fg = p.fg2 })
    hl("@punctuation.special",         { fg = s.operator,  bold = true })

    hl("@comment",                     { fg = p.dim,       italic = true })
    hl("@comment.documentation",       { fg = mix(p.dim, p.accent, 0.3), italic = true })
    hl("@comment.todo",                { fg = p.yellow,    bg = mix(p.yellow, p.surface, 0.80), bold = true })
    hl("@comment.error",               { fg = p.red,       bg = mix(p.red,    p.surface, 0.82), bold = true })
    hl("@comment.warning",             { fg = p.yellow,    bg = mix(p.yellow, p.surface, 0.82), bold = true })
    hl("@comment.note",                { fg = p.cyan,      bg = mix(p.cyan,   p.surface, 0.82), bold = true })

    hl("@tag",                         { fg = s.keyword })
    hl("@tag.attribute",               { fg = s.param,     italic = true })
    hl("@tag.delimiter",               { fg = p.fg3 })
    hl("@tag.builtin",                 { fg = s.keyword,   bold = true })

    hl("@attribute",                   { fg = s.decorator })
    hl("@attribute.builtin",           { fg = s.decorator, italic = true })

    hl("@namespace",                   { fg = s.namespace, italic = true })
    hl("@module",                      { fg = s.namespace, italic = true })
    hl("@module.builtin",              { fg = s.builtin,   italic = true })
    hl("@label",                       { fg = s.label })
    hl("@preproc",                     { fg = s.macro })
    hl("@define",                      { fg = s.macro })
    hl("@include",                     { fg = s.macro,     bold = true })

    hl("@markup.heading",              { fg = p.accent,    bold = true })
    hl("@markup.heading.1",            { fg = p.accent,    bold = true })
    hl("@markup.heading.2",            { fg = s.type,      bold = true })
    hl("@markup.heading.3",            { fg = s.fn_def,    bold = true })
    hl("@markup.heading.4",            { fg = p.green,     bold = true })
    hl("@markup.heading.5",            { fg = s.macro,     bold = true })
    hl("@markup.heading.6",            { fg = s.const,     bold = true })
    hl("@markup.raw",                  { fg = s.string,    bg = p.surf2 })
    hl("@markup.raw.block",            { fg = s.string,    bg = p.surf2 })
    hl("@markup.link",                 { fg = p.accent,    underline = true })
    hl("@markup.link.label",           { fg = s.type })
    hl("@markup.link.url",             { fg = s.string,    underline = true })
    hl("@markup.italic",               { italic = true })
    hl("@markup.bold",                 { bold = true })
    hl("@markup.strikethrough",        { strikethrough = true, fg = p.dim })
    hl("@markup.quote",                { fg = p.fg2,       italic = true })
    hl("@markup.list",                 { fg = s.operator })
    hl("@markup.list.checked",         { fg = p.green })
    hl("@markup.list.unchecked",       { fg = p.dim })
    hl("@markup.math",                 { fg = s.fn_def })

    hl("@diff.plus",                   { fg = p.green,     bg = mix(p.green,  p.surface, 0.88) })
    hl("@diff.minus",                  { fg = p.red,       bg = mix(p.red,    p.surface, 0.88) })
    hl("@diff.delta",                  { fg = p.yellow,    bg = mix(p.yellow, p.surface, 0.88) })

    hl("@lsp.type.class",         { fg = s.type,      bold = true })
    hl("@lsp.type.struct",        { fg = s.type,      bold = true })
    hl("@lsp.type.enum",          { fg = s.type })
    hl("@lsp.type.enumMember",    { fg = s.const,     italic = true })
    hl("@lsp.type.interface",     { fg = s.type,      italic = true })
    hl("@lsp.type.typeParameter", { fg = s.type,      italic = true })
    hl("@lsp.type.namespace",     { fg = s.namespace, italic = true })
    hl("@lsp.type.macro",         { fg = s.macro,     bold = true })
    hl("@lsp.type.decorator",     { fg = s.decorator, italic = true })
    hl("@lsp.type.event",         { fg = s.const })
    hl("@lsp.type.regexp",        { fg = s.escape })

    hl("@lsp.mod.readonly",       { fg = s.const,   italic = true })
    hl("@lsp.mod.static",         { italic = true })
    hl("@lsp.mod.deprecated",     { strikethrough = true, fg = p.dim })
    hl("@lsp.mod.abstract",       { italic = true })
    hl("@lsp.mod.async",          { fg = s.keyword, italic = true })
    hl("@lsp.mod.defaultLibrary", { italic = true })

    hl("@lsp.type.variable",  {})
    hl("@lsp.type.parameter", {})
    hl("@lsp.type.property",  {})
    hl("@lsp.type.function",  {})
    hl("@lsp.type.method",    {})
    hl("@lsp.type.operator",  {})
    hl("@lsp.type.comment",   {})
    hl("@lsp.type.string",    {})
    hl("@lsp.type.number",    {})
    hl("@lsp.type.boolean",   {})
    hl("@lsp.type.keyword",   {})
    hl("@lsp.type.type",      {})
    hl("@lsp.type.typedef",   {})

    hl("LspReferenceText",            { bg = p.sel2 })
    hl("LspReferenceRead",            { bg = p.sel2 })
    hl("LspReferenceWrite",           { bg = p.sel2,  underline = true })
    hl("LspSignatureActiveParameter", { fg = s.param, bold = true, underline = true })
    hl("LspCodeLens",                 { fg = p.dim,   italic = true })
    hl("LspInlayHint",                { fg = mix(p.dim, p.accent, 0.3), bg = p.surf2, italic = true })

    hl("TreesitterContext",           { bg = p.surf2 })
    hl("TreesitterContextLineNumber", { fg = p.dim,   bg = p.surf2 })
    hl("TreesitterContextSeparator",  { fg = p.surf4, bg = p.surf2 })
    hl("TreesitterContextBottom",     { underline = true, sp = p.surf4 })

    hl("RainbowDelimiter1", { fg = p.accent })
    hl("RainbowDelimiter2", { fg = s.type })
    hl("RainbowDelimiter3", { fg = p.green })
    hl("RainbowDelimiter4", { fg = s.fn_def })
    hl("RainbowDelimiter5", { fg = s.macro })
    hl("RainbowDelimiter6", { fg = s.const })
    hl("RainbowDelimiter7", { fg = p.purple })

    hl("NeoTreeNormal",        { fg = p.fg })
    hl("NeoTreeNormalNC",      { fg = p.fg2 })
    hl("NeoTreeEndOfBuffer",   { fg = p.surf4 })
    hl("NeoTreeRootName",      { fg = p.accent, bold = true })
    hl("NeoTreeDirectoryName", { fg = p.fg })
    hl("NeoTreeDirectoryIcon", { fg = p.accent })
    hl("NeoTreeFileName",      { fg = p.fg2 })
    hl("NeoTreeFileIcon",      { fg = p.dim })
    hl("NeoTreeIndentMarker",  { fg = p.surf4 })
    hl("NeoTreeExpander",      { fg = p.dim })
    hl("NeoTreeGitAdded",      { fg = p.green })
    hl("NeoTreeGitModified",   { fg = p.yellow })
    hl("NeoTreeGitDeleted",    { fg = p.red })
    hl("NeoTreeGitUntracked",  { fg = p.orange, italic = true })
    hl("NeoTreeGitIgnored",    { fg = p.surf4 })
    hl("NeoTreeGitConflict",   { fg = p.red,    bold = true })
    hl("NeoTreeGitStaged",     { fg = p.green,  bold = true })
    hl("NeoTreeCursorLine",    { bg = p.surf2 })
    hl("NeoTreeDimText",       { fg = p.dim })
    hl("NeoTreeFloatBorder",   { fg = p.surf4,  bg = p.surface })
    hl("NeoTreeFloatTitle",    { fg = p.accent, bg = p.surface, bold = true })
    hl("NeoTreeTitleBar",      { fg = p.bg,     bg = p.accent,  bold = true })

    hl("TelescopeBorder",            { fg = p.surf4 })
    hl("TelescopeNormal",            { fg = p.fg })
    hl("TelescopePreviewNormal",     { fg = p.fg2 })
    hl("TelescopePromptNormal",      { fg = p.fg,     bg = p.surf2 })
    hl("TelescopePromptBorder",      { fg = p.accent, bg = p.surf2 })
    hl("TelescopePromptTitle",       { fg = p.bg,     bg = p.accent, bold = true })
    hl("TelescopeResultsTitle",      { fg = p.dim })
    hl("TelescopePreviewTitle",      { fg = p.dim })
    hl("TelescopeSelection",         { fg = p.fg,     bg = p.sel })
    hl("TelescopeSelectionCaret",    { fg = p.accent, bg = p.sel })
    hl("TelescopeMultiSelection",    { fg = p.yellow, bg = p.sel })
    hl("TelescopeMatching",          { fg = p.yellow, bold = true })
    hl("TelescopePromptPrefix",      { fg = p.accent, bg = p.surf2 })
    hl("TelescopeResultsDiffAdd",    { fg = p.green })
    hl("TelescopeResultsDiffChange", { fg = p.yellow })
    hl("TelescopeResultsDiffDelete", { fg = p.red })

    hl("AlphaHeader",   { fg = p.accent })
    hl("AlphaButtons",  { fg = p.fg2 })
    hl("AlphaShortcut", { fg = p.yellow })
    hl("AlphaFooter",   { fg = p.dim, italic = true })

    hl("GitSignsAdd",              { fg = p.green })
    hl("GitSignsChange",           { fg = p.yellow })
    hl("GitSignsDelete",           { fg = p.red })
    hl("GitSignsAddNr",            { fg = p.green })
    hl("GitSignsChangeNr",         { fg = p.yellow })
    hl("GitSignsDeleteNr",         { fg = p.red })
    hl("GitSignsAddLn",            { bg = mix(p.green,  p.surface, 0.88) })
    hl("GitSignsChangeLn",         { bg = mix(p.yellow, p.surface, 0.88) })
    hl("GitSignsDeleteLn",         { bg = mix(p.red,    p.surface, 0.88) })
    hl("GitSignsCurrentLineBlame", { fg = p.dim, italic = true })

    hl("IblIndent",     { fg = p.surf3 })
    hl("IblScope",      { fg = mix(p.accent, p.surf2, 0.72) })
    hl("IblWhitespace", { fg = p.surf3 })

    local lualine_ok, lualine = pcall(require, "lualine")
    if lualine_ok then lualine.refresh({ place = { "statusline" } }) end

    applying = false
end

local function start_watcher()
    local w = vim.uv.new_fs_event()
    w:start(colors_path, {}, function()
        w:stop()
        vim.schedule(function()
            apply()
            vim.defer_fn(apply, 150)
            vim.defer_fn(apply, 400)
            start_watcher()
        end)
    end)
end

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        if not applying then vim.schedule(apply) end
    end,
})

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    callback = function()
        vim.schedule(apply)
    end,
})

require("lazy").setup({

    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        config = function()
            require("nvim-autopairs").setup({})
        end,
    },

    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        config = function()
            require("neo-tree").setup({
                close_if_last_window = true,
                filesystem = {
                    follow_current_file = { enabled = true },
                    filtered_items = {
                        visible         = false,
                        hide_dotfiles   = false,
                        hide_gitignored = false,
                    },
                },
                window = { width = 30 },
            })
        end,
    },

    {
        "nvim-lualine/lualine.nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            local theme = { normal={}, insert={}, visual={}, replace={}, command={}, inactive={} }
            require("lualine").setup({
                options = {
                    theme = function()
                        theme.normal   = { a = { fg = p.bg, bg = p.accent,  gui = "bold" }, b = { fg = p.fg2, bg = p.surface }, c = { fg = p.dim, bg = p.surf2 } }
                        theme.insert   = { a = { fg = p.bg, bg = p.green,   gui = "bold" }, b = { fg = p.fg2, bg = p.surface }, c = { fg = p.dim, bg = p.surf2 } }
                        theme.visual   = { a = { fg = p.bg, bg = p.purple,  gui = "bold" }, b = { fg = p.fg2, bg = p.surface }, c = { fg = p.dim, bg = p.surf2 } }
                        theme.replace  = { a = { fg = p.bg, bg = p.red,     gui = "bold" }, b = { fg = p.fg2, bg = p.surface }, c = { fg = p.dim, bg = p.surf2 } }
                        theme.command  = { a = { fg = p.bg, bg = p.yellow,  gui = "bold" }, b = { fg = p.fg2, bg = p.surface }, c = { fg = p.dim, bg = p.surf2 } }
                        theme.inactive = { a = { fg = p.dim, bg = p.surf2 },                b = { fg = p.dim, bg = p.surf2 },   c = { fg = p.dim, bg = p.surf2 } }
                        return theme
                    end,
                    component_separators = { left = "", right = "" },
                    section_separators   = { left = "", right = "" },
                    globalstatus         = true,
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch", "diff", "diagnostics" },
                    lualine_c = { { "filename", path = 1 } },
                    lualine_x = { "filetype" },
                    lualine_y = { "progress" },
                    lualine_z = { "location" },
                },
            })
        end,
    },

    {
        "goolord/alpha-nvim",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            local alpha     = require("alpha")
            local dashboard = require("alpha.themes.dashboard")

            local function center_art(art)
                local max_width = 0
                for _, line in ipairs(art) do
                    local w = vim.fn.strwidth(line)
                    if w > max_width then max_width = w end
                end
                local pad = math.floor((vim.o.columns - max_width) / 2)
                if pad < 0 then pad = 0 end
                local prefix = string.rep(" ", pad)
                local result = {}
                for _, line in ipairs(art) do
                    table.insert(result, prefix .. line)
                end
                return result
            end

            local function split_lines(str)
                local lines = {}
                for line in str:gmatch("[^\n]+") do
                    table.insert(lines, line)
                end
                return lines
            end

            local raw_art = split_lines([[
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠖⠃⠀⠀⠀⡁⠀⠀⠀⠀⠀⠐⠆⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⢔⡤⠊⠁⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⠀⠀⠁⠀⠀⠘⠁⢀⠀⠀⠀⠀⢈⠓⠂⠠⡄⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣶⠿⠞⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠒⠁⠀⠠⡚⠁⢀⣙⣀⣈⡩⠬⢁⠀⢑⠶⠤⡆⠤⡀⠀⠀⠀⠀⠀⠀⢀⠴⢲⣋⣽⣷⠟⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠀⢠⠀⠀⣶⠃⠗⣡⣶⣮⣿⡿⠿⠿⢿⣿⣷⣶⣤⣤⠤⠴⠦⠬⣤⣤⠄⣉⠉⠝⢲⣿⡷⠻⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠁⡀⡸⠁⣰⣿⡿⠛⠋⣁⡀⠤⠤⢄⡀⠈⠛⢯⣿⣟⣾⣶⣶⣮⣭⣵⣾⣿⣟⠿⠉⢨⠖⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠀⢠⠳⡧⣻⡿⠋⢀⠒⠉⠀⠀⠀⠀⠀⠀⠉⠢⠀⠀⠙⠛⣻⣿⣿⣿⢿⣿⣿⠟⡱⠖⠊⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⢠⣧⠓⣾⣿⠁⠀⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⢦⣠⣾⣿⠿⣿⣿⣿⡿⣫⠏⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠂⢃⣸⣿⠇⢠⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣠⣴⣿⠟⢿⠁⠸⡿⣿⣯⡶⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⢘⡄⠘⣿⣿⠀⠸⡀⠀⠀⠀⠀⠀⢀⣀⣴⣾⣿⡿⡟⡋⠐⡇⠀⢸⣿⣿⠃⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢡⠘⢰⣿⡿⡆⠀⣇⠀⣀⣠⣤⣶⣿⢷⢟⠻⠀⠈⠀⠀⠀⡇⠀⣼⣿⣿⠂⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⢀⡴⢯⣾⠟⡏⢀⣠⣿⣿⣿⣟⢟⡋⠅⠘⠉⠀⠀⠀⠀⢀⠀⠁⢠⣿⣟⠃⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⠞⣻⣷⡿⢙⣩⣶⡿⠿⠛⠉⠑⢡⡁⠀⠀⠀⠀⠀⠀⢀⠔⠁⠀⣰⣿⣿⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣡⣾⣥⣾⢫⡦⠾⠛⠙⠉⠀⠀⢀⣀⠀⠈⠙⠓⠦⠤⠤⠀⠘⠁⢀⡤⣾⡿⠏⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠔⣴⣾⣿⣿⢟⢝⠢⠃⢀⣤⢴⣾⣮⣷⣶⢿⣶⡤⣐⡀⠀⣠⣤⢶⣪⣿⣿⡿⠟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⡀⣦⣾⡿⡛⠵⠺⢈⡠⠶⠿⠥⠥⡭⠉⠉⢱⡛⠻⠿⣿⣿⣿⣿⣿⠿⠿⠿⠟⠭⠛⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⢴⠕⣋⠝⠕⠐⠀⠔⠉⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠁⠉⠁⠁⠁⠁⠈⠀⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⢀⣠⠁⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀]])

            dashboard.section.header.val  = center_art(raw_art)
            dashboard.section.header.opts = { hl = "AlphaHeader", position = "left" }

            dashboard.section.buttons.val = {
                dashboard.button("e", "  new file",  ":ene <BAR> startinsert<CR>"),
                dashboard.button("f", "  find file", ":Telescope find_files<CR>"),
                dashboard.button("r", "  recent",    ":Telescope oldfiles<CR>"),
                dashboard.button("n", "  explorer",  ":Neotree toggle<CR>"),
                dashboard.button("q", "  quit",      ":qa<CR>"),
            }

            dashboard.section.footer.val = {}
            dashboard.config.layout = {
                { type = "padding", val = math.floor((vim.o.lines - 28) / 2) },
                dashboard.section.header,
                { type = "padding", val = 2 },
                dashboard.section.buttons,
            }

            alpha.setup(dashboard.config)

            vim.api.nvim_create_autocmd("VimResized", {
                callback = function()
                    if vim.bo.filetype == "alpha" then
                        dashboard.section.header.val = center_art(raw_art)
                        alpha.redraw()
                    end
                end,
            })
        end,
    },

    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            require("telescope").setup({
                defaults = {
                    prompt_prefix   = "  ",
                    selection_caret = " ",
                    borderchars     = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                },
            })
            require("telescope").load_extension("fzf")
        end,
    },

    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },

    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        build  = ":TSUpdate",
        config = function()
            require("nvim-treesitter").setup({
                ensure_installed = {
                    "c", "cpp",
                    "python",
                    "bash",
                    "javascript", "typescript",
                    "jsx", "tsx",
                    "html", "css",
                    "go",
                    "markdown", "markdown_inline",
                    "regex",
                    "comment",
                    "json", "jsonc",
                    "yaml", "toml",
                    "lua", "vim", "vimdoc",
                    "query",
                },
                highlight = { enable = true },
                indent    = { enable = true },
            })
        end,
    },

    {
        "nvim-treesitter/nvim-treesitter-context",
        config = function()
            require("treesitter-context").setup({
                max_lines  = 4,
                trim_scope = "outer",
                mode       = "cursor",
                separator  = "─",
            })
        end,
    },

    {
        "HiPhish/rainbow-delimiters.nvim",
        config = function()
            local rd = require("rainbow-delimiters")
            require("rainbow-delimiters.setup").setup({
                strategy = {
                    [""] = rd.strategy["global"],
                    vim  = rd.strategy["local"],
                },
                query = {
                    [""] = "rainbow-delimiters",
                    tsx  = "rainbow-parens",
                    jsx  = "rainbow-parens",
                },
                highlight = {
                    "RainbowDelimiter1",
                    "RainbowDelimiter2",
                    "RainbowDelimiter3",
                    "RainbowDelimiter4",
                    "RainbowDelimiter5",
                    "RainbowDelimiter6",
                    "RainbowDelimiter7",
                },
            })
        end,
    },

    {
        "lukas-reineke/indent-blankline.nvim",
        main = "ibl",
        config = function()
            require("ibl").setup({
                indent = { char = "│" },
                scope  = { enabled = true },
            })
        end,
    },

    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
        },
        config = function()
            require("mason").setup()
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "pyright",
                    "lua_ls",
                    "ts_ls",
                    "eslint",
                    "html",
                    "cssls",
                    "gopls",
                    "bashls",
                    "emmet_ls",
                    "jsonls",
                },
                automatic_installation = false,
            })

            vim.lsp.config("emmet_ls", {
                filetypes = {
                    "html", "css",
                    "javascript", "javascriptreact",
                    "typescript", "typescriptreact",
                },
            })

            vim.lsp.config("ts_ls", {
                settings = {
                    typescript = { inlayHints = { enabled = "off" } },
                    javascript = { inlayHints = { enabled = "off" } },
                },
                filetypes = {
                    "javascript", "javascriptreact",
                    "typescript", "typescriptreact",
                },
            })

            vim.lsp.config("pyright", {
                settings = {
                    python = {
                        analysis = {
                            typeCheckingMode       = "standard",
                            autoSearchPaths        = true,
                            useLibraryCodeForTypes = true,
                            autoImportCompletions  = true,
                        },
                    },
                },
            })

            vim.lsp.config("clangd", {
                cmd = {
                    "clangd",
                    "--background-index",
                    "--clang-tidy",
                    "--header-insertion=iwyu",
                    "--completion-style=detailed",
                    "--function-arg-placeholders",
                    "--fallback-style=llvm",
                    "--offset-encoding=utf-16",
                },
                init_options = {
                    usePlaceholders    = true,
                    completeUnimported = true,
                    clangdFileStatus   = true,
                },
                filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
            })

            vim.lsp.enable({
                "pyright", "lua_ls", "ts_ls", "eslint",
                "html", "cssls", "gopls",
                "bashls", "emmet_ls", "jsonls", "clangd",
            })

            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if not client then return end

                    if client:supports_method("textDocument/semanticTokens/full") then
                        vim.lsp.semantic_tokens.start(args.buf, args.data.client_id)
                    end

                    vim.lsp.inlay_hint.enable(false, { bufnr = args.buf })
                end,
            })
        end,
    },

    {
        "stevearc/conform.nvim",
        config = function()
            require("conform").setup({
                formatters_by_ft = {
                    cpp             = { "clang_format" },
                    c               = { "clang_format" },
                    python          = { "isort", "black" },
                    javascript      = { "prettier" },
                    typescript      = { "prettier" },
                    javascriptreact = { "prettier" },
                    typescriptreact = { "prettier" },
                    html            = { "prettier" },
                    css             = { "prettier" },
                    json            = { "prettier" },
                    yaml            = { "prettier" },
                    markdown        = { "prettier" },
                    go              = { "gofmt" },
                    sh              = { "shfmt" },
                    bash            = { "shfmt" },
                },
                format_on_save = {
                    timeout_ms   = 2000,
                    lsp_fallback = true,
                },
                formatters = {
                    clang_format = {
                        args = { "--style=file", "--fallback-style=LLVM" },
                    },
                    shfmt = {
                        args = { "-i", "4" },
                    },
                },
            })
        end,
    },

    {
        "lewis6991/gitsigns.nvim",
        config = function()
            require("gitsigns").setup({
                signs = {
                    add          = { text = "▎" },
                    change       = { text = "▎" },
                    delete       = { text = "" },
                    topdelete    = { text = "" },
                    changedelete = { text = "▎" },
                },
            })
        end,
    },

})

vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        apply()
        start_watcher()
    end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
    pattern = "*",
    command = "silent! wa",
})

vim.keymap.set("n", "<leader>w",  ":w<CR>")
vim.keymap.set("n", "<leader>q",  ":q<CR>")
vim.keymap.set("n", "<leader>e",  ":Neotree toggle<CR>")
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>")
vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>")
vim.keymap.set("n", "<leader>F",  function() require("conform").format({ async = true, lsp_fallback = true }) end)
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action)
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
vim.keymap.set("n", "gd",         vim.lsp.buf.definition)
vim.keymap.set("n", "gr",         vim.lsp.buf.references)
vim.keymap.set("n", "K",          vim.lsp.buf.hover)
vim.keymap.set("n", "[d",         vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d",         vim.diagnostic.goto_next)