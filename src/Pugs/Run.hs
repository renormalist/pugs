{-# OPTIONS_GHC -fglasgow-exts -fno-full-laziness -fno-cse -cpp #-}


{-|
    Runtime engine.

>   The mountain throne once more is freed!
>   O! Wandering folk, the summons heed!
>   Come haste! Come haste! Across the waste!
>   The king of friend and kin has need...
-}

module Pugs.Run (
    runWithArgs,
    prepareEnv, runEnv,
    runAST, runComp,
    getLibs,
    -- mutable global storage
    _BypassPreludePC, _GlobalFinalizer,
) where
import Pugs.Run.Args
import Pugs.Run.Perl5 ()
import Pugs.Internals
import Pugs.Config
import Pugs.AST
import Pugs.Types
import Pugs.Eval
import Pugs.Prim
import Pugs.Prim.Eval
import Pugs.Embed
import Pugs.Prelude 
import Data.IORef
import System.FilePath
import qualified Data.Map as Map
import qualified Data.ByteString as Str
import DrIFT.YAML
import Data.Yaml.Syck
--import Data.Generics.Schemes
import System.IO


{-|
Run 'Main.run' with command line args. 

See 'Main.main' and 'Pugs.Run.Args.canonicalArgs'
-}
runWithArgs :: ([String] -> IO t) -> IO t
runWithArgs f = do
    args <- getArgs
    f $ canonicalArgs args

runEvalMain :: Env -> Eval Val -> IO Val
runEvalMain env eval = withSocketsDo $ do
    val     <- runEvalIO env eval
    -- freePerl5 my_perl
    liftIO performGC
    return val

runEnv :: Env -> IO Val
runEnv env = runEvalMain env $ evaluateMain (envBody env)

-- | Run for 'Pugs.Compile.Pugs' backend
runAST :: Pad -> Exp -> IO Val
runAST glob ast = do
    hSetBuffering stdout NoBuffering
    name    <- getProgName
    args    <- getArgs
    env     <- prepareEnv name args
    globRef <- liftSTM $ do
        glob' <- readTVar $ envGlobal env
        newTVar (glob `unionPads` glob')
    runEnv env{ envBody = ast, envGlobal = globRef, envDebug = Nothing }

-- | Run for 'Pugs.Compile.Haskell' backend
runComp :: Eval Val -> IO Val
runComp comp = do
    hSetBuffering stdout NoBuffering
    name <- getProgName
    args <- getArgs
    env  <- prepareEnv name args
    runEvalMain env{ envDebug = Nothing } comp

-- | Initialize globals and install primitives in an 'Env'
prepareEnv :: VStr -> [VStr] -> IO Env
prepareEnv name args = do
    let confHV = Map.map VStr config
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
    checkAV <- newArray []
    initAV  <- newArray []
    endAV   <- newArray []
    matchAV <- newScalar (VMatch mkMatchFail)
    incAV   <- newArray (map VStr libs)
    incHV   <- newHash Map.empty
    argsAV  <- newArray (map VStr args)
    inGV    <- newHandle stdin
    outGV   <- newHandle stdout
    errGV   <- newHandle stderr
    argsGV  <- newScalar undef
    errSV   <- newScalar (VStr "")
    defSV   <- newScalar undef
    autoSV  <- newScalar undef
    classes <- initClassObjects (-1) [] initTree
#if defined(PUGS_HAVE_HSPLUGINS)
    hspluginsSV <- newScalar (VInt 1)
#else
    hspluginsSV <- newScalar (VInt 0)
#endif
    let subExit = \x -> case x of
            [x] -> op1Exit x     -- needs refactoring (out of Prim)
            _   -> op1Exit undef
    env <- emptyEnv name $
        [ genSym "@*ARGS"       $ hideInSafemode $ MkRef argsAV
        , genSym "@*INC"        $ hideInSafemode $ MkRef incAV
        , genSym "%*INC"        $ hideInSafemode $ MkRef incHV
        , genSym "$*PUGS_HAS_HSPLUGINS" $ hideInSafemode $ MkRef hspluginsSV
        , genSym "$*EXECUTABLE_NAME"    $ hideInSafemode $ MkRef execSV
        , genSym "$*PROGRAM_NAME"       $ hideInSafemode $ MkRef progSV
        , genSym "$*PID"        $ hideInSafemode $ MkRef pidSV
        -- XXX these four need a proper `set' magic
        , genSym "$*UID"        $ hideInSafemode $ MkRef uidSV
        , genSym "$*EUID"       $ hideInSafemode $ MkRef euidSV
        , genSym "$*GID"        $ hideInSafemode $ MkRef gidSV
        , genSym "$*EGID"       $ hideInSafemode $ MkRef egidSV
        , genSym "@*CHECK"      $ MkRef checkAV
        , genSym "@*INIT"       $ MkRef initAV
        , genSym "@*END"        $ MkRef endAV
        , genSym "$*IN"         $ hideInSafemode $ MkRef inGV
        , genSym "$*OUT"        $ hideInSafemode $ MkRef outGV
        , genSym "$*ERR"        $ hideInSafemode $ MkRef errGV
        , genSym "$*ARGS"       $ hideInSafemode $ MkRef argsGV
        , genSym "$!"           $ MkRef errSV
        , genSym "$/"           $ MkRef matchAV
        , genSym "%*ENV"        $ hideInSafemode $ hashRef MkHashEnv
        , genSym "$*CWD"        $ hideInSafemode $ scalarRef MkScalarCwd
        -- XXX What would this even do?
        -- , genSym "%=POD"        (Val . VHash $ emptyHV)
        , genSym "@=POD"        $ MkRef $ constArray []
        , genSym "$=POD"        $ MkRef $ constScalar (VStr "")
        -- To answer the question "what revision does evalbot run on?"
        , genSym "$?PUGS_VERSION" $ MkRef $ constScalar (VStr $ getConfig "pugs_version")
        -- If you change the name or contents of $?PUGS_BACKEND, be sure
        -- to update all t/ and perl5/{PIL2JS,PIL-Run} as well.
        , genSym "$?PUGS_BACKEND" $ MkRef $ constScalar (VStr "BACKEND_PUGS")
        , genSym "$*OS"         $ hideInSafemode $ MkRef $ constScalar (VStr $ getConfig "osname")
        , genSym "&?BLOCK_EXIT" $ codeRef $ mkPrim
            { subName = "&?BLOCK_EXIT"
            , subBody = Prim subExit
            }
        , genSym "%?CONFIG" $ hideInSafemode $ hashRef confHV
        , genSym "$*_" $ MkRef defSV
        , genSym "$*AUTOLOAD" $ MkRef autoSV
        ] ++ classes
    -- defSVcell <- (genSym "$_" . MkRef) =<< newScalar undef
    let env' = env
    {-
            { envLexical  = defSVcell (envLexical env)
            , envImplicit = Map.singleton "$_" ()
            }
    -}
    unless safeMode $ do
        initPerl5 "" (Just . VControl $ ControlEnv env'{ envDebug = Nothing })
        return ()
    initPreludePC env'             -- null in first pass
    where
    hideInSafemode x = if safeMode then MkRef $ constScalar undef else x

initClassObjects :: ObjectId -> [Type] -> ClassTree -> IO [STM PadMutator]
initClassObjects uniq parent (Node typ children) = do
    obj     <- createObjectRaw uniq Nothing (mkType "Class")
        [ ("name",   castV $ showType typ)
        , ("traits", castV $ map showType parent)
        ]
    objSV   <- newScalar (VObject obj)
    rest    <- mapM (initClassObjects (pred uniq) [typ]) children
    let metaSym = genSym (':':'*':name) $ MkRef objSV
        codeSym = genMultiSym ('&':'*':name) $ codeRef (typeSub name)
        name    = showType typ
    return (metaSym:codeSym:concat rest)

{-|
Combine @%*ENV\<PERL6LIB\>@, -I, 'Pugs.Config.config' values and \".\" into the
@\@*INC@ list for 'Main.printConfigInfo'. If @%*ENV\<PERL6LIB\>@ is not set,
@%*ENV\<PERLLIB\>@ is used instead.
-}
getLibs :: IO [String]
getLibs = do
    args    <- getArgs
    p6lib   <- (getEnv "PERL6LIB") >>= (return . (fromMaybe ""))
    plib    <- (getEnv "PERLLIB")  >>= (return . (fromMaybe ""))
    let lib = if (p6lib == "") then plib else p6lib
    return $ filter (not . null) (libs lib $ canonicalArgs args)
    where
    -- broken, need real parser
    inclibs ("-I":dir:rest) = [dir] ++ inclibs(rest)
    inclibs (_:rest)        = inclibs(rest)
    inclibs ([])            = []
    libs p6lib args = (inclibs args)
              ++ (split (getConfig "path_sep") p6lib)
              ++ [ getConfig "archlib"
                 , getConfig "privlib"
                 , getConfig "sitearch"
                 , getConfig "sitelib"
                 , foldl1 joinFileName [getConfig "privlib", "auto", "pugs", "perl6", "lib"]
                 , foldl1 joinFileName [getConfig "sitelib", "auto", "pugs", "perl6", "lib"]
                 ]
              ++ [ "." ]

{-# NOINLINE _BypassPreludePC #-}
_BypassPreludePC :: IORef Bool
_BypassPreludePC = unsafePerformIO $ newIORef False

initPreludePC :: Env -> IO Env
initPreludePC env = do
    bypass <- readIORef _BypassPreludePC
    if bypass then return env else do
        let dispProgress = (posName . envPos $ env) == "<interactive>"
        when dispProgress $ putStr "Loading Prelude... "
        catch loadPreludePC $ \e -> do
            when (isUserError e && not (null (ioeGetErrorString e))) $ do
                hPrint stderr e
            when dispProgress $ do
                hPutStr stderr "Reloading Prelude from source..."
            evalPrelude
        when dispProgress $ putStrLn "done."
        return env
    where
    style = MkEvalStyle
        { evalResult = EvalResultModule
        , evalError  = EvalErrorFatal
        }
    evalPrelude = runEvalIO env{ envDebug = Nothing } $ opEval style "<prelude>" preludeStr
    loadPreludePC = do  -- XXX: this so wants to reuse stuff from op1EvalP6Y
        -- print "Parsing yaml..."
        incs <- liftIO $ fmap ("blib6/lib":) getLibs
        yml  <- liftIO $ getYaml incs "Prelude.pm.yml" Str.readFile
        when (nodeElem yml == YamlNil) $ fail ""
        -- FIXME: this detects an error if a bad version number was found,
        -- but not if no number was found at all. Then again, if that
        -- happens surely the fromYAML below will fail?
        case yml of
            MkYamlNode{ nodeElem=YamlSeq (v:_) }
                | MkYamlNode{ nodeElem=YamlStr vnum } <- v
                , vnum /= (packBuf $ show compUnitVersion) -> do
                    fail "incompatible version number for compilation unit"
            _ -> return ()
        -- print "Parsing done!"
        -- print "Loading yaml..."
        --(glob, ast) <- fromYAML yml
        MkCompUnit _ glob ast <- liftIO $ fromYAML yml
        -- print "Loading done!"
        liftSTM $ modifyTVar (envGlobal env) (`unionPads` glob)
        runEnv env{ envBody = ast, envDebug = Nothing }
        --     Right Nothing -> fail ""
        --     x  -> fail $ "Error loading precompiled Prelude: " ++ show x
    getYaml incs fileName loader = do
        pathName <- liftIO $ requireInc incs fileName ""
        parseYamlBytes =<< loader pathName
        

