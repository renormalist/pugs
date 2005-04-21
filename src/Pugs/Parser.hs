{-# OPTIONS_GHC -fglasgow-exts #-}
{-# OPTIONS_GHC -#include "UnicodeC.h" #-}

{-
    Higher-level parser for building ASTs.

    I sang of leaves, of leaves of gold, and leaves of gold there grew:
    Of wind I sang, a wind there came and in the branches blew.
    Beyond the Sun, beyond the Moon, the foam was on the Sea,
    And by the strand of Ilmarin there grew a golden Tree...
-}

module Pugs.Parser where
import Pugs.Internals
import Pugs.AST
import Pugs.Types
import Pugs.Types.Code as Code
import Pugs.Help
import Pugs.Lexer
import Pugs.Rule
import Pugs.Rule.Expr
import Pugs.Rule.Error

-- Lexical units --------------------------------------------------

ruleProgram :: RuleParser Env
ruleProgram = rule "program" $ do
    whiteSpace
    many (symbol ";")
    statements <- option [] ruleStatementList
    many (symbol ";")
    eof
    env <- getState
    return $ env { envBody = Statements statements }

ruleBlock :: RuleParser Exp
ruleBlock = lexeme ruleVerbatimBlock

ruleVerbatimBlock :: RuleParser Exp
ruleVerbatimBlock = verbatimRule "block" $ do
    body <- between (symbol "{") (char '}') ruleBlockBody
    retSyn "block" [body]

ruleBlockBody = do
    whiteSpace
    many (symbol ";")
    statements <- option [] ruleStatementList
    many (symbol ";")
    return $ Statements statements

ruleStandaloneBlock = tryRule "standalone block" $ do
    body <- bracesAlone ruleBlockBody
    retBlock SubBlock Nothing body
    where
    bracesAlone p  = between (symbol "{") closingBrace p
    closingBrace = do
        char '}'
        ruleWhiteSpaceLine

ruleStatement = do
    exp <- ruleExpression
    f <- option return $ choice
        [ rulePostConditional
        , rulePostLoop
        , rulePostIterate
        ]
    f exp

ruleStatementList :: RuleParser [(Exp, SourcePos)]
ruleStatementList = rule "statements" $ choice
    [ ruleDocBlock
    , nonSep  ruleBlockDeclaration
    , semiSep ruleDeclaration
    , nonSep  ruleConstruct
    , semiSep ruleStatement
    ]
    where
    nonSep = doSep many
    semiSep = doSep many1
    doSep count rule = do
        whiteSpace
        pos         <- getPosition
        statement   <- rule
        rest        <- option [] $ try $ do { count (symbol ";"); ruleStatementList }
        return ((statement, pos):rest)

ruleBeginOfLine = do
    pos <- getPosition
    unless (sourceColumn pos == 1) $ fail ""
    return ()

ruleDocIntroducer = (<?> "intro") $ do
    ruleBeginOfLine
    char '='

ruleDocCut = (<?> "cut") $ do
    ruleDocIntroducer
    string "cut"
    ruleWhiteSpaceLine
    return ()

ruleDocBlock = verbatimRule "Doc block" $ do
    isEnd <- try $ do
        ruleDocIntroducer
        section <- do
            c <- wordAlpha
            cs <- many $ satisfy (not . isSpace)
            return (c:cs)
        param <- option "" $ do
            satisfy isSpace
            -- XXX: drop trailing spaces?
            many $ satisfy (/= '\n')
        return (section == "begin" && param == "END")
    choice [ eof, do { many1 newline; return () } ]
    if isEnd
        then do
            many anyChar
            return []
        else do
            ruleDocBody
            whiteSpace
            option [] ruleStatementList

ruleDocBody = (try ruleDocCut) <|> eof <|> do
    many $ satisfy  (/= '\n')
    many1 newline -- XXX - paragraph mode
    ruleDocBody
    return ()

ruleQualifiedIdentifier :: RuleParser [String]
ruleQualifiedIdentifier = rule "qualified identifer" $ do
    identifier `sepBy1` (try $ string "::")

-- Declarations ------------------------------------------------

ruleBlockDeclaration :: RuleParser Exp
ruleBlockDeclaration = rule "block declaration" $ choice
    [ ruleSubDeclaration
    , ruleClosureTrait -- ???
    ]

ruleDeclaration :: RuleParser Exp
ruleDeclaration = rule "declaration" $ choice
    [ ruleModuleDeclaration
    , ruleVarDeclaration
    , ruleUseDeclaration
    , ruleInlineDeclaration
    , ruleRequireDeclaration
    ]

ruleSubHead :: RuleParser (Bool, String)
ruleSubHead = rule "subroutine head" $ do
    multi   <- option False $ do { symbol "multi" ; return True }
    symbol "sub"
    name    <- ruleSubName
    return (multi, name)

ruleSubScopedWithContext = rule "scoped subroutine with context" $ do
    scope   <- ruleScope
    cxt     <- identifier
    (multi, name) <- ruleSubHead
    return (scope, cxt, multi, name)

ruleSubScoped = rule "scoped subroutine" $ do
    scope <- ruleScope
    (multi, name) <- ruleSubHead
    return (scope, "Any", multi, name)

ruleSubGlobal = rule "global subroutine" $ do
    (multi, name) <- ruleSubHead
    return (SGlobal, "Any", multi, name)

ruleSubDeclaration :: RuleParser Exp
ruleSubDeclaration = rule "subroutine declaration" $ do
    (scope, typ, multi, name) <- tryChoice
        [ ruleSubScopedWithContext
        , ruleSubScoped
        , ruleSubGlobal
        ]
    formal  <- option Nothing $ ruleSubParameters ParensMandatory
    typ'    <- option typ $ try $ ruleBareTrait "returns"
    _       <- many $ ruleTrait -- traits; not yet used
    body    <- ruleBlock
    let (fun, names) = extract (body, [])
        params = map nameToParam (sort names) ++ (maybe [defaultArrayParam] id formal)
    -- Check for placeholder vs formal parameters
    unless (isNothing formal || null names || names == ["$_"] ) $
        fail "Cannot mix placeholder variables with formal parameters"
    env <- getState
    let subExp = Val . VCode $ Sub
            { isMulti       = multi
            , subName       = name
            , subPad        = envLexical env
            , subType       = SubRoutine
            , subAssoc      = "pre"
            , subReturns    = mkType typ'
            , subParams     = params
            , subBindings   = []
            , subFun        = fun
            }
    -- XXX: user-defined infix operator
    return $ Syn ";"
        [ Sym scope name
        , Syn ":=" [Var name, Syn "sub" [subExp]]
        ]

subNameWithPrefix prefix = (<?> "subroutine name") $ lexeme $ try $ do
    star    <- option "" $ string "*"
    c       <- wordAlpha
    cs      <- many wordAny
    return $ "&" ++ star ++ prefix ++ (c:cs)

ruleSubName = rule "subroutine name" $ do
    star    <- option "" $ string "*"
    fixity  <- option "" $ choice (map (try . string) $ words fixities)
    names   <- identifier `sepBy1` (try $ string "::")
    return $ "&" ++ star ++ fixity ++ concat (intersperse "::" names)
    where
    fixities = " prefix: postfix: infix: circumfix: "

ruleSubParameters :: ParensOption -> RuleParser (Maybe [Param])
ruleSubParameters wantParens = rule "subroutine parameters" $ do
    rv <- ruleParamList wantParens ruleFormalParam
    case rv of
        Just (invs:args:_)  -> return . Just $ map setInv invs ++ args
        _                   -> return Nothing
    where
    setInv e = e { isInvocant = True }

ruleParamList wantParens parse = rule "parameter list" $ do
    (formal, hasParens) <- f $
        ((parse `sepEndBy` symbol ",") `sepEndBy` symbol ":")
    case formal of
        [[]]   -> return $ if hasParens then Just [[], []] else Nothing
        [args] -> return $ Just [[], args]
        [_,_]  -> return $ Just formal
        _      -> fail "Only one invocant list allowed"
    where
    f = case wantParens of
        ParensOptional  -> maybeParensBool
        ParensMandatory -> \x -> do rv <- parens x; return (rv, True)

ruleFormalParam = rule "formal parameter" $ do
    cxt     <- option "" $ ruleContext
    sigil   <- option "" $ choice . map symbol $ words " ? * + ++ "
    name    <- ruleVarName -- XXX support *[...]
    trait   <- option id $ try $ do
        symbol "is"
        symbol "rw"
        return $ \x -> x { isLValue = True }
    let required = (sigil /=) `all` ["?", "+"]
    exp     <- ruleParamDefault required
    return $ trait $ buildParam cxt sigil name exp

ruleParamDefault True  = return $ Val VUndef
ruleParamDefault False = rule "default value" $ option (Val VUndef) $ do
    symbol "="
    parseLitOp

ruleVarDeclaration :: RuleParser Exp
ruleVarDeclaration = rule "variable declaration" $ do
    scope   <- ruleScope
    lhs     <- choice
        [ do name <- parseVarName
             return $ Var name
        , do names <- parens $ parseVarName `sepEndBy` symbol ","
             return $ Syn "," (map Var names)
        ]
    (sym, expMaybe) <- option ("=", Nothing) $ do
        sym <- tryChoice $ map symbol $ words " = := ::= "
        when (sym == "=") $ do
           lookAhead (satisfy (/= '='))
           return ()
        whiteSpace
        exp <- ruleExpression
        return (sym, Just exp)
    -- now match exps up with names and modify them.
    let names (Syn "," vars) = concatMap names vars
        names (Var name)     = [name]
        names exp            = error $ "invalid exp:" ++ show exp
        syn = map (Sym scope) $ names lhs
    return $ case expMaybe of
        Just exp -> Syn ";" $ syn ++ [Syn sym [lhs, exp]]
        Nothing  -> Syn ";" syn

ruleUseDeclaration :: RuleParser Exp
ruleUseDeclaration = rule "use declaration" $ do
    symbol "use"
    tryChoice [ ruleUseVersion, ruleUsePackage ]

ruleUseVersion = rule "use version" $ do
    option ' ' $ char 'v'
    version <- many1 (choice [ digit, char '.' ])
    when (version > versnum) $ do
        pos <- getPosition
        error $ "Perl v" ++ version ++ " required--this is only v" ++ versnum ++ ", stopped at " ++ (show pos)
    return $ Syn "noop" []

{-
ruleUsePackage = rule "use package" $ do
    _ <- identifier -- package -- XXX - ::
    return $ Syn "noop" []
-}

ruleUsePackage = rule "use package" $ do
    names <- identifier `sepBy1` (try $ string "::")
    _ <- option "" $ do -- version - XXX
        char '-'
        many1 (choice [ digit, char '.' ])
    return $ App "&require" [] [Val . VStr $ concat (intersperse "/" names) ++ ".pm"]

ruleInlineDeclaration = tryRule "inline declaration" $ do
    symbol "inline"
    args <- ruleExpression
    case args of
        App "&infix:=>" [Val key, Val val] [] -> do
            return $ Syn "inline" $ map (Val . VStr . vCast) [key, val]
        _ -> fail "not yet parsed"

ruleRequireDeclaration = tryRule "require declaration" $ do
    symbol "require"
    names <- identifier `sepBy1` (try $ string "::")
    _ <- option "" $ do -- version - XXX
        char '-'
        many1 (choice [ digit, char '.' ])
    return $ App "&require" [] [Val . VStr $ concat (intersperse "/" names) ++ ".pm"]

ruleModuleDeclaration = rule "module declaration" $ do
    symbol "module"
    n <- identifier `sepBy1` (try $ string "::") -- name - XXX
    v <- option "" $ do -- version - XXX
        char '-'
        str <- many1 (choice [ digit, char '.' ])
        return ('-':str)
    a <- option "" $ do -- author - XXX
        char '-'
        str <- many1 (satisfy (/= ';'))
        return ('-':str)
    return $ Syn "module" [Val . VStr $ concat (intersperse "::" n) ++ v ++ a] -- XXX

ruleClosureTrait = rule "closure trait" $ do
    name    <- tryChoice $ map symbol $ words " END "
    block   <- ruleBlock
    let (fun, names) = extract (block, [])
    -- Check for placeholder vs formal parameters
    unless (null names) $
        fail "Closure traits takes no formal parameters"
    let sub = Sub { isMulti       = False
                  , subName       = name
                  , subPad        = []
                  , subType       = SubBlock
                  , subAssoc      = "pre"
                  , subReturns    = anyType
                  , subParams     = []
                  , subBindings   = []
                  , subFun        = fun
                  }
    return $ App "&unshift" [Var "@*END"] [Syn "sub" [Val $ VCode sub]]

rulePackageDeclaration = rule "package declaration" $ fail ""

-- Constructs ------------------------------------------------

ruleConstruct = rule "construct" $ tryChoice
    [ ruleGatherConstruct
    , ruleForConstruct
    , ruleLoopConstruct
    , ruleCondConstruct
    , ruleWhileUntilConstruct
    , ruleTryConstruct
    , ruleStandaloneBlock
    , ruleGivenConstruct
    , ruleWhenConstruct
    , ruleDefaultConstruct
    ]

ruleKeywordConsturct keyword = rule (keyword ++ " construct") $ do
    symbol keyword
    block <- ruleBlock
    retSyn keyword [block]

ruleGatherConstruct = ruleKeywordConsturct "gather"

ruleTryConstruct = ruleKeywordConsturct "try"

ruleForConstruct = rule "for construct" $ do
    symbol "for"
    list  <- maybeParens ruleExpression
    block <- ruleBlockLiteral
    retSyn "for" [list, block]

ruleLoopConstruct = rule "loop construct" $ do
    symbol "loop"
    conds <- option [] $ maybeParens $ try $ do
        a <- option (Syn "noop" []) $ ruleExpression
        symbol ";"
        b <- option (Syn "noop" []) $ ruleExpression
        symbol ";"
        c <- option (Syn "noop" []) $ ruleExpression
        return [a,b,c]
    block <- ruleBlock
    -- XXX while/until
    retSyn "loop" (conds ++ [block])

ruleCondConstruct = rule "conditional construct" $ do
    csym <- choice [ symbol "if", symbol "unless" ]
    ruleCondBody $ csym

ruleCondBody csym = rule "conditional expression" $ do
    cond <- maybeParens $ ruleExpression
    body <- ruleBlock
    bodyElse <- option (Syn "noop" []) $ ruleElseConstruct
    retSyn csym [cond, body, bodyElse]

ruleElseConstruct = rule "else or elsif construct" $
    do
        symbol "else"
        ruleBlock
    <|> do
        symbol "elsif"
        ruleCondBody "if"

ruleWhileUntilConstruct = rule "while/until construct" $ do
    sym <- choice [ symbol "while", symbol "until" ]
    cond <- maybeParens $ ruleExpression
    body <- ruleBlock
    retSyn sym [ cond, body ]

ruleGivenConstruct = rule "given construct" $ do
    sym <- symbol "given"
    topic <- maybeParens $ ruleExpression
    body <- ruleBlock
    retSyn sym [ topic, body ]

ruleWhenConstruct = rule "when construct" $ do
    sym <- symbol "when"
    match <- maybeParens $ ruleExpression
    body <- ruleBlock
    retSyn sym [ match, body ]

-- XXX: make this translate into when true, when smartmatch
-- against true works
ruleDefaultConstruct = rule "default construct" $ do
    sym <- symbol "default"
    body <- ruleBlock
    retSyn sym [ body ]

-- Expressions ------------------------------------------------

ruleExpression = (<?> "expression") $ parseOp

rulePostConditional = rule "postfix conditional" $ do
    cond <- tryChoice $ map symbol ["if", "unless"]
    exp <- ruleExpression
    return $ \body -> retSyn cond [exp, body, Syn "noop" []]

rulePostLoop = rule "postfix loop" $ do
    cond <- tryChoice $ map symbol ["while", "until"]
    exp <- ruleExpression
    return $ \body -> retSyn cond [exp, body]

rulePostIterate = rule "postfix iteration" $ do
    cond <- tryChoice $ map symbol ["for"]
    exp <- ruleExpression
    return $ \body -> do
        block <- retBlock SubBlock Nothing body
        retSyn cond [exp, block]

ruleBlockLiteral = rule "block construct" $ do
    (typ, formal) <- option (SubBlock, Nothing) $ choice
        [ ruleBlockFormalPointy
        , ruleBlockFormalStandard
        ]
    body <- ruleBlock
    retBlock typ formal body

extractHash :: Exp -> Maybe Exp
extractHash (Syn "block" [exp]) = extractHash exp
extractHash (Statements [(exp@(App "&pair" _ _), _)]) = Just exp
extractHash (Statements [(exp@(App "&infix:=>" _ _), _)]) = Just exp
extractHash (Statements [(exp@(Syn "," (App "&pair" _ _:_)), _)]) = Just exp
extractHash (Statements [(exp@(Syn "," (App "&infix:=>" _ _:_)), _)]) = Just exp
extractHash _ = Nothing

retBlock SubBlock Nothing exp | Just hashExp <- extractHash exp = return $ Syn "\\{}" [hashExp]
retBlock typ formal body = do
    let (fun, names) = extract (body, [])
        params = (maybe [] id formal) ++ map nameToParam (sort names)
    -- Check for placeholder vs formal parameters
    unless (isNothing formal || null names || names == ["$_"] ) $
        fail "Cannot mix placeholder variables with formal parameters"
    let sub = Sub { isMulti       = False
                  , subName       = "<anon>"
                  , subPad        = []
                  , subType       = typ
                  , subAssoc      = "pre"
                  , subReturns    = anyType
                  , subParams     = if null params then [defaultArrayParam] else params
                  , subBindings   = []
                  , subFun        = fun
                  }
    return (Syn "sub" [Val $ VCode sub])

ruleBlockFormalStandard = rule "standard block parameters" $ do
    symbol "sub"
    params <- option Nothing $ ruleSubParameters ParensMandatory
    return $ (SubRoutine, params)

ruleBlockFormalPointy = rule "pointy block parameters" $ do
    symbol "->"
    params <- ruleSubParameters ParensOptional
    return $ (SubBlock, params)



















-- Not yet transcribed ------------------------------------------------

tightOperators = do
  (optionary, unary) <- currentUnaryFunctions
  return $
    [ methOps  " . .+ .? .* .+ .() .[] .{} .<<>> .= "   -- Method postfix
    , postOps  " ++ -- " ++ preOps " ++ -- "            -- Auto-Increment
    , rightOps " ** "                                   -- Exponentiation
    , preSyn "* **"
      ++ preOps (concatMap (\x -> " -" ++ [x]) "rwxoRWXOezsfdlpSbctugkTBMAC")
      ++ preOps " = ! + - ~ ? +^ ~^ ?^ \\ "             -- Symbolic Unary
    , leftOps $
               " »*« »/« »x« »xx« »~« " ++
               " >>*<< >>/<< >>x<< >>xx<< >>~<< " ++
               " * / % x xx +& +< +> ~& ~< ~> "         -- Multiplicative
    , leftOps  " »+« >>+<< + - ~ +| +^ ~| ~^ ?| "       -- Additive
    , listOps  " & ! "                                  -- Junctive And
    , listOps  " ^ | "                                  -- Junctive Or
    , optOps optionary, preOps unary                    -- Named Unary
    , noneSyn  " is but does "                          -- Traits
      ++ rightOps " => "                                -- Pair constructor
      ++ noneOps " cmp <=> .. ^.. ..^ ^..^ "            -- Non-chaining Binary
      ++ postOps "..."                                  -- Infinite range
    , chainOps $
               " != == < <= > >= ~~ !~ " ++
               " eq ne lt le gt ge =:= "                -- Chained Binary
    , leftOps  " && !! "                                -- Tight And
    , leftOps  " || ^^ // "                             -- Tight Or
    , [ternOp "??" "::" "if"]                           -- Ternary
    -- Assignment
    , rightSyn $
               " = := ::= " ++
               " ~= += -= *= /= %= x= Y= ¥= **= xx= ||= &&= //= ^^= " ++
               " +&= +|= +^= ~&= ~|= ~^= ?|= ?^= "
    ]

looseOperators = do
    names <- currentListFunctions
    return $
        [ preOps   names                                -- List Operator
        , leftOps  " ==> "                              -- Pipe Forward
        , leftOps  " and nor "                          -- Loose And
        , leftOps  " or xor err "                       -- Loose Or
        ]

operators = do
    tight <- tightOperators
    loose <- looseOperators
    return $ concat $
        [ tight
        , [ listSyn  " , ", listOps " Y ¥ " ]           -- Comma
        , loose
    --  , [ listSyn  " ; " ]                            -- Terminator
        ]

litOperators = do
    tight <- tightOperators
    loose <- looseOperators
    return $ tight ++ loose

currentFunctions = do
    env     <- getState
    let glob = unsafePerformIO $ readIORef $ envGlobal env
    return (glob ++ envLexical env)

currentUnaryFunctions = do
    funs <- currentFunctions
    return . mapPair munge . partition fst . sort $
        [ (opt, encodeUTF8 name) | f@(MkSym _ (MkRef (ICode code))) <- funs
        , Code.assoc code == "pre"
        , length (Code.params code) == 1
        , let param = head $ Code.params code
        , let opt   = isOptional param
        , let name  = parseName $ symName f
        -- XXX: find other MMD duplicates
        , name /= "sort", name /= "say" && name /= "print" && name /= "reverse"
        , not $ isSlurpy param
        ]
    where
    munge = unwords . map snd
    mapPair f (x, y) = (f x, f y)

parseName str
    | (_, (_:name)) <- break (== ':') str
    = name
    | otherwise
    = dropWhile (not . isAlpha) str


currentListFunctions = do
    return []
{-
    funs <- currentFunctions
    return $ unwords [
        encodeUTF8 name | f@Symbol{ symExp = Val (VCode sub) } <- funs
        , subAssoc sub == "pre"
        , isJust $ find isSlurpy $ subParams sub
        , let name = parseName $ symName f
        ]
    -- " not <== any all one none perl eval "
-}

parseOp = do
    ops <- operators
    buildExpressionParser ops parseTerm (Syn "" [])

parseTightOp = do
    ops <- tightOperators
    buildExpressionParser ops parseTerm (Syn "" [])

parseLitOp = do
    ops <- litOperators
    buildExpressionParser ops parseTerm (Syn "" [])

ops f s = [f n | n <- sortBy revLength (words $ decodeUTF8 s)]
    where
    revLength x y = compare (length y) (length x)

doApp str args = App str args []

preSyn      = ops $ makeOp1 Prefix "" Syn
preOps      = ops $ makeOp1 Prefix "&prefix:" doApp
postOps     = ops $ makeOp1 Postfix "&postfix:" doApp
optOps      = ops $ makeOp1 OptionalPrefix "&prefix:" doApp
leftOps     = ops $ makeOp2 AssocLeft "&infix:" doApp
rightOps    = ops $ makeOp2 AssocRight "&infix:" doApp
noneOps     = ops $ makeOp2 AssocNone "&infix:" doApp
listOps     = leftOps
chainOps    = leftOps
leftSyn     = ops $ makeOp2 AssocLeft "" Syn
rightSyn    = ops $ makeOp2 AssocRight "" Syn
noneSyn     = ops $ makeOp2 AssocNone "" Syn
listSyn     = ops $ makeOp0 AssocList "" Syn
chainSyn    = leftSyn

-- chainOps    = ops $ makeOpChained

makeOp1 prec sigil con name = prec $ try $ do
    symbol name
    -- `int(3)+4` should not be parsed as `int((3)+4)`
    when (isWordAny (last name)) $ do
        lookAhead (satisfy (/= '('))
        return ()
    return $ \x -> con fullName $ case x of
        Syn "" []   -> []
        _           -> [x]
    where
    fullName
        | isAlpha (head name)
        , sigil == "&prefix:"
        = ('&':name)
        | otherwise
        = sigil ++ name

makeOp2 prec sigil con name = (`Infix` prec) $ do
    symbol name
    return $ \x y -> con (sigil ++ name) [x,y]

makeOp0 prec sigil con name = (`Infix` prec) $ do
    many1 $ do
        string name
        whiteSpace
    return make
    where
    make x (Syn syn xs) | syn == name = con (sigil ++ name) (x:xs)
    make x (Syn "" []) = con (sigil ++ name) [x]
    make x y = con (sigil ++ name) [x,y]

parseTerm = rule "term" $ do
    term <- choice
        [ ruleVar
        , ruleLit
        , parseApply
        , parens ruleExpression
        ]
    fs <- many rulePostTerm
    return $ foldr (.) id (reverse fs) $ term

rulePostTerm = tryVerbatimRule "term postfix" $ do
    hasDot <- option False $ do whiteSpace; char '.'; return True
    choice $ (if hasDot then [ruleInvocation] else []) ++
        [ ruleArraySubscript
        , ruleHashSubscript
        , ruleCodeSubscript
        ]

ruleInvocation = tryVerbatimRule "invocation" $ do
    hasEqual <- option False $ do char '='; whiteSpace; return True
    name            <- ruleSubName
    (invs,args)     <- option ([],[]) $ parseParenParamList
    return $ \x -> if hasEqual
        then Syn "=" [x, App name (x:invs) args]
        else App name (x:invs) args

ruleInvocationParens = do
    hasEqual <- option False $ do char '='; whiteSpace; return True
    name            <- ruleSubName
    (invs,args)     <- parens $ parseNoParenParamList
    -- XXX we just append the adverbial block onto the end of the arg list
    -- it really goes into the *& slot if there is one. -lp
    return $ \x -> if hasEqual
        then Syn "=" [x, App name (x:invs) args]
        else App name (x:invs) args

ruleArraySubscript = tryVerbatimRule "array subscript" $ do
    symbol "["
    p <- option id $ do exp <- ruleExpression; return $ \x -> Syn "[]" [x, exp]
    char ']'
    return p

ruleHashSubscript = tryVerbatimRule "hash subscript" $ do
    choice [ ruleHashSubscriptBraces, ruleHashSubscriptQW ]

ruleHashSubscriptBraces = do
    symbol "{"
    p <- option id $ do exp <- ruleExpression; return $ \x -> Syn "{}" [x, exp]
    char '}'
    return p

ruleHashSubscriptQW = do
    exp <- angleBracketLiteral
    return $ \x -> Syn "{}" [x, exp]

ruleCodeSubscript = tryRule "code subscript" $ do
    (invs,args) <- parens $ parseParamList
    return $ \x -> Syn "()" [x, Syn "invs" invs, Syn "args" args]

parseApply = lexeme $ do
    name            <- ruleSubName
    option ' ' $ char '.'
    (invs,args)   <- parseParamList
    return $ App name invs args

parseParamList = parseParenParamList <|> parseNoParenParamList

parseParenParamList = try $ do
    params <- option Nothing $ do
        return . Just =<< parens parseNoParenParamList
    block       <- option [] ruleAdverbBlock
    when (isNothing params && null block) $ fail ""
    let (inv, norm) = maybe ([], []) id params
    -- XXX we just append the adverbial block onto the end of the arg list
    -- it really goes into the *& slot if there is one. -lp
    processFormals [inv, norm ++ block]

ruleAdverbBlock = tryRule "adverbial block" $ do
    char ':'
    rblock <- ruleBlockLiteral
    next <- option [] ruleAdverbBlock
    return (rblock:next)

parseNoParenParamList = do
    formal <- (`sepEndBy` symbol ":") $ fix $ \rec -> do
        rv <- option Nothing $ do
            return . Just =<< choice [ ruleBlockLiteral, ruleExpression ]
        case rv of
            Nothing  -> return []
            Just exp -> do
                let f = case exp of
                        Syn "sub" _ -> optional
                        _ -> (>> return ())
                rest <- option [] $ do { f $ symbol ","; rec }
                return (exp:rest)
    processFormals formal

processFormals :: Monad m => [[Exp]] -> m ([Exp], [Exp])
processFormals formal = do
    case formal of
        []                  -> return ([], [])
        [args]              -> return ([], unwind args)
        [invocants,args]    -> return (unwind invocants, unwind args)
        _                   -> fail "Only one invocant list allowed"
    where
    unwind :: [Exp] -> [Exp]
    unwind [] = []
    unwind ((Syn "," list):xs) = unwind list ++ unwind xs
    unwind x  = x

nameToParam :: String -> Param
nameToParam name = Param
    { isInvocant    = False
    , isOptional    = False
    , isNamed       = False
    , isLValue      = False
    , isThunk       = False
    , paramName     = name
    , paramContext  = case name of
        "$_" -> CxtSlurpy   $ typeOfSigil (head name)
        _    -> CxtItem $ typeOfSigil (head name)
    , paramDefault  = Val VUndef
    }

maybeParensBool p = choice
    [ do rv <- parens p; return (rv, True)
    , do rv <- p; return (rv, False)
    ]

maybeParens p = choice [ parens p, p ]
maybeDotParens p = choice [ dotParens p, p ]
    where
    dotParens rule = do
        option ' ' $ char '.'
        parens rule

parseVarName = rule "variable name" ruleVarNameString

ruleVarNameString =   try (string "$!")  -- error variable
                  <|> try (string "$/")  -- match object
                  <|> try ruleMatchVar
                  <|> do
    sigil   <- oneOf "$@%&"
    -- ^ placeholder, * global, ? magical, . member, : private member
    caret   <- option "" $ choice $ map string $ words " ^ * ? . : "
    names   <- many1 wordAny `sepBy1` (try $ string "::")
    return $ (sigil:caret) ++ concat (intersperse "::" names)

ruleMatchVar = do
    sigil   <- oneOf "$@%&"
    digits  <- many1 digit
    return $ (sigil:digits)

ruleVar = do
    name    <- ruleVarNameString
    return $ makeVar name

makeVar ('$':rest) | all (`elem` "1234567890") rest =
    Syn "[]" [Var "$/", Val $ VInt $ read rest]
makeVar var = Var var

nonTerm = do
    pos <- getPosition
    return $ NonTerm pos

ruleLit = choice
    [ ruleBlockLiteral
    , numLiteral
    , emptyListLiteral
    , emptyArrayLiteral
    , arrayLiteral
    , pairLiteral
    , undefLiteral
--    , namedLiteral "undef"  VUndef
    , namedLiteral "NaN"    (VNum $ 0/0)
    , namedLiteral "Inf"    (VNum $ 1/0)
    , dotdotdotLiteral
    , qLiteral
    , rxLiteral
    , substLiteral
    ]

undefLiteral = try $ do
    symbol "undef"
    (invs,args)   <- maybeParens $ parseParamList
    return $ if null (invs ++ args)
        then Val VUndef
        else App "&undef" invs args

numLiteral = do
    n <- naturalOrRat
    case n of
        Left  i -> return . Val $ VInt i
        Right d -> return . Val $ VRat d

emptyListLiteral = tryRule "empty list" $ do
    parens whiteSpace
    return $ Syn "," []

emptyArrayLiteral = tryRule "empty array" $ do
    brackets whiteSpace
    return $ Syn "\\[]" [emptyExp]

arrayLiteral = do
    item <- brackets ruleExpression
    return $ Syn "\\[]" [item]

pairLiteral = tryChoice [ pairArrow, pairAdverb ]

pairArrow = do
    key <- identifier
    symbol "=>"
    val <- parseTerm
    return (Val (VStr key), val)
    return $ App "&infix:=>" [Val (VStr key), val] []

pairAdverb = do
    string ":"
    key <- many1 wordAny
    val <- option (Val $ VInt 1) (valueDot <|> valueExp)
    return $ App "&infix:=>" [Val (VStr key), val] []
    where
    valueDot = do
        skipMany1 (satisfy isSpace)
        symbol "."
        option (Val $ VInt 1) $ valueExp
    valueExp = choice
        [ parens ruleExpression
        , arrayLiteral
        , angleBracketLiteral
        ]

-- Interpolating constructs
qInterpolatorChar = do
    char '\\'
    nextchar <- escapeCode -- see Lexer.hs
    return (Val $ VStr [nextchar])

qInterpolateDelimiter protectedChar = do
    char '\\'
    c <- oneOf (protectedChar:"\\")
    return (Val $ VStr [c])

qInterpolateQuoteConstruct = try $ do
    string "\\q"
    flag <- many1 alphaNum
    char '['
    expr <- interpolatingStringLiteral (char ']') (qInterpolator $ getQFlags [flag] ']')
    char ']'
    return expr

qInterpolatorPostTerm = try $ do
    option ' ' $ char '.'
    choice
        [ ruleInvocationParens
        , ruleArraySubscript
        , ruleHashSubscript
        , ruleCodeSubscript
        ]

qInterpolator :: QFlags -> RuleParser Exp
qInterpolator flags = choice [
        closure,
        backslash,
        variable
    ]
    where
        closure = if qfInterpolateClosure flags
            then ruleVerbatimBlock
            else mzero
        backslash = case qfInterpolateBackslash flags of
            'a' -> try qInterpolatorChar
               <|> (try qInterpolateQuoteConstruct)
               <|> (try $ qInterpolateDelimiter $ qfProtectedChar flags)
            's' -> try qInterpolateQuoteConstruct
               <|> (try $ qInterpolateDelimiter $ qfProtectedChar flags)
            'n' -> mzero
            _   -> fail ""
        variable = try $ do
            var <- ruleVarNameString
            fs <- case head var of
                '$' -> if qfInterpolateScalar flags &&
                          notProtected var flags
                    then many qInterpolatorPostTerm
                    else fail ""
                '@' -> if qfInterpolateArray flags
                    then many1 qInterpolatorPostTerm
                    else fail ""
                '%' -> if qfInterpolateHash flags
                    then many1 qInterpolatorPostTerm
                    else fail ""
                '&' -> if qfInterpolateFunction flags
                    then many1 qInterpolatorPostTerm
                    else fail ""
                _   -> fail ""
            return $ foldr (.) id (reverse fs) $ makeVar var
        notProtected var flags =
            if second == qfProtectedChar flags
                then False -- $ followed by delimiter is protected
                else if qfP5RegularExpression flags &&
                        second `elem` ")]# \t"
                {- XXX this doesn't support Unicode whitespace. I'm not
                   sure this is a problem, because it's primarily meant
                   for legacy Perl 5 code -}
                    then False -- $ followed by )]# or whitespace
                    else True -- $ followed by anything else is interpolated
            where second = head $ tail var

