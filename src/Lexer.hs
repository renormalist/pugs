{-# OPTIONS -fglasgow-exts #-}

{-
    Lexical analyzer.

    No words were laid on stream or stone
    When Durin woke and walked alone.
    He named the nameless hills and dells;
    He drank from yet untasted wells...
-}

module Lexer where
import Internals
import AST
import Rule
import Rule.Language
import qualified Rule.Token as P

type RuleParser a = GenParser Char Env a
data ParensOption = ParensMandatory | ParensOptional
    deriving (Show, Eq)

perl6Def  = javaStyle
          { P.commentStart   = [] -- "=pod"
          , P.commentEnd     = [] -- "=cut"
          , P.commentLine    = "#"
          , P.nestedComments = False
          , P.identStart     = wordAlpha
          , P.identLetter    = wordAny
          , P.caseSensitive  = False
          }

literalIdentifier = do
    c <- wordAlpha
    cs <- many wordAny
    return (c:cs)
    
wordAlpha   = satisfy isWordAlpha <?> "alphabetic word character"
wordAny     = satisfy isWordAny <?> "word character"

isWordAny x = (isAlphaNum x || x == '_')
isWordAlpha x = (isAlpha x || x == '_')

setVar :: String -> Val -> RuleParser ()
setVar = do
    -- env <- getState
    -- let lex = envLexical env
    -- setState env{ envLexical = lex' }
    error ""

getVar :: String -> RuleParser Val
getVar = do
    -- env <- getState
    error ""    

perl6Lexer = P.makeTokenParser perl6Def
whiteSpace = P.whiteSpace perl6Lexer
parens     = P.parens perl6Lexer
lexeme     = P.lexeme perl6Lexer
identifier = P.identifier perl6Lexer
braces     = P.braces perl6Lexer
brackets   = P.brackets perl6Lexer
angles     = P.angles perl6Lexer
balanced   = P.balanced perl6Lexer
balancedDelim = P.balancedDelim perl6Lexer
decimal    = P.decimal perl6Lexer

ruleWhiteSpaceLine = do
    many $ satisfy (\x -> isSpace x && x /= '\n')
    ruleEndOfLine
   
ruleEndOfLine = choice [ do { char '\n'; return () }, eof ]

symbol s
    | isWordAny (last s) = try $ do
        rv <- string s
        choice [ eof >> return ' ', lookAhead (satisfy (not . isWordAny)) ]
        whiteSpace
        return rv
    | otherwise          = try $ do
        rv <- string s
        -- XXX Wrong - the correct solution is to lookahead as much as possible
        -- in the expression parser below
        choice [ eof >> return ' ', lookAhead (satisfy (ahead $ last s)) ]
        whiteSpace
        return rv
        where
        ahead '-' '>' = False -- XXX hardcoke
        ahead '!' '~' = False -- XXX hardcoke
        ahead x   '=' = not (x `elem` "!~+-*/")
        ahead s   x   = x `elem` ";!" || x /= s

stringLiteral = singleQuoted

interpolatingStringLiteral endchar interpolator = do
        list <- stringList
        return $ Syn "cxt" [Val (VStr "Str"), homogenConcat list]
    where
        homogenConcat :: [Exp] -> Exp
        homogenConcat []             = Val (VStr "")
        homogenConcat [x]            = App "&infix:~" [x, Val (VStr "")] []
        homogenConcat (Val (VStr x):Val (VStr y):xs) = homogenConcat (Val (VStr (x ++ y)) : xs)
        homogenConcat (x:y:xs)       = App "&infix:~" [x, homogenConcat (y:xs)] []
        
        stringList = do
            lookAhead (char endchar)
            return []
          <|> do
            parse <- interpolator
            rest  <- stringList
            return (parse:rest)
          <|> do
            char <- anyChar
            rest <- stringList
            return (Val (VStr [char]):rest)
        

naturalOrRat  = natRat
    <?> "number"
    where
    natRat = do
            char '0'
            zeroNumRat
        <|> decimalRat
                      
    zeroNumRat = do
            n <- hexadecimal <|> decimal <|> octalBad <|> octal <|> binary
            return (Left n)
        <|> decimalRat
        <|> fractRat 0
        <|> return (Left 0)                  
                      
    decimalRat = do
        n <- decimalLiteral
        option (Left n) (try $ fractRat n)

    fractRat n = do
            fract <- try fraction
            expo  <- option (1%1) expo
            return (Right $ ((n % 1) + fract) * expo) -- Right is Rat
        <|> do
            expo <- expo
            if expo < 1
                then return (Right $ (n % 1) * expo)
                else return (Right $ (n % 1) * expo)

    fraction = do
            char '.'
            try $ do { char '.'; unexpected "dotdot" } <|> return ()
            digits <- many digit <?> "fraction"
            return (digitsToRat digits)
        <?> "fraction"
        where
        digitsToRat d = digitsNum d % (10 ^ length d)
        digitsNum d = foldl (\x y -> x * 10 + (toInteger $ digitToInt y)) 0 d 

    expo :: GenParser Char st Rational
    expo = do
            oneOf "eE"
            f <- sign
            e <- decimalLiteral <?> "exponent"
            return (power (if f then e else -e))
        <?> "exponent"
        where
        power e | e < 0      = 1 % (10^abs(e))
                | otherwise  = (10^e) % 1

    -- sign            :: CharParser st (Integer -> Integer)
    sign            =   (char '-' >> return False) 
                    <|> (char '+' >> return True)
                    <|> return True

{-
    nat             = zeroNumber <|> decimalLiteral
        
    zeroNumber      = do{ char '0'
                        ; hexadecimal <|> decimal <|> octalBad <|> octal <|> decimalLiteral <|> return 0
                        }
                      <?> ""       
-}

    decimalLiteral         = number 10 digit        
    hexadecimal     = do{ char 'x'; number 16 hexDigit }
    decimal         = do{ char 'd'; number 10 digit }
    octal           = do{ char 'o'; number 8 octDigit }
    octalBad        = do{ many1 octDigit ; fail "0100 is not octal in perl6 any more, use 0o100 instead." }
    binary          = do{ char 'b'; number 2 (oneOf "01")  }

    -- number :: Integer -> CharParser st Char -> CharParser st Integer
    number base baseDigit
        = do{ digits <- many1 baseDigit
            ; let n = foldl (\x d -> base*x + toInteger (digitToInt d)) 0 digits
            ; seq n (return n)
            }          


singleQuoted = verbatimRule "literal string" $ do
    str <- between (char '\'') (char '\'' <?> "end of string") (many singleStrChar)
    return (foldr (id (:)) "" str)

singleStrChar = try quotedQuote <|> noneOf "'"

-- backslahed nonalphanumerics (except for ^) translate into themselves
escapeCode      = charEsc <|> charNum <|> charAscii <|> charControl <|> anyChar
                <?> "escape code"

-- charControl :: CharParser st Char
charControl     = do{ char '^'
                    ; code <- upper
                    ; return (toEnum (fromEnum code - fromEnum 'A'))
                    }

-- charNum :: CharParser st Char                    
charNum         = do{ code <- decimal 
                              <|> do{ char 'o'; number 8 octDigit }
                              <|> do{ char 'x'; number 16 hexDigit }
                              <|> do{ char 'd'; number 10 digit }
                    ; return (toEnum (fromInteger code))
                    }

number base baseDigit
    = do{ digits <- many1 baseDigit
        ; let n = foldl (\x d -> base*x + toInteger (digitToInt d)) 0 digits
        ; seq n (return n)
        }          

charEsc         = choice (map parseEsc escMap)
                where
                  parseEsc (c,code)     = do{ char c; return code }
                  
charAscii       = choice (map parseAscii asciiMap)
                where
                  parseAscii (asc,code) = try (do{ string asc; return code })


-- escape code tables
escMap          = zip ("abfnrtv\\\"\'") ("\a\b\f\n\r\t\v\\\"\'")
asciiMap        = zip (ascii3codes ++ ascii2codes) (ascii3 ++ ascii2) 

ascii2codes     = ["BS","HT","LF","VT","FF","CR","SO","SI","EM",
                   "FS","GS","RS","US","SP"]
ascii3codes     = ["NUL","SOH","STX","ETX","EOT","ENQ","ACK","BEL",
                   "DLE","DC1","DC2","DC3","DC4","NAK","SYN","ETB",
                   "CAN","SUB","ESC","DEL"]

ascii2          = ['\BS','\HT','\LF','\VT','\FF','\CR','\SO','\SI',
                   '\EM','\FS','\GS','\RS','\US','\SP']
ascii3          = ['\NUL','\SOH','\STX','\ETX','\EOT','\ENQ','\ACK',
                   '\BEL','\DLE','\DC1','\DC2','\DC3','\DC4','\NAK',
                   '\SYN','\ETB','\CAN','\SUB','\ESC','\DEL']

quotedQuote = do
    string "\\'"
    return '\''

rule name action = (<?> name) $ lexeme $ action

verbatimRule name action = (<?> name) $ action

literalRule name action = (<?> name) $ postSpace $ action

tryRule name action = (<?> name) $ lexeme $ try action

tryVerbatimRule name action = (<?> name) $ try action

ruleScope :: RuleParser Scope
ruleScope = tryRule "scope" $ do
    scope <- choice $ map symbol scopes
    return (readScope scope)
    where
    scopes = map (map toLower) $ map (tail . show) $ enumFrom ((toEnum 1) :: Scope)
    readScope s
        | (c:cs)    <- s
        , [(x, _)]  <- reads ('S':toUpper c:cs)
        = x
        | otherwise
        = SGlobal

postSpace rule = try $ do
    rv <- rule
    notFollowedBy wordAny
    whiteSpace
    return rv

ruleTrait = do
    symbol "is"
    trait <- identifier
    return trait

ruleTraitName trait = do
    symbol "is"
    symbol trait
    identifier

ruleBareTrait trait = do
    choice [ ruleTraitName trait
           , do { symbol trait ; identifier }
           ]

ruleContext = literalRule "context" $ do
    lead    <- upper
    rest    <- many1 wordAny
    return (lead:rest)

ruleVarName = literalRule "variable name" $ do
    sigil   <- oneOf "$@%&"
    caret   <- option "" $ choice $ map string $ words " ^ * ? "
    name    <- many1 wordAny
    return $ (sigil:caret) ++ name

tryChoice = choice . map try

-- Expression Parser below, adapted from Parsec's Expr.hs ---

-----------------------------------------------------------------------------
-- Module      :  Text.ParserCombinators.Parsec.Expr
-- Copyright   :  (c) Daan Leijen 1999-2001
-- License     :  BSD-style (see the file libraries/parsec/LICENSE)
-----------------------------------------------------------------------------

-----------------------------------------------------------
-- Assoc and OperatorTable
-----------------------------------------------------------
data Assoc                = AssocNone 
                          | AssocLeft
                          | AssocRight
                          | AssocList
                          | AssocChain
                        
data Operator t st a      = Infix (GenParser t st (a -> a -> a)) Assoc
                          | Prefix (GenParser t st (a -> a))
                          | Postfix (GenParser t st (a -> a))

type OperatorTable t st a = [[Operator t st a]]



-----------------------------------------------------------
-- Convert an OperatorTable and basic term parser into
-- a full fledged expression parser
-----------------------------------------------------------
buildExpressionParser :: OperatorTable tok st a -> GenParser tok st a -> GenParser tok st a
buildExpressionParser operators simpleExpr
    = foldl (makeParser) simpleExpr operators
    where
      makeParser term ops
        = let (rassoc,lassoc,nassoc
               ,prefix,postfix)      = foldr splitOp ([],[],[],[],[]) ops
              
              rassocOp   = choice rassoc
              lassocOp   = choice lassoc
              nassocOp   = choice nassoc
              prefixOp   = choice prefix  <?> ""
              postfixOp  = choice postfix <?> ""
              
              ambigious assoc op= try $
                                  do{ op; fail ("ambiguous use of a " ++ assoc 
                                                 ++ " associative operator")
                                    }
              
              ambigiousRight    = ambigious "right" rassocOp
              ambigiousLeft     = ambigious "left" lassocOp
              ambigiousNon      = ambigious "non" nassocOp 

              foldOp = foldr (.) id
              
              termP = do
                pres    <- many prefixOp
                x       <- term
                posts   <- many postfixOp
                return $ foldOp posts $ foldOp pres x
              
              rassocP x  = do{ f <- rassocOp
                             ; y  <- do{ z <- termP; rassocP1 z }
                             ; return (f x y)
                             }
                           <|> ambigiousLeft
                           <|> ambigiousNon
                           -- <|> return x
                           
              rassocP1 x = rassocP x  <|> return x                           
                           
              lassocP x  = do{ f <- lassocOp
                             ; y <- termP
                             ; lassocP1 (f x y)
                             }
                           <|> ambigiousRight
                           <|> ambigiousNon
                           -- <|> return x
                           
              lassocP1 x = lassocP x <|> return x                           
                           
              nassocP x  = do{ f <- nassocOp
                             ; y <- termP
                             ;    ambigiousRight
                              <|> ambigiousLeft
                              <|> ambigiousNon
                              <|> return (f x y)
                             }                                                          
                           -- <|> return x                                                      
                           
           in  do{ x <- termP
                 ; rassocP x <|> lassocP  x <|> nassocP x <|> return x
                   <?> "operator"
                 }
                

      splitOp (Infix op assoc) (rassoc,lassoc,nassoc,prefix,postfix)
        = case assoc of
            AssocNone  -> (rassoc,lassoc,op:nassoc,prefix,postfix)
            AssocLeft  -> (rassoc,op:lassoc,nassoc,prefix,postfix)
            AssocRight -> (op:rassoc,lassoc,nassoc,prefix,postfix)
            _          -> internalError "splitOp: unimplemented assoc type."
            -- FIXME: add two new assoc types here.
            
      splitOp (Prefix op) (rassoc,lassoc,nassoc,prefix,postfix)
        = (rassoc,lassoc,nassoc,op:prefix,postfix)
        
      splitOp (Postfix op) (rassoc,lassoc,nassoc,prefix,postfix)
        = (rassoc,lassoc,nassoc,prefix,op:postfix)
      
