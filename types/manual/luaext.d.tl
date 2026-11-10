-- Globals the WoW Lua 5.1 environment adds on top of the standard library.
-- (Teal already declares the standard library itself.)

-- String helpers
global strsplit: function(delimiter: string, str: string, pieces?: integer): string...
global strsplittable: function(delimiter: string, str: string, pieces?: integer): {string}
global strjoin: function(delimiter: string, ...: string): string
global strtrim: function(str: string, chars?: string): string
global strconcat: function(...: string): string
global strlenutf8: function(str: string): integer
global strcmputf8i: function(a: string, b: string): integer
global format: function(fmt: string, ...: any): string
global strlower: function(s: string): string
global strupper: function(s: string): string
global strlen: function(s: string): integer
global strsub: function(s: string, i: integer, j?: integer): string
global strfind: function(s: string, pattern: string, init?: integer, plain?: boolean): integer, integer, string...
global strmatch: function(s: string, pattern: string, init?: integer): string...
global gsub: function(s: string, pattern: string, repl: any, n?: integer): string, integer
global strrep: function(s: string, n: integer, sep?: string): string
global strbyte: function(s: string, i?: integer, j?: integer): integer...
global strchar: function(...: integer): string

-- Table helpers
global tinsert: function<T>(t: {T}, posOrValue: integer | T, value?: T)
global tremove: function<T>(t: {T}, pos?: integer): T
global wipe: function<T>(t: T): T
global tContains: function<T>(t: {T}, value: T): boolean
global tInvert: function<K, V>(t: {K:V}): {V:K}
global CopyTable: function<T>(t: T, shallow?: boolean): T

-- Math helpers
global floor: function(x: number): integer
global ceil: function(x: number): integer
global abs: function(x: number): number
global max: function(x: number, ...: number): number
global min: function(x: number, ...: number): number
global Clamp: function(value: number, min: number, max: number): number
global Round: function(value: number): integer

-- Time
global time: function(t?: table): integer
global date: function(fmt?: string, t?: integer): any
global debugprofilestop: function(): number

-- bit library (Lua BitOp)
global record bit
   band: function(...: integer): integer
   bor: function(...: integer): integer
   bxor: function(...: integer): integer
   bnot: function(a: integer): integer
   lshift: function(a: integer, n: integer): integer
   rshift: function(a: integer, n: integer): integer
   arshift: function(a: integer, n: integer): integer
   mod: function(a: integer, n: integer): integer
end

-- Misc (geterrorhandler, seterrorhandler, issecurevariable come from the generated API)