qLiteral = do -- This should include q:anything// as well as '' "" <>
    (qEnd, flags) <- getQDelim
    qLiteral1 qEnd flags

qLiteral1 :: RuleParser x -- Closing delimiter
             -> QFlags
             -> RuleParser Exp
qLiteral1 qEnd flags = do
    expr <- interpolatingStringLiteral qEnd (qInterpolator flags)
    qEnd
    case qfSplitWords flags of
        -- expr ~~ rx:perl5:g/(\S+)/
        'y' -> return $ doSplit expr
        'p' -> return $ doSplit expr
        'n' -> return expr
        _   -> fail ""
    where
    -- words() regards \xa0 as (breaking) whitespace. But \xa0 is
    -- a nonbreaking ws char.
    doSplit (Cxt (CxtItem _) (Val (VStr str))) = case perl6Words str of
        []  -> Syn "," []
        [x] -> Val (VStr x)
        xs  -> Syn "," $ map (Val . VStr) xs
    
    doSplit expr = Cxt cxtSlurpyAny $ App "&infix:~~" [expr, rxSplit] []
    rxSplit = Syn "rx" $
        [ Val $ VStr "(\\S+)"
        , Val $ VList
            [ VPair (VStr "P5", VInt 1)
            , VPair (VStr "g", VInt 1)
            ]
        ]
        
    perl6Words :: String -> [String]
    perl6Words s
      | findSpace == [] = []
      | otherwise       = w : words s''
      where
      (w, s'')  = break isBreakingSpace findSpace
      findSpace = dropWhile isBreakingSpace s
      
    isBreakingSpace('\x09') = True
    isBreakingSpace('\x0a') = True
    isBreakingSpace('\x0d') = True
    isBreakingSpace('\x20') = True
    isBreakingSpace(_)      = False

