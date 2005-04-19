{-# OPTIONS_GHC -fglasgow-exts -cpp #-}

{-
    Runtime engine.

    The mountain throne once more is freed!
    O! Wandering folk, the summons heed!
    Come haste! Come haste! Across the waste!
    The king of friend and kin has need...
-}

module Pugs.Run where
import Pugs.Run.Args
import Pugs.Internals
import Pugs.Config
import Pugs.AST
import Pugs.Types
import Pugs.Eval
import Pugs.Prim
import qualified Data.Map as Map

runWithArgs f = do
    args <- getArgs
    f $ canonicalArgs args

runEval :: Env -> Eval Val -> IO Val
runEval env eval = withSocketsDo $ do
    my_perl <- initPerl5 ""
    val <- (`runReaderT` env) $ do
        (`runContT` return) $
            resetT eval
    freePerl5 my_perl
    return val

runEnv :: Env -> IO Val
runEnv env = runEval env $ evaluateMain (envBody env)

runAST :: Exp -> IO Val
runAST ast = do
    hSetBuffering stdout NoBuffering
    name <- getProgName
    args <- getArgs
    env  <- prepareEnv name args
    runEnv env{ envBody = ast, envDebug = Nothing }

runComp :: Eval Val -> IO Val
runComp comp = do
    hSetBuffering stdout NoBuffering
    name <- getProgName
    args <- getArgs
    env  <- prepareEnv name args
    runEval env{ envDebug = Nothing } comp

prepareEnv :: VStr -> [VStr] -> IO Env
prepareEnv name args = do
    let confHV = [ (k, VStr v) | (k, v) <- Map.toList config ]
    exec    <- getArg0
    libs    <- getLibs
    pid     <- getProcessID
    pidSV   <- newScalar (VInt $ toInteger pid)
    uid     <- getRealUserID
    uidSV   <- newScalar (VInt $ toInteger uid)
    euid    <- getEffectiveUserID
    euidSV  <- newScalar (VInt $ toInteger euid)
    gid     <- getRealGroupID
    gidSV   <- newScalar (VInt $ toInteger gid)
    egid    <- getEffectiveGroupID
    egidSV  <- newScalar (VInt $ toInteger egid)
    execSV  <- newScalar (VStr exec)
    progSV  <- newScalar (VStr name)
    modSV   <- newScalar (VStr "main")
    endAV   <- newArray []
    matchAV <- newArray []
    incAV   <- newArray (map VStr libs)
    argsAV  <- newArray (map VStr args)
    inGV    <- newHandle stdin
    outGV   <- newHandle stdout
    errGV   <- newHandle stderr
    argsGV  <- newScalar undef
    errSV   <- newScalar (VStr "")
    defSV   <- newScalar undef
#if defined(PUGS_HAVE_HSPLUGINS)
    hspluginsSV <- newScalar (VInt 1)
#else
    hspluginsSV <- newScalar (VInt 0)
#endif
    let subExit = \x -> case x of
            [x] -> op1 "exit" x
            _   -> op1 "exit" undef
    emptyEnv
        [ SymVar SGlobal "@*ARGS"       $ MkRef argsAV
        , SymVar SGlobal "@*INC"        $ MkRef incAV
        , SymVar SGlobal "$*PUGS_HAS_HSPLUGINS" $ MkRef hspluginsSV
        , SymVar SGlobal "$*EXECUTABLE_NAME"    $ MkRef execSV
        , SymVar SGlobal "$*PROGRAM_NAME"       $ MkRef progSV
        , SymVar SGlobal "$*PID"        $ MkRef pidSV
        -- XXX these four need a proper `set' magic
        , SymVar SGlobal "$*UID"        $ MkRef uidSV
        , SymVar SGlobal "$*EUID"       $ MkRef euidSV
        , SymVar SGlobal "$*GID"        $ MkRef gidSV
        , SymVar SGlobal "$*EGID"       $ MkRef egidSV
        , SymVar SGlobal "@*END"        $ MkRef endAV
        , SymVar SGlobal "$*IN"         $ MkRef inGV
        , SymVar SGlobal "$*OUT"        $ MkRef outGV
        , SymVar SGlobal "$*ERR"        $ MkRef errGV
        , SymVar SGlobal "$*ARGS"       $ MkRef argsGV
        , SymVar SGlobal "$!"           $ MkRef errSV
        , SymVar SGlobal "$/"           $ MkRef matchAV
        , SymVar SGlobal "%*ENV"        $ hashRef (undefined :: IHashEnv)
        , SymVar SGlobal "$*CWD"        $ scalarRef (undefined :: IScalarCwd)
        -- XXX What would this even do?
        -- , SymVar SGlobal "%=POD"        (Val . VHash $ emptyHV)
        , SymVar SGlobal "@=POD"        $ MkRef $ constArray []
        , SymVar SGlobal "$=POD"        $ MkRef $ constScalar (VStr "")
        , SymVar SGlobal "$?OS"         $ MkRef $ constScalar (VStr $ getConfig "osname")
        , SymVar SGlobal "$*OS"         $ MkRef $ constScalar (VStr $ getConfig "osname")
        , SymVar SGlobal "$?MODULE"     $ MkRef modSV
        , SymVar SGlobal "&?BLOCK_EXIT" $ codeRef $ Sub
            { isMulti = False
            , subName = "&?BLOCK_EXIT"
            , subType = SubPrim
            , subPad = []
            , subAssoc = "pre"
            , subParams = []
            , subBindings = []
            , subReturns = "Void"
            , subFun = Prim subExit
            }
        , SymVar SGlobal "%?CONFIG" $ hashRef confHV
        , SymVar SMy "$_" $ MkRef defSV
        , SymVar SMy "$?FILE" $ MkRef progSV
        ]



getLibs :: IO [String]
getLibs = do
    args    <- getArgs
    p6lib   <- tryIO "" (getEnv "PERL6LIB")
    return $ filter (not . null) (libs p6lib $ canonicalArgs args)
    where
    -- broken, need real parser
    inclibs ("-I":dir:rest) = [dir] ++ inclibs(rest)
    inclibs (_:rest)        = inclibs(rest)
    inclibs ([])            = []

    libs p6lib args =  (inclibs args)
              ++ (split (getConfig "path_sep") p6lib)
              ++ [ getConfig "archlib"
                 , getConfig "privlib"
                 , getConfig "sitearch"
                 , getConfig "sitelib"
                 ]
              ++ [ "." ]