angleBracketLiteral :: RuleParser Exp
angleBracketLiteral = try $
        do
        symbol "<<"
        qLiteral1 (symbol ">>") (qqFlags { qfSplitWords = 'p', qfProtectedChar = '>' })
    <|> do
        symbol "<"
        qLiteral1 (char '>') (qFlags { qfSplitWords = 'y', qfProtectedChar = '>' })
    <|> do
        symbol "\xab"
        qLiteral1 (char '\xbb') (qFlags { qfSplitWords = 'y', qfProtectedChar = '\xbb' })

-- Quoting delimitor and flags
data QFlags = QFlags { qfSplitWords :: !Char,           -- No, Yes, Protect
                       qfInterpolateScalar :: !Bool,
                       qfInterpolateArray :: !Bool,
                       qfInterpolateHash :: !Bool,
                       qfInterpolateFunction :: !Bool,
                       qfInterpolateClosure :: !Bool,
                       qfInterpolateBackslash :: !Char, -- No, Single, All
                       qfProtectedChar :: !Char,
                       qfP5RegularExpression :: !Bool
                      {- qfProtectedChar is the character to be
                         protected by backslashes, if
                         qfInterpolateBackslash is Single or All.
                       -}
                     }

getQFlags :: [String] -> Char -> QFlags
getQFlags flagnames protectedChar =
    (foldr useflag qFlags $ reverse flagnames) { qfProtectedChar = protectedChar }
    where
        -- Additive flags
          useflag "w" qf          = qf { qfSplitWords = 'y' }
          useflag "words" qf      = qf { qfSplitWords = 'y' }
          useflag "ww" qf         = qf { qfSplitWords = 'p' }
          useflag "quotewords" qf = qf { qfSplitWords = 'p' }
          useflag "s" qf          = qf { qfInterpolateScalar = True }
          useflag "scalar" qf     = qf { qfInterpolateScalar = True }
          useflag "a" qf          = qf { qfInterpolateArray = True }
          useflag "array" qf      = qf { qfInterpolateArray = True }
          useflag "h" qf          = qf { qfInterpolateHash = True }
          useflag "hash" qf       = qf { qfInterpolateHash = True }
          useflag "f" qf          = qf { qfInterpolateFunction = True }
          useflag "function" qf   = qf { qfInterpolateFunction = True }
          useflag "c" qf          = qf { qfInterpolateClosure = True }
          useflag "closure" qf    = qf { qfInterpolateClosure = True }
          useflag "b" qf          = qf { qfInterpolateBackslash = 'a' }
          useflag "backslash" qf  = qf { qfInterpolateBackslash = 'a' }

        -- Zeroing flags
          useflag "0" _           = rawFlags
          useflag "raw" _         = rawFlags
          useflag "1" _           = qFlags
          useflag "single" _      = qFlags
          useflag "2" _           = qqFlags
          useflag "double" _      = qqFlags
          useflag "q" _           = qqFlags -- support qq//

        -- XXX What to do in case of unknown flag? Currently do nothing
          useflag _ qf            = qf

openingDelim = anyChar
{- XXX can be later defined to exclude alphanumerics, maybe also exclude
closing delims from being openers (disallow q]a]) -}

getQDelim = try $
    do  string "q"
        flags <- do
            firstflag <- many alphaNum
            allflags  <- many oneflag
            case firstflag of
                "" -> return allflags
                _  -> return $ firstflag:allflags

        notFollowedBy alphaNum
        whiteSpace
        delim <- openingDelim
        return (char $ balancedDelim delim, getQFlags flags $ balancedDelim delim)
    <|> try (do
        string "<<"
        return (
            string ">>" >> return 'x',
            qqFlags { qfSplitWords = 'p', qfProtectedChar = '>' }))
    <|> do
        delim <- oneOf "\"'<\xab"
        case delim of
            '"'     -> return (char '"',    qqFlags)
            '\''    -> return (char '\'',   qFlags)
            '<'     -> return (char '>',    qFlags { qfSplitWords = 'y', qfProtectedChar = '>' })
            '\xab'  -> return (char '\xbb', qqFlags { qfSplitWords = 'p', qfProtectedChar = '\xbb' })
            _       -> fail ""

    where
          oneflag = do string ":"
                       many alphaNum

-- Default flags
qFlags    = QFlags 'n' False False False False False 's' '\'' False
qqFlags   = QFlags 'n' True True True True True 'a' '"' False
rawFlags  = QFlags 'n' False False False False False 'n' 'x' False
rxP5Flags = QFlags 'n' True True True True True 'n' '/' True

-- Regexps
rxLiteral1 :: Char -- Closing delimiter
             -> RuleParser Exp
rxLiteral1 delim = qLiteral1 (char delim) $
        rxP5Flags { qfProtectedChar = delim }

ruleAdverbHash = do
    pairs <- many pairAdverb
    return $ Syn "\\{}" [Syn "," pairs]

substLiteral = try $ do
    symbol "s"
    adverbs <- ruleAdverbHash
    ch      <- openingDelim
    let endch = balancedDelim ch
    expr    <- rxLiteral1 endch
    ch      <- if ch == endch then return ch else do { whiteSpace ; anyChar }
    let endch = balancedDelim ch
    subst   <- qLiteral1 (char endch) qqFlags { qfProtectedChar = endch }
    return $ Syn "subst" [expr, subst, adverbs]

rxLiteral = try $ do
    symbol "rx"
    adverbs <- ruleAdverbHash
    ch      <- anyChar
    expr    <- rxLiteral1 $ balancedDelim ch
    return $ Syn "rx" [expr, adverbs]

namedLiteral n v = do { symbol n; return $ Val v }

dotdotdotLiteral = do
    pos <- getPosition
    symbol "..."
    return . Val $ VError "..." (NonTerm pos)

op_methodPostfix    = []
op_namedUnary       = []
methOps _ = []

ternOp pre post syn = (`Infix` AssocRight) $ do
    symbol pre
    y <- parseTightOp
    symbol post
    return $ \x z -> Syn syn [x, y, z]

runRule :: Env -> (Env -> a) -> RuleParser Env -> FilePath -> String -> a
runRule env f p name str = f $ case ( runParser p env name str ) of
    Left err    -> env { envBody = Val $ VError (showErr err) (NonTerm $ errorPos err) }
    Right env'  -> env'

showErr err =
      showErrorMessages "or" "unknown parse error"
                        "expecting" "unexpected" "end of input"
                       (errorMessages err)

retSyn :: String -> [Exp] -> RuleParser Exp
retSyn sym args = do
    return $ Syn sym args
    
